"""
Rule definitions — loaded by the automation engine at startup.
Each rule is a dict that gets upserted into the database.
"""
import json

DEFAULT_RULES = [
    {
        "name": "high_amount_transaction",
        "description": "Flag transactions above $5,000",
        "rule_type": "amount",
        "condition": json.dumps({"field": "amount", "operator": ">", "value": 5000}),
        "action": "flag",
        "severity": "high",
    },
    {
        "name": "very_high_amount_transaction",
        "description": "Block transactions above $10,000",
        "rule_type": "amount",
        "condition": json.dumps({"field": "amount", "operator": ">", "value": 10000}),
        "action": "block",
        "severity": "critical",
    },
    {
        "name": "high_frequency_transactions",
        "description": "Alert when more than 10 transactions occur within 1 hour",
        "rule_type": "frequency",
        "condition": json.dumps({"field": "frequency_1h", "operator": ">", "value": 10}),
        "action": "alert",
        "severity": "high",
    },
    {
        "name": "late_night_large_transaction",
        "description": "Flag large transactions between midnight and 5 AM",
        "rule_type": "time",
        "condition": json.dumps({
            "field": "hour", "operator": "between", "value": [0, 5],
            "and": {"field": "amount", "operator": ">", "value": 1000}
        }),
        "action": "flag",
        "severity": "medium",
    },
    {
        "name": "multiple_failed_attempts",
        "description": "Block after 3 or more failed transaction attempts",
        "rule_type": "frequency",
        "condition": json.dumps({"field": "failed_attempts", "operator": ">=", "value": 3}),
        "action": "block",
        "severity": "critical",
    },
    {
        "name": "new_device_high_amount",
        "description": "Review high-value transactions from unrecognised devices",
        "rule_type": "device",
        "condition": json.dumps({
            "field": "new_device", "operator": "==", "value": 1,
            "and": {"field": "amount", "operator": ">", "value": 500}
        }),
        "action": "review",
        "severity": "medium",
    },
    {
        "name": "vpn_detected",
        "description": "Flag transactions made through a VPN",
        "rule_type": "location",
        "condition": json.dumps({"field": "vpn_detected", "operator": "==", "value": 1}),
        "action": "flag",
        "severity": "medium",
    },
    {
        "name": "high_fraud_score",
        "description": "Block transactions with ML fraud probability > 80 %",
        "rule_type": "ml_score",
        "condition": json.dumps({"field": "fraud_score", "operator": ">", "value": 0.8}),
        "action": "block",
        "severity": "critical",
    },
    {
        "name": "medium_fraud_score",
        "description": "Flag transactions with ML fraud probability between 50 % and 80 %",
        "rule_type": "ml_score",
        "condition": json.dumps({
            "field": "fraud_score", "operator": "between", "value": [0.5, 0.8]
        }),
        "action": "flag",
        "severity": "high",
    },
]
