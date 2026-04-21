# FraudGuard — Real-Time Fraud Detection System

A full-stack fraud detection platform: **Python/Flask backend** with SQLite + ML, and a **Flutter mobile app** with local SQLite caching, real-time WebSocket alerts, and on-device heuristic scoring.

---

## Architecture Overview

```
┌──────────────────────────────────────────────────┐
│                  Flutter Mobile App               │
│  ┌──────────┐ ┌───────────┐ ┌──────────────────┐ │
│  │Dashboard │ │Transactions│ │ Alerts / Settings│ │
│  └────┬─────┘ └─────┬─────┘ └────────┬─────────┘ │
│       │             │                │            │
│  ┌────▼─────────────▼────────────────▼─────────┐ │
│  │         Services Layer                       │ │
│  │  ApiService │ LocalDbService │ WebSocket     │ │
│  └────────────────────┬────────────────────────┘ │
│                       │                           │
│  ┌────────────────────▼────────────────────────┐ │
│  │     SQLite (sqflite) — Local Cache           │ │
│  │  transactions | alerts | cached_stats        │ │
│  └─────────────────────────────────────────────┘ │
└──────────────────────┬───────────────────────────┘
                       │  HTTP / WebSocket
┌──────────────────────▼───────────────────────────┐
│                 Flask Backend                      │
│  ┌───────────┐ ┌──────────┐ ┌──────────────────┐ │
│  │ REST API  │ │SocketIO  │ │  FraudDetector   │ │
│  │ /api/*    │ │(realtime)│ │  ML + Heuristics │ │
│  └───────────┘ └──────────┘ └──────────────────┘ │
│  ┌──────────────────────────────────────────────┐ │
│  │       Automation Engine (Rules)              │ │
│  │  high_amount | vpn | fraud_score | device …  │ │
│  └──────────────────────────────────────────────┘ │
│  ┌──────────────────────────────────────────────┐ │
│  │       SQLite  fraud_detection.db             │ │
│  │  users | transactions | alerts | rules       │ │
│  └──────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────┘
```

---

## Project Structure

```
fraud-detection-app/
├── backend/
│   ├── app.py                   # Flask app entry point
│   ├── requirements.txt
│   ├── .env                     # Secret keys & port
│   ├── ml_model/
│   │   ├── train.py             # Train & save model.pkl
│   │   ├── model.pkl            # Generated after training
│   │   └── model_metadata.json  # Generated after training
│   ├── automation/
│   │   ├── engine.py            # Rule evaluation engine
│   │   └── rules.py             # Default rule definitions
│   ├── database/
│   │   ├── models.py            # SQLAlchemy ORM models
│   │   └── db_config.py         # SQLite init
│   └── api/
│       ├── routes.py            # REST endpoints
│       └── websocket.py         # SocketIO events
│
├── mobile_app/
│   ├── lib/
│   │   ├── main.dart            # App entry & routing
│   │   ├── ml/
│   │   │   ├── ml_engine.dart   # On-device heuristic scoring
│   │   │   └── model_loader.dart
│   │   ├── automation/
│   │   │   ├── automation_engine.dart
│   │   │   └── action_handler.dart
│   │   ├── screens/
│   │   │   ├── splash_screen.dart
│   │   │   ├── login_screen.dart
│   │   │   ├── dashboard_screen.dart
│   │   │   ├── transaction_screen.dart
│   │   │   ├── alerts_screen.dart
│   │   │   └── settings_screen.dart
│   │   ├── services/
│   │   │   ├── api_service.dart
│   │   │   ├── local_db_service.dart  # SQLite (sqflite)
│   │   │   ├── websocket_service.dart
│   │   │   └── notification_service.dart
│   │   ├── models/
│   │   │   ├── transaction.dart
│   │   │   └── user.dart
│   │   └── utils/
│   │       ├── constants.dart   # ← Set your IP here
│   │       └── theme.dart
│   ├── assets/models/           # Place .tflite model here (optional)
│   └── pubspec.yaml
│
└── setup.sh                     # One-shot backend bootstrap
```

---

## Quick Start

### Step 1 — Backend Setup

```bash
# From the repo root
chmod +x setup.sh
./setup.sh
```

This will:
1. Create a Python virtual environment
2. Install all dependencies
3. Train the Random Forest fraud model → `ml_model/model.pkl`
4. Create the `.env` config file

### Step 2 — Start the Backend

```bash
cd backend
source venv/bin/activate
python app.py
```

The API will start on `http://0.0.0.0:5000`.

### Step 3 — Configure the Flutter App

Edit `mobile_app/lib/utils/constants.dart` and replace the IP with your computer's **local network IP**:

```dart
static const String baseUrl = 'http://YOUR_MACHINE_IP:5000/api';
static const String wsUrl   = 'ws://YOUR_MACHINE_IP:5000';
```

To find your IP:
- **macOS/Linux**: `ifconfig | grep "inet " | grep -v 127.0.0.1`
- **Windows**: `ipconfig` → look for IPv4 under your Wi-Fi adapter

> ⚠️ Your phone and computer must be on the **same Wi-Fi network**.

### Step 4 — Run the Flutter App

```bash
cd mobile_app
flutter pub get
flutter run
```

---

## API Reference

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Register new user |
| POST | `/api/auth/login` | Login, receive JWT |
| GET  | `/api/auth/me` | Current user info |

### Transactions
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET  | `/api/transactions` | List transactions (paginated) |
| GET  | `/api/transactions/:id` | Get single transaction |
| POST | `/api/transactions/analyze` | Analyze & score a transaction |
| PATCH| `/api/transactions/:id/review` | Update review status |

### Alerts
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET   | `/api/alerts` | List alerts |
| PATCH | `/api/alerts/:id/read` | Mark as read |
| PATCH | `/api/alerts/:id/resolve` | Resolve alert |

### Rules
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET    | `/api/rules` | List all rules |
| POST   | `/api/rules` | Create rule |
| PATCH  | `/api/rules/:id` | Update / toggle rule |
| DELETE | `/api/rules/:id` | Delete rule |

### Dashboard
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/dashboard/stats` | Fraud stats + 7-day trend |

---

## Analyze a Transaction (cURL example)

```bash
# 1. Login
TOKEN=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@test.com","password":"password123"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

# 2. Analyze a transaction
curl -X POST http://localhost:5000/api/transactions/analyze \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "amount": 8500,
    "merchant": "Electronics Store",
    "merchant_category": "electronics",
    "channel": "online",
    "card_type": "credit",
    "new_device": true,
    "vpn_detected": true,
    "frequency_24h": 12,
    "failed_attempts": 0,
    "avg_amount_7d": 200
  }'
```

---

## ML Model

The Random Forest classifier is trained on 10,000 synthetic transactions with ~3% fraud rate.

**Features used:**
- `amount`, `amount_ratio` (vs 7-day average)
- `hour`, `day_of_week`, `night_transaction`, `weekend`
- `merchant_category`, `channel`, `card_type`, `transaction_type`
- `frequency_24h`, `avg_amount_7d`
- `distance_from_home`, `failed_attempts`
- `new_device`, `vpn_detected`

**Retrain at any time:**
```bash
cd backend && source venv/bin/activate && python ml_model/train.py
```

---

## Default Fraud Rules

| Rule | Condition | Action | Severity |
|------|-----------|--------|----------|
| `high_amount_transaction` | amount > $5,000 | flag | high |
| `very_high_amount_transaction` | amount > $10,000 | block | critical |
| `high_frequency_transactions` | > 10 txns/hour | alert | high |
| `late_night_large_transaction` | 00:00–05:00 & amount > $1,000 | flag | medium |
| `multiple_failed_attempts` | failed_attempts ≥ 3 | block | critical |
| `new_device_high_amount` | new_device & amount > $500 | review | medium |
| `vpn_detected` | vpn = true | flag | medium |
| `high_fraud_score` | ML score > 80% | block | critical |
| `medium_fraud_score` | ML score 50–80% | flag | high |

---

## Local SQLite Schema (Flutter)

```sql
CREATE TABLE transactions (
  id INTEGER PRIMARY KEY,
  transaction_id TEXT UNIQUE,
  amount REAL,
  merchant TEXT,
  fraud_score REAL,
  is_fraud INTEGER,
  status TEXT,
  timestamp TEXT,
  synced INTEGER   -- 0 = pending sync to backend
  -- ... full schema in local_db_service.dart
);

CREATE TABLE alerts (
  id INTEGER PRIMARY KEY,
  alert_id TEXT UNIQUE,
  severity TEXT,
  title TEXT,
  message TEXT,
  is_read INTEGER,
  is_resolved INTEGER,
  created_at TEXT
);

CREATE TABLE cached_stats (
  key TEXT UNIQUE,
  value TEXT,       -- JSON blob
  cached_at TEXT    -- Auto-expired after 1 hour
);
```

---

## WebSocket Events

Connect to the WebSocket server and join your room to receive real-time events:

```javascript
// Client → Server
{ "event": "join_alerts", "data": { "token": "<jwt>" } }

// Server → Client
{ "event": "new_alert",         "data": { ...alert } }
{ "event": "transaction_update","data": { ...transaction } }
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `model.pkl not found` | Run `python ml_model/train.py` |
| Flutter can't reach backend | Check IP in `constants.dart`; ensure same Wi-Fi |
| `JWT expired` | Token TTL is 24h — log out and log in again |
| WebSocket not connecting | SocketIO uses eventlet; ensure `eventlet` is installed |
| Android HTTP blocked | Add `android:usesCleartextTraffic="true"` to `AndroidManifest.xml` for local dev |
