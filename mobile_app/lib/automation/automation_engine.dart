// lib/automation/automation_engine.dart
import 'action_handler.dart';

class AutomationEngine {
  final ActionHandler _handler = ActionHandler();

  Map<String, dynamic> evaluate(Map<String, dynamic> txData, double fraudScore) {
    final rules = _builtInRules();
    String action = 'approve';
    String severity = 'low';
    final triggeredRules = <String>[];

    final severityRank = {'low': 1, 'medium': 2, 'high': 3, 'critical': 4};
    final actionRank   = {'approve': 0, 'flag': 1, 'review': 2, 'alert': 3, 'block': 4};

    for (final rule in rules) {
      if (_matchesRule(rule, txData, fraudScore)) {
        triggeredRules.add(rule['name'] as String);
        final rAction   = rule['action']   as String;
        final rSeverity = rule['severity'] as String;
        if ((actionRank[rAction]   ?? 0) > (actionRank[action]   ?? 0)) action   = rAction;
        if ((severityRank[rSeverity] ?? 0) > (severityRank[severity] ?? 0)) severity = rSeverity;
      }
    }

    final result = {
      'action': action,
      'severity': severity,
      'triggered_rules': triggeredRules,
    };

    _handler.handle(result, txData);
    return result;
  }

  bool _matchesRule(Map<String, dynamic> rule, Map<String, dynamic> tx, double score) {
    final type = rule['type'] as String;
    switch (type) {
      case 'amount':
        final amt = (tx['amount'] as num?)?.toDouble() ?? 0;
        return amt > (rule['threshold'] as num).toDouble();
      case 'fraud_score':
        return score >= (rule['threshold'] as num).toDouble();
      case 'fraud_score_range':
        final lo = (rule['lo'] as num).toDouble();
        final hi = (rule['hi'] as num).toDouble();
        return score >= lo && score < hi;
      case 'device':
        return tx['new_device'] == true &&
            ((tx['amount'] as num?)?.toDouble() ?? 0) > (rule['threshold'] as num).toDouble();
      case 'vpn':
        return tx['vpn_detected'] == true;
      case 'failed_attempts':
        return (tx['failed_attempts'] as int? ?? 0) >= (rule['threshold'] as int);
      default:
        return false;
    }
  }

  List<Map<String, dynamic>> _builtInRules() => [
    {'name': 'high_amount',        'type': 'amount',          'threshold': 5000,  'action': 'flag',   'severity': 'high'},
    {'name': 'very_high_amount',   'type': 'amount',          'threshold': 10000, 'action': 'block',  'severity': 'critical'},
    {'name': 'high_fraud_score',   'type': 'fraud_score',     'threshold': 0.8,   'action': 'block',  'severity': 'critical'},
    {'name': 'medium_fraud_score', 'type': 'fraud_score_range','lo': 0.5, 'hi': 0.8,'action': 'flag', 'severity': 'high'},
    {'name': 'new_device_high',    'type': 'device',          'threshold': 500,   'action': 'review', 'severity': 'medium'},
    {'name': 'vpn_detected',       'type': 'vpn',                                  'action': 'flag',   'severity': 'medium'},
    {'name': 'failed_attempts',    'type': 'failed_attempts', 'threshold': 3,     'action': 'block',  'severity': 'critical'},
  ];
}
