// lib/ml/ml_engine.dart
// On-device fraud scoring — heuristic model used when the backend is unreachable.
// Replace with tflite_flutter inference when a .tflite model is embedded.

class MLEngine {
  static final MLEngine _instance = MLEngine._internal();
  factory MLEngine() => _instance;
  MLEngine._internal();

  bool _ready = false;
  bool get isReady => _ready;

  Future<void> loadModel() async {
    // In production: load the .tflite asset here via tflite_flutter.
    // For now we mark ready and use heuristics.
    _ready = true;
  }

  /// Returns a fraud probability in [0, 1] plus a list of reason strings.
  Map<String, dynamic> predict(Map<String, dynamic> features) {
    if (!_ready) {
      return {'fraud_score': 0.0, 'reasons': <String>[], 'model': 'none'};
    }
    return _heuristicScore(features);
  }

  Map<String, dynamic> _heuristicScore(Map<String, dynamic> f) {
    double score = 0.0;
    final reasons = <String>[];

    final amount   = (f['amount']   as num?)?.toDouble() ?? 0.0;
    final avgAmt   = (f['avg_amount_7d'] as num?)?.toDouble() ?? amount;
    final freq24h  = (f['frequency_24h'] as int?) ?? 1;
    final failedAt = (f['failed_attempts'] as int?) ?? 0;
    final newDev   = (f['new_device'] as bool?) ?? false;
    final vpn      = (f['vpn_detected'] as bool?) ?? false;
    final hour     = (f['hour'] as int?) ?? 12;
    final distance = (f['distance_from_home'] as num?)?.toDouble() ?? 0.0;

    if (amount > 10000)      { score += 0.35; reasons.add('Very high amount (>\$10k)'); }
    else if (amount > 5000)  { score += 0.20; reasons.add('High amount (>\$5k)'); }

    if (avgAmt > 0 && amount / avgAmt > 5) {
      score += 0.20;
      reasons.add('Amount ${(amount / avgAmt).toStringAsFixed(1)}× above 7-day average');
    }

    if (freq24h > 15)        { score += 0.20; reasons.add('High transaction frequency ($freq24h/24h)'); }
    else if (freq24h > 10)   { score += 0.10; }

    if (failedAt >= 3)       { score += 0.30; reasons.add('$failedAt failed attempts'); }

    if (newDev)              { score += 0.15; reasons.add('Unrecognised device'); }
    if (vpn)                 { score += 0.20; reasons.add('VPN detected'); }

    if (hour >= 0 && hour < 5) { score += 0.10; reasons.add('Late-night transaction'); }

    if (distance > 500)      { score += 0.15; reasons.add('Location ${distance.round()} km from home'); }

    return {
      'fraud_score': score.clamp(0.0, 1.0),
      'reasons': reasons,
      'model': 'heuristic',
    };
  }
}
