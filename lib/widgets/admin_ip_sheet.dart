import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/public_ip_service.dart';

class AdminIpSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final String publicIp;
  final Map<String, dynamic> settings;
  final Map<String, dynamic> locationInfo;
  final bool isLocationValid;
  final ValueChanged<String>? onIpUpdated;

  const AdminIpSheet({
    super.key,
    required this.user,
    required this.publicIp,
    required this.settings,
    required this.locationInfo,
    required this.isLocationValid,
    this.onIpUpdated,
  });

  @override
  State<AdminIpSheet> createState() => _AdminIpSheetState();
}

class _AdminIpSheetState extends State<AdminIpSheet> {
  bool _isSyncing = false;
  String? _error;
  late String _officeIps;
  final Map<String, String> _resolvedDdns = {};

  @override
  void initState() {
    super.initState();
    _officeIps = (widget.settings['office_public_ip'] ?? '').toString().trim();
    _resolveDdnsItems();
  }

  void _resolveDdnsItems() {
    final list = _savedIpList;
    for (final item in list) {
      if (RegExp(r'[a-zA-Z]').hasMatch(item)) {
        PublicIpService.resolveDdns(item).then((resolved) {
          if (resolved != null && mounted) {
            setState(() {
              _resolvedDdns[item] = resolved;
            });
          }
        });
      }
    }
  }

  bool _isIpMatched(String targetIp) {
    if (targetIp.isEmpty || _officeIps.isEmpty) return false;
    final clean = targetIp.trim().replaceAll(RegExp(r'\s+'), '');
    final validList = _officeIps
        .split(RegExp(r'[,;\n\r]+'))
        .map((e) => e.replaceAll(RegExp(r'\s+'), '').trim())
        .where((e) => e.isNotEmpty)
        .toList();
    for (final pattern in validList) {
      if (pattern.endsWith('*')) {
        if (clean.startsWith(pattern.substring(0, pattern.length - 1))) return true;
      }
      if (pattern == clean) return true;
      // Khớp qua No-IP DDNS đã phân giải
      if (_resolvedDdns.containsKey(pattern) && _resolvedDdns[pattern] == clean) {
        return true;
      }
    }
    return false;
  }

  List<String> get _savedIpList {
    if (_officeIps.isEmpty) return [];
    return _officeIps
        .split(RegExp(r'[,;\n\r]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _syncIp() async {
    if (widget.publicIp.isEmpty) return;
    setState(() {
      _isSyncing = true;
      _error = null;
    });

    try {
      final res = await ApiService.updateOfficeIp(
        adminEmail: widget.user['email']?.toString() ?? '',
        newIp: widget.publicIp,
        latitude: widget.locationInfo['latitude'] is num
            ? (widget.locationInfo['latitude'] as num).toDouble()
            : null,
        longitude: widget.locationInfo['longitude'] is num
            ? (widget.locationInfo['longitude'] as num).toDouble()
            : null,
      );

      if (res['success'] == true) {
        final allIps = res['all_ips']?.toString();
        final updatedOfficeIps = (allIps != null && allIps.isNotEmpty)
            ? allIps
            : (_officeIps.isEmpty ? widget.publicIp : ', ');

        setState(() {
          _officeIps = updatedOfficeIps;
          widget.settings['office_public_ip'] = updatedOfficeIps;
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_settings', jsonEncode(widget.settings));
        widget.onIpUpdated?.call(updatedOfficeIps);

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              content: Text('🎉 Đã thêm IP () vào danh sách công ty!'),
            ),
          );
        }
      } else {
        throw Exception(res['error'] ?? 'Cập nhật IP thất bại');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMatched = _isIpMatched(widget.publicIp);
    final savedIps = _savedIpList;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Cập nhật IP văn phòng',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isMatched ? const Color(0xFFA7F3D0) : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'IP thiết bị hiện tại',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isMatched ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isMatched ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: isMatched ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isMatched ? 'Đã hợp lệ' : 'Chưa có',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isMatched ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        widget.publicIp.isNotEmpty ? widget.publicIp : 'Đang lấy IP...',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.isLocationValid ? Icons.check_circle_rounded : Icons.location_on_outlined,
                        color: widget.isLocationValid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.isLocationValid
                              ? 'Đang ở văn phòng (m) - Đủ điều kiện'
                              : 'Chưa định vị GPS hoặc ở xa văn phòng',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: widget.isLocationValid ? const Color(0xFF047857) : const Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
                  ),
                ],
                const SizedBox(height: 16),

                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: (_isSyncing || widget.publicIp.isEmpty) ? null : _syncIp,
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(
                            isMatched ? Icons.refresh_rounded : Icons.add_rounded,
                            size: 19,
                          ),
                    label: Text(
                      isMatched
                          ? 'IP này đã có (Bấm để đồng bộ lại)'
                          : 'Thêm IP này vào danh sách công ty',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Danh sách IP công ty đã lưu',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),

                if (savedIps.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'Chưa cấu hình IP công ty trên Google Sheet',
                        style: TextStyle(color: Color(0xFF6B7280)),
                      ),
                    ),
                  )
                else
                  ...savedIps.map((ip) {
                    final isDdns = RegExp(r'[a-zA-Z]').hasMatch(ip);
                    final resolved = _resolvedDdns[ip];
                    final isThisOne = (ip == widget.publicIp) || (resolved != null && resolved == widget.publicIp);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isThisOne ? const Color(0xFFA7F3D0) : const Color(0xFFE5E7EB),
                          width: isThisOne ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isDdns ? Icons.dns_rounded : Icons.router_rounded,
                            size: 20,
                            color: isThisOne ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ip,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: isThisOne ? const Color(0xFF047857) : const Color(0xFF1F2937),
                                  ),
                                ),
                                if (isDdns && resolved != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'Trỏ về IP: $resolved',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6B7280),
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isThisOne)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Đang dùng',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
