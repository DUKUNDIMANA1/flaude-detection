// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';
import '../models/transaction.dart';
import '../models/user.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final _storage = const FlutterSecureStorage();

  // ── Auth helpers ──────────────────────────────────────────────────────────
  Future<String?> get _token => _storage.read(key: AppConstants.tokenKey);

  Future<Map<String, String>> get _authHeaders async {
    final token = await _token;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Auth ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      await _storage.write(key: AppConstants.tokenKey, value: data['token']);
      await _storage.write(key: AppConstants.userKey, value: jsonEncode(data['user']));
      return {'success': true, 'user': data['user']};
    }
    return {'success': false, 'error': data['error'] ?? 'Login failed'};
  }

  Future<Map<String, dynamic>> register(
      String username, String email, String password) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'email': email, 'password': password}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 201) {
      await _storage.write(key: AppConstants.tokenKey, value: data['token']);
      await _storage.write(key: AppConstants.userKey, value: jsonEncode(data['user']));
      return {'success': true, 'user': data['user']};
    }
    return {'success': false, 'error': data['error'] ?? 'Registration failed'};
  }

  Future<void> logout() async {
    await _storage.delete(key: AppConstants.tokenKey);
    await _storage.delete(key: AppConstants.userKey);
  }

  Future<User?> getCurrentUser() async {
    final userJson = await _storage.read(key: AppConstants.userKey);
    if (userJson == null) return null;
    return User.fromJson(jsonDecode(userJson));
  }

  // ── Transactions ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getTransactions({
    int page = 1,
    int perPage = 20,
    String? status,
    bool? isFraud,
  }) async {
    final params = {
      'page': page.toString(),
      'per_page': perPage.toString(),
      if (status != null) 'status': status,
      if (isFraud != null) 'is_fraud': isFraud.toString(),
    };
    final uri = Uri.parse('${AppConstants.baseUrl}/transactions')
        .replace(queryParameters: params);
    final res = await http.get(uri, headers: await _authHeaders);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return {
        'success': true,
        'transactions': (data['transactions'] as List)
            .map((t) => Transaction.fromJson(t))
            .toList(),
        'total': data['total'],
        'pages': data['pages'],
      };
    }
    return {'success': false, 'error': 'Failed to fetch transactions'};
  }

  Future<Map<String, dynamic>> analyzeTransaction(
      Map<String, dynamic> txData) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/transactions/analyze'),
      headers: await _authHeaders,
      body: jsonEncode(txData),
    );
    if (res.statusCode == 200) {
      return {'success': true, ...jsonDecode(res.body)};
    }
    return {'success': false, 'error': 'Analysis failed'};
  }

  Future<Map<String, dynamic>> reviewTransaction(
      int txnId, String status, String? notes) async {
    final res = await http.patch(
      Uri.parse('${AppConstants.baseUrl}/transactions/$txnId/review'),
      headers: await _authHeaders,
      body: jsonEncode({'status': status, if (notes != null) 'review_notes': notes}),
    );
    if (res.statusCode == 200) {
      return {'success': true, 'transaction': Transaction.fromJson(jsonDecode(res.body))};
    }
    return {'success': false, 'error': 'Review failed'};
  }

  // ── Alerts ────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getAlerts({
    int page = 1,
    bool? isRead,
    String? severity,
  }) async {
    final params = {
      'page': page.toString(),
      if (isRead != null) 'is_read': isRead.toString(),
      if (severity != null) 'severity': severity,
    };
    final uri = Uri.parse('${AppConstants.baseUrl}/alerts')
        .replace(queryParameters: params);
    final res = await http.get(uri, headers: await _authHeaders);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return {'success': true, ...data};
    }
    return {'success': false, 'error': 'Failed to fetch alerts'};
  }

  Future<bool> markAlertRead(int alertId) async {
    final res = await http.patch(
      Uri.parse('${AppConstants.baseUrl}/alerts/$alertId/read'),
      headers: await _authHeaders,
    );
    return res.statusCode == 200;
  }

  Future<bool> resolveAlert(int alertId) async {
    final res = await http.patch(
      Uri.parse('${AppConstants.baseUrl}/alerts/$alertId/resolve'),
      headers: await _authHeaders,
    );
    return res.statusCode == 200;
  }

  // ── Dashboard ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDashboardStats() async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/dashboard/stats'),
      headers: await _authHeaders,
    );
    if (res.statusCode == 200) {
      return {'success': true, ...jsonDecode(res.body)};
    }
    return {'success': false, 'error': 'Failed to fetch stats'};
  }

  // ── Rules ─────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getRules() async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/rules'),
      headers: await _authHeaders,
    );
    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    }
    return [];
  }

  Future<bool> toggleRule(int ruleId, bool isActive) async {
    final res = await http.patch(
      Uri.parse('${AppConstants.baseUrl}/rules/$ruleId'),
      headers: await _authHeaders,
      body: jsonEncode({'is_active': isActive}),
    );
    return res.statusCode == 200;
  }
}
