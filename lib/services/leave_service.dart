import 'api_service.dart';

class LeaveService {
  static Future<Map<String, dynamic>> createRequest({
    required String email,
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) {
    return ApiService.request('createLeaveRequest', {
      'email': email,
      'leave_type': leaveType,
      'start_date': _dateOnly(startDate),
      'end_date': _dateOnly(endDate),
      'reason': reason,
    });
  }

  static Future<List<dynamic>> getMine(String email) async {
    final result = await ApiService.request('getMyLeaveRequests', {
      'email': email,
    });
    if (result['success'] == true) {
      return result['requests'] ?? [];
    }
    throw Exception(result['error'] ?? 'Không tải được lịch nghỉ.');
  }

  static String _dateOnly(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
