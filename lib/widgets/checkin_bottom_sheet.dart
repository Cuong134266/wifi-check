import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

// Conditional import: native dùng WebView, web dùng Image fallback
import 'checkin_map_native.dart'
    if (dart.library.html) 'checkin_map_web.dart'
    as map_impl;

class CheckinBottomSheet extends StatefulWidget {
  final Future<bool> Function() checkinTask;
  final Map<String, dynamic> locationInfo;
  final bool isAlreadyCheckedIn;
  final String? checkinTime;
  final Map<String, dynamic>? tarotCard;
  final String Function()? errorMessage;

  const CheckinBottomSheet({
    Key? key,
    required this.checkinTask,
    required this.locationInfo,
    this.isAlreadyCheckedIn = false,
    this.checkinTime,
    this.tarotCard,
    this.errorMessage,
  }) : super(key: key);

  @override
  State<CheckinBottomSheet> createState() => _CheckinBottomSheetState();
}

class _CheckinBottomSheetState extends State<CheckinBottomSheet>
    with SingleTickerProviderStateMixin {
  static const double _tarotCardWidth = 252;
  static const double _tarotCardHeight = 370;

  bool _isLoading = true;
  bool _isSuccess = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late final ScrollController _tarotScrollController;

  @override
  void initState() {
    super.initState();
    _tarotScrollController = ScrollController();
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
    _tarotScrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _waitForCheckin() async {
    try {
      final success = await widget.checkinTask();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSuccess = success;
        });
        _fadeController.forward();

        if (!success && widget.tarotCard == null) {
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
        if (widget.tarotCard == null) {
          Future.delayed(const Duration(milliseconds: 2000), () {
            if (mounted) Navigator.pop(context);
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tarotCard != null) return _buildTarotReadingSheet(context);

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

  Widget _buildTarotReadingSheet(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * .82,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                scrollbars: false,
                dragDevices: const {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                  PointerDeviceKind.stylus,
                },
              ),
              child: Scrollbar(
                controller: _tarotScrollController,
                thumbVisibility: true,
                trackVisibility: true,
                interactive: true,
                child: SingleChildScrollView(
                  controller: _tarotScrollController,
                  physics: const ClampingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(top: 8, bottom: 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 700;
                          final artwork = Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildTarotCard(),
                              const SizedBox(height: 22),
                              _buildTarotCheckinPanel(),
                            ],
                          );
                          final reading = _buildTarotReading();

                          if (compact) {
                            return Column(
                              children: [
                                artwork,
                                const SizedBox(height: 28),
                                reading,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 292, child: artwork),
                              const SizedBox(width: 38),
                              Expanded(child: reading),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                'Đóng',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarotReading() {
    final card = widget.tarotCard!;
    final keywords = card['keywords']
        .toString()
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${card['family'] ?? ''}  ·  ${card['name'] ?? ''}'.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF9A753B),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          card['vn']?.toString() ?? card['name']?.toString() ?? '',
          style: const TextStyle(
            color: Color(0xFF172033),
            fontSize: 38,
            height: 1.05,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 15),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: keywords
              .map(
                (keyword) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFF1DFC0)),
                  ),
                  child: Text(
                    keyword,
                    style: const TextStyle(
                      color: Color(0xFF8A642E),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 22),
        Text(
          card['overview']?.toString() ?? '',
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 14,
            height: 1.75,
          ),
        ),
        _buildMeaningSection('Tình cảm & kết nối', card['love']),
        _buildMeaningSection('Công việc & nguồn lực', card['work']),
        _buildMeaningSection('Mặt hạn chế cần đối chiếu', card['shadow']),
        _buildMeaningSection('Một bước cụ thể', card['action']),
        _buildMeaningSection('Thông điệp hôm nay', card['dailyMessage']),
        _buildMeaningSection('Điều nên chú ý', card['caution']),
        _buildMeaningSection('Một việc nhỏ nên làm', card['smallAction']),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 22),
          padding: const EdgeInsets.fromLTRB(18, 15, 18, 17),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(
              left: BorderSide(color: Color(0xFFC6AB7D), width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MỘT ĐIỀU ĐỂ SUY NGẪM',
                style: TextStyle(
                  color: Color(0xFF9A753B),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                card['question']?.toString() ?? '',
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 16,
                  height: 1.55,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMeaningSection(String title, dynamic content) {
    final text = content?.toString().trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 21),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF172033),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarotCheckinPanel() {
    final error = widget.errorMessage?.call().trim() ?? '';
    final distance = double.tryParse(
      widget.locationInfo['distance']?.toString() ?? '',
    );
    final now = DateTime.now();
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final color = _isLoading
        ? const Color(0xFFB38A49)
        : _isSuccess
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);
    final background = _isLoading
        ? const Color(0xFFFFFBEB)
        : _isSuccess
        ? const Color(0xFFF0FDF4)
        : const Color(0xFFFEF2F2);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Column(
        children: [
          if (_isLoading)
            SizedBox(
              width: 25,
              height: 25,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
            )
          else
            Icon(
              _isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
              color: color,
              size: 30,
            ),
          const SizedBox(height: 9),
          Text(
            _isLoading
                ? 'Đang check-in…'
                : _isSuccess
                ? 'Check-in thành công'
                : 'Không thể check-in',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF172033),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _isLoading
                ? 'Đang xác minh tài khoản, vị trí và mạng công ty.'
                : _isSuccess
                ? (widget.isAlreadyCheckedIn && widget.checkinTime != null
                      ? widget.checkinTime!
                      : 'Đã ghi nhận lúc $currentTime')
                : (error.isNotEmpty
                      ? error
                      : 'Vui lòng kiểm tra vị trí và mạng công ty.'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              height: 1.5,
            ),
          ),
          if (!_isLoading && _isSuccess && distance != null) ...[
            const SizedBox(height: 8),
            Text(
              'Cách văn phòng ${distance.round()} m',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
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
        if (widget.tarotCard != null)
          _buildTarotCard()
        else
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
        if (widget.tarotCard != null) ...[
          Text(
            '${widget.tarotCard!['vn'] ?? widget.tarotCard!['name'] ?? ''}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFFD09A45),
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 6),
        ],
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

  Widget _buildTarotCard() {
    final name = widget.tarotCard?['name']?.toString().trim() ?? '';
    final safeName = name.replaceAll(RegExp(r'\s+'), '_');
    final image = Image.asset(
      'assets/images/$safeName.webp',
      fit: BoxFit.contain,
      cacheWidth: 504,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => const Icon(
        Icons.broken_image_outlined,
        color: Color(0xFFC8AF7F),
        size: 42,
      ),
    );

    return Container(
      width: _tarotCardWidth,
      height: _tarotCardHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF111A2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC0A06C)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.16),
            blurRadius: 22,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: name.isEmpty
          ? const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFFC8AF7F),
              size: 42,
            )
          : image,
    );
  }

  Widget _buildErrorView() {
    final providedError = widget.errorMessage?.call().trim() ?? '';
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
        Text(
          providedError.isNotEmpty
              ? providedError
              : 'Vui lòng kiểm tra lại kết nối mạng hoặc liên hệ Admin',
          textAlign: TextAlign.center,
          style: const TextStyle(
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
