// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings);
  }

  Future<void> showFraudAlert({
    required String title,
    required String body,
    String? severity,
  }) async {
    final importance = _importanceFromSeverity(severity);
    final androidDetails = AndroidNotificationDetails(
      'fraud_alerts',
      'Fraud Alerts',
      channelDescription: 'Real-time fraud detection alerts',
      importance: importance,
      priority: importance == Importance.max ? Priority.high : Priority.defaultPriority,
      color: _colorFromSeverity(severity),
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  Importance _importanceFromSeverity(String? severity) {
    switch (severity) {
      case 'critical': return Importance.max;
      case 'high':     return Importance.high;
      case 'medium':   return Importance.defaultImportance;
      default:         return Importance.low;
    }
  }

  // Returns an Android color int
  dynamic _colorFromSeverity(String? severity) {
    switch (severity) {
      case 'critical': return const Object(); // red — placeholder
      case 'high':     return const Object(); // orange
      default:         return null;
    }
  }
}
