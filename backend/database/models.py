from datetime import datetime
from database.db_config import db
import bcrypt


class User(db.Model):
    __tablename__ = 'users'

    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    role = db.Column(db.String(20), default='analyst')  # admin, analyst
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_login = db.Column(db.DateTime)

    transactions = db.relationship('Transaction', foreign_keys='Transaction.user_id', backref='user', lazy=True)
    alerts = db.relationship('Alert', foreign_keys='Alert.user_id', backref='user', lazy=True)

    def set_password(self, password):
        salt = bcrypt.gensalt()
        self.password_hash = bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')

    def check_password(self, password):
        return bcrypt.checkpw(password.encode('utf-8'), self.password_hash.encode('utf-8'))

    def to_dict(self):
        return {
            'id': self.id,
            'username': self.username,
            'email': self.email,
            'role': self.role,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat(),
            'last_login': self.last_login.isoformat() if self.last_login else None
        }


class Transaction(db.Model):
    __tablename__ = 'transactions'

    id = db.Column(db.Integer, primary_key=True)
    transaction_id = db.Column(db.String(100), unique=True, nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=True)
    amount = db.Column(db.Float, nullable=False)
    merchant = db.Column(db.String(200))
    merchant_category = db.Column(db.String(100))
    location = db.Column(db.String(200))
    latitude = db.Column(db.Float)
    longitude = db.Column(db.Float)
    card_type = db.Column(db.String(50))
    card_last4 = db.Column(db.String(4))
    transaction_type = db.Column(db.String(50))  # purchase, withdrawal, transfer
    channel = db.Column(db.String(50))  # online, pos, atm, mobile
    ip_address = db.Column(db.String(50))
    device_id = db.Column(db.String(100))
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    
    # ML Results
    fraud_score = db.Column(db.Float, default=0.0)
    is_fraud = db.Column(db.Boolean, default=False)
    fraud_reasons = db.Column(db.Text)  # JSON string
    model_version = db.Column(db.String(20))
    
    # Status
    status = db.Column(db.String(30), default='pending')  # pending, approved, blocked, review
    reviewed_by = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=True)
    reviewed_at = db.Column(db.DateTime)
    review_notes = db.Column(db.Text)

    alerts = db.relationship('Alert', backref='transaction', lazy=True)

    def to_dict(self):
        return {
            'id': self.id,
            'transaction_id': self.transaction_id,
            'user_id': self.user_id,
            'amount': self.amount,
            'merchant': self.merchant,
            'merchant_category': self.merchant_category,
            'location': self.location,
            'latitude': self.latitude,
            'longitude': self.longitude,
            'card_type': self.card_type,
            'card_last4': self.card_last4,
            'transaction_type': self.transaction_type,
            'channel': self.channel,
            'ip_address': self.ip_address,
            'device_id': self.device_id,
            'timestamp': self.timestamp.isoformat(),
            'fraud_score': self.fraud_score,
            'is_fraud': self.is_fraud,
            'fraud_reasons': self.fraud_reasons,
            'model_version': self.model_version,
            'status': self.status,
            'reviewed_by': self.reviewed_by,
            'reviewed_at': self.reviewed_at.isoformat() if self.reviewed_at else None,
            'review_notes': self.review_notes
        }


class Alert(db.Model):
    __tablename__ = 'alerts'

    id = db.Column(db.Integer, primary_key=True)
    alert_id = db.Column(db.String(100), unique=True, nullable=False)
    transaction_id_ref = db.Column(db.Integer, db.ForeignKey('transactions.id'), nullable=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=True)
    alert_type = db.Column(db.String(50))  # fraud_detected, high_risk, rule_violation
    severity = db.Column(db.String(20))  # low, medium, high, critical
    title = db.Column(db.String(200))
    message = db.Column(db.Text)
    is_read = db.Column(db.Boolean, default=False)
    is_resolved = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    resolved_at = db.Column(db.DateTime)
    resolved_by = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=True)

    def to_dict(self):
        return {
            'id': self.id,
            'alert_id': self.alert_id,
            'transaction_id': self.transaction_id_ref,
            'user_id': self.user_id,
            'alert_type': self.alert_type,
            'severity': self.severity,
            'title': self.title,
            'message': self.message,
            'is_read': self.is_read,
            'is_resolved': self.is_resolved,
            'created_at': self.created_at.isoformat(),
            'resolved_at': self.resolved_at.isoformat() if self.resolved_at else None,
            'resolved_by': self.resolved_by
        }


class Rule(db.Model):
    __tablename__ = 'rules'

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), unique=True, nullable=False)
    description = db.Column(db.Text)
    rule_type = db.Column(db.String(50))  # amount, frequency, location, time, merchant
    condition = db.Column(db.Text)  # JSON string with rule logic
    action = db.Column(db.String(50))  # block, flag, alert, review
    severity = db.Column(db.String(20))  # low, medium, high, critical
    is_active = db.Column(db.Boolean, default=True)
    trigger_count = db.Column(db.Integer, default=0)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'description': self.description,
            'rule_type': self.rule_type,
            'condition': self.condition,
            'action': self.action,
            'severity': self.severity,
            'is_active': self.is_active,
            'trigger_count': self.trigger_count,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }
