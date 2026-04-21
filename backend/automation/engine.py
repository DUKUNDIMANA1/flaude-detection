"""
Automation Engine
Evaluates rules against a transaction and decides the resulting action.
"""
import json
import uuid
from datetime import datetime, timedelta
from typing import Dict, Any, List, Tuple


class AutomationEngine:
    def __init__(self, db, models):
        self.db = db
        self.Rule = models['Rule']
        self.Alert = models['Alert']
        self.Transaction = models['Transaction']

    # ── Public API ────────────────────────────────────────────────────────────

    def evaluate_transaction(self, transaction, tx_features: Dict[str, Any]) -> Dict[str, Any]:
        """
        Run all active rules against *transaction* and return a result dict.
        Side-effects: creates Alert rows, updates rule trigger counts.
        """
        rules = self.Rule.query.filter_by(is_active=True).all()
        triggered_rules: List[Dict] = []
        final_action = 'approve'
        final_severity = 'low'

        severity_rank = {'low': 1, 'medium': 2, 'high': 3, 'critical': 4}
        action_rank   = {'approve': 0, 'flag': 1, 'review': 2, 'alert': 3, 'block': 4}

        for rule in rules:
            try:
                condition = json.loads(rule.condition)
                if self._evaluate_condition(condition, tx_features):
                    triggered_rules.append({
                        'rule_id': rule.id,
                        'rule_name': rule.name,
                        'action': rule.action,
                        'severity': rule.severity,
                    })

                    # Escalate action/severity
                    if action_rank.get(rule.action, 0) > action_rank.get(final_action, 0):
                        final_action = rule.action
                    if severity_rank.get(rule.severity, 0) > severity_rank.get(final_severity, 0):
                        final_severity = rule.severity

                    # Update trigger counter
                    rule.trigger_count = (rule.trigger_count or 0) + 1
            except Exception:
                pass  # Malformed rule — skip silently

        # Determine status from action
        status_map = {
            'approve': 'approved',
            'flag':    'flagged',
            'review':  'review',
            'alert':   'review',
            'block':   'blocked',
        }
        new_status = status_map.get(final_action, 'pending')

        # Create alerts for serious outcomes
        alerts_created = []
        if final_action in ('block', 'alert', 'flag') and triggered_rules:
            alert = self._create_alert(transaction, triggered_rules, final_severity)
            alerts_created.append(alert.alert_id)

        self.db.session.commit()

        return {
            'action': final_action,
            'status': new_status,
            'severity': final_severity,
            'triggered_rules': triggered_rules,
            'alerts_created': alerts_created,
        }

    def seed_default_rules(self):
        """Insert default rules if the table is empty."""
        from automation.rules import DEFAULT_RULES
        if self.Rule.query.count() == 0:
            for r in DEFAULT_RULES:
                rule = self.Rule(**r)
                self.db.session.add(rule)
            self.db.session.commit()

    # ── Condition evaluator ───────────────────────────────────────────────────

    def _evaluate_condition(self, condition: Dict, features: Dict) -> bool:
        field    = condition.get('field')
        operator = condition.get('operator')
        value    = condition.get('value')
        and_cond = condition.get('and')

        feature_value = features.get(field)
        if feature_value is None:
            return False

        result = self._compare(feature_value, operator, value)

        if result and and_cond:
            result = result and self._evaluate_condition(and_cond, features)

        return result

    @staticmethod
    def _compare(feature_val, operator: str, value) -> bool:
        try:
            if operator == '>':        return float(feature_val) >  float(value)
            if operator == '>=':       return float(feature_val) >= float(value)
            if operator == '<':        return float(feature_val) <  float(value)
            if operator == '<=':       return float(feature_val) <= float(value)
            if operator == '==':       return feature_val == value
            if operator == '!=':       return feature_val != value
            if operator == 'between':  return float(value[0]) <= float(feature_val) <= float(value[1])
            if operator == 'in':       return feature_val in value
        except (TypeError, ValueError):
            pass
        return False

    # ── Alert factory ─────────────────────────────────────────────────────────

    def _create_alert(self, transaction, triggered_rules: List[Dict], severity: str):
        rule_names = ', '.join(r['rule_name'] for r in triggered_rules)
        alert = self.Alert(
            alert_id=str(uuid.uuid4()),
            transaction_id_ref=transaction.id,
            user_id=transaction.user_id,
            alert_type='rule_violation' if transaction.fraud_score < 0.5 else 'fraud_detected',
            severity=severity,
            title=f"Suspicious transaction detected — {severity.upper()} severity",
            message=(
                f"Transaction {transaction.transaction_id} triggered rules: {rule_names}. "
                f"Amount: ${transaction.amount:.2f}. "
                f"Fraud score: {transaction.fraud_score:.2%}."
            ),
        )
        self.db.session.add(alert)
        return alert
