// lib/services/api_service.dart - FIXED VERSION
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final _storage = const FlutterSecureStorage();

  // ── Auth helpers ──────────────────────────────────────────────────────────
  Future<String?> get _token => _storage.read(key: AppConstants.tokenKey);

  Future<Map<String, String>> get _authHeaders async {
    final token = await _token;
    print('Current token: $token'); // Debug log
    
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ── Auth ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('${AppConstants.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        await _storage.write(key: AppConstants.tokenKey, value: data['token']);
        await _storage.write(key: AppConstants.userKey, value: jsonEncode(data['user']));
        print('Login successful, token saved'); // Debug log
        return {'success': true, 'user': data['user']};
      }
      return {'success': false, 'error': data['error'] ?? 'Login failed'};
    } catch (e) {
      print('Login error: $e'); // Debug log
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: AppConstants.tokenKey);
    await _storage.delete(key: AppConstants.userKey);
    print('Logged out, token cleared'); // Debug log
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final userJson = await _storage.read(key: AppConstants.userKey);
    if (userJson == null) return null;
    return jsonDecode(userJson);
  }

  // ── Predict Endpoint ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>> predictFraud(Map<String, dynamic> transactionData) async {
    try {
      final headers = await _authHeaders;
      print('=== PREDICT REQUEST ===');
      print('URL: ${AppConstants.baseUrl}/predict');
      print('Headers: $headers');
      print('Data: $transactionData');
      
      final res = await http.post(
        Uri.parse('${AppConstants.baseUrl}/predict'),
        headers: headers,
        body: jsonEncode(transactionData),
      );
      
      print('=== RESPONSE ===');
      print('Status: ${res.statusCode}');
      print('Body: ${res.body}');
      
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else if (res.statusCode == 401) {
        print('401 Unauthorized - clearing token');
        await logout();
        return {'error': 'Authentication expired. Please login again.'};
      } else {
        return {'error': 'Request failed with status: ${res.statusCode}'};
      }
    } catch (e) {
      print('Error in predictFraud: $e');
      return {'error': 'Network error: $e'};
    }
  }

  // ── Test Connection ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> testConnection() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConstants.baseUrl}/health'),
        headers: {'Content-Type': 'application/json'},
      );
      
      return {
        'success': res.statusCode == 200,
        'status': res.statusCode,
        'message': res.statusCode == 200 ? 'Connection successful' : 'Connection failed'
      };
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }
}
