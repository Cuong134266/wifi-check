import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/ether_background.dart';
import '../services/wifi_service.dart';
import '../services/device_service.dart';
import '../services/api_service.dart';

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  // --- User state ---
  Map<String, dynamic>? _user;
  Map<String, dynamic> _settings = {};
  
  // --- WiFi state ---
  Map<String, dynamic> _wifiInfo = {};
  Map<String, dynamic> _deviceInfo = {};
  bool _isCheckingIn = false;
  bool _isCheckedIn = false;
  String _wifiStatusText = 'Đang kiểm tra WiFi...';
  String _wifiSubText = 'Hệ thống sẽ ghi nhận khi có kết nối mạng công ty.';
  bool _isWifiValid = false;
  bool _isLoggingIn = false;

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
    _initData();
  }

  Future<void> _initData() async {
    _deviceInfo = await DeviceService.getInfo();
    _loadCache(); // ⚡ LOAD TỨC THÌ TỪ LOCAL CACHE
    await _checkWifi();
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
        _wifiSubText = wifiInfo['error'] ?? 'Hệ thống sẽ ghi nhận khi kết nối mạng công ty.';
        _isWifiValid = false;
      });
      return;
    }

    setState(() {
      _wifiInfo = wifiInfo;
      _wifiStatusText = 'Đã sẵn sàng điểm danh...';
      _wifiSubText = 'Bạn đang kết nối ${wifiInfo['ssid']}. Điểm danh ngay trên màn hình này.';
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
              _wifiSubText = 'Bạn đang kết nối ${_wifiInfo['ssid']}. Điểm danh ngay trên màn hình này.';
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
      if (!e.toString().contains("cancel")) _showSnackbar('Đăng nhập thất bại: $e');
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

      if (!_isWifiValid) {
        _showSnackbar('WiFi không hợp lệ để điểm danh.');
        setState(() => _isCheckingIn = false);
        return;
      }

      final res = await ApiService.checkin(_user!['email'], _wifiInfo, {});
      
      if (res['success'] == true) {
        setState(() {
          _isCheckedIn = true;
          _wifiStatusText = 'Đã hoàn tất điểm danh';
          _wifiSubText = res['checkin']?['message'] ?? 'Bạn đã ghi nhận hôm nay.';
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
      final res = await ApiService.request('history', {'email': _user!['email']});
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_user == null) const SizedBox(width: 40) else
          GestureDetector(
             onTap: _logout,
             child: const Icon(Icons.logout, color: Colors.black45, size: 20),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(200), // Glassmorphism light mode
              borderRadius: BorderRadius.circular(40),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundImage: _user != null && (_user!['avatar'] ?? '').isNotEmpty 
                      ? NetworkImage(_user!['avatar']) : null,
                  backgroundColor: Colors.blue.shade100,
                  child: _user == null 
                      ? const Icon(Icons.person, size: 16, color: Colors.black45)
                      : (_user!['avatar'] ?? '').isEmpty 
                          ? Text((_user!['name'] ?? '?')[0].toUpperCase(), style: const TextStyle(fontSize: 10))
                          : null,
                ),
                const SizedBox(width: 8),
                Text(
                  _user != null ? (_user!['name'] ?? _user!['email']).split(' ')[0] : 'Khách',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
          ),
          
          GestureDetector(
             onTap: _checkWifi,
             child: const Icon(Icons.refresh, color: Colors.black45, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_isLoggingIn || _isCheckingIn)
          const CircularProgressIndicator(color: Colors.black54)
        else
          Icon(
            _isCheckedIn ? Icons.check_circle_outline : (_isWifiValid ? Icons.wifi : Icons.wifi_off),
            size: 48,
            color: _isCheckedIn ? Colors.green : Colors.black87,
          ),
        const SizedBox(height: 24),
        Text(
          _isCheckedIn ? 'Đã hoàn tất điểm danh' : _wifiStatusText,
          style: const TextStyle(
            fontSize: 28, 
            fontWeight: FontWeight.w400,
            color: Color(0xFF1F2937),
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            _wifiSubText,
            style: const TextStyle(
              fontSize: 15, 
              fontWeight: FontWeight.w300,
              color: Color(0xFF4B5563), 
              height: 1.4,
            ),
            textAlign: TextAlign.center,
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
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
              children: [
                TextSpan(text: 'Truy cập thống kê', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w500)),
                TextSpan(text: ' để xem xếp hạng và lịch sử điểm danh của bạn.'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(200),
              borderRadius: BorderRadius.circular(40),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionPill(
                  label: _isCheckedIn ? 'Hoàn tất' : 'Điểm danh',
                  icon: Icons.download_rounded,
                  onTap: (_isCheckingIn || _isLoggingIn || _isCheckedIn || !_isWifiValid) ? null : _handleCheckin,
                  isActive: !_isCheckedIn && _isWifiValid,
                ),
                _buildActionPill(
                  label: 'Thống kê',
                  icon: Icons.upload_rounded,
                  onTap: () {
                    setState(() => _showHistory = true);
                  },
                  isActive: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPill({required String label, required IconData icon, required VoidCallback? onTap, required bool isActive}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isActive ? Colors.black.withAlpha(15) : Colors.transparent,
          borderRadius: BorderRadius.circular(36),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: isActive ? Colors.black87 : Colors.black45),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isActive ? Colors.black87 : Colors.black45)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // STATS (HISTORY + RANKING) VIEW 
  // ═══════════════════════════════════════════════
  Widget _buildStatsView() {
    return Column(
      children: [
        // Back Header & Tab Segments
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => setState(() => _showHistory = false),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 48), // balance back button
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
                              color: _statsSubTab == 0 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: _statsSubTab == 0 ? [const BoxShadow(color: Colors.black12, blurRadius: 2)] : [],
                            ),
                            child: const Center(child: Text('Cá nhân', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
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
                              color: _statsSubTab == 1 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: _statsSubTab == 1 ? [const BoxShadow(color: Colors.black12, blurRadius: 2)] : [],
                            ),
                            child: const Center(child: Text('Xếp hạng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
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
           Expanded(child: Center(child: ElevatedButton(onPressed: _ensureLoggedIn, child: const Text('Đăng nhập để xem'))))
        else
           Expanded(
             child: _statsSubTab == 0 ? _buildHistoryList() : _buildRankingList(),
           ),
      ],
    );
  }

  Widget _buildHistoryList() {
    if (_historyRecords.isEmpty && _isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_historyRecords.isEmpty) {
      return const Center(child: Text('Lịch sử hiện đang trống', style: TextStyle(color: Colors.black54)));
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
          decoration: BoxDecoration(color: Colors.white.withAlpha(200), borderRadius: BorderRadius.circular(16)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r['date'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(isLate ? 'Trễ ${r['late_minutes']} phút' : 'Đúng giờ', style: TextStyle(fontSize: 13, color: isLate ? Colors.orange : Colors.green)),
                ],
              ),
              Text(
                r['checkin_time']?.toString().substring(0, 5) ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
      return const Center(child: Text('Bảng xếp hạng đang trống', style: TextStyle(color: Colors.black54)));
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
            color: isCurrentUser ? Colors.blue.withAlpha(20) : Colors.white.withAlpha(200),
            borderRadius: BorderRadius.circular(16),
            border: isCurrentUser ? Border.all(color: Colors.blueAccent.withAlpha(50)) : null,
          ),
          child: Row(
            children: [
              SizedBox(width: 24, child: Text('${index + 1}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black.withAlpha(100)))),
              CircleAvatar(radius: 14, backgroundImage: (r['avatar'] ?? '').isNotEmpty ? NetworkImage(r['avatar']) : null, backgroundColor: Colors.black12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['name'] ?? '', style: TextStyle(fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w600)),
                    Text('${r['on_time_days'] ?? 0} lượt đúng giờ', style: const TextStyle(fontSize: 11, color: Colors.green)),
                  ],
                ),
              ),
              if ((r['late_days'] ?? 0) > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.orange.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                  child: Text('Trễ ${r['late_days']}', style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        );
      },
    );
  }
}
