/**
 * QR check-in + leave request add-on for the existing Apps Script backend.
 *
 * Paste this file below the current backend code, then add these cases to the
 * handleRequest switch:
 *
 *   case 'createQrSession': result = createQrSession(params); break;
 *   case 'checkinByQr': result = checkinByQr(params); break;
 *   case 'createLeaveRequest': result = createLeaveRequest(params); break;
 *   case 'getMyLeaveRequests': result = getMyLeaveRequests(params); break;
 *   case 'getLeaveRequests': result = getLeaveRequests(params); break;
 *   case 'approveLeaveRequest': result = approveLeaveRequest(params); break;
 *   case 'rejectLeaveRequest': result = rejectLeaveRequest(params); break;
 *   case 'cancelLeaveRequest': result = cancelLeaveRequest(params); break;
 *
 * Also run initQrLeaveSheets() once from Apps Script, or add it inside initSheets().
 *
 * To make QR audit visible in Raw_JSON/Checkins, add these fields to the
 * checkinData object inside checkinEmployee():
 *
 *   qr_token_id: params.qr_token_id || '',
 *   qr_issuer_email: params.qr_issuer_email || '',
 *   qr_issuer_name: params.qr_issuer_name || '',
 *   qr_scanner_email: params.qr_scanner_email || '',
 *
 * Then add the same fields as extra columns in syncRawJsonToCheckins() if you
 * want them expanded outside raw_json. They are still preserved in Raw_JSON
 * after the checkinData addition.
 */

const SHEET_QR_SESSIONS = 'QrSessions';
const SHEET_QR_SCAN_LOGS = 'QrScanLogs';
const SHEET_LEAVE_REQUESTS = 'LeaveRequests';

function initQrLeaveSheets() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();

  let qrSheet = ss.getSheetByName(SHEET_QR_SESSIONS);
  if (!qrSheet) {
    qrSheet = ss.insertSheet(SHEET_QR_SESSIONS);
    qrSheet.appendRow([
      'token_id', 'token_hash', 'issuer_email', 'issuer_name', 'issuer_device_id',
      'created_at', 'expires_at', 'used_count', 'max_uses', 'status',
      'last_used_at', 'raw_json'
    ]);
    qrSheet.getRange('1:1').setFontWeight('bold');
  }

  let leaveSheet = ss.getSheetByName(SHEET_LEAVE_REQUESTS);
  if (!leaveSheet) {
    leaveSheet = ss.insertSheet(SHEET_LEAVE_REQUESTS);
    leaveSheet.appendRow([
      'request_id', 'email', 'name', 'leave_type', 'start_date', 'end_date',
      'days', 'reason', 'status', 'approver_email', 'approver_name',
      'created_at', 'updated_at', 'note', 'raw_json'
    ]);
    leaveSheet.getRange('1:1').setFontWeight('bold');
  }

  let qrLogSheet = ss.getSheetByName(SHEET_QR_SCAN_LOGS);
  if (!qrLogSheet) {
    qrLogSheet = ss.insertSheet(SHEET_QR_SCAN_LOGS);
    qrLogSheet.appendRow([
      'timestamp', 'date', 'token_id', 'issuer_email', 'issuer_name',
      'scanner_email', 'scanner_name', 'checkin_result', 'latitude',
      'longitude', 'gps_distance', 'public_ip', 'raw_json'
    ]);
    qrLogSheet.getRange('1:1').setFontWeight('bold');
  }

  return { success: true, message: 'QR and leave sheets initialized' };
}

function createQrSession(params) {
  const email = (params.email || '').toString().trim().toLowerCase();
  const deviceId = (params.device_id || '').toString();
  if (!email) return { success: false, error: 'Email is required' };

  const employee = _getEmployeeByEmail(email);
  if (!employee) return { success: false, error: 'Nhân viên không tồn tại' };

  const settings = getSettingsMap();
  const tz = settings['timezone'] || 'Asia/Ho_Chi_Minh';
  const today = Utilities.formatDate(new Date(), tz, 'yyyy-MM-dd');
  const canIssue = employee.role === 'admin' || _hasCheckedInToday(email, today, tz);
  if (!canIssue) {
    return { success: false, error: 'Chỉ admin hoặc người đã check-in hôm nay mới được xuất QR.' };
  }

  initQrLeaveSheets();

  const now = new Date();
  const ttlSeconds = parseInt(settings['qr_ttl_seconds'] || '90', 10) || 90;
  const maxUses = parseInt(settings['qr_max_uses'] || '30', 10) || 30;
  const expiresAt = new Date(now.getTime() + ttlSeconds * 1000);
  const tokenId = Utilities.getUuid();
  const token = Utilities.getUuid() + '-' + Utilities.getUuid();
  const tokenHash = _sha256Hex(token);

  const raw = {
    token_id: tokenId,
    issuer_email: email,
    issuer_name: employee.name,
    issuer_device_id: deviceId,
    created_at: now.toISOString(),
    expires_at: expiresAt.toISOString(),
    ttl_seconds: ttlSeconds,
    max_uses: maxUses
  };

  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_QR_SESSIONS);
  sheet.appendRow([
    tokenId, tokenHash, email, employee.name, deviceId,
    now.toISOString(), expiresAt.toISOString(), 0, maxUses, 'active',
    '', JSON.stringify(raw)
  ]);

  return {
    success: true,
    token: token,
    payload: JSON.stringify({
      type: 'ux_checkin_qr',
      token: token,
      token_id: tokenId,
      issuer_email: email,
      issuer_name: employee.name,
      expires_at: expiresAt.toISOString()
    }),
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
  const tz = settings['timezone'] || 'Asia/Ho_Chi_Minh';
  const today = Utilities.formatDate(new Date(), tz, 'yyyy-MM-dd');
  const issuer = _getEmployeeByEmail(session.issuer_email);
  const issuerCanStillIssue = issuer && (issuer.role === 'admin' || _hasCheckedInToday(session.issuer_email, today, tz));
  if (!issuerCanStillIssue) {
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

  const employee = _getEmployeeByEmail(email);
  if (!employee) return { success: false, error: 'Nhân viên không tồn tại' };

  const start = _parseIsoDate(startDate);
  const end = _parseIsoDate(endDate);
  if (!start || !end || end.getTime() < start.getTime()) {
    return { success: false, error: 'Khoảng ngày nghỉ không hợp lệ' };
  }

  initQrLeaveSheets();

  const days = _countLeaveDays(start, end, leaveType);
  const now = new Date();
  const requestId = Utilities.getUuid();
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

  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_LEAVE_REQUESTS);
  sheet.appendRow([
    requestId, email, employee.name, leaveType, startDate, endDate,
    days, reason, 'approved', '', '', now.toISOString(), now.toISOString(),
    '', JSON.stringify(raw)
  ]);

  return { success: true, request: raw };
}

function getMyLeaveRequests(params) {
  const email = (params.email || '').toString().trim().toLowerCase();
  if (!email) return { success: false, error: 'Email is required' };
  return { success: true, requests: _readLeaveRequests({ email: email }) };
}

function getLeaveRequests(params) {
  const adminEmail = (params.admin_email || '').toString().trim().toLowerCase();
  if (!isAdmin(adminEmail)) return { success: false, error: 'Unauthorized' };
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

  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_LEAVE_REQUESTS);
  if (!sheet) return { success: false, error: 'Chưa có sheet nghỉ phép' };
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

function _reviewLeaveRequest(params, status) {
  const adminEmail = (params.admin_email || '').toString().trim().toLowerCase();
  const requestId = (params.request_id || '').toString().trim();
  const note = (params.note || '').toString();
  if (!isAdmin(adminEmail)) return { success: false, error: 'Unauthorized' };
  if (!requestId) return { success: false, error: 'request_id required' };

  const admin = _getEmployeeByEmail(adminEmail);
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_LEAVE_REQUESTS);
  if (!sheet) return { success: false, error: 'Chưa có sheet nghỉ phép' };
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

function _getEmployeeByEmail(email) {
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

function _hasCheckedInToday(email, today, tz) {
  const rawSheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName('Raw_JSON');
  if (!rawSheet) return false;
  const rawData = rawSheet.getDataRange().getValues();
  for (let i = 1; i < rawData.length; i++) {
    if (rawData[i][3] !== 'checkin') continue;
    let rowDate = rawData[i][1];
    if (rowDate instanceof Date) {
      rowDate = Utilities.formatDate(rowDate, tz, 'yyyy-MM-dd');
    } else {
      rowDate = rowDate.toString();
    }
    if (rawData[i][2].toString().toLowerCase() === email.toLowerCase() && rowDate === today) {
      return true;
    }
  }
  return false;
}

function _getQrSessionByToken(token) {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_QR_SESSIONS);
  if (!sheet) return null;
  const hash = _sha256Hex(token);
  const data = sheet.getDataRange().getValues();
  for (let i = 1; i < data.length; i++) {
    if (data[i][1] === hash) {
      return {
        row: i + 1,
        token_id: data[i][0],
        token_hash: data[i][1],
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

function _appendQrScanLog(session, scanner, params, result) {
  initQrLeaveSheets();
  const settings = getSettingsMap();
  const tz = settings['timezone'] || 'Asia/Ho_Chi_Minh';
  const now = new Date();
  const today = Utilities.formatDate(now, tz, 'yyyy-MM-dd');
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_QR_SCAN_LOGS);
  sheet.appendRow([
    now.toISOString(),
    today,
    session.token_id,
    session.issuer_email,
    session.issuer_name,
    scanner.email,
    scanner.name,
    result.success === true ? 'success' : 'already_checked_in',
    params.latitude || '',
    params.longitude || '',
    params.gps_distance || '',
    params.public_ip || '',
    JSON.stringify({
      qr_token_id: session.token_id,
      qr_issuer_email: session.issuer_email,
      qr_issuer_name: session.issuer_name,
      qr_scanner_email: scanner.email,
      qr_scanner_name: scanner.name,
      result: result
    })
  ]);
}

function _updateQrSessionStatus(row, status) {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_QR_SESSIONS);
  sheet.getRange(row, 10).setValue(status);
}

function _sha256Hex(text) {
  const bytes = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, text, Utilities.Charset.UTF_8);
  return bytes.map(function(b) {
    const v = (b < 0 ? b + 256 : b).toString(16);
    return v.length === 1 ? '0' + v : v;
  }).join('');
}

function _appendMethod(current, method) {
  const parts = (current || '').split('+').map(function(s) { return s.trim(); }).filter(Boolean);
  if (parts.indexOf(method) === -1) parts.push(method);
  if (parts.indexOf('gps') === -1) parts.unshift('gps');
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

function _readLeaveRequests(filter) {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_LEAVE_REQUESTS);
  if (!sheet) return [];
  const data = sheet.getDataRange().getValues();
  const rows = [];
  for (let i = 1; i < data.length; i++) {
    const row = {
      request_id: data[i][0],
      email: data[i][1],
      name: data[i][2],
      leave_type: data[i][3],
      start_date: data[i][4],
      end_date: data[i][5],
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
  }
  rows.sort(function(a, b) { return String(b.created_at).localeCompare(String(a.created_at)); });
  return rows;
}
