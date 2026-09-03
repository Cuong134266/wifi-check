import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/ether_background.dart';
import '../services/wifi_service.dart';
import '../services/public_ip_service.dart';
import '../services/device_service.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/qr_checkin_service.dart';
import '../widgets/checkin_bottom_sheet.dart';
import '../widgets/error_bottom_sheet.dart';
import '../widgets/leave_request_sheet.dart';
import '../widgets/qr_checkin_sheet.dart';
import 'qr_scanner_screen.dart';
import '../widgets/skeleton_card.dart';
import '../widgets/count_up_text.dart';
import '../services/web_sign_in.dart' as web;
import 'dart:math' as math;

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
  Timer? _wifiTimer;
  DateTime _currentTime = DateTime.now();

  // --- Animation ---
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _springController;
  Animation<double>? _springAnimation;

  // --- Container Transform Animation ---
  late AnimationController _expandCtrl;
  late AnimationController _headerSlideCtrl;

  // --- WiFi state ---
  Map<String, dynamic> _wifiInfo = {};
  Map<String, dynamic> _deviceInfo = {};
  bool _isCheckingIn = false;
  bool _isCheckedIn = false;
  String _wifiStatusText = 'Đang kiểm tra mạng...';
  String _wifiSubText = 'Hệ thống sẽ ghi nhận khi kết nối mạng công ty.';
  bool _isWifiValid = false;

  // --- Public IP state ---
  String _publicIp = '';
  bool _isIpValid = false;
  bool _isLoggingIn = false;

  // --- Location state ---
  Map<String, dynamic> _locationInfo = {};
  bool _isLocationValid = false;
  String _locationStatusText = '';
  bool _isFetchingLocation = false;
  bool _locationPermissionDenied = false; // true khi user đã bấm Từ chối quyền GPS

  // --- Interaction state ---
  bool _isDragging = false;
  double _dragOffset = 0.0;

  // Web auth stream
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSubscription;
  Completer<bool>? _webLoginCompleter;

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

    // Tự động kiểm tra lại mạng mỗi 30 giây (tiết kiệm tài nguyên và pin)
    _wifiTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && !_isCheckedIn) {
        _checkNetwork();
        _checkLocation();
      }
    });

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _bounceAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _headerSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Lắng nghe sự kiện đăng nhập từ Google (cần cho Web renderButton)
    _authSubscription = GoogleSignIn.instance.authenticationEvents.listen((event) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        _handleGoogleAccount(event.user);
      }
    });

    _initData();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _wifiTimer?.cancel();
    _bounceController.dispose();
    _springController.dispose();
    _expandCtrl.dispose();
    _headerSlideCtrl.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initData() async {
    _deviceInfo = await DeviceService.getInfo();
    _loadCache();
    await _restoreCachedUser(); // Khôi phục tài khoản đã lưu trước đó
    await _checkNetwork();
    
    // Mở popup hỏi quyền vị trí ngay khi vừa vào web
    await _checkLocation();
    
    // Nếu đã có user từ cache, tải dữ liệu ngầm
    if (_user != null) {
      _loadHistoryBg();
      _loadRankingBg();
    }
    // Nếu chưa có user: KHÔNG tự đăng nhập ngầm.
    // Người dùng phải tự bấm nút để chọn tài khoản.
  }

  /// Khôi phục tài khoản đã lưu từ SharedPreferences
  Future<void> _restoreCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('cached_user');
    final settingsJson = prefs.getString('cached_settings');
    if (userJson != null) {
      setState(() {
        _user = jsonDecode(userJson);
        if (settingsJson != null) _settings = jsonDecode(settingsJson);
      });
    }
  }

  /// Lưu tài khoản vào SharedPreferences
  Future<void> _saveUser(Map<String, dynamic> user, Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_user', jsonEncode(user));
    await prefs.setString('cached_settings', jsonEncode(settings));
  }

  bool _isEarly() {
    return _currentTime.hour < 8 ||
        (_currentTime.hour == 8 && _currentTime.minute < 15);
  }

  Future<void> _checkLocation() async {
    // Trên Mobile: ngăn gọi đồng thời nhiều lần, nhưng vẫn cho qua trên Web
    if (_isFetchingLocation && !kIsWeb) return;
    _isFetchingLocation = true;
    try {
      final locInfo = await LocationService.getInfo(_settings);
      if (!mounted) return;
      setState(() {
        _locationInfo = locInfo;
        final denied = locInfo['permission_denied'] == true;
        _locationPermissionDenied = denied;
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
          _locationStatusText = denied
              ? 'Quyền Vị trí bị từ chối'
              : (locInfo['error'] ?? 'GPS không khả dụng');
        }
      });
    } finally {
      _isFetchingLocation = false;
    }
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

  Future<void> _checkNetwork() async {
    final wifiInfo = await WifiService.getInfo();
    if (!mounted) return;
    _wifiInfo = wifiInfo;

    final publicIp = await PublicIpService.getPublicIp();
    if (!mounted) return;

    setState(() {
      _publicIp = publicIp;
      _wifiStatusText = 'Đã sẵn sàng điểm danh...';
      _wifiSubText = publicIp.isEmpty
          ? 'Hệ thống sẽ ghi nhận bằng GPS và QR/WiFi khi có.'
          : 'IP mạng: $publicIp • chỉ dùng để ghi log.';
      _isIpValid = true;
      _isWifiValid = true;
    });
  }
  /// Xử lý GoogleSignInAccount sau khi đăng nhập thành công (dùng chung native + web)
  Future<bool> _handleGoogleAccount(GoogleSignInAccount account) async {
    try {
      final result = await ApiService.loginAndSync(
        account.email,
        account.displayName ?? '',
        account.photoUrl ?? '',
        _deviceInfo,
      );

      if (result['success'] == true) {
        if (!mounted) return false;
        final employee = Map<String, dynamic>.from(result['employee'] as Map);
        final settings = result['settings'] != null 
            ? Map<String, dynamic>.from(result['settings'] as Map) 
            : <String, dynamic>{};
        setState(() {
          _user = employee;
          _settings = settings;
          if (result['today_status'] is Map && (result['today_status'] as Map)['checked_in'] == true) {
            _isCheckedIn = true;
          }
        });

        _saveUser(employee, settings);
        _loadHistoryBg();
        _loadRankingBg();

        // Re-verify Public IP sau khi có settings mới từ server
        _checkNetwork();

        // Nếu đang chờ web login completer, giải phóng nó
        if (_webLoginCompleter != null && !_webLoginCompleter!.isCompleted) {
          _webLoginCompleter!.complete(true);
        }
        return true;
      } else {
        await GoogleSignIn.instance.signOut();
        _showErrorPopup(result['error'] ?? 'Lỗi xác thực');
        if (_webLoginCompleter != null && !_webLoginCompleter!.isCompleted) {
          _webLoginCompleter!.complete(false);
        }
        return false;
      }
    } catch (e) {
      _showErrorPopup('Đăng nhập thất bại: $e');
      if (_webLoginCompleter != null && !_webLoginCompleter!.isCompleted) {
        _webLoginCompleter!.complete(false);
      }
      return false;
    }
  }

  Future<bool> _ensureLoggedIn() async {
    if (_user != null) return true;
    if (_isLoggingIn) return false;

    setState(() => _isLoggingIn = true);
    try {
      // Đăng nhập tương tác: yêu cầu Google hiện bảng chọn tài khoản
      // (authenticate() trên v7 = Credential Manager / Account Picker)
      if (kIsWeb) {
        // WEB: Mở dialog chứa nút đăng nhập Google chính thức
        _webLoginCompleter = Completer<bool>();
        bool dialogIsOpen = false;
        
        if (mounted) {
          dialogIsOpen = true;
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Đăng nhập bằng Google',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              content: SizedBox(
                height: 60,
                child: Center(
                  child: web.renderButton(),
                ),
              ),
            ),
          ).then((_) {
            dialogIsOpen = false;
            // User đóng dialog mà chưa đăng nhập
            if (_webLoginCompleter != null && !_webLoginCompleter!.isCompleted) {
              _webLoginCompleter!.complete(false);
            }
          });
        }
        final result = await _webLoginCompleter!.future;
        _webLoginCompleter = null;
        
        // Đóng dialog nếu vẫn đang mở (nghĩa là đăng nhập thành công và onSignInResult gọi complete(true))
        if (dialogIsOpen && mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        return result;
      } else {
        // NATIVE: Dùng authenticate() bình thường
        final authedAccount = await GoogleSignIn.instance.authenticate();
        if (authedAccount == null) return false;
        return await _handleGoogleAccount(authedAccount);
      }
    } catch (e) {
      if (!e.toString().contains("cancel") && !e.toString().contains("Popup closed")) {
        _showErrorPopup('Đăng nhập thất bại: $e');
      }
      return false;
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  Future<bool> _performCheckin() async {
    try {
      if (!await _ensureLoggedIn()) return false;

      // Đảm bảo device info đã sẵn sàng
      if (_deviceInfo.isEmpty) {
        _deviceInfo = await DeviceService.getInfo();
      }

      // Đảm bảo có Public IP (từ cache 0ms hoặc fetch nhanh)
      if (_publicIp.isEmpty) {
        _publicIp = await PublicIpService.getPublicIp();
      }

      // GATE 1: Kiểm tra Public IP khớp với công ty (0ms network vì đã có knownIp)
      final ipResult = await PublicIpService.verify(_settings, knownIp: _publicIp);
      if (ipResult['verified'] != true && ipResult['skipped'] != true) {
        _showErrorPopup('Bạn phải kết nối mạng công ty để điểm danh.\n${ipResult['reason'] ?? ''}');
        return false;
      }

      // GATE 2: Kiểm tra GPS trong bán kính công ty
      if (!_isLocationValid) {
        _showErrorPopup('Bạn phải ở trong phạm vi công ty (bán kính 2km) và cấp quyền Vị trí để điểm danh.');
        return false;
      }

      // Xác định phương thức checkin
      String checkinMethod = _isLocationValid ? 'gps' : 'manual';
      if (!kIsWeb && _wifiInfo['ssid'] != null && _wifiInfo['ssid'] != 'Web Browser') {
        checkinMethod += '+wifi';
      }

      final res = await ApiService.checkin(_user!['email'], _wifiInfo, _deviceInfo, {
        'latitude': _locationInfo['latitude']?.toString() ?? '',
        'longitude': _locationInfo['longitude']?.toString() ?? '',
        'distance': _locationInfo['distance']?.toString() ?? '',
        'public_ip': _publicIp,
        'checkin_method': checkinMethod,
      });

      if (res['success'] == true) {
        _isCheckedIn = true;
        _wifiStatusText = 'Đã hoàn tất điểm danh';
        _wifiSubText = res['checkin']?['message'] ?? 'Bạn đã ghi nhận hôm nay.';
        _loadHistoryBg();
        _loadRankingBg();
        return true;
      } else {
        if (res['already_checked_in'] == true) {
          _isCheckedIn = true;
          _wifiStatusText = 'Đã điểm danh hôm nay';
          _wifiSubText = 'Lúc ${res['checkin_time']}';
          return true;
        } else {
          _showErrorPopup(res['error'] ?? 'Lỗi không xác định');
          return false;
        }
      }
    } catch (e) {
      if (e.toString().contains('đã check-in')) {
        _isCheckedIn = true;
        _wifiStatusText = 'Đã điểm danh hôm nay';
        return true;
      } else {
        _showErrorPopup(e.toString());
        return false;
      }
    }
  }


  Future<bool> _performCheckinWithLocation(
    Future<Map<String, dynamic>> locationFuture,
  ) async {
    if (_isCheckedIn) return true;

    // Nếu location trong state chưa có hoặc chưa hợp lệ, đợi locationFuture
    if (!_isLocationValid || _locationInfo.isEmpty) {
      final locInfo = await locationFuture;
      if (!mounted) return false;
      _locationInfo = locInfo;
      _isLocationValid = locInfo['available'] == true && locInfo['in_range'] == true;
    }

    if (_publicIp.isEmpty) {
      _publicIp = await PublicIpService.getPublicIp();
    }

    return _performCheckin();
  }

  void _showCheckinResultSheet() {
    if (!mounted) return;

    // ══════════════════════════════════════════════════
    // SAFARI/CHROME GESTURE FIX:
    // Khởi động GPS NGAY TẠI ĐÂY trước bất kỳ thứ gì khác.
    // showGeneralDialog() có thể phá vỡ User Gesture context
    // vì nó schedule frame qua WidgetsBinding.
    // Nếu getInfo() được gọi bên TRONG pageBuilder thì Safari
    // và Chrome đã mất "User Gesture Token" → không bao giờ hiện popup!
    // ══════════════════════════════════════════════════
    final Future<Map<String, dynamic>> locationFuture =
        LocationService.getInfo(_settings);

    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 48.0, left: 16, right: 16),
              child: Material(
                color: Colors.transparent,
                child: CheckinBottomSheet(
                  checkinFuture: _performCheckinWithLocation(locationFuture),
                  locationInfo: _locationInfo,
                  isAlreadyCheckedIn: false,
                  checkinTime: _wifiSubText,
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: FadeTransition(
            opacity: anim1,

            child: child,
          ),
        );
      },
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  // Tải nền tĩnh lặng để có sẵn data trước khi mở Tab

  void _showQrIssuerSheet() async {
    if (!await _ensureLoggedIn()) return;
    if (!mounted || _user == null) return;

    final result = await showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      barrierDismissible: true,
      barrierLabel: 'QR',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 48.0, left: 16, right: 16),
              child: Material(
                color: Colors.transparent,
                child: QrIssuerSheet(user: _user!, deviceInfo: _deviceInfo),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );

    if (result is String && mounted) {
      _showErrorPopup(result);
    }
  }

  void _showQrScannerSheet() async {
    if (!await _ensureLoggedIn()) return;
    if (!mounted) return;

    final rawQr = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const QrScannerScreen(),
      ),
    );

    if (rawQr == 'ISSUE_QR') {
      _showQrIssuerSheet();
      return;
    }

    if (rawQr is String && mounted) {
      _showQrCheckinResultSheet(rawQr);
    }
  }

  void _showQrCheckinResultSheet(String rawQr) {
    if (!mounted) return;

    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 48.0, left: 16, right: 16),
              child: Material(
                color: Colors.transparent,
                child: CheckinBottomSheet(
                  checkinFuture: _performQrCheckin(rawQr),
                  locationInfo: _locationInfo,
                  isAlreadyCheckedIn: false,
                  checkinTime: _wifiSubText,
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<bool> _performQrCheckin(String rawQr) async {
    if (_user == null) throw Exception('Bạn cần đăng nhập trước.');

    final locInfo = (_isLocationValid && _locationInfo.isNotEmpty)
        ? _locationInfo
        : await LocationService.getInfo(_settings);
    if (locInfo['available'] != true || locInfo['in_range'] != true) {
      throw Exception('Bạn phải ở trong phạm vi công ty và cấp quyền vị trí để quét QR.');
    }

    final publicIp = _publicIp.isNotEmpty
        ? _publicIp
        : await PublicIpService.getPublicIp();
    final result = await QrCheckinService.checkinByQr(
      email: _user!['email'],
      qrPayload: rawQr,
      wifiInfo: _wifiInfo,
      deviceInfo: _deviceInfo,
      locationInfo: locInfo,
      publicIp: publicIp,
    );

    if (result['success'] == true || result['already_checked_in'] == true) {
      if (!mounted) return true;
      setState(() {
        _isCheckedIn = true;
        _locationInfo = locInfo;
        _isLocationValid = true;
        _publicIp = publicIp;
        _wifiStatusText = result['already_checked_in'] == true
            ? 'Đã điểm danh hôm nay'
            : 'Đã hoàn tất điểm danh';
        _wifiSubText = result['checkin']?['message'] ?? 'Check-in QR thành công.';
      });
      _loadHistoryBg();
      _loadRankingBg();
      return true;
    }

    throw Exception(result['error'] ?? 'Check-in QR thất bại.');
  }

  void _showLeaveRequestSheet() async {
    if (!await _ensureLoggedIn()) return;
    if (!mounted || _user == null) return;

    final result = await showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      barrierDismissible: true,
      barrierLabel: 'Leave',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0, left: 16, right: 16),
              child: Material(
                color: Colors.transparent,
                child: LeaveRequestSheet(user: _user!),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );

    if (result is Map && mounted) {
      _showLeaveSuccessSheet(result);
    }
  }

  void _showLeaveSuccessSheet(Map result) {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      barrierDismissible: true,
      barrierLabel: 'LeaveSuccess',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 48.0, left: 16, right: 16),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF3F4F6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Image.asset(
                        'assets/images/imgCheck.png',
                        width: 140,
                        height: 140,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Đăng ký thành công',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F2937),
                          fontFamily: 'Inter',
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result['start'] == result['end']
                            ? 'Đơn nghỉ ${result['type']?.toString().toLowerCase()} ngày ${result['start']} đã được ghi nhận'
                            : 'Đơn nghỉ ${result['type']?.toString().toLowerCase()} từ ${result['start']} đến ${result['end']} đã được ghi nhận',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF9CA3AF),
                          fontFamily: 'Inter',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF000000),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'OK',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }
  Future<void> _loadHistoryBg() async {
    if (_user == null) return;
    try {
      final now = DateTime.now();
      final res = await ApiService.request('history', {
        'email': _user!['email'],
        'month': now.month.toString(),
        'year': now.year.toString(),
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
      final now = DateTime.now();
      final res = await ApiService.request('ranking', {
        'month': now.month.toString(),
        'year': now.year.toString(),
      });
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

  void _showErrorPopup(String msg) {
    if (!mounted) return;
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 48.0, left: 16, right: 16),
              child: Material(
                color: Colors.transparent,
                child: ErrorBottomSheet(message: msg),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (e) {
      await GoogleSignIn.instance.signOut();
    }
    
    // Xoá cache để tránh rò rỉ dữ liệu cross-account
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_history');
      await prefs.remove('cached_ranking');
    } catch (_) {}
    
    setState(() {
      _user = null;
      _isCheckedIn = false;
      _showHistory = false;
      _historyRecords = [];
      _rankingList = [];
      _statsSubTab = 0;
      _checkNetwork();
    });
  }

  // ═══════════════════════════════════════════════
  // POPUP DIALOG: Open / Close Stats
  // ═══════════════════════════════════════════════
  void _openStats() {
    if (_user == null) return;
    _showHistory = true;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Stats',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (ctx, anim, anim2, child) {
        final curve = Curves.easeOutCubic.transform(anim.value);
        return Transform.scale(
          scale: 0.85 + (0.15 * curve),
          alignment: Alignment.topCenter,
          child: Opacity(opacity: curve, child: child),
        );
      },
      pageBuilder: (ctx, anim, anim2) {
        return _StatsPopup(
          user: _user,
          historyRecords: _historyRecords,
          rankingList: _rankingList,
          isLoadingHistory: _isLoadingHistory,
          isLoadingRanking: _isLoadingRanking,
          onClose: () => Navigator.of(ctx).pop(),
          onLoadHistory: _loadHistory,
          onLoadHistoryBg: _loadHistoryBg,
          onLoadRanking: _loadRanking,
          onLoadRankingBg: _loadRankingBg,
          onEnsureLoggedIn: _ensureLoggedIn,
          onRefreshData: () {
            // After refresh, update the popup
            setState(() {});
          },
        );
      },
    ).then((_) {
      _showHistory = false;
    });
  }

  void _closeStats() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EtherBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(child: _buildHomeView(key: const ValueKey('home'))),
              _buildFooter(),
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
              if (_user != null) _openStats();
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
                  // Avatar: ảnh mạng nếu đã login, icon mặc định nếu chưa
                  if (_user != null && (_user!['avatar'] ?? '').isNotEmpty)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: NetworkImage(_user!['avatar']),
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF3F4F6),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        size: 22,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Text(
                    _user != null
                        ? (_user!['name'] ?? _user!['email'])
                        : 'Đăng nhập',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      color: _user != null
                          ? const Color(0xFF111827)
                          : const Color(0xFF6B7280),
                      fontFamily: 'Inter',
                      letterSpacing: -0.2,
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

  Widget _buildHomeView({Key? key}) {
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

    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 84), // Dịch toàn bộ cụm lên trên thêm 24px nữa
      child: Column(
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
            fontSize: 52, // Tăng kích cỡ chữ đồng hồ lên 52px
            fontWeight: FontWeight.w700, // Làm chữ đậm thêm một chút
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
    ),
  );
}

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32, left: 24, right: 24),
      child: Column(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const double thumbSize = 52.0;
                  final double maxDrag = constraints.maxWidth - thumbSize - 10;

                  return AnimatedBuilder(
                    animation: _springController,
                    builder: (context, child) {
                      final double currentOffset = _isDragging
                          ? _dragOffset
                          : (_springAnimation?.value ?? _dragOffset);
                      
                      final double visualOffset = currentOffset.clamp(0.0, maxDrag);

                      return Container(
                        height: 64,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                              width: thumbSize + visualOffset,
                              height: 52,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCF8F3),
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            Center(
                              child: Text(
                                'Vuốt sang phải để check-in',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: visualOffset > maxDrag * 0.5
                                      ? const Color(0xFF1F2937).withOpacity((1 - (visualOffset / maxDrag)).clamp(0.0, 1.0))
                                      : const Color(0xFF1F2937),
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                            Positioned(
                              left: visualOffset,
                              child: GestureDetector(
                                onHorizontalDragStart: (details) {
                                  if (_isCheckingIn || _isLoggingIn) return;
                                  _springController.stop();
                                  setState(() => _isDragging = true);
                                },
                                onHorizontalDragUpdate: (details) {
                                  if (_isCheckingIn || _isLoggingIn) return;
                                  setState(() {
                                    _dragOffset += details.primaryDelta!;
                                    if (_dragOffset < 0) _dragOffset = 0;
                                    if (_dragOffset > maxDrag + 20) _dragOffset = maxDrag + 20;
                                  });
                                },
                                onHorizontalDragEnd: (details) {
                                  if (_isCheckingIn || _isLoggingIn) return;
                                  if (_dragOffset > maxDrag * 0.75 ||
                                      (details.primaryVelocity != null &&
                                          details.primaryVelocity! > 300)) {
                                    setState(() => _dragOffset = maxDrag);
                                    _showCheckinResultSheet();
                                    Future.delayed(const Duration(milliseconds: 500), () {
                                      if (mounted) _executeSpringBack();
                                    });
                                  } else {
                                    _executeSpringBack();
                                  }
                                },
                                onHorizontalDragCancel: () {
                                  if (_isCheckingIn || _isLoggingIn) return;
                                  _executeSpringBack();
                                },
                                child: Container(
                                  width: thumbSize,
                                  height: thumbSize,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF000000),
                                    borderRadius: BorderRadius.circular(26),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: _isCheckingIn || _isLoggingIn
                                      ? const Padding(
                                          padding: EdgeInsets.all(16.0),
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Center(
                                          child: Icon(
                                            Icons.keyboard_arrow_right_rounded,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildQuickActions(),
          const SizedBox(height: 12),
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


  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _QuickActionButton(
          icon: Icons.qr_code_scanner_rounded,
          label: 'QR',
          onTap: _showQrScannerSheet,
        ),
        const SizedBox(width: 10),
        _QuickActionButton(
          icon: Icons.event_busy_rounded,
          label: 'Xin nghỉ',
          onTap: _showLeaveRequestSheet,
        ),
      ],
    );
  }
  void _executeSpringBack() {
    final startOffset = _dragOffset;
    setState(() => _isDragging = false);
    _springAnimation = Tween<double>(begin: startOffset, end: 0.0).animate(
      CurvedAnimation(parent: _springController, curve: Curves.easeOutBack),
    );
    _springController.forward(from: 0.0);
  }
}


class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 78,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.82),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: const Color(0xFF111827)),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _HistoryCardAnimated extends StatefulWidget {
  final dynamic record;
  final bool isLate;
  final int lateMin;
  final bool isFirst;
  final bool isMaxLate;
  final Duration animDelay;

  const _HistoryCardAnimated({
    required this.record,
    required this.isLate,
    required this.lateMin,
    required this.isFirst,
    required this.isMaxLate,
    required this.animDelay,
  });

  @override
  State<_HistoryCardAnimated> createState() => _HistoryCardAnimatedState();
}

class _HistoryCardAnimatedState extends State<_HistoryCardAnimated> with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    if (widget.isFirst || widget.isMaxLate) {
      Future.delayed(widget.animDelay + const Duration(milliseconds: 300), () {
        if (mounted) {
          _pulseCtrl.forward(from: 0).then((_) => _pulseCtrl.reverse());
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_isPressed ? 0.975 : 1.0),
        transformAlignment: Alignment.center,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (widget.isFirst)
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
          ],
          border: Border.all(
            color: widget.isFirst ? const Color(0xFFF3F4F6) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.record['date'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 2),
                if (widget.isLate)
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 + (_pulseCtrl.value * 0.05),
                        alignment: Alignment.centerLeft,
                        child: child,
                      );
                    },
                    child: Row(
                      children: [
                        const Text('Trễ ', style: TextStyle(fontSize: 13, color: Colors.orange)),
                        CountUpText(
                          value: widget.lateMin,
                          suffix: ' phút',
                          delay: widget.animDelay + const Duration(milliseconds: 180),
                          duration: const Duration(milliseconds: 600),
                          style: const TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                else
                  const Text('Đúng giờ', style: TextStyle(fontSize: 13, color: Colors.green)),
              ],
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(12 * (1 - value), 0),
                    child: child,
                  ),
                );
              },
              child: Text(
                () {
                  final t = widget.record['checkin_time']?.toString() ?? '';
                  return t.length >= 5 ? t.substring(0, 5) : t;
                }(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingCardAnimated extends StatefulWidget {
  final dynamic record;
  final int index;
  final bool isCurrentUser;
  final bool isTop1;
  final int lateMinutes;
  final int lateDays;
  final int onTimeDays;
  final Duration animDelay;

  const _RankingCardAnimated({
    required this.record,
    required this.index,
    required this.isCurrentUser,
    required this.isTop1,
    required this.lateMinutes,
    required this.lateDays,
    required this.onTimeDays,
    required this.animDelay,
  });

  @override
  State<_RankingCardAnimated> createState() => _RankingCardAnimatedState();
}

class _RankingCardAnimatedState extends State<_RankingCardAnimated> with TickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _breatheCtrl;
  late AnimationController _medalCtrl;

  @override
  void initState() {
    super.initState();
    _breatheCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    if (widget.isCurrentUser) {
      _breatheCtrl.repeat(reverse: true);
    }

    _medalCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    if (widget.index < 3) {
      Future.delayed(widget.animDelay + const Duration(milliseconds: 300), () {
        if (mounted) _medalCtrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _breatheCtrl.dispose();
    _medalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const medals = ['\uD83E\uDD47', '\uD83E\uDD48', '\uD83E\uDD49'];
    final hasMedal = widget.index < 3;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedBuilder(
        animation: _breatheCtrl,
        builder: (context, child) {
          final breathe = widget.isCurrentUser ? _breatheCtrl.value : 0.0;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOutCubic,
            transform: Matrix4.identity()..scale(_isPressed ? 0.975 : 1.0),
            transformAlignment: Alignment.center,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isCurrentUser
                  ? Color.lerp(const Color(0xFFFFF7ED), const Color(0xFFFEF3C7), breathe)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isCurrentUser
                    ? const Color(0xFFFBBF24)
                    : widget.isTop1
                        ? const Color(0xFFFFE4E1)
                        : const Color(0xFFF3F4F6),
                width: widget.isCurrentUser || widget.isTop1 ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.isCurrentUser 
                      ? const Color(0xFFFBBF24).withOpacity(0.1 + breathe * 0.1) 
                      : Colors.black.withOpacity(0.04),
                  blurRadius: widget.isCurrentUser ? 12 : 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: child,
          );
        },
        child: Row(
          children: [
            // --- Rank / Medal ---
            SizedBox(
              width: 32,
              child: Center(
                child: hasMedal
                    ? AnimatedBuilder(
                        animation: CurvedAnimation(parent: _medalCtrl, curve: Curves.elasticOut),
                        builder: (context, child) {
                          final val = _medalCtrl.value == 0 ? 0.0 : CurvedAnimation(parent: _medalCtrl, curve: Curves.elasticOut).value;
                          return Transform.scale(
                            scale: 0.5 + (0.5 * val),
                            child: child,
                          );
                        },
                        child: Text(medals[widget.index], style: const TextStyle(fontSize: 20)),
                      )
                    : Text(
                        '${widget.index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.black.withOpacity(0.3),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 8),

            // --- Avatar ---
            CircleAvatar(
              radius: 18,
              backgroundImage: (widget.record['avatar'] ?? '').isNotEmpty
                  ? NetworkImage(widget.record['avatar'])
                  : null,
              backgroundColor: const Color(0xFFE5E7EB),
              child: (widget.record['avatar'] ?? '').isEmpty
                  ? Text(
                      (widget.record['name'] ?? '?').substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // --- Name + stats ---
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.record['name'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: widget.isCurrentUser
                          ? const Color(0xFFD97706)
                          : const Color(0xFF111827),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.onTimeDays} đúng giờ  •  ${widget.lateDays} muộn',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),

            // --- Late minutes badge ---
            if (widget.lateMinutes > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: widget.isTop1
                      ? const Color(0xFFFFE4E1)
                      : const Color(0xFFFFF3F0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    CountUpText(
                      value: widget.lateMinutes,
                      delay: widget.animDelay + const Duration(milliseconds: 180),
                      duration: const Duration(milliseconds: 800),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: widget.isTop1 ? const Color(0xFFEF4444) : const Color(0xFFF97316),
                      ),
                    ),
                    Text(
                      'phút',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: widget.isTop1 ? const Color(0xFFEF4444) : const Color(0xFFF97316),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '✨ Chưa muộn',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF22C55E),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// STATS POPUP DIALOG
// ============================================================================
class _StatsPopup extends StatefulWidget {
  final Map<String, dynamic>? user;
  final List<dynamic> historyRecords;
  final List<dynamic> rankingList;
  final bool isLoadingHistory;
  final bool isLoadingRanking;
  final VoidCallback onClose;
  final VoidCallback onLoadHistory;
  final Future<void> Function() onLoadHistoryBg;
  final VoidCallback onLoadRanking;
  final Future<void> Function() onLoadRankingBg;
  final VoidCallback onEnsureLoggedIn;
  final VoidCallback onRefreshData;

  const _StatsPopup({
    required this.user, required this.historyRecords, required this.rankingList,
    required this.isLoadingHistory, required this.isLoadingRanking,
    required this.onClose, required this.onLoadHistory, required this.onLoadHistoryBg,
    required this.onLoadRanking, required this.onLoadRankingBg,
    required this.onEnsureLoggedIn, required this.onRefreshData,
  });

  @override
  State<_StatsPopup> createState() => _StatsPopupState();
}

class _StatsPopupState extends State<_StatsPopup> with TickerProviderStateMixin {
  int _tab = 0;
  late AnimationController _gradientCtrl;  // white → gradient
  late AnimationController _headerCtrl;    // header slide-down
  bool _listReady = false;                 // triggers list stagger

  @override
  void initState() {
    super.initState();
    _gradientCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _headerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

    // Phase sequence: card opens (handled by showGeneralDialog 400ms)
    // → gradient fades in → header slides down + list cascades
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _gradientCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _headerCtrl.forward();
    });

    if (widget.historyRecords.isEmpty) widget.onLoadHistory();
    if (widget.rankingList.isEmpty) widget.onLoadRanking();
  }

  @override
  void dispose() {
    _gradientCtrl.dispose();
    _headerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: AnimatedBuilder(
          animation: _gradientCtrl,
          builder: (context, child) {
            final gt = Curves.easeInOut.transform(_gradientCtrl.value);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(Colors.white, const Color(0xFFF0FDF4), gt)!,
                    Color.lerp(Colors.white, const Color(0xFFFFF7ED), gt)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12 + 0.06 * gt), blurRadius: 30, offset: const Offset(0, 10))],
              ),
              child: child,
            );
          },
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                // ── Header: Tabs + X button ──
                AnimatedBuilder(
                  animation: _headerCtrl,
                  builder: (context, child) {
                    final ht = Curves.easeOutCubic.transform(_headerCtrl.value);
                    return Transform.translate(
                      offset: Offset(0, -16 * (1 - ht)),
                      child: Opacity(opacity: ht, child: child),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(20)),
                            child: LayoutBuilder(builder: (ctx, c) {
                              final hw = c.maxWidth / 2;
                              return Stack(children: [
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 350), curve: Curves.easeInOutCubic,
                                  left: _tab == 0 ? 0 : hw, top: 0, bottom: 0, width: hw,
                                  child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))])),
                                ),
                                Row(children: [_tabBtn('Cá nhân', 0), _tabBtn('Xếp hạng', 1)]),
                              ]);
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: widget.onClose,
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.06)),
                            child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF374151)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // ── List content ──
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                      child: _tab == 0
                          ? KeyedSubtree(key: const ValueKey(0), child: _buildHistoryContent())
                          : KeyedSubtree(key: const ValueKey(1), child: _buildRankingContent()),
                    ),
                  ),
                ),
                // ── OK Button (matching app black rounded style) ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      onPressed: widget.onClose,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF000000),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        elevation: 0,
                      ),
                      child: const Text('OK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Inter', letterSpacing: 0.5)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabBtn(String label, int idx) {
    return Expanded(child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _tab = idx);
        if (idx == 0) { widget.historyRecords.isEmpty ? widget.onLoadHistory() : widget.onLoadHistoryBg(); }
        else { widget.rankingList.isEmpty ? widget.onLoadRanking() : widget.onLoadRankingBg(); }
      },
      child: Center(child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        style: TextStyle(fontSize: 13, fontWeight: _tab == idx ? FontWeight.w600 : FontWeight.w400,
          color: _tab == idx ? const Color(0xFF111827) : const Color(0xFF6B7280).withOpacity(0.7)),
        child: Text(label),
      )),
    ));
  }

  Widget _buildHistoryContent() {
    if (widget.historyRecords.isEmpty && widget.isLoadingHistory) return const SkeletonList(count: 5, isRanking: false);
    if (widget.historyRecords.isEmpty) return _emptyState(widget.onLoadHistory);
    int maxLate = 0;
    for (final r in widget.historyRecords) { final lm = ((r['late_minutes'] ?? 0) as num).toInt(); if (lm > maxLate) maxLate = lm; }
    return RefreshIndicator(
      onRefresh: widget.onLoadHistoryBg, color: const Color(0xFFF97316),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: widget.historyRecords.length,
        itemBuilder: (ctx, i) {
          final r = widget.historyRecords[i];
          final isLate = r['status'] == 'late';
          final lateMin = ((r['late_minutes'] ?? 0) as num).toInt();
          // Each item gets its own delayed start for sequential reveal
          final delayMs = 300 + 60 * i;
          return _SequentialRevealItem(
            delayMs: delayMs,
            child: _HistoryCardAnimated(record: r, isLate: isLate, lateMin: lateMin, isFirst: i == 0,
              isMaxLate: isLate && lateMin == maxLate && maxLate > 0, animDelay: Duration(milliseconds: delayMs)),
          );
        },
      ),
    );
  }

  Widget _buildRankingContent() {
    if (widget.rankingList.isEmpty && widget.isLoadingRanking) return const SkeletonList(count: 5, isRanking: true);
    if (widget.rankingList.isEmpty) return _emptyState(widget.onLoadRanking);
    return RefreshIndicator(
      onRefresh: widget.onLoadRankingBg, color: const Color(0xFFF97316),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: widget.rankingList.length,
        itemBuilder: (ctx, i) {
          final r = widget.rankingList[i];
          final isCurrentUser = widget.user != null && r['email'] == widget.user!['email'];
          final lateMinutes = ((r['total_late_minutes'] ?? 0) as num).toInt();
          final lateDays = ((r['late_days'] ?? 0) as num).toInt();
          final onTimeDays = ((r['on_time_days'] ?? 0) as num).toInt();
          final delayMs = 300 + 70 * i;
          return _SequentialRevealItem(
            delayMs: delayMs,
            child: _RankingCardAnimated(record: r, index: i, isCurrentUser: isCurrentUser, isTop1: i == 0,
              lateMinutes: lateMinutes, lateDays: lateDays, onTimeDays: onTimeDays, animDelay: Duration(milliseconds: delayMs)),
          );
        },
      ),
    );
  }

  Widget _emptyState(VoidCallback onRetry) {
    return Center(child: TextButton.icon(
      onPressed: onRetry, icon: const Icon(Icons.refresh, size: 18), label: const Text('Tải lại'),
    ));
  }
}

// ── Sequential Reveal Item: each card waits its turn then slides up + fades in ──
class _SequentialRevealItem extends StatefulWidget {
  final int delayMs;
  final Widget child;
  const _SequentialRevealItem({required this.delayMs, required this.child});
  @override
  State<_SequentialRevealItem> createState() => _SequentialRevealItemState();
}

class _SequentialRevealItemState extends State<_SequentialRevealItem> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = const Cubic(0.22, 1, 0.36, 1).transform(_ctrl.value);
        return Transform.translate(
          offset: Offset(0, 32 * (1 - t)),
          child: Opacity(opacity: t, child: child),
        );
      },
      child: widget.child,
    );
  }
}




