import 'dart:io';

void main() {
  final file = File('lib/screens/checkin_screen.dart');
  final lines = file.readAsLinesSync();

  int startIdx = -1;
  for (int i = 1200; i < 1250; i++) {
    if (lines[i].contains('GestureDetector(')) {
      startIdx = i;
      break;
    }
  }

  int endIdx = -1;
  for (int i = startIdx; i < 1350; i++) {
    if (lines[i].contains('_buildQuickActions()')) {
      endIdx = i;
      break;
    }
  }

  if (startIdx != -1 && endIdx != -1) {
    // The previous line was 'const SizedBox(height: 8),' which we also want to remove
    final newCode = '''          LayoutBuilder(
            builder: (context, constraints) {
              const double thumbSize = 64.0;
              final double maxDrag = constraints.maxWidth - thumbSize;

              return AnimatedBuilder(
                animation: _springController,
                builder: (context, child) {
                  final double currentOffset = _isDragging
                      ? _dragOffset
                      : (_springAnimation?.value ?? _dragOffset);
                  
                  final double visualOffset = currentOffset.clamp(0.0, maxDrag);

                  return Container(
                    height: 64,
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
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCF8F3),
                            borderRadius: BorderRadius.circular(32),
                          ),
                        ),
                        Center(
                          child: Text(
                            \\'Vuốt sang phải để check-in\\',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: visualOffset > maxDrag * 0.5
                                  ? const Color(0xFF1F2937).withOpacity((1 - (visualOffset / maxDrag)).clamp(0.0, 1.0))
                                  : const Color(0xFF1F2937),
                              fontFamily: \\'Inter\\',
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
                                borderRadius: BorderRadius.circular(32),
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
          const SizedBox(height: 24),''';

    final newLines = <String>[];
    newLines.addAll(lines.sublist(0, startIdx));
    newLines.add(newCode);
    newLines.addAll(lines.sublist(endIdx - 1)); // We keep _buildQuickActions(), but omit the SizedBox(height: 8) before it
    
    file.writeAsStringSync(newLines.join('\n'));
    print('Successfully replaced swipe button.');
  } else {
    print('Failed to find startIdx (\) or endIdx (\)');
  }
}

