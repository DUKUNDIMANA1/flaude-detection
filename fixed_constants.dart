// lib/utils/constants.dart - FIXED VERSION
class AppConstants {
  // Fixed API URL for FastAPI backend
  static const String baseUrl = 'https://fraud-guard-ai-git-main-madhav-debbatas-projects.vercel.app';
  
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
