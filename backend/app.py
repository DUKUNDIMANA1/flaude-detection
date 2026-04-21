"""
Fraud Detection Backend — Flask + SQLite + SocketIO
Run:
    python app.py
"""
import os
import sys
import json
import uuid
import joblib
import numpy as np
from datetime import datetime, timedelta
from flask import Flask, jsonify
from flask_jwt_extended import JWTManager
from flask_cors import CORS
from dotenv import load_dotenv

load_dotenv()

# ── App factory ───────────────────────────────────────────────────────────────
app = Flask(__name__)
app.config['SECRET_KEY']         = os.getenv('SECRET_KEY', 'fraud-detect-secret-2024')
app.config['JWT_SECRET_KEY']     = os.getenv('JWT_SECRET_KEY', 'jwt-fraud-secret-2024')
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(hours=24)

CORS(app, resources={r'/api/*': {'origins': '*'}})
jwt = JWTManager(app)

# ── Database ──────────────────────────────────────────────────────────────────
from database.db_config import init_db, db
init_db(app)

# ── WebSocket ─────────────────────────────────────────────────────────────────
from api.websocket import init_socketio, broadcast_alert, broadcast_transaction
socketio = init_socketio(app)

# ── ML Model ──────────────────────────────────────────────────────────────────
MODEL_PATH = os.path.join(os.path.dirname(__file__), 'ml_model', 'model.pkl')
FEATURE_COLUMNS = [
    'amount', 'hour', 'day_of_week', 'merchant_category',
    'channel', 'card_type', 'transaction_type', 'frequency_24h',
    'avg_amount_7d', 'distance_from_home', 'failed_attempts',
    'new_device', 'vpn_detected', 'night_transaction', 'weekend',
    'amount_ratio',
]

ml_pipeline = None
if os.path.exists(MODEL_PATH):
    try:
        ml_pipeline = joblib.load(MODEL_PATH)
        print(f"✓ ML model loaded from {MODEL_PATH}")
    except Exception as e:
        print(f"⚠ Could not load ML model: {e}")
else:
    print("⚠ model.pkl not found — run ml_model/train.py first. Using heuristic scoring.")


class FraudDetector:
    """Wraps the ML pipeline and orchestrates the full analysis pipeline."""

    def analyze(self, tx_data: dict) -> dict:
        from database.models import Transaction, User
        from automation.engine import AutomationEngine
        from database.models import Rule, Alert

        # Build features
        ts = datetime.utcnow()
        features = self._extract_features(tx_data, ts)

        # ML score
        fraud_score, fraud_reasons = self._score(features)

        # Persist transaction
        txn = Transaction(
            transaction_id=tx_data.get('transaction_id') or str(uuid.uuid4()),
            user_id=tx_data.get('user_id'),
            amount=float(tx_data.get('amount', 0)),
            merchant=tx_data.get('merchant'),
            merchant_category=tx_data.get('merchant_category'),
            location=tx_data.get('location'),
            latitude=tx_data.get('latitude'),
            longitude=tx_data.get('longitude'),
            card_type=tx_data.get('card_type'),
            card_last4=tx_data.get('card_last4'),
            transaction_type=tx_data.get('transaction_type', 'purchase'),
            channel=tx_data.get('channel', 'online'),
            ip_address=tx_data.get('ip_address'),
            device_id=tx_data.get('device_id'),
            timestamp=ts,
            fraud_score=fraud_score,
            is_fraud=fraud_score >= 0.5,
            fraud_reasons=json.dumps(fraud_reasons),
            model_version='1.0.0',
            status='pending',
        )
        db.session.add(txn)
        db.session.flush()  # get txn.id without committing

        # Automation rules
        engine = AutomationEngine(db, {'Rule': Rule, 'Alert': Alert, 'Transaction': Transaction})
        rule_result = engine.evaluate_transaction(txn, {**features, 'fraud_score': fraud_score})
        txn.status = rule_result['status']

        db.session.commit()

        # Broadcast via WebSocket
        broadcast_transaction(txn)
        if rule_result['alerts_created']:
            from database.models import Alert as AlertModel
            alert = AlertModel.query.filter(
                AlertModel.alert_id == rule_result['alerts_created'][0]
            ).first()
            if alert:
                broadcast_alert(alert, txn.user_id)

        return {
            'transaction': txn.to_dict(),
            'fraud_score': fraud_score,
            'is_fraud': txn.is_fraud,
            'fraud_reasons': fraud_reasons,
            'action': rule_result['action'],
            'status': txn.status,
            'triggered_rules': rule_result['triggered_rules'],
        }

    # ── Private helpers ───────────────────────────────────────────────────────

    @staticmethod
    def _extract_features(tx_data: dict, ts: datetime) -> dict:
        amount      = float(tx_data.get('amount', 0))
        avg_amount  = float(tx_data.get('avg_amount_7d', amount))
        channel_map = {'online': 0, 'pos': 1, 'atm': 2, 'mobile': 3}
        card_map    = {'debit': 0, 'credit': 1, 'prepaid': 2}
        type_map    = {'purchase': 0, 'withdrawal': 1, 'transfer': 2}
        cat_map     = {
            'groceries': 1, 'travel': 2, 'entertainment': 3, 'electronics': 4,
            'restaurant': 5, 'gas': 6, 'healthcare': 7, 'shopping': 8,
            'utilities': 9, 'other': 10,
        }
        return {
            'amount':             amount,
            'hour':               ts.hour,
            'day_of_week':        ts.weekday(),
            'merchant_category':  cat_map.get(str(tx_data.get('merchant_category', 'other')).lower(), 10),
            'channel':            channel_map.get(str(tx_data.get('channel', 'online')).lower(), 0),
            'card_type':          card_map.get(str(tx_data.get('card_type', 'debit')).lower(), 0),
            'transaction_type':   type_map.get(str(tx_data.get('transaction_type', 'purchase')).lower(), 0),
            'frequency_24h':      int(tx_data.get('frequency_24h', 1)),
            'avg_amount_7d':      avg_amount,
            'distance_from_home': float(tx_data.get('distance_from_home', 0)),
            'failed_attempts':    int(tx_data.get('failed_attempts', 0)),
            'new_device':         int(bool(tx_data.get('new_device', False))),
            'vpn_detected':       int(bool(tx_data.get('vpn_detected', False))),
            'night_transaction':  1 if ts.hour in range(0, 6) else 0,
            'weekend':            1 if ts.weekday() in (5, 6) else 0,
            'amount_ratio':       amount / (avg_amount + 1e-9),
            # Extra features used by rules engine only
            'frequency_1h':       int(tx_data.get('frequency_1h', 1)),
        }

    def _score(self, features: dict) -> tuple:
        if ml_pipeline:
            return self._ml_score(features)
        return self._heuristic_score(features)

    @staticmethod
    def _ml_score(features: dict) -> tuple:
        vec = np.array([[features.get(f, 0) for f in FEATURE_COLUMNS]])
        prob = float(ml_pipeline.predict_proba(vec)[0][1])
        reasons = []
        if features['amount'] > 5000:   reasons.append('High transaction amount')
        if features['frequency_24h'] > 10: reasons.append('Unusual transaction frequency')
        if features['new_device']:       reasons.append('Unrecognised device')
        if features['vpn_detected']:     reasons.append('VPN detected')
        if features['night_transaction']: reasons.append('Late-night transaction')
        if features['distance_from_home'] > 100: reasons.append('Unusual location')
        if features['amount_ratio'] > 5: reasons.append('Amount significantly above average')
        return prob, reasons

    @staticmethod
    def _heuristic_score(features: dict) -> tuple:
        score = 0.0
        reasons = []
        if features['amount'] > 5000:    score += 0.3; reasons.append('High transaction amount')
        if features['frequency_24h'] > 10: score += 0.2; reasons.append('Unusual frequency')
        if features['new_device']:       score += 0.15; reasons.append('Unrecognised device')
        if features['vpn_detected']:     score += 0.2; reasons.append('VPN detected')
        if features['night_transaction']: score += 0.1; reasons.append('Late-night transaction')
        if features['failed_attempts'] >= 3: score += 0.3; reasons.append('Multiple failed attempts')
        if features['amount_ratio'] > 5: score += 0.2; reasons.append('Amount above average')
        return min(score, 1.0), reasons


# ── Global instances ──────────────────────────────────────────────────────────
fraud_detector = FraudDetector()

# Seed automation engine
with app.app_context():
    from database.models import Rule, Alert, Transaction as TxnModel
    from automation.engine import AutomationEngine
    engine_tmp = AutomationEngine(db, {'Rule': Rule, 'Alert': Alert, 'Transaction': TxnModel})
    automation_engine = engine_tmp
    engine_tmp.seed_default_rules()

# ── Register blueprints ───────────────────────────────────────────────────────
from api.routes import bp as api_bp
app.register_blueprint(api_bp)


# ── Health check ──────────────────────────────────────────────────────────────
@app.route('/health')
def health():
    return jsonify({'status': 'ok', 'model_loaded': ml_pipeline is not None})


# ── Error handlers ────────────────────────────────────────────────────────────
@app.errorhandler(404)
def not_found(e):
    return jsonify({'error': 'Not found'}), 404

@app.errorhandler(500)
def server_error(e):
    return jsonify({'error': 'Internal server error'}), 500


# ── Entrypoint ────────────────────────────────────────────────────────────────
if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    print(f"Starting Fraud Detection API on port {port} …")
    socketio.run(app, host='0.0.0.0', port=port, debug=os.getenv('DEBUG', 'false').lower() == 'true')
