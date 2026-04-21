"""
REST API routes
"""
import json
import uuid
from datetime import datetime, timedelta
from flask import Blueprint, request, jsonify
from flask_jwt_extended import (
    create_access_token, jwt_required, get_jwt_identity
)
from database.db_config import db
from database.models import User, Transaction, Alert, Rule
from sqlalchemy import func, desc

bp = Blueprint('api', __name__, url_prefix='/api')


# ── Auth ──────────────────────────────────────────────────────────────────────

@bp.route('/auth/register', methods=['POST'])
def register():
    data = request.get_json() or {}
    required = ('username', 'email', 'password')
    if not all(data.get(k) for k in required):
        return jsonify({'error': 'username, email and password are required'}), 400
    if User.query.filter_by(email=data['email']).first():
        return jsonify({'error': 'Email already registered'}), 409
    if User.query.filter_by(username=data['username']).first():
        return jsonify({'error': 'Username already taken'}), 409

    user = User(
        username=data['username'],
        email=data['email'],
        role=data.get('role', 'analyst'),
    )
    user.set_password(data['password'])
    db.session.add(user)
    db.session.commit()
    token = create_access_token(identity=str(user.id))
    return jsonify({'token': token, 'user': user.to_dict()}), 201


@bp.route('/auth/login', methods=['POST'])
def login():
    data = request.get_json() or {}
    user = User.query.filter_by(email=data.get('email')).first()
    if not user or not user.check_password(data.get('password', '')):
        return jsonify({'error': 'Invalid credentials'}), 401
    user.last_login = datetime.utcnow()
    db.session.commit()
    token = create_access_token(identity=str(user.id))
    return jsonify({'token': token, 'user': user.to_dict()})


@bp.route('/auth/me', methods=['GET'])
@jwt_required()
def me():
    user = User.query.get(int(get_jwt_identity()))
    if not user:
        return jsonify({'error': 'User not found'}), 404
    return jsonify(user.to_dict())


# ── Transactions ──────────────────────────────────────────────────────────────

@bp.route('/transactions', methods=['GET'])
@jwt_required()
def list_transactions():
    page     = int(request.args.get('page', 1))
    per_page = int(request.args.get('per_page', 20))
    status   = request.args.get('status')
    is_fraud = request.args.get('is_fraud')

    q = Transaction.query
    if status:
        q = q.filter(Transaction.status == status)
    if is_fraud is not None:
        q = q.filter(Transaction.is_fraud == (is_fraud.lower() == 'true'))

    paginated = q.order_by(desc(Transaction.timestamp)).paginate(
        page=page, per_page=per_page, error_out=False
    )
    return jsonify({
        'transactions': [t.to_dict() for t in paginated.items],
        'total': paginated.total,
        'pages': paginated.pages,
        'current_page': page,
    })


@bp.route('/transactions/<int:txn_id>', methods=['GET'])
@jwt_required()
def get_transaction(txn_id):
    txn = Transaction.query.get_or_404(txn_id)
    return jsonify(txn.to_dict())


@bp.route('/transactions/<int:txn_id>/review', methods=['PATCH'])
@jwt_required()
def review_transaction(txn_id):
    txn   = Transaction.query.get_or_404(txn_id)
    data  = request.get_json() or {}
    uid   = int(get_jwt_identity())

    if 'status' in data:
        txn.status = data['status']
    if 'review_notes' in data:
        txn.review_notes = data['review_notes']
    txn.reviewed_by = uid
    txn.reviewed_at = datetime.utcnow()
    db.session.commit()
    return jsonify(txn.to_dict())


@bp.route('/transactions/analyze', methods=['POST'])
@jwt_required()
def analyze_transaction():
    """Analyze a raw transaction payload and return fraud assessment."""
    from app import fraud_detector, automation_engine
    data = request.get_json() or {}
    result = fraud_detector.analyze(data)
    return jsonify(result)


# ── Alerts ────────────────────────────────────────────────────────────────────

@bp.route('/alerts', methods=['GET'])
@jwt_required()
def list_alerts():
    page       = int(request.args.get('page', 1))
    per_page   = int(request.args.get('per_page', 20))
    is_read    = request.args.get('is_read')
    severity   = request.args.get('severity')

    q = Alert.query
    if is_read is not None:
        q = q.filter(Alert.is_read == (is_read.lower() == 'true'))
    if severity:
        q = q.filter(Alert.severity == severity)

    paginated = q.order_by(desc(Alert.created_at)).paginate(
        page=page, per_page=per_page, error_out=False
    )
    return jsonify({
        'alerts': [a.to_dict() for a in paginated.items],
        'total': paginated.total,
        'pages': paginated.pages,
        'current_page': page,
        'unread_count': Alert.query.filter_by(is_read=False).count(),
    })


@bp.route('/alerts/<int:alert_id>/read', methods=['PATCH'])
@jwt_required()
def mark_alert_read(alert_id):
    alert = Alert.query.get_or_404(alert_id)
    alert.is_read = True
    db.session.commit()
    return jsonify(alert.to_dict())


@bp.route('/alerts/<int:alert_id>/resolve', methods=['PATCH'])
@jwt_required()
def resolve_alert(alert_id):
    alert = Alert.query.get_or_404(alert_id)
    alert.is_resolved = True
    alert.is_read = True
    alert.resolved_at = datetime.utcnow()
    alert.resolved_by = int(get_jwt_identity())
    db.session.commit()
    return jsonify(alert.to_dict())


# ── Rules ─────────────────────────────────────────────────────────────────────

@bp.route('/rules', methods=['GET'])
@jwt_required()
def list_rules():
    rules = Rule.query.order_by(Rule.created_at.desc()).all()
    return jsonify([r.to_dict() for r in rules])


@bp.route('/rules', methods=['POST'])
@jwt_required()
def create_rule():
    data = request.get_json() or {}
    rule = Rule(
        name=data.get('name'),
        description=data.get('description'),
        rule_type=data.get('rule_type'),
        condition=data.get('condition'),
        action=data.get('action', 'flag'),
        severity=data.get('severity', 'medium'),
        is_active=data.get('is_active', True),
    )
    db.session.add(rule)
    db.session.commit()
    return jsonify(rule.to_dict()), 201


@bp.route('/rules/<int:rule_id>', methods=['PATCH'])
@jwt_required()
def update_rule(rule_id):
    rule = Rule.query.get_or_404(rule_id)
    data = request.get_json() or {}
    for field in ('name', 'description', 'rule_type', 'condition', 'action', 'severity', 'is_active'):
        if field in data:
            setattr(rule, field, data[field])
    db.session.commit()
    return jsonify(rule.to_dict())


@bp.route('/rules/<int:rule_id>', methods=['DELETE'])
@jwt_required()
def delete_rule(rule_id):
    rule = Rule.query.get_or_404(rule_id)
    db.session.delete(rule)
    db.session.commit()
    return jsonify({'message': 'Rule deleted'})


# ── Dashboard / Analytics ─────────────────────────────────────────────────────

@bp.route('/dashboard/stats', methods=['GET'])
@jwt_required()
def dashboard_stats():
    now      = datetime.utcnow()
    day_ago  = now - timedelta(days=1)
    week_ago = now - timedelta(days=7)

    total_txns      = Transaction.query.count()
    total_fraud     = Transaction.query.filter_by(is_fraud=True).count()
    today_txns      = Transaction.query.filter(Transaction.timestamp >= day_ago).count()
    today_fraud     = Transaction.query.filter(
                          Transaction.timestamp >= day_ago, Transaction.is_fraud == True).count()
    week_txns       = Transaction.query.filter(Transaction.timestamp >= week_ago).count()
    week_fraud      = Transaction.query.filter(
                          Transaction.timestamp >= week_ago, Transaction.is_fraud == True).count()
    unread_alerts   = Alert.query.filter_by(is_read=False).count()
    pending_review  = Transaction.query.filter_by(status='review').count()

    avg_fraud_score = db.session.query(func.avg(Transaction.fraud_score)).scalar() or 0

    # Last 7 days fraud trend
    trend = []
    for i in range(6, -1, -1):
        day_start = now - timedelta(days=i+1)
        day_end   = now - timedelta(days=i)
        cnt = Transaction.query.filter(
            Transaction.timestamp >= day_start,
            Transaction.timestamp < day_end,
            Transaction.is_fraud == True
        ).count()
        trend.append({
            'date': day_start.strftime('%Y-%m-%d'),
            'fraud_count': cnt,
        })

    return jsonify({
        'total_transactions': total_txns,
        'total_fraud': total_fraud,
        'fraud_rate': round((total_fraud / total_txns * 100) if total_txns else 0, 2),
        'today_transactions': today_txns,
        'today_fraud': today_fraud,
        'week_transactions': week_txns,
        'week_fraud': week_fraud,
        'unread_alerts': unread_alerts,
        'pending_review': pending_review,
        'avg_fraud_score': round(float(avg_fraud_score), 4),
        'fraud_trend': trend,
    })
