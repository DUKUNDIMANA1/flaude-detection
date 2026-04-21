#!/usr/bin/env bash
# setup.sh — one-shot backend bootstrap (no Docker required)
set -e

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   FraudGuard Backend Setup               ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Python ────────────────────────────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
    echo "ERROR: python3 not found. Install Python 3.10+ and re-run."
    exit 1
fi

PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "✓ Python $PYTHON_VERSION detected"

# ── Virtual environment ───────────────────────────────────────────────────────
cd backend

if [ ! -d "venv" ]; then
    echo "→ Creating virtual environment …"
    python3 -m venv venv
fi

source venv/bin/activate
echo "✓ Virtual environment activated"

# ── Dependencies ──────────────────────────────────────────────────────────────
echo "→ Installing Python dependencies …"
pip install --upgrade pip -q
pip install -r requirements.txt -q
echo "✓ Dependencies installed"

# ── .env ─────────────────────────────────────────────────────────────────────
if [ ! -f ".env" ]; then
    cat > .env << 'ENV'
SECRET_KEY=change-me-in-production
JWT_SECRET_KEY=jwt-change-me-in-production
PORT=5000
DEBUG=false
ENV
    echo "✓ .env file created (update keys before deploying)"
fi

# ── ML model ─────────────────────────────────────────────────────────────────
if [ ! -f "ml_model/model.pkl" ]; then
    echo "→ Training ML model (this takes ~30 seconds) …"
    python3 ml_model/train.py
    echo "✓ Model trained and saved to ml_model/model.pkl"
else
    echo "✓ ML model already exists — skipping training"
fi

# ── Init __init__.py files ────────────────────────────────────────────────────
for pkg in database api automation ml_model; do
    touch "${pkg}/__init__.py"
done

echo ""
echo "═══════════════════════════════════════════"
echo "  Setup complete!"
echo "  Start the backend with:"
echo "    cd backend && source venv/bin/activate && python app.py"
echo "═══════════════════════════════════════════"
echo ""
echo "  Then update your Flutter app:"
echo "    mobile_app/lib/utils/constants.dart"
echo "    → Set baseUrl and wsUrl to your machine's IP"
echo ""
