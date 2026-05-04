import 'package:flutter/material.dart';

import '../services/leave_service.dart';

class LeaveRequestSheet extends StatefulWidget {
  final Map<String, dynamic> user;

  const LeaveRequestSheet({super.key, required this.user});

  @override
  State<LeaveRequestSheet> createState() => _LeaveRequestSheetState();
}

class _LeaveRequestSheetState extends State<LeaveRequestSheet> {
  final TextEditingController _reasonCtrl = TextEditingController(text: 'e xin nghỉ: ');
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String _leaveType = 'morning';
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  List<dynamic> _requests = [];

  static const Map<String, String> _typeLabels = {
    'morning': 'Buổi sáng',
    'afternoon': 'Buổi chiều',
    'full_day': 'Cả ngày',
  };

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await LeaveService.getMine(widget.user['email']?.toString() ?? '');
      if (mounted) setState(() => _requests = requests);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final current = start ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      } else {
        _endDate = picked;
        if (_endDate.isBefore(_startDate)) _startDate = _endDate;
      }
    });
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await LeaveService.createRequest(
        email: widget.user['email']?.toString() ?? '',
        leaveType: _leaveType,
        startDate: _startDate,
        endDate: _endDate,
        reason: _reasonCtrl.text.trim(),
      );
      if (result['success'] != true) {
        throw Exception(result['error'] ?? 'Không gửi được đơn nghỉ.');
      }
      Navigator.of(context).pop({
        'type': _typeLabels[_leaveType] ?? _leaveType,
        'start': _formatDate(_startDate),
        'end': _formatDate(_endDate),
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  'Đăng ký nghỉ',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _DateButton(
                        label: 'Từ ngày',
                        value: _formatDate(_startDate),
                        onTap: () => _pickDate(start: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateButton(
                        label: 'Đến ngày',
                        value: _formatDate(_endDate),
                        onTap: () => _pickDate(start: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _leaveType,
                  decoration: _inputDecoration('Loại nghỉ'),
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
                  items: _typeLabels.entries
                      .map((entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Text(entry.value, style: const TextStyle(fontSize: 15)),
                            ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _leaveType = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reasonCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: _inputDecoration('Lý do'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: const Text('Gửi đăng ký'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Đơn gần đây',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                if (_loading)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ))
                else if (_requests.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'Chưa có đơn nghỉ',
                        style: TextStyle(color: Color(0xFF6B7280)),
                      ),
                    ),
                  )
                else
                  ..._requests.take(8).map(_buildRequestCard),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
    );
  }

  Widget _buildRequestCard(dynamic request) {
    final status = request['status']?.toString() ?? '';
    final color = switch (status) {
      'approved' => const Color(0xFF16A34A),
      'rejected' => const Color(0xFFDC2626),
      'cancelled' => const Color(0xFF6B7280),
      _ => const Color(0xFFF59E0B),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${request['start_date']} - ${request['end_date']}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  _typeLabels[request['leave_type']] ?? request['leave_type']?.toString() ?? '',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              _statusLabel(status),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _statusLabel(String status) {
    return switch (status) {
      'approved' => 'Đã ghi nhận',
      'rejected' => 'Từ chối',
      'cancelled' => 'Đã hủy',
      _ => 'Đang xử lý',
    };
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
