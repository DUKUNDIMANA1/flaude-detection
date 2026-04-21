"""
WebSocket events for real-time fraud alerts
"""
from flask_socketio import SocketIO, emit, join_room, leave_room
from flask_jwt_extended import decode_token
from database.models import Alert, Transaction

socketio = SocketIO()


def init_socketio(app):
    socketio.init_app(app, cors_allowed_origins='*', async_mode='eventlet')
    return socketio


@socketio.on('connect')
def on_connect():
    emit('connected', {'message': 'Connected to fraud detection server'})


@socketio.on('disconnect')
def on_disconnect():
    pass


@socketio.on('join_alerts')
def on_join_alerts(data):
    """Client joins a room to receive live alert pushes."""
    try:
        token = data.get('token', '')
        decoded = decode_token(token)
        user_id = decoded.get('sub')
        room = f'user_{user_id}'
        join_room(room)
        emit('joined', {'room': room})
    except Exception:
        emit('error', {'message': 'Authentication failed'})


@socketio.on('leave_alerts')
def on_leave_alerts(data):
    try:
        token = data.get('token', '')
        decoded = decode_token(token)
        user_id = decoded.get('sub')
        leave_room(f'user_{user_id}')
    except Exception:
        pass


def broadcast_alert(alert: Alert, user_id: int = None):
    """Called by the fraud detector to push a new alert to all connected clients."""
    room = f'user_{user_id}' if user_id else 'broadcast'
    socketio.emit('new_alert', alert.to_dict(), room=room)


def broadcast_transaction(transaction: Transaction):
    """Push a transaction result to all subscribers."""
    socketio.emit('transaction_update', transaction.to_dict())
