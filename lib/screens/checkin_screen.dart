import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/ether_background.dart';
import '../services/wifi_service.dart';
import '../services/device_service.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen>
    with TickerProviderStateMixin {
  // --- User state ---
  Map<String, dynamic>? _user;
  Map<String, dynamic> _settings = {};

  // --- Realtime Clock ---
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  // --- Animation ---
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _springController;
  Animation<double>? _springAnimation;

  // --- WiFi state ---
  Map<String, dynamic> _wifiInfo = {};
  Map<String, dynamic> _deviceInfo = {};
  bool _isCheckingIn = false;
  bool _isCheckedIn = false;
  String _wifiStatusText = 'Đang kiểm tra WiFi...';
  String _wifiSubText = 'Hệ thống sẽ ghi nhận khi có kết nối mạng công ty.';
  bool _isWifiValid = false;
  bool _isLoggingIn = false;

  // --- Location state ---
  Map<String, dynamic> _locationInfo = {};
  bool _isLocationValid = false;
  String _locationStatusText = '';

  // --- Interaction state ---
  bool _isDragging = false;
  double _dragOffset = 0.0;

  // --- Views ---
  bool _showHistory = false;
  int _statsSubTab = 0; // 0 = Cá nhân, 1 = Xếp hạng

  // --- Data ---
  List<dynamic> _historyRecords = [];
  List<dynamic> _rankingList = [];
  bool _isLoadingHistory = false;
  bool _isLoadingRanking = false;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted)
        setState(() {
          _currentTime = DateTime.now();
        });
    });

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _bounceAnimation = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _initData();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _bounceController.dispose();
    _springController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    _deviceInfo = await DeviceService.getInfo();
    _loadCache();
    await _checkWifi();
    await _checkLocation();
  }

  bool _isEarly() {
    return _currentTime.hour < 8 ||
        (_currentTime.hour == 8 && _currentTime.minute < 15);
  }

  Future<void> _checkLocation() async {
    final locInfo = await LocationService.getInfo(_settings);
    if (!mounted) return;
    setState(() {
      _locationInfo = locInfo;
      if (locInfo['available'] == true) {
        final distance = (locInfo['distance'] as double).round();
        final radius = (locInfo['radius'] as double).round();
        if (locInfo['in_range'] == true) {
          _isLocationValid = true;
          _locationStatusText = 'Trong phạm vi ($distance m / $radius m)';
        } else {
          _isLocationValid = false;
          _locationStatusText = 'Ngoài phạm vi ($distance m / $radius m)';
        }
      } else {
        _isLocationValid = false;
        _locationStatusText = locInfo['error'] ?? 'GPS không khả dụng';
      }
    });
  }

  // Khôi phục dữ liệu từ Cache (Shared Preferences) cho tốc độ 0ms
  Future<void> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final hStr = prefs.getString('cached_history');
    final rStr = prefs.getString('cached_ranking');
    setState(() {
      if (hStr != null) _historyRecords = jsonDecode(hStr);
      if (rStr != null) _rankingList = jsonDecode(rStr);
    });
  }

  Future<void> _saveCache(String key, List<dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }

  Future<void> _checkWifi() async {
    final wifiInfo = await WifiService.getInfo();
    if (!mounted) return;

    if (!wifiInfo['connected']) {
      setState(() {
        _wifiInfo = wifiInfo;
        _wifiStatusText = 'Chưa kết nối mạng nội bộ';
        _wifiSubText =
            wifiInfo['error'] ??
            'Hệ thống sẽ ghi nhận khi kết nối mạng công ty.';
        _isWifiValid = false;
      });
      return;
    }

    setState(() {
      _wifiInfo = wifiInfo;
      _wifiStatusText = 'Đã sẵn sàng điểm danh...';
      _wifiSubText =
          'Bạn đang kết nối ${wifiInfo['ssid']}. Điểm danh ngay trên màn hình này.';
      _isWifiValid = true;
    });
  }

  Future<bool> _ensureLoggedIn() async {
    if (_user != null) return true;

    setState(() => _isLoggingIn = true);
    try {
      await GoogleSignIn.instance.signOut();
      final account = await GoogleSignIn.instance.authenticate();

      final result = await ApiService.loginAndSync(
        account.email,
        account.displayName ?? '',
        account.photoUrl ?? '',
        _deviceInfo,
      );

      if (result['success'] == true) {
        if (!mounted) return false;
        setState(() {
          _user = result['employee'];
          _settings = result['settings'] ?? {};
          if (result['today_status']?['checked_in'] == true) {
            _isCheckedIn = true;
          }
        });

        // Eager fetch: tải ngầm lịch sử ngay sau khi login thành công!
        _loadHistoryBg();
        _loadRankingBg();

        if (_wifiInfo['connected'] == true) {
          final verifyResult = WifiService.verify(_wifiInfo, _settings);
          setState(() {
            if (verifyResult['verified']) {
              _wifiStatusText = 'Đã sẵn sàng điểm danh...';
              _wifiSubText =
                  'Bạn đang kết nối ${_wifiInfo['ssid']}. Điểm danh ngay trên màn hình này.';
              _isWifiValid = true;
            } else {
              _wifiStatusText = 'Mạng không hợp lệ';
              _wifiSubText = (verifyResult['reasons'] as List).join(' • ');
              _isWifiValid = false;
            }
          });
        }
        return true;
      } else {
        await GoogleSignIn.instance.signOut();
        _showSnackbar(result['error'] ?? 'Lỗi xác thực');
        return false;
      }
    } catch (e) {
      if (!e.toString().contains("cancel"))
        _showSnackbar('Đăng nhập thất bại: $e');
      return false;
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  Future<void> _handleCheckin() async {
    if (_isCheckedIn) return;

    setState(() => _isCheckingIn = true);
    try {
      if (!await _ensureLoggedIn()) {
        setState(() => _isCheckingIn = false);
        return;
      }

      if (!_isWifiValid && !_isLocationValid) {
        _showSnackbar('WiFi hoặc GPS không hợp lệ để điểm danh.');
        setState(() => _isCheckingIn = false);
        return;
      }

      final res = await ApiService.checkin(_user!['email'], _wifiInfo, {
        'latitude': _locationInfo['latitude']?.toString() ?? '',
        'longitude': _locationInfo['longitude']?.toString() ?? '',
        'gps_accuracy': _locationInfo['accuracy']?.toString() ?? '',
        'gps_distance': _locationInfo['distance']?.toString() ?? '',
        'checkin_method': _isWifiValid
            ? (_isLocationValid ? 'wifi+gps' : 'wifi')
            : 'gps',
      });

      if (res['success'] == true) {
        setState(() {
          _isCheckedIn = true;
          _wifiStatusText = 'Đã hoàn tất điểm danh';
          _wifiSubText =
              res['checkin']?['message'] ?? 'Bạn đã ghi nhận hôm nay.';
        });
        // Tự động kéo mới dữ liệu sau khi điểm danh thành công
        _loadHistoryBg();
      } else {
        if (res['already_checked_in'] == true) {
          setState(() {
            _isCheckedIn = true;
            _wifiStatusText = 'Đã điểm danh hôm nay';
            _wifiSubText = 'Lúc ${res['checkin_time']}';
          });
        } else {
          _showSnackbar(res['error'] ?? 'Lỗi không xác định');
        }
      }
    } catch (e) {
      if (e.toString().contains('đã check-in')) {
        setState(() {
          _isCheckedIn = true;
          _wifiStatusText = 'Đã điểm danh hôm nay';
        });
      } else {
        _showSnackbar(e.toString());
      }
    } finally {
      if (mounted) setState(() => _isCheckingIn = false);
    }
  }

  // Tải nền tĩnh lặng để có sẵn data trước khi mở Tab
  Future<void> _loadHistoryBg() async {
    if (_user == null) return;
    try {
      final res = await ApiService.request('history', {
        'email': _user!['email'],
      });
      if (res['success'] == true && mounted) {
        final records = res['records'] ?? [];
        setState(() => _historyRecords = records);
        _saveCache('cached_history', records);
      }
    } catch (_) {}
  }

  Future<void> _loadRankingBg() async {
    try {
      final res = await ApiService.request('ranking', {});
      if (res['success'] == true && mounted) {
        final rank = res['ranking'] ?? [];
        setState(() => _rankingList = rank);
        _saveCache('cached_ranking', rank);
      }
    } catch (_) {}
  }

  // Hàm load trực tiếp khi ở chung tab (Nếu cache chưa có)
  Future<void> _loadHistory() async {
    if (!await _ensureLoggedIn()) return;
    setState(() => _isLoadingHistory = true);
    await _loadHistoryBg();
    if (mounted) setState(() => _isLoadingHistory = false);
  }

  Future<void> _loadRanking() async {
    if (!await _ensureLoggedIn()) return;
    setState(() => _isLoadingRanking = true);
    await _loadRankingBg();
    if (mounted) setState(() => _isLoadingRanking = false);
  }

  void _showSnackbar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _logout() async {
    await GoogleSignIn.instance.signOut();
    setState(() {
      _user = null;
      _isCheckedIn = false;
      _showHistory = false;
      _checkWifi();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EtherBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: _showHistory ? _buildStatsView() : _buildHomeView(),
              ),
              if (!_showHistory) _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // TOP BAR (Profile Pill)
  // ═══════════════════════════════════════════════
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 24, left: 24, right: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              if (_user != null) setState(() => _showHistory = true);
            },
            onLongPress: _logout,
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 6, 20, 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 24,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image:
                            (_user != null &&
                                (_user!['avatar'] ?? '').isNotEmpty)
                            ? NetworkImage(_user!['avatar']) as ImageProvider
                            : const AssetImage(
                                'assets/images/default_avatar.png',
                              ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _user != null
                        ? (_user!['name'] ?? _user!['email'])
                        : 'Mạnh Cường',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      color: Color(0xFF111827),
                      fontFamily: 'Inter',
                      letterSpacing: -0.2, // Sleek tighter spacing
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getFormattedDate() {
    const weekdays = [
      'Chủ Nhật',
      'Thứ 2',
      'Thứ 3',
      'Thứ 4',
      'Thứ 5',
      'Thứ 6',
      'Thứ 7',
    ];
    final weekdayStr = _currentTime.weekday == 7
        ? weekdays[0]
        : weekdays[_currentTime.weekday];
    final day = _currentTime.day.toString().padLeft(2, '0');
    final month = _currentTime.month.toString().padLeft(2, '0');
    return '$weekdayStr, ngày $day tháng $month năm ${_currentTime.year}';
  }

  String _getFormattedTime() {
    return '${_currentTime.hour.toString().padLeft(2, '0')}:${_currentTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildHomeView() {
    final bool isEarly = _isEarly();
    final String statusText = _isCheckedIn
        ? "Đã điểm danh hôm nay"
        : (isEarly
              ? "🎉 Đang sớm checkin luôn đi"
              : "🔥 Muộn rồi checkin nhanh lên");
    final Color statusBg = _isCheckedIn
        ? const Color(0xFFE8F5E9)
        : (isEarly ? const Color(0xFFDCF8F3) : const Color(0xFFFDECEC));
    final Color statusColor = _isCheckedIn
        ? const Color(0xFF2E7D32)
        : (isEarly ? const Color(0xFF141517) : const Color(0xFFC62828));

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Center Image
        Container(
          width: 140,
          height: 140,
          child: Image.asset(
            'assets/images/img_calendar.png',
            width: 140,
            height: 140,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 32),
        // Date
        Text(
          _getFormattedDate(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF4B5563),
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 8),
        // Time
        Text(
          _getFormattedTime(),
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
            fontFamily: 'Inter',
            height: 1.1,
          ),
        ),
        const SizedBox(height: 24),
        // Status Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: statusBg,
            borderRadius: BorderRadius.circular(40),
          ),
          child: Text(
            statusText,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: statusColor,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32, left: 24, right: 24),
      child: Column(
        children: [
          GestureDetector(
            onVerticalDragStart: (details) {
              if (_isCheckingIn || _isLoggingIn || _isCheckedIn) return;
              _springController.stop();
              setState(() => _isDragging = true);
            },
            onVerticalDragUpdate: (details) {
              if (_isCheckingIn || _isLoggingIn || _isCheckedIn) return;
              setState(() {
                _dragOffset += details.primaryDelta!;
                if (_dragOffset > 0) _dragOffset = 0;
                if (_dragOffset < -200) _dragOffset = -200; // Limit drag height
              });
            },
            onVerticalDragEnd: (details) {
              if (_isCheckingIn || _isLoggingIn || _isCheckedIn) return;
              if (_dragOffset < -80 ||
                  (details.primaryVelocity != null &&
                      details.primaryVelocity! < -300)) {
                _handleCheckin();
              }
              _executeSpringBack();
            },
            onVerticalDragCancel: () {
              if (_isCheckingIn || _isLoggingIn || _isCheckedIn) return;
              _executeSpringBack();
            },
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _bounceAnimation,
                _springController,
              ]),
              builder: (context, child2) {
                final double currentSpringOffset = _springAnimation != null
                    ? _springAnimation!.value
                    : _dragOffset;
                final double bounceOffset = _isDragging
                    ? 0
                    : _bounceAnimation.value;
                final double totalOffset =
                    (_isDragging ? _dragOffset : currentSpringOffset) -
                    bounceOffset;

                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Drag Trail (Gradient shadow)
                    if (totalOffset < -2)
                      Positioned(
                        bottom: 0,
                        child: Container(
                          width: 64,
                          height: 64 + (-totalOffset),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.7),
                                Colors.black.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // The actual button
                    Transform.translate(
                      offset: Offset(0, totalOffset),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFF000000),
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: _isCheckingIn || _isLoggingIn
                            ? const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Center(
                                child: SvgPicture.asset(
                                  'assets/icons/ic_arrow_up.svg',
                                  width: 28,
                                  height: 28,
                                ),
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Vuốt lên để checkin",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: const TextSpan(
              text: "By MBBank ",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Color(0xFF94A3B8),
                fontFamily: 'Inter',
              ),
              children: [
                TextSpan(
                  text: "UXTeam",
                  style: TextStyle(
                    color: Color(0xFFEA580C),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _executeSpringBack() {
    setState(() => _isDragging = false);
    _springAnimation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _springController, curve: Curves.elasticOut),
    );
    _springController.forward(from: 0.0);
  }

  // ═══════════════════════════════════════════════
  // STATS (HISTORY + RANKING) VIEW
  // ═══════════════════════════════════════════════
  Widget _buildStatsView() {
    return Column(
      children: [
        // Back Header & Tab Segments
        Padding(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: 8,
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => setState(() => _showHistory = false),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(
                    right: 48,
                  ), // balance back button
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(150),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _statsSubTab = 0);
                            if (_historyRecords.isEmpty) _loadHistory();
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: _statsSubTab == 0
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: _statsSubTab == 0
                                  ? [
                                      const BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 2,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: const Center(
                              child: Text(
                                'Cá nhân',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _statsSubTab = 1);
                            if (_rankingList.isEmpty) _loadRanking();
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: _statsSubTab == 1
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: _statsSubTab == 1
                                  ? [
                                      const BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 2,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: const Center(
                              child: Text(
                                'Xếp hạng',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_user == null)
          Expanded(
            child: Center(
              child: ElevatedButton(
                onPressed: _ensureLoggedIn,
                child: const Text('Đăng nhập để xem'),
              ),
            ),
          )
        else
          Expanded(
            child: _statsSubTab == 0
                ? _buildHistoryList()
                : _buildRankingList(),
          ),
      ],
    );
  }

  Widget _buildHistoryList() {
    if (_historyRecords.isEmpty && _isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_historyRecords.isEmpty) {
      return const Center(
        child: Text(
          'Lịch sử hiện đang trống',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: _historyRecords.length,
      itemBuilder: (context, index) {
        final r = _historyRecords[index];
        final isLate = r['status'] == 'late';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(200),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r['date'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    isLate ? 'Trễ ${r['late_minutes']} phút' : 'Đúng giờ',
                    style: TextStyle(
                      fontSize: 13,
                      color: isLate ? Colors.orange : Colors.green,
                    ),
                  ),
                ],
              ),
              Text(
                r['checkin_time']?.toString().substring(0, 5) ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRankingList() {
    if (_rankingList.isEmpty && _isLoadingRanking) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_rankingList.isEmpty) {
      return const Center(
        child: Text(
          'Bảng xếp hạng đang trống',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: _rankingList.length,
      itemBuilder: (context, index) {
        final r = _rankingList[index];
        final isCurrentUser = _user != null && r['email'] == _user!['email'];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isCurrentUser
                ? Colors.blue.withAlpha(20)
                : Colors.white.withAlpha(200),
            borderRadius: BorderRadius.circular(16),
            border: isCurrentUser
                ? Border.all(color: Colors.blueAccent.withAlpha(50))
                : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black.withAlpha(100),
                  ),
                ),
              ),
              CircleAvatar(
                radius: 14,
                backgroundImage: (r['avatar'] ?? '').isNotEmpty
                    ? NetworkImage(r['avatar'])
                    : null,
                backgroundColor: Colors.black12,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r['name'] ?? '',
                      style: TextStyle(
                        fontWeight: isCurrentUser
                            ? FontWeight.bold
                            : FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${r['on_time_days'] ?? 0} lượt đúng giờ',
                      style: const TextStyle(fontSize: 11, color: Colors.green),
                    ),
                  ],
                ),
              ),
              if ((r['late_days'] ?? 0) > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Trễ ${r['late_days']}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
