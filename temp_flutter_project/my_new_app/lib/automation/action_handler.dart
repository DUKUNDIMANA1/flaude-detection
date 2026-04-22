// lib/automation/action_handler.dart
import '../services/notification_service.dart';

class ActionHandler {
  final NotificationService _notifications = NotificationService();

  void handle(Map<String, dynamic> ruleResult, Map<String, dynamic> txData) {
    final action   = ruleResult['action']   as String;
    final severity = ruleResult['severity'] as String;
    final amount   = (txData['amount'] as num?)?.toDouble() ?? 0;
    final merchant = txData['merchant'] as String? ?? 'Unknown merchant';

    switch (action) {
      case 'block':
        _notifications.showFraudAlert(
          title: '🚨 Transaction BLOCKED',
          body: '\$${amount.toStringAsFixed(2)} at $merchant was blocked — fraud detected.',
          severity: severity,
        );
        break;
      case 'flag':
        _notifications.showFraudAlert(
          title: '⚠️ Suspicious Transaction Flagged',
          body: '\$${amount.toStringAsFixed(2)} at $merchant flagged for review.',
          severity: severity,
        );
        break;
      case 'alert':
        _notifications.showFraudAlert(
          title: '🔔 Fraud Alert',
          body: '\$${amount.toStringAsFixed(2)} at $merchant requires attention.',
          severity: severity,
        );
        break;
      case 'review':
        _notifications.showFraudAlert(
          title: '🔍 Transaction Under Review',
          body: '\$${amount.toStringAsFixed(2)} at $merchant sent for manual review.',
          severity: severity,
        );
        break;
      default:
        // approve — no notification
        break;
    }
  }
}
