// lib/utils/constants.dart
class AppConstants {
  // Change this to your backend IP when running on a real device
  static const String baseUrl = 'http://192.168.56.1:5000/api';
  static const String wsUrl   = 'ws://192.168.56.1:5000';

  // Local SQLite
  static const String dbName    = 'fraud_local.db';
  static const int    dbVersion = 1;

  // Secure storage keys
  static const String tokenKey   = 'auth_token';
  static const String userKey    = 'current_user';

  // Fraud thresholds
  static const double highRiskThreshold   = 0.7;
  static const double mediumRiskThreshold = 0.4;

  // Pagination
  static const int defaultPageSize = 20;
}
