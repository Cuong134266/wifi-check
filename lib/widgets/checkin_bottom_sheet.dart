import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/foundation.dart';

// Conditional import: native dùng WebView, web dùng Image fallback
import 'checkin_map_native.dart' if (dart.library.html) 'checkin_map_web.dart' as map_impl;

class CheckinBottomSheet extends StatefulWidget {
  final Future<bool> checkinFuture;
  final Map<String, dynamic> locationInfo;
  final bool isAlreadyCheckedIn;
  final String? checkinTime;

  const CheckinBottomSheet({
    Key? key,
    required this.checkinFuture,
    required this.locationInfo,
    this.isAlreadyCheckedIn = false,
    this.checkinTime,
  }) : super(key: key);

  @override
  State<CheckinBottomSheet> createState() => _CheckinBottomSheetState();
}

class _CheckinBottomSheetState extends State<CheckinBottomSheet>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isSuccess = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    if (widget.isAlreadyCheckedIn) {
      _isLoading = false;
      _isSuccess = true;
      _fadeController.forward();
    } else {
      _waitForCheckin();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _waitForCheckin() async {
    try {
      final success = await widget.checkinFuture;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSuccess = success;
        });
        _fadeController.forward();

        if (!success) {
          Future.delayed(const Duration(milliseconds: 2000), () {
            if (mounted) Navigator.pop(context);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSuccess = false;
        });
        _fadeController.forward();
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (mounted) Navigator.pop(context);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Nút Close góc trên cùng bên phải
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

              if (_isLoading) _buildSkeleton(),
              if (!_isLoading && _isSuccess)
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildSuccessView(),
                ),
              if (!_isLoading && !_isSuccess)
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildErrorView(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE5E7EB),
      highlightColor: const Color(0xFFF9FAFB),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 200,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 160,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          const SizedBox(height: 20),
          // Divider skeleton
          Container(width: double.infinity, height: 1, color: Colors.white),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    String timeString;
    if (widget.isAlreadyCheckedIn && widget.checkinTime != null) {
      final t = widget.checkinTime!;
      final match = RegExp(r'(\d{1,2}:\d{2})').firstMatch(t);
      timeString = match?.group(1) ?? t;
    } else {
      final now = DateTime.now();
      timeString =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    }

    // Lấy tọa độ
    double lat = 21.028511;
    double lng = 105.804817;
    try {
      if (widget.locationInfo['latitude'] != null) {
        lat = double.parse(widget.locationInfo['latitude'].toString());
      }
      if (widget.locationInfo['longitude'] != null) {
        lng = double.parse(widget.locationInfo['longitude'].toString());
      }
    } catch (_) {}

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // imgCheck từ Figma
        Image.asset(
          'assets/images/imgCheck.png',
          width: 140,
          height: 140,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 20),
        // Title
        const Text(
          'Checkin thành công',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
            fontFamily: 'Inter',
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        // Subtitle
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF9CA3AF),
              fontFamily: 'Inter',
            ),
            children: [
              const TextSpan(text: 'Bạn đã check vào lúc '),
              TextSpan(
                text: timeString,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE35B2C),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Divider
        Container(
          width: double.infinity,
          height: 1,
          color: const Color(0xFFE5E7EB),
        ),
        const SizedBox(height: 20),

        // MAP — sử dụng conditional import
        SizedBox(
          height: 160,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: map_impl.buildMapWidget(lat, lng),
          ),
        ),

        const SizedBox(height: 24),
        // OK Button
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
    );
  }

  Widget _buildErrorView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/imgClose.png',
          width: 140,
          height: 140,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 20),
        const Text(
          'Checkin thất bại',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
            fontFamily: 'Inter',
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Vui lòng kiểm tra lại kết nối mạng hoặc liên hệ Admin',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: Color(0xFF9CA3AF),
            fontFamily: 'Inter',
          ),
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
    );
  }
}
