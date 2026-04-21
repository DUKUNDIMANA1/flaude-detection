"""
Fraud Detection ML Model Training
Generates synthetic training data and trains a Random Forest classifier.
Run this once to produce model.pkl before starting the backend.
"""
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import classification_report, confusion_matrix, roc_auc_score
from sklearn.pipeline import Pipeline
import joblib
import os
import json
from datetime import datetime, timedelta, timezone
import random

# ── Reproducibility ──────────────────────────────────────────────────────────
np.random.seed(42)
random.seed(42)

# ── Synthetic dataset ─────────────────────────────────────────────────────────
def generate_synthetic_data(n_samples: int = 10_000) -> pd.DataFrame:
    """Generate realistic transaction data with ~3 % fraud rate."""
    data = []
    for i in range(n_samples):
        is_fraud = 1 if random.random() < 0.03 else 0
        hour        = random.randint(0, 23)
        day_of_week = random.randint(0, 6)
        amount      = (random.uniform(500, 10_000) if is_fraud else random.uniform(1, 2_000))
        merchant_cat = random.choice([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
        channel      = random.choice([0, 1, 2, 3])          # online, pos, atm, mobile
        card_type    = random.choice([0, 1, 2])              # debit, credit, prepaid
        txn_type     = random.choice([0, 1, 2])              # purchase, withdrawal, transfer

        # Behavioural features
        freq_24h      = (random.randint(5, 30)  if is_fraud else random.randint(1, 10))
        avg_amount    = (random.uniform(200, 5_000) if is_fraud else random.uniform(50, 500))
        dist_from_home = (random.uniform(100, 10_000) if is_fraud else random.uniform(0, 100))
        failed_attempts = (random.randint(1, 5) if is_fraud else 0)
        new_device    = 1 if (is_fraud and random.random() > 0.5) else 0
        vpn_detected  = 1 if (is_fraud and random.random() > 0.6) else 0
        night_txn     = 1 if hour in range(0, 6) else 0
        weekend       = 1 if day_of_week in (5, 6) else 0

        # Amount ratios
        amount_ratio = amount / (avg_amount + 1e-9)

        data.append({
            'amount': amount,
            'hour': hour,
            'day_of_week': day_of_week,
            'merchant_category': merchant_cat,
            'channel': channel,
            'card_type': card_type,
            'transaction_type': txn_type,
            'frequency_24h': freq_24h,
            'avg_amount_7d': avg_amount,
            'distance_from_home': dist_from_home,
            'failed_attempts': failed_attempts,
            'new_device': new_device,
            'vpn_detected': vpn_detected,
            'night_transaction': night_txn,
            'weekend': weekend,
            'amount_ratio': amount_ratio,
            'is_fraud': is_fraud,
        })

    return pd.DataFrame(data)


FEATURE_COLUMNS = [
    'amount', 'hour', 'day_of_week', 'merchant_category',
    'channel', 'card_type', 'transaction_type', 'frequency_24h',
    'avg_amount_7d', 'distance_from_home', 'failed_attempts',
    'new_device', 'vpn_detected', 'night_transaction', 'weekend',
    'amount_ratio',
]


def train_model():
    print("Generating synthetic training data …")
    df = generate_synthetic_data(10_000)
    print(f"Dataset: {len(df)} rows  |  fraud rate: {df['is_fraud'].mean():.2%}")

    X = df[FEATURE_COLUMNS]
    y = df['is_fraud']
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    pipeline = Pipeline([
        ('scaler', StandardScaler()),
        ('classifier', RandomForestClassifier(
            n_estimators=100,
            max_depth=10,
            min_samples_split=5,
            class_weight='balanced',
            random_state=42,
            n_jobs=-1,
        )),
    ])

    print("Training model …")
    pipeline.fit(X_train, y_train)

    y_pred      = pipeline.predict(X_test)
    y_pred_prob = pipeline.predict_proba(X_test)[:, 1]

    print("\n── Evaluation ─────────────────────────────────────────────")
    print(classification_report(y_test, y_pred, target_names=['Legitimate', 'Fraud']))
    print(f"ROC-AUC: {roc_auc_score(y_test, y_pred_prob):.4f}")
    print("Confusion matrix:")
    print(confusion_matrix(y_test, y_pred))

    # Save artefacts
    model_dir = os.path.dirname(os.path.abspath(__file__))
    model_path = os.path.join(model_dir, 'model.pkl')
    joblib.dump(pipeline, model_path)
    print(f"\nModel saved → {model_path}")

    # Save metadata
    meta = {
        'version': '1.0.0',
        'trained_at': datetime.now(timezone.utc).isoformat(),
        'features': FEATURE_COLUMNS,
        'n_estimators': 100,
        'fraud_threshold': 0.5,
        'roc_auc': round(roc_auc_score(y_test, y_pred_prob), 4),
    }
    meta_path = os.path.join(model_dir, 'model_metadata.json')
    with open(meta_path, 'w') as f:
        json.dump(meta, f, indent=2)
    print(f"Metadata saved → {meta_path}")
    return pipeline


if __name__ == '__main__':
    train_model()
