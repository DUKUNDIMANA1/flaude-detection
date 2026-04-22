// lib/models/transaction.dart
class Transaction {
  final int? id;
  final String transactionId;
  final int? userId;
  final double amount;
  final String? merchant;
  final String? merchantCategory;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? cardType;
  final String? cardLast4;
  final String transactionType;
  final String channel;
  final String? ipAddress;
  final String? deviceId;
  final DateTime timestamp;
  final double fraudScore;
  final bool isFraud;
  final List<String> fraudReasons;
  final String? modelVersion;
  final String status;
  final String? reviewNotes;

  Transaction({
    this.id,
    required this.transactionId,
    this.userId,
    required this.amount,
    this.merchant,
    this.merchantCategory,
    this.location,
    this.latitude,
    this.longitude,
    this.cardType,
    this.cardLast4,
    this.transactionType = 'purchase',
    this.channel = 'online',
    this.ipAddress,
    this.deviceId,
    required this.timestamp,
    this.fraudScore = 0.0,
    this.isFraud = false,
    this.fraudReasons = const [],
    this.modelVersion,
    this.status = 'pending',
    this.reviewNotes,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    List<String> reasons = [];
    if (json['fraud_reasons'] != null) {
      try {
        final raw = json['fraud_reasons'];
        if (raw is String && raw.isNotEmpty) {
          reasons = List<String>.from(
            (raw.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').split(','))
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty),
          );
        } else if (raw is List) {
          reasons = List<String>.from(raw);
        }
      } catch (_) {}
    }

    return Transaction(
      id: json['id'],
      transactionId: json['transaction_id'] ?? '',
      userId: json['user_id'],
      amount: (json['amount'] ?? 0).toDouble(),
      merchant: json['merchant'],
      merchantCategory: json['merchant_category'],
      location: json['location'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      cardType: json['card_type'],
      cardLast4: json['card_last4'],
      transactionType: json['transaction_type'] ?? 'purchase',
      channel: json['channel'] ?? 'online',
      ipAddress: json['ip_address'],
      deviceId: json['device_id'],
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      fraudScore: (json['fraud_score'] ?? 0.0).toDouble(),
      isFraud: json['is_fraud'] ?? false,
      fraudReasons: reasons,
      modelVersion: json['model_version'],
      status: json['status'] ?? 'pending',
      reviewNotes: json['review_notes'],
    );
  }

  Map<String, dynamic> toJson() => {
    'transaction_id': transactionId,
    'user_id': userId,
    'amount': amount,
    'merchant': merchant,
    'merchant_category': merchantCategory,
    'location': location,
    'latitude': latitude,
    'longitude': longitude,
    'card_type': cardType,
    'card_last4': cardLast4,
    'transaction_type': transactionType,
    'channel': channel,
    'ip_address': ipAddress,
    'device_id': deviceId,
    'timestamp': timestamp.toIso8601String(),
    'fraud_score': fraudScore,
    'is_fraud': isFraud,
    'fraud_reasons': fraudReasons.toString(),
    'model_version': modelVersion,
    'status': status,
    'review_notes': reviewNotes,
  };

  // SQLite helpers
  Map<String, dynamic> toMap() => {
    'id': id,
    'transaction_id': transactionId,
    'user_id': userId,
    'amount': amount,
    'merchant': merchant,
    'merchant_category': merchantCategory,
    'location': location,
    'latitude': latitude,
    'longitude': longitude,
    'card_type': cardType,
    'card_last4': cardLast4,
    'transaction_type': transactionType,
    'channel': channel,
    'ip_address': ipAddress,
    'device_id': deviceId,
    'timestamp': timestamp.toIso8601String(),
    'fraud_score': fraudScore,
    'is_fraud': isFraud ? 1 : 0,
    'fraud_reasons': fraudReasons.join(','),
    'model_version': modelVersion,
    'status': status,
    'review_notes': reviewNotes,
  };

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      transactionId: map['transaction_id'] ?? '',
      userId: map['user_id'],
      amount: (map['amount'] ?? 0).toDouble(),
      merchant: map['merchant'],
      merchantCategory: map['merchant_category'],
      location: map['location'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      cardType: map['card_type'],
      cardLast4: map['card_last4'],
      transactionType: map['transaction_type'] ?? 'purchase',
      channel: map['channel'] ?? 'online',
      ipAddress: map['ip_address'],
      deviceId: map['device_id'],
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      fraudScore: (map['fraud_score'] ?? 0.0).toDouble(),
      isFraud: (map['is_fraud'] ?? 0) == 1,
      fraudReasons: (map['fraud_reasons'] ?? '').toString().split(',')
          .where((e) => e.trim().isNotEmpty).toList(),
      modelVersion: map['model_version'],
      status: map['status'] ?? 'pending',
      reviewNotes: map['review_notes'],
    );
  }
}
