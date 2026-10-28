import 'dart:async';
import 'dart:math' as math;
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
    with TickerProviderStateMixin {
  static const double _tarotCardWidth = 252;
  static const double _tarotCardHeight = 370;
  final GlobalKey _tarotCardKey = GlobalKey();

  bool _isLoading = true;
  bool _isSuccess = false;
  bool _tarotRevealed = false;
  double _tiltX = 0;
  double _tiltY = 0;
  double _foilX = 50;
  double _foilY = 50;
  late AnimationController _fadeController;
  late AnimationController _tarotFlipController;
  late Animation<double> _tarotFlipAnimation;
  late Animation<double> _fadeAnimation;
  late final ScrollController _tarotScrollController;
  int? _scrollPointer;
  double? _scrollPointerY;
  Duration? _scrollPointerTime;
  double _scrollVelocity = 0;

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
    _tarotFlipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );
    _tarotFlipAnimation = CurvedAnimation(
      parent: _tarotFlipController,
      curve: Curves.easeInOutCubic,
    );
    if (widget.tarotCard != null) {
      Future.delayed(const Duration(milliseconds: 420), () {
        if (!mounted || _tarotRevealed) return;
        setState(() => _tarotRevealed = true);
        _tarotFlipController.forward(from: 0);
      });
    }
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
    _tarotFlipController.dispose();
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
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _handleScrollPointerDown,
              onPointerMove: _handleScrollPointerMove,
              onPointerUp: _handleScrollPointerEnd,
              onPointerCancel: _handleScrollPointerEnd,
              onPointerSignal: _handleScrollPointerSignal,
              child: SingleChildScrollView(
                controller: _tarotScrollController,
                physics: const NeverScrollableScrollPhysics(),
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
          '${card['name'] ?? ''} — ${card['vn'] ?? ''}',
          style: const TextStyle(
            color: Color(0xFF172033),
            fontSize: 30,
            height: 1.08,
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
        _buildFeaturedMeaning(
          'THÔNG ĐIỆP HÔM NAY',
          card['dailyMessage'],
          Icons.auto_awesome_rounded,
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildCompactMeaning(
                  'ĐIỀU NÊN CHÚ Ý',
                  card['caution'],
                  Icons.lightbulb_outline_rounded,
                  const Color(0xFF8A6B32),
                  const Color(0xFFFFF8E9),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactMeaning(
                  'MỘT VIỆC NHỎ',
                  card['smallAction'],
                  Icons.spa_outlined,
                  const Color(0xFF477B70),
                  const Color(0xFFEEF7F3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Container(width: 26, height: 1, color: const Color(0xFFC6AB7D)),
            const SizedBox(width: 9),
            const Text(
              'KHÁM PHÁ CHI TIẾT',
              style: TextStyle(
                color: Color(0xFF9A753B),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        _buildMeaningSection(
          'Bản thân',
          card['overview'],
          icon: Icons.person_outline_rounded,
          tint: const Color(0xFF8069A2),
        ),
        _buildMeaningSection(
          'Công việc & nguồn lực',
          card['work'],
          icon: Icons.work_outline_rounded,
          tint: const Color(0xFFB18443),
        ),
        _buildMeaningSection(
          'Mối quan hệ',
          card['love'],
          icon: Icons.favorite_border_rounded,
          tint: const Color(0xFFB66E78),
        ),
        _buildMeaningSection(
          'Góc cần cân bằng',
          card['shadow'],
          icon: Icons.balance_rounded,
          tint: const Color(0xFF718096),
        ),
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

  Widget _buildFeaturedMeaning(String label, dynamic content, IconData icon) {
    final text = content?.toString().trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(19, 18, 19, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF8E9), Color(0xFFF8F4FF)],
        ),
        border: Border.all(color: const Color(0xFFEDE2CD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF9A753B)),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF9A753B),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF263248),
              fontSize: 17,
              height: 1.65,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMeaning(
    String label,
    dynamic content,
    IconData icon,
    Color accent,
    Color background,
  ) {
    final text = content?.toString().trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accent.withValues(alpha: .13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: accent),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF526176),
              fontSize: 12,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeaningSection(
    String title,
    dynamic content, {
    required IconData icon,
    required Color tint,
  }) {
    final text = content?.toString().trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 15, 15),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE9EDF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: tint),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF172033),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              height: 1.7,
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
        border: Border.all(color: color.withValues(alpha: .25)),
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
                ? (widget.isAlreadyCheckedIn &&
                          _isCheckinTimeOnly(widget.checkinTime)
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

  bool _isCheckinTimeOnly(String? value) {
    if (value == null) return false;
    return RegExp(r'^\s*(?:Lúc\s*)?\d{1,2}:\d{2}\s*$').hasMatch(value);
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
      'assets/tarot_thumbs/$safeName.jpg',
      fit: BoxFit.contain,
      cacheWidth: 504,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => const Icon(
        Icons.broken_image_outlined,
        color: Color(0xFFC8AF7F),
        size: 42,
      ),
    );
    return Listener(
      key: _tarotCardKey,
      onPointerHover: _handleTarotPointerHover,
      onPointerMove: _handleTarotPointerMove,
      child: MouseRegion(
        onExit: (_) => _resetTarotTilt(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: false,
          onTap: _flipTarotCard,
          onPanStart: (_) => _resetScrollGesture(),
          onPanUpdate: (details) => _updateTarotTilt(details.globalPosition),
          onPanEnd: (_) => _resetTarotTilt(),
          child: SizedBox(
            width: _tarotCardWidth,
            height: _tarotCardHeight,
            child: AnimatedBuilder(
              animation: _tarotFlipAnimation,
              builder: (context, _) {
                final angle = _tarotFlipAnimation.value * math.pi;
                final showFront = angle >= math.pi / 2;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, .0012)
                    ..rotateX(_tiltX)
                    ..rotateY(_tiltY),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(angle),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (!showFront)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                color: Color(0xFFF6EFE2),
                              ),
                              child: Image.asset(
                                'assets/images/Cover.webp',
                                fit: BoxFit.cover,
                                frameBuilder:
                                    (
                                      context,
                                      child,
                                      frame,
                                      wasSynchronouslyLoaded,
                                    ) {
                                      if (wasSynchronouslyLoaded) return child;
                                      return AnimatedOpacity(
                                        opacity: frame == null ? 0 : 1,
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeOut,
                                        child: child,
                                      );
                                    },
                              ),
                            ),
                          ),
                        if (showFront)
                          Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.rotationY(math.pi),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: image,
                            ),
                          ),
                        if (showFront)
                          IgnorePointer(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: Alignment(
                                      (_foilX - 50) / 50,
                                      (_foilY - 50) / 50,
                                    ),
                                    radius: 1.15,
                                    colors: [
                                      const Color(
                                        0xFFE8D5A8,
                                      ).withValues(alpha: .20),
                                      const Color(
                                        0xFFCDBAF4,
                                      ).withValues(alpha: .15),
                                      const Color(
                                        0xFF8FD8CB,
                                      ).withValues(alpha: .12),
                                      const Color(
                                        0xFFEFB9C8,
                                      ).withValues(alpha: .14),
                                      Colors.transparent,
                                    ],
                                    stops: const [0, .24, .48, .72, 1],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (showFront)
                          IgnorePointer(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment(
                                      (_foilX - 50) / 50 - .6,
                                      -1,
                                    ),
                                    end: Alignment((_foilX - 50) / 50 + .6, 1),
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withValues(alpha: .26),
                                      const Color(
                                        0xFFFFF2D1,
                                      ).withValues(alpha: .12),
                                      Colors.transparent,
                                    ],
                                    stops: const [0, .46, .52, 1],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFC0A06C)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .16),
                                blurRadius: 22,
                                offset: const Offset(0, 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _resetScrollGesture() {
    _scrollPointer = null;
    _scrollPointerY = null;
    _scrollPointerTime = null;
    _scrollVelocity = 0;
  }

  void _updateTarotTilt(Offset globalPosition) {
    final renderObject = _tarotCardKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return;
    final position = renderObject.globalToLocal(globalPosition);
    final x = (position.dx / _tarotCardWidth * 2 - 1).clamp(-1.0, 1.0);
    final y = (position.dy / _tarotCardHeight * 2 - 1).clamp(-1.0, 1.0);
    setState(() {
      _tiltX = -y * .12;
      _tiltY = x * .16;
      _foilX = (50 + x * 38).clamp(12.0, 88.0);
      _foilY = (50 + y * 38).clamp(12.0, 88.0);
    });
  }

  void _handleTarotPointerHover(PointerEvent event) {
    _updateTarotTilt(event.position);
  }

  void _handleTarotPointerMove(PointerMoveEvent event) {
    _updateTarotTilt(event.position);
  }

  void _resetTarotTilt() {
    if (!mounted) return;
    setState(() {
      _tiltX = 0;
      _tiltY = 0;
      _foilX = 50;
      _foilY = 50;
    });
  }

  void _flipTarotCard() {
    if (_tarotRevealed) {
      _tarotFlipController.reverse();
      setState(() => _tarotRevealed = false);
    } else {
      setState(() => _tarotRevealed = true);
      _tarotFlipController.forward();
    }
  }

  void _scrollBy(double delta) {
    if (!_tarotScrollController.hasClients || delta == 0) return;
    final position = _tarotScrollController.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _tarotScrollController.jumpTo(target.toDouble());
  }

  void _flingScroll() {
    if (!_tarotScrollController.hasClients || _scrollVelocity.abs() < 20) {
      return;
    }
    final velocity = _scrollVelocity.clamp(-5000.0, 5000.0);
    _tarotScrollController.animateTo(
      (_tarotScrollController.offset + velocity * .18).clamp(
        _tarotScrollController.position.minScrollExtent,
        _tarotScrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 650),
      curve: Curves.decelerate,
    );
  }

  void _handleScrollPointerDown(PointerDownEvent event) {
    final cardRender = _tarotCardKey.currentContext?.findRenderObject();
    if (cardRender is RenderBox) {
      final cardRect = cardRender.localToGlobal(Offset.zero) & cardRender.size;
      if (cardRect.contains(event.position)) {
        _scrollPointer = null;
        _scrollPointerY = null;
        return;
      }
    }
    _scrollPointer = event.pointer;
    _scrollPointerY = event.position.dy;
    _scrollPointerTime = event.timeStamp;
    _scrollVelocity = 0;
  }

  void _handleScrollPointerMove(PointerMoveEvent event) {
    if (_scrollPointer != event.pointer || _scrollPointerY == null) return;
    final previousY = _scrollPointerY!;
    final previousTime = _scrollPointerTime ?? event.timeStamp;
    final elapsed = event.timeStamp - previousTime;
    _scrollPointerY = event.position.dy;
    _scrollPointerTime = event.timeStamp;
    _scrollBy(previousY - event.position.dy);
    if (elapsed > Duration.zero) {
      final velocity = (previousY - event.position.dy) /
          elapsed.inMicroseconds * Duration.microsecondsPerSecond;
      _scrollVelocity = _scrollVelocity * .65 + velocity * .35;
    }
  }

  void _handleScrollPointerEnd(PointerEvent event) {
    if (_scrollPointer != event.pointer) return;
    _flingScroll();
    _resetScrollGesture();
  }

  void _handleScrollPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      _scrollBy(event.scrollDelta.dy);
    }
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
