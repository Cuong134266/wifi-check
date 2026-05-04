import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with SingleTickerProviderStateMixin {
  MobileScannerController? _controller;
  bool _handling = false;
  String? _error;
  late AnimationController _animationController;
  bool _hasPermission = false;
  bool _cameraReady = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initCamera();
  }

  Future<void> _initCamera() async {
    // On web, skip permission_handler (browser handles it natively)
    if (!kIsWeb) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cần quyền camera để quét QR')),
          );
        }
        return;
      }
    }

    if (!mounted) return;

    setState(() {
      _hasPermission = true;
    });

    // Create and start the controller
    final controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
    );

    setState(() {
      _controller = controller;
    });

    // On web, explicitly start after a short delay to let the widget mount
    if (kIsWeb) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      try {
        await controller.start();
        if (mounted) {
          setState(() {
            _cameraReady = true;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = 'Không thể mở camera: $e';
          });
        }
      }
    } else {
      setState(() {
        _cameraReady = true;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_handling) return;
    String? raw;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        raw = value;
        break;
      }
    }
    if (raw == null || raw.isEmpty) return;

    setState(() {
      _handling = true;
      _error = null;
    });
    
    if (mounted) Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while waiting for permission/camera
    if (!_hasPermission || _controller == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    _error ?? 'Đang yêu cầu quyền camera...',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Positioned(
              top: 50,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      );
    }

    final scanWindowSize = MediaQuery.of(context).size.width * 0.7;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera feed
          MobileScanner(
            controller: _controller!,
            onDetect: _handleDetect,
          ),
          // Show a hint if camera is still loading on web
          if (!_cameraReady)
            const Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent),
            ),
          // Custom Overlay with Cutout
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.6),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    height: scanWindowSize,
                    width: scanWindowSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Scanning Animation and Brackets
          Center(
            child: SizedBox(
              height: scanWindowSize,
              width: scanWindowSize,
              child: Stack(
                children: [
                  // Corner brackets
                  CustomPaint(
                    size: Size(scanWindowSize, scanWindowSize),
                    painter: _ScannerBracketsPainter(),
                  ),
                  // Animated Scanning Line
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Positioned(
                        top: _animationController.value * (scanWindowSize - 4),
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyanAccent.withOpacity(0.8),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // Header Overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Expanded(
                  child: Text(
                    'Quét mã QR',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 48), // Balance for centering
              ],
            ),
          ),
          // Processing Indicator
          if (_handling)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.cyanAccent),
                    SizedBox(height: 16),
                    Text(
                      'Đang xử lý...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          // Export QR Button
          Positioned(
            bottom: _error != null ? 100 : 40,
            left: 24,
            right: 24,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop('ISSUE_QR');
              },
              icon: const Icon(Icons.qr_code_rounded),
              label: const Text('Xuất mã QR của tôi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
            ),
          ),
          // Error Message
          if (_error != null)
            Positioned(
              bottom: 40,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFB91C1C).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScannerBracketsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const double cornerLength = 30.0;
    const double radius = 24.0; // Should match border radius of cutout

    // Top Left
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(radius, radius), radius: radius),
      -3.14159, 1.5708, false, paint,
    );
    canvas.drawLine(const Offset(0, radius), const Offset(0, cornerLength), paint);
    canvas.drawLine(const Offset(radius, 0), const Offset(cornerLength, 0), paint);

    // Top Right
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width - radius, radius), radius: radius),
      -1.5708, 1.5708, false, paint,
    );
    canvas.drawLine(Offset(size.width, radius), Offset(size.width, cornerLength), paint);
    canvas.drawLine(Offset(size.width - radius, 0), Offset(size.width - cornerLength, 0), paint);

    // Bottom Left
    canvas.drawArc(
      Rect.fromCircle(center: Offset(radius, size.height - radius), radius: radius),
      1.5708, 1.5708, false, paint,
    );
    canvas.drawLine(Offset(0, size.height - radius), Offset(0, size.height - cornerLength), paint);
    canvas.drawLine(Offset(radius, size.height), Offset(cornerLength, size.height), paint);

    // Bottom Right
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width - radius, size.height - radius), radius: radius),
      0, 1.5708, false, paint,
    );
    canvas.drawLine(Offset(size.width, size.height - radius), Offset(size.width, size.height - cornerLength), paint);
    canvas.drawLine(Offset(size.width - radius, size.height), Offset(size.width - cornerLength, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
