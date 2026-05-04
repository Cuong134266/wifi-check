/**
 * UXTeam Check-in Backend - Google Apps Script
 *
 * Sheets:
 * Employees, Checkins, Devices, Settings, Raw_JSON,
 * QrSessions, QrScanLogs, LeaveRequests
 */

const SHEET_EMPLOYEES = 'Employees';
const SHEET_CHECKINS = 'Checkins';
const SHEET_DEVICES = 'Devices';
const SHEET_SETTINGS = 'Settings';
const SHEET_RAW = 'Raw_JSON';
const SHEET_QR_SESSIONS = 'QrSessions';
const SHEET_QR_SCAN_LOGS = 'QrScanLogs';
const SHEET_QR_SCAN_RAW = 'QrScanRaw';
const SHEET_LEAVE_REQUESTS = 'LeaveRequests';
const SHEET_LEAVE_RAW = 'LeaveRequestsRaw';

function doGet(e) {
  return handleRequest(e);
}

function doPost(e) {
  return handleRequest(e);
}

function handleRequest(e) {
  try {
    let params = {};
    if (e && e.postData && e.postData.contents) {
      params = JSON.parse(e.postData.contents);
    }
    if (e && e.parameter) Object.assign(params, e.parameter);

    const action = params.action;
    let result;
    switch (action) {
      case 'init':
        result = initSheets();
        break;
      case 'login':
        result = loginEmployee(params);
        break;
      case 'checkin':
        result = checkinEmployee(params);
        break;
      case 'history':
        result = getHistory(params);
        break;
      case 'ranking':
        result = getRanking(params);
        break;
      case 'today':
        result = getTodayStatus(params);
        break;
      case 'employees':
        result = getEmployees(params);
        break;
      case 'addEmployee':
        result = addEmployee(params);
        break;
      case 'removeEmployee':
        result = removeEmployee(params);
        break;
      case 'registerDevice':
        result = registerDevice(params);
        break;
      case 'resetDevice':
        result = resetDevice(params);
        break;
      case 'getSettings':
        result = getSettings();
        break;
      case 'updateSettings':
        result = updateSettings(params);
        break;
      case 'stats':
        result = getStats(params);
        break;
      case 'createQrSession':
        result = createQrSession(params);
        break;
      case 'checkinByQr':
        result = checkinByQr(params);
        break;
      case 'createLeaveRequest':
        result = createLeaveRequest(params);
        break;
      case 'getMyLeaveRequests':
        result = getMyLeaveRequests(params);
        break;
      case 'getLeaveRequests':
        result = getLeaveRequests(params);
        break;
      case 'approveLeaveRequest':
        result = approveLeaveRequest(params);
        break;
      case 'rejectLeaveRequest':
        result = rejectLeaveRequest(params);
        break;
      case 'cancelLeaveRequest':
        result = cancelLeaveRequest(params);
        break;
      case 'syncRawJsonToCheckins':
        result = syncRawJsonToCheckins();
        break;
      case 'syncQrScanRawToLogs':
        result = syncQrScanRawToLogs();
        break;
      case 'syncLeaveRawToRequests':
        result = syncLeaveRawToRequests();
        break;
      case 'syncAllRaw':
        result = syncAllRaw();
        break;
      default:
        result = { success: false, error: 'Unknown action: ' + action };
    }
    return jsonResponse(result);
  } catch (err) {
    return jsonResponse({ success: false, error: err.message || String(err) });
  }
}

function jsonResponse(data) {
  return ContentService
    .createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}

function initSheets() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  _ensureSheet(SHEET_EMPLOYEES, ['email', 'name', 'avatar', 'department', 'role', 'status', 'created_at']);
  _ensureSheet(SHEET_CHECKINS, [
    'Email', 'Tên', 'Date', 'Checkin', 'Timestamp',
    'Tên WiFi (SSID)', 'MAC WiFi', 'Public IP', 'Mã Thiết bị (ID)',
    'Tên Thiết bị / Browser', 'Vĩ độ GPS', 'Kinh độ GPS',
    'Khoảng Cách Bán Kính', 'Toạ độ Bản đồ', 'Trạng Thái',
    'Số Phút Đi Muộn', 'Ghi Chú / Phương thức', 'QR Token ID',
    'QR Người Xuất Email', 'QR Người Xuất Tên', 'QR Người Quét Email'
  ]);
  _ensureSheet(SHEET_DEVICES, ['email', 'device_id', 'device_model', 'device_os', 'registered_at', 'is_active']);
  _ensureSheet(SHEET_RAW, ['Timestamp', 'Date', 'Email', 'Type', 'Raw_JSON', 'Sync_Status']);
  _ensureSheet(SHEET_QR_SESSIONS, [
    'token_id', 'token_hash', 'issuer_email', 'issuer_name', 'issuer_device_id',
    'created_at', 'expires_at', 'used_count', 'max_uses', 'status',
    'last_used_at', 'raw_json'
  ]);
  _ensureSheet(SHEET_QR_SCAN_LOGS, [
    'timestamp', 'date', 'token_id', 'issuer_email', 'issuer_name',
    'scanner_email', 'scanner_name', 'checkin_result', 'latitude',
    'longitude', 'gps_distance', 'public_ip', 'raw_json'
  ]);
  _ensureSheet(SHEET_QR_SCAN_RAW, ['Timestamp', 'Date', 'Type', 'Raw_JSON', 'Sync_Status']);
  _ensureSheet(SHEET_LEAVE_REQUESTS, [
    'request_id', 'email', 'name', 'leave_type', 'start_date', 'end_date',
    'days', 'reason', 'status', 'approver_email', 'approver_name',
    'created_at', 'updated_at', 'note', 'raw_json'
  ]);
  _ensureSheet(SHEET_LEAVE_RAW, ['Timestamp', 'Date', 'Email', 'Type', 'Raw_JSON', 'Sync_Status']);

  const setSheet = ss.getSheetByName(SHEET_SETTINGS);
  if (setSheet.getLastRow() <= 1) {
    [
      ['office_wifi_ssid', 'UX TEAM 04, UX TEAM 04 5G, UX TEAM 06, UX TEAM 00, MB-Guest'],
      ['office_wifi_bssid', '3c:52:a1:e9:af:f3, 3c:52:a1:e9:af:f2, 40:ee:15:e3:2f:d8'],
      ['office_ip_prefix', '192.168.1., 192.168.0.'],
      ['office_public_ip', ''],
      ['office_lat', '21.0078017'],
      ['office_lng', '105.8071089'],
      ['office_radius', '2000'],
      ['qr_ttl_seconds', '90'],
      ['qr_max_uses', '30'],
      ['work_start', '08:00'],
      ['checkin_deadline', '08:15'],
      ['late_threshold_minutes', '15'],
      ['timezone', 'Asia/Ho_Chi_Minh'],
      ['company_name', 'UXTeam'],
      ['allow_multi_device', 'true'],
      ['work_days', '1,2,3,4,5,6'],
      ['ignore_emails', '']
    ].forEach(row => setSheet.appendRow(row));
  }
  return { success: true, message: 'Sheets initialized successfully' };
}

function loginEmployee(params) {
  const email = (params.email || '').toString().trim().toLowerCase();
  if (!email) return { success: false, error: 'Email is required' };
  initSheets();

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(SHEET_EMPLOYEES);
  const data = sheet.getDataRange().getValues();
  for (let i = 1; i < data.length; i++) {
    if (data[i][0].toString().toLowerCase() !== email) continue;
    if (data[i][5] === 'inactive') return { success: false, error: 'Tài khoản đã bị vô hiệu hóa' };

    if (params.name && data[i][1] !== params.name) sheet.getRange(i + 1, 2).setValue(params.name);
    if (params.avatar && data[i][2] !== params.avatar) sheet.getRange(i + 1, 3).setValue(params.avatar);
    if (params.device_id) _registerDeviceIfMissing(email, params.device_id, params.device_model, params.device_os);

    const settings = getSettingsMap();
    return {
      success: true,
      employee: {
        email: data[i][0],
        name: data[i][1] || params.name,
        avatar: data[i][2] || params.avatar,
        department: data[i][3],
        role: data[i][4] || 'user',
        status: data[i][5] || 'active'
      },
      settings: settings,
      today_status: _todayStatus(email, settings)
    };
  }
  return { success: false, error: 'Email không có trong danh sách nhân viên. Liên hệ admin.' };
}

function checkinEmployee(params) {
  const email = (params.email || '').toString().trim().toLowerCase();
  if (!email) return { success: false, error: 'Email is required' };
  initSheets();

  const employee = _getEmployeeByEmail(email);
  if (!employee) return { success: false, error: 'Nhân viên không tồn tại' };

  const settings = getSettingsMap();
  const tz = settings.timezone || 'Asia/Ho_Chi_Minh';
  const now = new Date();
  const today = Utilities.formatDate(now, tz, 'yyyy-MM-dd');
  const timeStr = Utilities.formatDate(now, tz, 'HH:mm:ss');
  const isSystemAuto = (params.device_model || '') === 'System Auto';
  const isWebClient = !params.wifi_ssid || params.wifi_ssid === 'Web Browser';
  const isQrCheckin = (params.checkin_method || '').indexOf('qr') !== -1;

  if (!isWebClient && !isSystemAuto && !isQrCheckin) {
    const wifiCheck = _verifyWifi(params, settings);
    if (!wifiCheck.success) return wifiCheck;
  }
  
  if (!isWebClient && !isSystemAuto) {
    const deviceCheck = _verifyDevice(params, settings);
    if (!deviceCheck.success) return deviceCheck;
  }

  if (!isSystemAuto && !isQrCheckin) {
    const gpsCheck = _verifyGps(params, settings);
    if (!gpsCheck.success) return gpsCheck;
  }

  const duplicate = _findTodayCheckin(email, today, tz);
  if (duplicate) {
    return {
      success: false,
      error: 'Bạn đã check-in hôm nay lúc ' + duplicate.checkin_time,
      already_checked_in: true,
      checkin_time: duplicate.checkin_time
    };
  }

  const deadline = settings.checkin_deadline || '08:15';
  const lateMinutes = Math.max(0, _minutesOf(timeStr) - _minutesOf(deadline));
  const status = lateMinutes > 0 ? 'late' : 'on_time';
  const checkinData = {
    email: email,
    wifi_ssid: params.wifi_ssid || '',
    wifi_bssid: params.wifi_bssid || '',
    ip_address: params.ip_address || '',
    signal_strength: params.signal_strength || '',
    device_id: params.device_id || '',
    device_model: params.device_model || '',
    latitude: params.latitude || '',
    longitude: params.longitude || '',
    gps_distance: params.gps_distance || '',
    public_ip: params.public_ip || '',
    checkin_method: params.checkin_method || '',
    qr_token_id: params.qr_token_id || '',
    qr_issuer_email: params.qr_issuer_email || '',
    qr_issuer_name: params.qr_issuer_name || '',
    qr_scanner_email: params.qr_scanner_email || '',
    action: 'checkin',
    checkin_time: timeStr,
    late_minutes: lateMinutes,
    status: status,
    employee_name: employee.name
  };

  SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_RAW)
    .appendRow([now.toISOString(), today, email, 'checkin', JSON.stringify(checkinData), 'pending']);

  return {
    success: true,
    checkin: {
      date: today,
      time: timeStr,
      status: status,
      late_minutes: lateMinutes,
      wifi_ssid: params.wifi_ssid || '',
      message: status === 'on_time'
        ? '✅ Check-in thành công! Đúng giờ.'
        : `⚠️ Check-in thành công! Muộn ${lateMinutes} phút.`
    }
  };
}

function createQrSession(params) {
  const email = (params.email || '').toString().trim().toLowerCase();
  if (!email) return { success: false, error: 'Email is required' };
  initSheets();

  const employee = _getEmployeeByEmail(email);
  if (!employee) return { success: false, error: 'Nhân viên không tồn tại' };

  const settings = getSettingsMap();
  const tz = settings.timezone || 'Asia/Ho_Chi_Minh';
  const today = Utilities.formatDate(new Date(), tz, 'yyyy-MM-dd');
  const canIssue = employee.role === 'admin' || _hasCheckedInToday(email, today, tz);
  if (!canIssue) return { success: false, error: 'Chỉ admin hoặc người đã check-in hôm nay mới được xuất QR.' };

  const now = new Date();
  const ttlSeconds = parseInt(settings.qr_ttl_seconds || '90', 10) || 90;
  const maxUses = parseInt(settings.qr_max_uses || '30', 10) || 30;
  const expiresAt = new Date(now.getTime() + ttlSeconds * 1000);
  const tokenId = Utilities.getUuid();
  const token = Utilities.getUuid() + '-' + Utilities.getUuid();
  const tokenHash = _sha256Hex(token);
  const raw = {
    token_id: tokenId,
    issuer_email: email,
    issuer_name: employee.name,
    issuer_device_id: params.device_id || '',
    created_at: now.toISOString(),
    expires_at: expiresAt.toISOString(),
    ttl_seconds: ttlSeconds,
    max_uses: maxUses
  };

  SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_QR_SESSIONS).appendRow([
    tokenId, tokenHash, email, employee.name, params.device_id || '',
    now.toISOString(), expiresAt.toISOString(), 0, maxUses, 'active', '',
    JSON.stringify(raw)
  ]);

  const payload = JSON.stringify({
    type: 'ux_checkin_qr',
    token: token,
    token_id: tokenId,
    issuer_email: email,
    issuer_name: employee.name,
    expires_at: expiresAt.toISOString()
  });
  return {
    success: true,
    token: token,
    payload: payload,
    token_id: tokenId,
    issuer: { email: email, name: employee.name },
    expires_at: expiresAt.toISOString(),
    ttl_seconds: ttlSeconds
  };
}

function checkinByQr(params) {
  const scannerEmail = (params.email || '').toString().trim().toLowerCase();
  const token = (params.qr_token || params.token || '').toString().trim();
  if (!scannerEmail) return { success: false, error: 'Email is required' };
  if (!token) return { success: false, error: 'QR token is required' };
  initSheets();

  const scanner = _getEmployeeByEmail(scannerEmail);
  if (!scanner) return { success: false, error: 'Nhân viên không tồn tại' };

  const session = _getQrSessionByToken(token);
  if (!session) return { success: false, error: 'QR không hợp lệ.' };
  if (session.status !== 'active') return { success: false, error: 'QR đã bị khóa hoặc hết hiệu lực.' };
  if (new Date(session.expires_at).getTime() < Date.now()) {
    _updateQrSessionStatus(session.row, 'expired');
    return { success: false, error: 'QR đã hết hạn. Vui lòng quét mã mới.' };
  }
  if (session.used_count >= session.max_uses) {
    _updateQrSessionStatus(session.row, 'used_up');
    return { success: false, error: 'QR đã đạt số lượt sử dụng tối đa.' };
  }
  if (session.issuer_email.toLowerCase() === scannerEmail) {
    return { success: false, error: 'Không thể tự quét QR của chính mình.' };
  }

  const settings = getSettingsMap();
  const tz = settings.timezone || 'Asia/Ho_Chi_Minh';
  const today = Utilities.formatDate(new Date(), tz, 'yyyy-MM-dd');
  const issuer = _getEmployeeByEmail(session.issuer_email);
  if (!issuer || (issuer.role !== 'admin' && !_hasCheckedInToday(session.issuer_email, today, tz))) {
    return { success: false, error: 'Người xuất QR chưa đủ điều kiện hoặc không còn hợp lệ.' };
  }

  const augmented = Object.assign({}, params, {
    email: scannerEmail,
    checkin_method: _appendMethod(params.checkin_method, 'qr'),
    qr_token_id: session.token_id,
    qr_issuer_email: session.issuer_email,
    qr_issuer_name: session.issuer_name,
    qr_scanner_email: scannerEmail
  });
  const result = checkinEmployee(augmented);
  if (result.success === true || result.already_checked_in === true) {
    _markQrSessionUsed(session.row, session.used_count + 1);
    _appendQrScanLog(session, scanner, augmented, result);
  }
  return result;
}

function createLeaveRequest(params) {
  const email = (params.email || '').toString().trim().toLowerCase();
  const leaveType = (params.leave_type || '').toString().trim();
  const startDate = (params.start_date || '').toString().trim();
  const endDate = (params.end_date || startDate).toString().trim();
  const reason = (params.reason || '').toString().trim();
  if (!email) return { success: false, error: 'Email is required' };
  if (!leaveType) return { success: false, error: 'Loại nghỉ là bắt buộc' };
  if (!startDate || !endDate) return { success: false, error: 'Ngày nghỉ là bắt buộc' };
  initSheets();

  const employee = _getEmployeeByEmail(email);
  if (!employee) return { success: false, error: 'Nhân viên không tồn tại' };
  const start = _parseIsoDate(startDate);
  const end = _parseIsoDate(endDate);
  if (!start || !end || end.getTime() < start.getTime()) {
    return { success: false, error: 'Khoảng ngày nghỉ không hợp lệ' };
  }

  const now = new Date();
  const requestId = Utilities.getUuid();
  const days = _countLeaveDays(start, end, leaveType);
  const raw = {
    request_id: requestId,
    email: email,
    name: employee.name,
    leave_type: leaveType,
    start_date: startDate,
    end_date: endDate,
    days: days,
    reason: reason,
    status: 'approved',
    created_at: now.toISOString()
  };
  SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_LEAVE_RAW)
    .appendRow([now.toISOString(), startDate, email, 'leave_request', JSON.stringify(raw), 'pending']);
  return { success: true, request: raw };
}

function getMyLeaveRequests(params) {
  const email = (params.email || '').toString().trim().toLowerCase();
  if (!email) return { success: false, error: 'Email is required' };
  initSheets();
  return { success: true, requests: _readLeaveRequests({ email: email }) };
}

function getLeaveRequests(params) {
  const adminEmail = (params.admin_email || '').toString().trim().toLowerCase();
  if (!isAdmin(adminEmail)) return { success: false, error: 'Unauthorized' };
  initSheets();
  syncLeaveRawToRequests();
  return { success: true, requests: _readLeaveRequests({ status: params.status || '' }) };
}

function approveLeaveRequest(params) {
  return _reviewLeaveRequest(params, 'approved');
}

function rejectLeaveRequest(params) {
  return _reviewLeaveRequest(params, 'rejected');
}

function cancelLeaveRequest(params) {
  const email = (params.email || '').toString().trim().toLowerCase();
  const requestId = (params.request_id || '').toString().trim();
  if (!email || !requestId) return { success: false, error: 'Email and request_id required' };
  initSheets();
  syncLeaveRawToRequests();

  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_LEAVE_REQUESTS);
  const data = sheet.getDataRange().getValues();
  for (let i = 1; i < data.length; i++) {
    if (data[i][0] === requestId && data[i][1].toString().toLowerCase() === email) {
      if (data[i][8] !== 'pending') return { success: false, error: 'Chỉ hủy được đơn đang chờ duyệt' };
      sheet.getRange(i + 1, 9).setValue('cancelled');
      sheet.getRange(i + 1, 13).setValue(new Date().toISOString());
      return { success: true, message: 'Đã hủy đơn nghỉ' };
    }
  }
  return { success: false, error: 'Không tìm thấy đơn nghỉ' };
}

function getHistory(params) {
  const email = (params.email || '').toString().trim().toLowerCase();
  if (!email) return { success: false, error: 'Email is required' };
  initSheets();

  const now = new Date();
  const targetMonth = params.month ? parseInt(params.month, 10) : now.getMonth() + 1;
  const targetYear = params.year ? parseInt(params.year, 10) : now.getFullYear();
  const prefix = `${targetYear}-${String(targetMonth).padStart(2, '0')}`;
  const rawData = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_RAW).getDataRange().getValues();
  const earliestByDay = {};

  for (let i = 1; i < rawData.length; i++) {
    if (rawData[i][3] !== 'checkin' || !rawData[i][4]) continue;
    const rowDate = _formatSheetDate(rawData[i][1]);
    if (rawData[i][2].toString().toLowerCase() !== email) continue;
    if (!rowDate.startsWith(prefix)) continue;
    try {
      const obj = JSON.parse(rawData[i][4]);
      const timeStr = obj.checkin_time || '99:99:99';
      if (!earliestByDay[rowDate] || timeStr < earliestByDay[rowDate].checkin_time) {
        earliestByDay[rowDate] = {
          date: rowDate,
          checkin_time: timeStr,
          wifi_ssid: obj.wifi_ssid || '',
          device_model: obj.device_model || '',
          status: obj.status,
          late_minutes: parseInt(obj.late_minutes, 10) || 0,
          checkin_method: obj.checkin_method || ''
        };
      }
    } catch (err) {}
  }

  const records = Object.values(earliestByDay).sort((a, b) => b.date.localeCompare(a.date));
  let totalLate = 0, lateDays = 0, onTimeDays = 0;
  records.forEach(r => {
    if (r.status === 'late') {
      lateDays++;
      totalLate += r.late_minutes;
    } else {
      onTimeDays++;
    }
  });
  return {
    success: true,
    month: targetMonth,
    year: targetYear,
    records: records,
    summary: {
      total_days: records.length,
      on_time_days: onTimeDays,
      late_days: lateDays,
      total_late_minutes: totalLate,
      attendance_rate: records.length > 0 ? Math.round((onTimeDays / records.length) * 100) : 0
    }
  };
}

function getTodayStatus(params) {
  const email = (params.email || '').toString().trim().toLowerCase();
  if (!email) return { success: false, error: 'Email is required' };
  initSheets();
  return Object.assign({ success: true }, _todayStatus(email, getSettingsMap()));
}

function getRanking(params) {
  initSheets();
  const now = new Date();
  const targetMonth = params.month ? parseInt(params.month, 10) : now.getMonth() + 1;
  const targetYear = params.year ? parseInt(params.year, 10) : now.getFullYear();
  const prefix = `${targetYear}-${String(targetMonth).padStart(2, '0')}`;
  const empMap = {};
  const empData = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_EMPLOYEES).getDataRange().getValues();
  for (let i = 1; i < empData.length; i++) {
    const email = empData[i][0].toString().toLowerCase();
    if (empData[i][5] === 'inactive') continue;
    empMap[email] = {
      email: empData[i][0],
      name: empData[i][1],
      avatar: empData[i][2],
      department: empData[i][3],
      late_days: 0,
      total_late_minutes: 0,
      on_time_days: 0,
      total_days: 0
    };
  }

  const rawData = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_RAW).getDataRange().getValues();
  const earliestByKey = {};
  for (let i = 1; i < rawData.length; i++) {
    if (rawData[i][3] !== 'checkin' || !rawData[i][4]) continue;
    const email = rawData[i][2].toString().toLowerCase();
    if (!empMap[email]) continue;
    const rowDate = _formatSheetDate(rawData[i][1]);
    if (!rowDate.startsWith(prefix)) continue;
    try {
      const obj = JSON.parse(rawData[i][4]);
      const key = `${email}|${rowDate}`;
      const timeStr = obj.checkin_time || '99:99:99';
      if (!earliestByKey[key] || timeStr < earliestByKey[key].checkin_time) {
        earliestByKey[key] = {
          email: email,
          status: obj.status,
          late_minutes: parseInt(obj.late_minutes, 10) || 0,
          checkin_time: timeStr
        };
      }
    } catch (err) {}
  }
  Object.values(earliestByKey).forEach(r => {
    empMap[r.email].total_days++;
    if (r.status === 'late') {
      empMap[r.email].late_days++;
      empMap[r.email].total_late_minutes += r.late_minutes;
    } else {
      empMap[r.email].on_time_days++;
    }
  });

  const ranking = Object.values(empMap)
    .filter(e => e.total_days > 0)
    .sort((a, b) => {
      if (b.total_late_minutes !== a.total_late_minutes) return b.total_late_minutes - a.total_late_minutes;
      return b.on_time_days - a.on_time_days;
    });
  ranking.forEach((r, idx) => r.rank = idx + 1);
  return { success: true, month: targetMonth, year: targetYear, ranking: ranking, total_employees: Object.keys(empMap).length };
}

function getEmployees(params) {
  if (!isAdmin(params.admin_email)) return { success: false, error: 'Unauthorized' };
  initSheets();
  const data = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_EMPLOYEES).getDataRange().getValues();
  return {
    success: true,
    employees: data.slice(1).map(r => ({
      email: r[0], name: r[1], avatar: r[2], department: r[3],
      role: r[4], status: r[5], created_at: r[6]
    }))
  };
}

function addEmployee(params) {
  if (!isAdmin(params.admin_email)) return { success: false, error: 'Unauthorized' };
  const email = (params.email || '').toString().trim().toLowerCase();
  if (!email) return { success: false, error: 'Email is required' };
  initSheets();
  if (_getEmployeeByEmail(email)) return { success: false, error: 'Email đã tồn tại' };
  SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_EMPLOYEES)
    .appendRow([email, params.name || '', '', params.department || '', params.role || 'user', 'active', new Date().toISOString()]);
  return { success: true, message: `Đã thêm nhân viên: ${email}` };
}

function removeEmployee(params) {
  if (!isAdmin(params.admin_email)) return { success: false, error: 'Unauthorized' };
  const email = (params.email || '').toString().trim().toLowerCase();
  if (!email) return { success: false, error: 'Email is required' };
  initSheets();
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_EMPLOYEES);
  const data = sheet.getDataRange().getValues();
  for (let i = 1; i < data.length; i++) {
    if (data[i][0].toString().toLowerCase() === email) {
      sheet.getRange(i + 1, 6).setValue('inactive');
      return { success: true, message: `Đã vô hiệu hóa: ${email}` };
    }
  }
  return { success: false, error: 'Không tìm thấy nhân viên' };
}

function registerDevice(params) {
  const email = (params.email || '').toString().trim().toLowerCase();
  const deviceId = (params.device_id || '').toString().trim();
  if (!email || !deviceId) return { success: false, error: 'Email and device_id required' };
  initSheets();
  return _registerDeviceIfMissing(email, deviceId, params.device_model, params.device_os);
}

function resetDevice(params) {
  if (!isAdmin(params.admin_email)) return { success: false, error: 'Unauthorized' };
  const targetEmail = (params.target_email || '').toString().trim().toLowerCase();
  if (!targetEmail) return { success: false, error: 'target_email required' };
  initSheets();
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_DEVICES);
  const data = sheet.getDataRange().getValues();
  let count = 0;
  for (let i = 1; i < data.length; i++) {
    if (data[i][0].toString().toLowerCase() === targetEmail) {
      sheet.getRange(i + 1, 6).setValue('inactive');
      count++;
    }
  }
  return { success: true, message: `Reset ${count} device(s) for ${targetEmail}` };
}

function getSettings() {
  initSheets();
  return { success: true, settings: getSettingsMap() };
}

function updateSettings(params) {
  if (!isAdmin(params.admin_email)) return { success: false, error: 'Unauthorized' };
  initSheets();
  let settings = params.settings || {};
  if (typeof settings === 'string') settings = JSON.parse(settings);
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_SETTINGS);
  const data = sheet.getDataRange().getValues();
  Object.entries(settings).forEach(([key, value]) => {
    let found = false;
    for (let i = 1; i < data.length; i++) {
      if (data[i][0] === key) {
        sheet.getRange(i + 1, 2).setValue(value);
        found = true;
        break;
      }
    }
    if (!found) sheet.appendRow([key, value]);
  });
  return { success: true, message: 'Settings updated' };
}

function getStats(params) {
  if (!isAdmin(params.admin_email)) return { success: false, error: 'Unauthorized' };
  const ranking = getRanking(params);
  const totalCheckins = ranking.ranking.reduce((sum, r) => sum + r.total_days, 0);
  const totalLate = ranking.ranking.reduce((sum, r) => sum + r.late_days, 0);
  const totalLateMinutes = ranking.ranking.reduce((sum, r) => sum + r.total_late_minutes, 0);
  return {
    success: true,
    stats: {
      total_employees: ranking.total_employees,
      total_checkins: totalCheckins,
      total_on_time: totalCheckins - totalLate,
      total_late: totalLate,
      total_late_minutes: totalLateMinutes,
      on_time_rate: totalCheckins > 0 ? Math.round(((totalCheckins - totalLate) / totalCheckins) * 100) : 0,
      month: ranking.month,
      year: ranking.year
    }
  };
}

function syncRawJsonToCheckins() {
  initSheets();
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const rawSheet = ss.getSheetByName(SHEET_RAW);
  const ciSheet = ss.getSheetByName(SHEET_CHECKINS);
  const rawData = rawSheet.getDataRange().getValues();
  const ciData = ciSheet.getDataRange().getValues();
  const processedKeys = new Set();
  for (let i = 1; i < ciData.length; i++) {
    processedKeys.add(`${_formatSheetDate(ciData[i][2])}_${ciData[i][0].toString().toLowerCase()}`);
  }

  const newRows = [];
  const rowsToMarkDone = [];
  for (let i = 1; i < rawData.length; i++) {
    const type = rawData[i][3];
    const jsonStr = rawData[i][4];
    const syncStatus = rawData[i][5] ? rawData[i][5].toString().toLowerCase() : 'pending';
    if (type !== 'checkin' || !jsonStr || syncStatus === 'done') continue;
    rowsToMarkDone.push(i + 1);
    const dateStr = _formatSheetDate(rawData[i][1]);
    const email = rawData[i][2].toString().toLowerCase();
    const key = `${dateStr}_${email}`;
    if (processedKeys.has(key)) continue;
    try {
      const obj = JSON.parse(jsonStr);
      const lat = obj.latitude || '';
      const lng = obj.longitude || '';
      const mapLink = lat && lng ? `https://www.google.com/maps?q=${lat},${lng}` : '';
      newRows.push([
        obj.email || email,
        obj.employee_name || '',
        dateStr,
        obj.checkin_time || '',
        rawData[i][0],
        obj.wifi_ssid || '',
        obj.wifi_bssid || '',
        obj.public_ip || obj.ip_address || '',
        obj.device_id || '',
        obj.device_model || '',
        lat,
        lng,
        obj.gps_distance !== undefined && obj.gps_distance !== '' ? parseFloat(obj.gps_distance).toFixed(1) + ' m' : '',
        mapLink,
        obj.status || '',
        obj.late_minutes !== undefined ? obj.late_minutes : '',
        obj.checkin_method || '',
        obj.qr_token_id || '',
        obj.qr_issuer_email || '',
        obj.qr_issuer_name || '',
        obj.qr_scanner_email || ''
      ]);
      processedKeys.add(key);
    } catch (err) {}
  }

  if (newRows.length > 0) {
    ciSheet.getRange(ciSheet.getLastRow() + 1, 1, newRows.length, 21).setValues(newRows);
  }
  rowsToMarkDone.forEach(rowIdx => rawSheet.getRange(rowIdx, 6).setValue('DONE'));
  return { success: true, count: newRows.length, updated_raws: rowsToMarkDone.length };
}

function syncQrScanRawToLogs() {
  initSheets();
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const rawSheet = ss.getSheetByName(SHEET_QR_SCAN_RAW);
  const logSheet = ss.getSheetByName(SHEET_QR_SCAN_LOGS);
  const rawData = rawSheet.getDataRange().getValues();
  const logData = logSheet.getDataRange().getValues();
  const processed = new Set();

  for (let i = 1; i < logData.length; i++) {
    processed.add(String(logData[i][2] || '') + '_' + String(logData[i][5] || '').toLowerCase());
  }

  const newRows = [];
  const rowsToMarkDone = [];
  for (let i = 1; i < rawData.length; i++) {
    const type = rawData[i][2];
    const jsonStr = rawData[i][3];
    const syncStatus = rawData[i][4] ? rawData[i][4].toString().toLowerCase() : 'pending';
    if (type !== 'qr_scan' || !jsonStr || syncStatus === 'done') continue;
    rowsToMarkDone.push(i + 1);
    try {
      const obj = JSON.parse(jsonStr);
      const key = String(obj.token_id || '') + '_' + String(obj.scanner_email || '').toLowerCase();
      if (processed.has(key)) continue;
      newRows.push([
        obj.timestamp || rawData[i][0],
        obj.date || rawData[i][1],
        obj.token_id || '',
        obj.issuer_email || '',
        obj.issuer_name || '',
        obj.scanner_email || '',
        obj.scanner_name || '',
        obj.checkin_result || '',
        obj.latitude || '',
        obj.longitude || '',
        obj.gps_distance || '',
        obj.public_ip || '',
        jsonStr
      ]);
      processed.add(key);
    } catch (err) {}
  }

  if (newRows.length > 0) {
    logSheet.getRange(logSheet.getLastRow() + 1, 1, newRows.length, 13).setValues(newRows);
  }
  rowsToMarkDone.forEach(rowIdx => rawSheet.getRange(rowIdx, 5).setValue('DONE'));
  return { success: true, count: newRows.length, updated_raws: rowsToMarkDone.length };
}

function syncLeaveRawToRequests() {
  initSheets();
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const rawSheet = ss.getSheetByName(SHEET_LEAVE_RAW);
  const requestSheet = ss.getSheetByName(SHEET_LEAVE_REQUESTS);
  const rawData = rawSheet.getDataRange().getValues();
  const requestData = requestSheet.getDataRange().getValues();
  const processed = new Set();

  for (let i = 1; i < requestData.length; i++) {
    processed.add(String(requestData[i][0] || ''));
  }

  const newRows = [];
  const rowsToMarkDone = [];
  for (let i = 1; i < rawData.length; i++) {
    const type = rawData[i][3];
    const jsonStr = rawData[i][4];
    const syncStatus = rawData[i][5] ? rawData[i][5].toString().toLowerCase() : 'pending';
    if (type !== 'leave_request' || !jsonStr || syncStatus === 'done') continue;
    rowsToMarkDone.push(i + 1);
    try {
      const obj = JSON.parse(jsonStr);
      if (processed.has(obj.request_id)) continue;
      newRows.push([
        obj.request_id || '',
        obj.email || rawData[i][2] || '',
        obj.name || '',
        obj.leave_type || '',
        obj.start_date || '',
        obj.end_date || '',
        obj.days || '',
        obj.reason || '',
        obj.status || 'approved',
        obj.approver_email || '',
        obj.approver_name || '',
        obj.created_at || rawData[i][0],
        obj.updated_at || obj.created_at || rawData[i][0],
        obj.note || '',
        jsonStr
      ]);
      processed.add(obj.request_id);
    } catch (err) {}
  }

  if (newRows.length > 0) {
    requestSheet.getRange(requestSheet.getLastRow() + 1, 1, newRows.length, 15).setValues(newRows);
  }
  rowsToMarkDone.forEach(rowIdx => rawSheet.getRange(rowIdx, 6).setValue('DONE'));
  return { success: true, count: newRows.length, updated_raws: rowsToMarkDone.length };
}

function syncAllRaw() {
  return {
    success: true,
    checkins: syncRawJsonToCheckins(),
    qr_scans: syncQrScanRawToLogs(),
    leaves: syncLeaveRawToRequests()
  };
}

function getSettingsMap() {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_SETTINGS);
  if (!sheet) return {};
  const data = sheet.getDataRange().getValues();
  const map = {};
  for (let i = 1; i < data.length; i++) {
    let val = data[i][1];
    if (val instanceof Date) {
      val = String(val.getHours()).padStart(2, '0') + ':' + String(val.getMinutes()).padStart(2, '0');
    }
    map[data[i][0]] = val === undefined || val === null ? '' : val.toString();
  }
  return map;
}

function isAdmin(email) {
  const employee = _getEmployeeByEmail((email || '').toString().trim().toLowerCase());
  return !!employee && employee.role === 'admin';
}

function _ensureSheet(name, headers) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = ss.getSheetByName(name);
  if (!sheet) sheet = ss.insertSheet(name);
  if (sheet.getLastRow() === 0) {
    sheet.appendRow(headers);
    sheet.getRange('1:1').setFontWeight('bold');
  }
  return sheet;
}

function _getEmployeeByEmail(email) {
  if (!email) return null;
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_EMPLOYEES);
  if (!sheet) return null;
  const data = sheet.getDataRange().getValues();
  for (let i = 1; i < data.length; i++) {
    if (data[i][0].toString().toLowerCase() === email.toLowerCase()) {
      if (data[i][5] === 'inactive') return null;
      return {
        email: data[i][0],
        name: data[i][1],
        avatar: data[i][2],
        department: data[i][3],
        role: data[i][4] || 'user',
        status: data[i][5] || 'active'
      };
    }
  }
  return null;
}

function _registerDeviceIfMissing(email, deviceId, deviceModel, deviceOs) {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_DEVICES);
  const data = sheet.getDataRange().getValues();
  const settings = getSettingsMap();
  const allowMulti = settings.allow_multi_device === 'true' || settings.allow_multi_device === 'TRUE';

  for (let i = 1; i < data.length; i++) {
    if (data[i][0].toString().toLowerCase() === email && data[i][1] === deviceId) {
      return { success: true, message: 'Device already registered', already_registered: true };
    }
  }
  if (!allowMulti) {
    for (let i = 1; i < data.length; i++) {
      if (data[i][0].toString().toLowerCase() === email && data[i][5] === 'active') {
        return { success: false, error: 'Tài khoản đã được liên kết với thiết bị khác.' };
      }
    }
  }
  sheet.appendRow([email, deviceId, deviceModel || 'Unknown', deviceOs || 'Unknown', new Date().toISOString(), 'active']);
  return { success: true, message: 'Device registered successfully' };
}

function _verifyWifi(params, settings) {
  const officeSsid = settings.office_wifi_ssid || '';
  const officeBssid = settings.office_wifi_bssid || '';
  const officeIpPrefix = settings.office_ip_prefix || '';
  if (officeSsid) {
    const validSsids = officeSsid.split(',').map(s => s.trim()).filter(Boolean);
    if (validSsids.length > 0 && validSsids.indexOf(params.wifi_ssid || '') === -1) {
      return { success: false, error: `WiFi không đúng. Yêu cầu: ${officeSsid}, Hiện tại: ${params.wifi_ssid || 'Không kết nối'}` };
    }
  }
  if (officeBssid && params.wifi_bssid) {
    const validBssids = officeBssid.split(',').map(s => s.trim().toLowerCase()).filter(Boolean);
    if (validBssids.length > 0 && validBssids.indexOf(params.wifi_bssid.toLowerCase()) === -1) {
      return { success: false, error: 'BSSID router không khớp.' };
    }
  }
  if (officeIpPrefix && params.ip_address) {
    const validPrefixes = officeIpPrefix.split(',').map(s => s.trim()).filter(Boolean);
    if (validPrefixes.length > 0 && !validPrefixes.some(prefix => params.ip_address.startsWith(prefix))) {
      return { success: false, error: 'IP address không thuộc mạng nội bộ công ty.' };
    }
  }
  return { success: true };
}

function _verifyDevice(params, settings) {
  if (!params.device_id || settings.allow_multi_device === 'true' || settings.allow_multi_device === 'TRUE') {
    return { success: true };
  }
  const data = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_DEVICES).getDataRange().getValues();
  for (let i = 1; i < data.length; i++) {
    if (data[i][0].toString().toLowerCase() === params.email.toString().toLowerCase()
      && data[i][1] === params.device_id && data[i][5] === 'active') {
      return { success: true };
    }
  }
  return { success: false, error: 'Thiết bị chưa được đăng ký. Liên hệ admin.' };
}

function _verifyGps(params, settings) {
  const officeLat = parseFloat(settings.office_lat || '0');
  const officeLng = parseFloat(settings.office_lng || '0');
  const officeRadius = parseFloat(settings.office_radius || '2000');
  if (!officeLat || !officeLng) return { success: true };
  if (!params.latitude || !params.longitude) return { success: false, error: 'Cần cấp quyền vị trí để check-in.' };
  const lat = parseFloat(params.latitude);
  const lng = parseFloat(params.longitude);
  if (!lat || !lng) return { success: false, error: 'Tọa độ GPS không hợp lệ.' };
  const dist = _haversineDistance(lat, lng, officeLat, officeLng);
  if (dist > officeRadius) {
    return { success: false, error: `Bạn đang ở ngoài phạm vi công ty (${Math.round(dist)}m / ${Math.round(officeRadius)}m).` };
  }
  return { success: true, distance: dist };
}

function _todayStatus(email, settings) {
  const tz = settings.timezone || 'Asia/Ho_Chi_Minh';
  const today = Utilities.formatDate(new Date(), tz, 'yyyy-MM-dd');
  const found = _findTodayCheckin(email, today, tz);
  return found ? { checked_in: true, checkin_time: found.checkin_time, status: found.status } : { checked_in: false };
}

function _findTodayCheckin(email, today, tz) {
  const rawSheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_RAW);
  if (!rawSheet) return null;
  const rawData = rawSheet.getDataRange().getValues();
  for (let i = 1; i < rawData.length; i++) {
    if (rawData[i][3] !== 'checkin' || !rawData[i][4]) continue;
    let rawDate = rawData[i][1];
    rawDate = rawDate instanceof Date ? Utilities.formatDate(rawDate, tz, 'yyyy-MM-dd') : rawDate.toString();
    if (rawData[i][2].toString().toLowerCase() === email.toLowerCase() && rawDate === today) {
      try {
        const obj = JSON.parse(rawData[i][4]);
        return { checkin_time: obj.checkin_time || '', status: obj.status || '' };
      } catch (err) {
        return { checkin_time: '', status: '' };
      }
    }
  }
  return null;
}

function _hasCheckedInToday(email, today, tz) {
  return !!_findTodayCheckin(email, today, tz);
}

function _getQrSessionByToken(token) {
  const hash = _sha256Hex(token);
  const data = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_QR_SESSIONS).getDataRange().getValues();
  for (let i = 1; i < data.length; i++) {
    if (data[i][1] === hash) {
      return {
        row: i + 1,
        token_id: data[i][0],
        issuer_email: data[i][2],
        issuer_name: data[i][3],
        issuer_device_id: data[i][4],
        created_at: data[i][5],
        expires_at: data[i][6],
        used_count: parseInt(data[i][7], 10) || 0,
        max_uses: parseInt(data[i][8], 10) || 1,
        status: data[i][9] || 'active'
      };
    }
  }
  return null;
}

function _markQrSessionUsed(row, usedCount) {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_QR_SESSIONS);
  sheet.getRange(row, 8).setValue(usedCount);
  sheet.getRange(row, 11).setValue(new Date().toISOString());
}

function _updateQrSessionStatus(row, status) {
  SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_QR_SESSIONS).getRange(row, 10).setValue(status);
}

function _appendQrScanLog(session, scanner, params, result) {
  const settings = getSettingsMap();
  const tz = settings.timezone || 'Asia/Ho_Chi_Minh';
  const now = new Date();
  const today = Utilities.formatDate(now, tz, 'yyyy-MM-dd');
  const raw = {
    timestamp: now.toISOString(),
    date: today,
    token_id: session.token_id,
    issuer_email: session.issuer_email,
    issuer_name: session.issuer_name,
    scanner_email: scanner.email,
    scanner_name: scanner.name,
    checkin_result: result.success === true ? 'success' : 'already_checked_in',
    latitude: params.latitude || '',
    longitude: params.longitude || '',
    gps_distance: params.gps_distance || '',
    public_ip: params.public_ip || '',
    result: result
  };
  SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_QR_SCAN_RAW)
    .appendRow([now.toISOString(), today, 'qr_scan', JSON.stringify(raw), 'pending']);
}

function _reviewLeaveRequest(params, status) {
  const adminEmail = (params.admin_email || '').toString().trim().toLowerCase();
  const requestId = (params.request_id || '').toString().trim();
  const note = (params.note || '').toString();
  if (!isAdmin(adminEmail)) return { success: false, error: 'Unauthorized' };
  if (!requestId) return { success: false, error: 'request_id required' };
  initSheets();
  syncLeaveRawToRequests();
  const admin = _getEmployeeByEmail(adminEmail);
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_LEAVE_REQUESTS);
  const data = sheet.getDataRange().getValues();
  for (let i = 1; i < data.length; i++) {
    if (data[i][0] === requestId) {
      sheet.getRange(i + 1, 9).setValue(status);
      sheet.getRange(i + 1, 10).setValue(adminEmail);
      sheet.getRange(i + 1, 11).setValue(admin ? admin.name : adminEmail);
      sheet.getRange(i + 1, 13).setValue(new Date().toISOString());
      sheet.getRange(i + 1, 14).setValue(note);
      return { success: true, message: status === 'approved' ? 'Đã duyệt đơn nghỉ' : 'Đã từ chối đơn nghỉ' };
    }
  }
  return { success: false, error: 'Không tìm thấy đơn nghỉ' };
}

function _readLeaveRequests(filter) {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_LEAVE_REQUESTS);
  if (!sheet) return [];
  const data = sheet.getDataRange().getValues();
  const rows = [];
  const seen = new Set();
  for (let i = 1; i < data.length; i++) {
    const row = {
      request_id: data[i][0],
      email: data[i][1],
      name: data[i][2],
      leave_type: data[i][3],
      start_date: _formatSheetDate(data[i][4]),
      end_date: _formatSheetDate(data[i][5]),
      days: data[i][6],
      reason: data[i][7],
      status: data[i][8],
      approver_email: data[i][9],
      approver_name: data[i][10],
      created_at: data[i][11],
      updated_at: data[i][12],
      note: data[i][13]
    };
    if (filter.email && row.email.toString().toLowerCase() !== filter.email) continue;
    if (filter.status && row.status !== filter.status) continue;
    rows.push(row);
    seen.add(String(row.request_id || ''));
  }

  const rawSheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_LEAVE_RAW);
  if (rawSheet) {
    const rawData = rawSheet.getDataRange().getValues();
    for (let i = 1; i < rawData.length; i++) {
      if (rawData[i][3] !== 'leave_request' || !rawData[i][4]) continue;
      try {
        const obj = JSON.parse(rawData[i][4]);
        if (seen.has(String(obj.request_id || ''))) continue;
        const row = {
          request_id: obj.request_id || '',
          email: obj.email || rawData[i][2] || '',
          name: obj.name || '',
          leave_type: obj.leave_type || '',
          start_date: obj.start_date || '',
          end_date: obj.end_date || '',
          days: obj.days || '',
          reason: obj.reason || '',
          status: obj.status || 'pending',
          approver_email: obj.approver_email || '',
          approver_name: obj.approver_name || '',
          created_at: obj.created_at || rawData[i][0],
          updated_at: obj.updated_at || obj.created_at || rawData[i][0],
          note: obj.note || ''
        };
        if (filter.email && row.email.toString().toLowerCase() !== filter.email) continue;
        if (filter.status && row.status !== filter.status) continue;
        rows.push(row);
        seen.add(String(row.request_id || ''));
      } catch (err) {}
    }
  }
  rows.sort((a, b) => String(b.created_at).localeCompare(String(a.created_at)));
  return rows;
}

function _sha256Hex(text) {
  const bytes = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, text, Utilities.Charset.UTF_8);
  return bytes.map(b => {
    const v = (b < 0 ? b + 256 : b).toString(16);
    return v.length === 1 ? '0' + v : v;
  }).join('');
}

function _appendMethod(current, method) {
  const parts = (current || '').split('+').map(s => s.trim()).filter(Boolean);
  if (parts.indexOf('gps') === -1) parts.unshift('gps');
  if (parts.indexOf(method) === -1) parts.push(method);
  return parts.join('+');
}

function _parseIsoDate(value) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!m) return null;
  return new Date(parseInt(m[1], 10), parseInt(m[2], 10) - 1, parseInt(m[3], 10));
}

function _countLeaveDays(start, end, leaveType) {
  const oneDay = 24 * 60 * 60 * 1000;
  const rawDays = Math.floor((end.getTime() - start.getTime()) / oneDay) + 1;
  if (leaveType === 'morning' || leaveType === 'afternoon') return 0.5;
  return rawDays;
}

function _formatSheetDate(value) {
  if (value instanceof Date) {
    return Utilities.formatDate(value, Session.getScriptTimeZone(), 'yyyy-MM-dd');
  }
  return value ? value.toString() : '';
}

function _minutesOf(time) {
  const parts = (time || '00:00').split(':').map(Number);
  return (parts[0] || 0) * 60 + (parts[1] || 0);
}

function _haversineDistance(lat1, lon1, lat2, lon2) {
  const R = 6371000;
  const dLat = _toRad(lat2 - lat1);
  const dLon = _toRad(lon2 - lon1);
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(_toRad(lat1)) * Math.cos(_toRad(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function _toRad(deg) {
  return deg * (Math.PI / 180);
}
