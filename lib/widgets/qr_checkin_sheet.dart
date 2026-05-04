import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/qr_checkin_service.dart';

class QrIssuerSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final Map<String, dynamic> deviceInfo;

  const QrIssuerSheet({
    super.key,
    required this.user,
    required this.deviceInfo,
  });

  @override
  State<QrIssuerSheet> createState() => _QrIssuerSheetState();
}

class _QrIssuerSheetState extends State<QrIssuerSheet> {
  Timer? _timer;
  Map<String, dynamic>? _session;
  bool _loading = true;
  String? _error;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _loadSession();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _session == null) return;
      final expiresAt = DateTime.tryParse(_session!['expires_at']?.toString() ?? '');
      if (expiresAt == null) return;
      final left = expiresAt.difference(DateTime.now()).inSeconds;
      setState(() => _secondsLeft = left.clamp(0, 999).toInt());
      if (left <= 5 && !_loading) _loadSession();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadSession() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await QrCheckinService.createSession(
        email: widget.user['email']?.toString() ?? '',
        name: widget.user['name']?.toString() ?? '',
        deviceId: widget.deviceInfo['id']?.toString() ?? '',
      );
      if (!mounted) return;
      if (result['success'] == true) {
        final expiresAt = DateTime.tryParse(result['expires_at']?.toString() ?? '');
        setState(() {
          _session = result;
          _secondsLeft = expiresAt == null
              ? 0
              : expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 999).toInt();
        });
      } else {
        if (mounted) Navigator.of(context).pop(result['error']?.toString() ?? 'Không tạo được QR.');
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payload = _session?['payload']?.toString();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'QR check-in',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading && payload == null)
            const SizedBox(
              height: 260,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SizedBox(
              height: 220,
              child: Center(
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFB91C1C)),
                ),
              ),
            )
          else
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: payload!,
                    version: QrVersions.auto,
                    size: 240,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Hết hạn sau ${_secondsLeft}s',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.user['name']?.toString() ?? widget.user['email']?.toString() ?? '',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _loadSession,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Làm mới QR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

