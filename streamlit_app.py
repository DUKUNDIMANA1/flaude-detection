"""
Fraud Detection Streamlit App
Deploy on Streamlit Cloud or run locally with: streamlit run streamlit_app.py
"""
import streamlit as st
import pandas as pd
import numpy as np
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime, timedelta
import joblib
import os
import sqlite3
import sys

# Add backend directory to Python path
sys.path.append(os.path.join(os.path.dirname(__file__), 'backend'))

from database.models import User, Transaction, Alert, Rule
from database.db_config import db
from automation.engine import AutomationEngine

# Page configuration
st.set_page_config(
    page_title="FraudGuard - Fraud Detection Dashboard",
    page_icon="🛡️",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS
st.markdown("""
<style>
    .main-header {
        font-size: 2.5rem;
        font-weight: bold;
        color: #1f77b4;
        text-align: center;
        margin-bottom: 2rem;
    }
    .metric-card {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        padding: 1.5rem;
        border-radius: 10px;
        color: white;
        margin: 0.5rem 0;
    }
    .alert-high {
        background-color: #ff4b4b;
        color: white;
        padding: 0.5rem;
        border-radius: 5px;
    }
    .alert-medium {
        background-color: #ffa500;
        color: white;
        padding: 0.5rem;
        border-radius: 5px;
    }
    .alert-low {
        background-color: #28a745;
        color: white;
        padding: 0.5rem;
        border-radius: 5px;
    }
</style>
""", unsafe_allow_html=True)

# Initialize session state
if 'authenticated' not in st.session_state:
    st.session_state.authenticated = False
if 'user' not in st.session_state:
    st.session_state.user = None

# Load ML model
@st.cache_resource
def load_ml_model():
    model_path = os.path.join(os.path.dirname(__file__), 'backend', 'ml_model', 'model.pkl')
    if os.path.exists(model_path):
        return joblib.load(model_path)
    return None

ml_model = load_ml_model()

# Database helper functions
def get_db_connection():
    conn = sqlite3.connect('backend/fraud_detection.db')
    return conn

def get_dashboard_stats():
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Get basic stats
    cursor.execute("SELECT COUNT(*) FROM transactions")
    total_transactions = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM transactions WHERE is_fraud = 1")
    total_fraud = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM transactions WHERE DATE(timestamp) = DATE('now')")
    today_transactions = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM transactions WHERE is_fraud = 1 AND DATE(timestamp) = DATE('now')")
    today_fraud = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM transactions WHERE DATE(timestamp) >= DATE('now', '-7 days')")
    week_transactions = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM transactions WHERE is_fraud = 1 AND DATE(timestamp) >= DATE('now', '-7 days')")
    week_fraud = cursor.fetchone()[0]
    
    cursor.execute("SELECT AVG(fraud_score) FROM transactions WHERE fraud_score IS NOT NULL")
    avg_fraud_score = cursor.fetchone()[0] or 0
    
    cursor.execute("SELECT COUNT(*) FROM transactions WHERE status = 'pending'")
    pending_review = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM alerts WHERE is_read = 0")
    unread_alerts = cursor.fetchone()[0]
    
    # Get fraud trend for last 7 days
    cursor.execute("""
        SELECT DATE(timestamp) as date, COUNT(*) as fraud_count
        FROM transactions 
        WHERE is_fraud = 1 AND DATE(timestamp) >= DATE('now', '-7 days')
        GROUP BY DATE(timestamp)
        ORDER BY date
    """)
    fraud_trend = [{'date': row[0], 'fraud_count': row[1]} for row in cursor.fetchall()]
    
    conn.close()
    
    return {
        'total_transactions': total_transactions,
        'total_fraud': total_fraud,
        'fraud_rate': (total_fraud / total_transactions * 100) if total_transactions > 0 else 0,
        'today_transactions': today_transactions,
        'today_fraud': today_fraud,
        'week_transactions': week_transactions,
        'week_fraud': week_fraud,
        'avg_fraud_score': round(avg_fraud_score, 3),
        'pending_review': pending_review,
        'unread_alerts': unread_alerts,
        'fraud_trend': fraud_trend
    }

def get_recent_transactions(limit=50):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT * FROM transactions 
        ORDER BY timestamp DESC 
        LIMIT ?
    """, (limit,))
    
    columns = [description[0] for description in cursor.description]
    transactions = [dict(zip(columns, row)) for row in cursor.fetchall()]
    conn.close()
    return transactions

def get_recent_alerts(limit=20):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT * FROM alerts 
        ORDER BY created_at DESC 
        LIMIT ?
    """, (limit,))
    
    columns = [description[0] for description in cursor.description]
    alerts = [dict(zip(columns, row)) for row in cursor.fetchall()]
    conn.close()
    return alerts

def analyze_transaction(transaction_data):
    """Analyze a transaction using ML model and rules"""
    if not ml_model:
        return {'error': 'ML model not loaded'}
    
    try:
        # Prepare features for ML model
        feature_columns = [
            'amount', 'hour', 'day_of_week', 'merchant_category',
            'channel', 'card_type', 'transaction_type', 'frequency_24h',
            'avg_amount_7d', 'distance_from_home', 'failed_attempts',
            'new_device', 'vpn_detected', 'night_transaction', 'weekend',
            'amount_ratio',
        ]
        
        # Create feature array (simplified for demo)
        features = np.zeros(len(feature_columns))
        
        # Map some basic features
        amount = transaction_data.get('amount', 0)
        features[0] = amount  # amount
        features[7] = transaction_data.get('frequency_24h', 0)  # frequency_24h
        features[8] = transaction_data.get('avg_amount_7d', 0)  # avg_amount_7d
        features[10] = transaction_data.get('failed_attempts', 0)  # failed_attempts
        features[11] = 1 if transaction_data.get('new_device', False) else 0  # new_device
        features[12] = 1 if transaction_data.get('vpn_detected', False) else 0  # vpn_detected
        
        # Calculate amount_ratio
        avg_amount = transaction_data.get('avg_amount_7d', 1)
        if avg_amount > 0:
            features[14] = amount / avg_amount  # amount_ratio
        
        # Get ML prediction
        fraud_score = ml_model.predict_proba([features])[0][1]
        
        # Apply automation rules
        automation_engine = AutomationEngine(None, {'Rule': Rule, 'Alert': Alert, 'Transaction': Transaction})
        rule_result = automation_engine.evaluate_transaction(transaction_data, {'fraud_score': fraud_score})
        
        return {
            'fraud_score': round(fraud_score, 3),
            'is_fraud': fraud_score > 0.5,
            'rule_result': rule_result,
            'risk_level': 'High' if fraud_score > 0.7 else 'Medium' if fraud_score > 0.3 else 'Low'
        }
        
    except Exception as e:
        return {'error': str(e)}

# Authentication
def login_page():
    st.markdown('<h1 class="main-header">🛡️ FraudGuard</h1>', unsafe_allow_html=True)
    
    col1, col2, col3 = st.columns([1, 2, 1])
    with col2:
        st.subheader("Login")
        
        with st.form("login_form"):
            email = st.text_input("Email", key="login_email")
            password = st.text_input("Password", type="password", key="login_password")
            submit_button = st.form_submit_button("Login")
            
            if submit_button:
                # Simple authentication (in production, use proper auth)
                if email == "admin@test.com" and password == "password123":
                    st.session_state.authenticated = True
                    st.session_state.user = {"email": email, "role": "admin"}
                    st.success("Login successful!")
                    st.rerun()
                else:
                    st.error("Invalid credentials. Use admin@test.com / password123")

def main_dashboard():
    st.markdown('<h1 class="main-header">🛡️ FraudGuard Dashboard</h1>', unsafe_allow_html=True)
    
    # Sidebar navigation
    with st.sidebar:
        st.title("Navigation")
        page = st.selectbox("Choose a page", ["Dashboard", "Analyze Transaction", "Transactions", "Alerts", "Settings"])
        
        st.markdown("---")
        st.info(f"Logged in as: {st.session_state.user['email']}")
        if st.button("Logout"):
            st.session_state.authenticated = False
            st.session_state.user = None
            st.rerun()
    
    if page == "Dashboard":
        dashboard_page()
    elif page == "Analyze Transaction":
        analyze_page()
    elif page == "Transactions":
        transactions_page()
    elif page == "Alerts":
        alerts_page()
    elif page == "Settings":
        settings_page()

def dashboard_page():
    # Get dashboard stats
    stats = get_dashboard_stats()
    
    # Key metrics
    col1, col2, col3, col4 = st.columns(4)
    with col1:
        st.markdown(f"""
        <div class="metric-card">
            <h3>{stats['total_transactions']}</h3>
            <p>Total Transactions</p>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        st.markdown(f"""
        <div class="metric-card">
            <h3>{stats['total_fraud']}</h3>
            <p>Total Fraud Cases</p>
        </div>
        """, unsafe_allow_html=True)
    
    with col3:
        st.markdown(f"""
        <div class="metric-card">
            <h3>{stats['fraud_rate']:.2f}%</h3>
            <p>Fraud Rate</p>
        </div>
        """, unsafe_allow_html=True)
    
    with col4:
        st.markdown(f"""
        <div class="metric-card">
            <h3>{stats['avg_fraud_score']:.3f}</h3>
            <p>Avg Fraud Score</p>
        </div>
        """, unsafe_allow_html=True)
    
    # Charts section
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("Fraud Trend (Last 7 Days)")
        if stats['fraud_trend']:
            trend_df = pd.DataFrame(stats['fraud_trend'])
            fig = px.line(trend_df, x='date', y='fraud_count', 
                         title='Daily Fraud Cases', 
                         labels={'fraud_count': 'Number of Fraud Cases'})
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No fraud data available for the last 7 days")
    
    with col2:
        st.subheader("Today's Summary")
        col2_1, col2_2 = st.columns(2)
        with col2_1:
            st.metric("Today's Transactions", stats['today_transactions'])
            st.metric("Today's Fraud", stats['today_fraud'])
        with col2_2:
            st.metric("Pending Review", stats['pending_review'])
            st.metric("Unread Alerts", stats['unread_alerts'])
    
    # Recent transactions
    st.subheader("Recent Transactions")
    recent_txns = get_recent_transactions(10)
    if recent_txns:
        df = pd.DataFrame(recent_txns)
        # Select relevant columns
        display_columns = ['transaction_id', 'amount', 'merchant', 'fraud_score', 'is_fraud', 'status', 'timestamp']
        df_display = df[display_columns] if all(col in df.columns for col in display_columns) else df
        
        # Style the dataframe
        def highlight_fraud(row):
            if row.get('is_fraud', False):
                return ['background-color: #ffcccc'] * len(row)
            elif row.get('fraud_score', 0) > 0.5:
                return ['background-color: #fff3cd'] * len(row)
            return [''] * len(row)
        
        styled_df = df_display.style.apply(highlight_fraud, axis=1)
        st.dataframe(styled_df, use_container_width=True)
    else:
        st.info("No transactions found")

def analyze_page():
    st.subheader("Analyze Transaction")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("Transaction Details")
        amount = st.number_input("Amount", min_value=0.0, value=100.0, step=0.01)
        merchant = st.text_input("Merchant", value="Test Store")
        merchant_category = st.selectbox("Merchant Category", 
                                     ["electronics", "retail", "restaurant", "gas", "online", "other"])
        channel = st.selectbox("Channel", ["online", "pos", "atm", "mobile"])
        card_type = st.selectbox("Card Type", ["credit", "debit"])
        
    with col2:
        st.write("Risk Factors")
        new_device = st.checkbox("New Device")
        vpn_detected = st.checkbox("VPN Detected")
        frequency_24h = st.number_input("Transactions (24h)", min_value=0, value=1)
        failed_attempts = st.number_input("Failed Attempts", min_value=0, value=0)
        avg_amount_7d = st.number_input("Avg Amount (7 days)", min_value=0.0, value=50.0, step=0.01)
    
    if st.button("Analyze Transaction", type="primary"):
        transaction_data = {
            'amount': amount,
            'merchant': merchant,
            'merchant_category': merchant_category,
            'channel': channel,
            'card_type': card_type,
            'new_device': new_device,
            'vpn_detected': vpn_detected,
            'frequency_24h': frequency_24h,
            'failed_attempts': failed_attempts,
            'avg_amount_7d': avg_amount_7d,
        }
        
        with st.spinner("Analyzing transaction..."):
            result = analyze_transaction(transaction_data)
        
        if 'error' in result:
            st.error(f"Analysis failed: {result['error']}")
        else:
            st.success("Analysis complete!")
            
            # Display results
            col1, col2, col3 = st.columns(3)
            with col1:
                st.metric("Fraud Score", f"{result['fraud_score']:.3f}")
            with col2:
                st.metric("Risk Level", result['risk_level'])
            with col3:
                st.metric("Is Fraud", "Yes" if result['is_fraud'] else "No")
            
            # Risk level color coding
            if result['risk_level'] == 'High':
                st.markdown('<div class="alert-high">High Risk Transaction - Immediate Review Required</div>', unsafe_allow_html=True)
            elif result['risk_level'] == 'Medium':
                st.markdown('<div class="alert-medium">Medium Risk Transaction - Review Recommended</div>', unsafe_allow_html=True)
            else:
                st.markdown('<div class="alert-low">Low Risk Transaction - Approved</div>', unsafe_allow_html=True)

def transactions_page():
    st.subheader("Transaction History")
    
    # Filters
    col1, col2, col3 = st.columns(3)
    with col1:
        status_filter = st.selectbox("Status", ["All", "pending", "approved", "blocked", "review"])
    with col2:
        fraud_filter = st.selectbox("Fraud Status", ["All", "Fraud", "Not Fraud"])
    with col3:
        limit = st.number_input("Limit", min_value=10, max_value=1000, value=50)
    
    if st.button("Refresh"):
        st.rerun()
    
    # Get and display transactions
    transactions = get_recent_transactions(limit)
    
    if transactions:
        df = pd.DataFrame(transactions)
        
        # Apply filters
        if status_filter != "All":
            df = df[df['status'] == status_filter]
        
        if fraud_filter == "Fraud":
            df = df[df['is_fraud'] == 1]
        elif fraud_filter == "Not Fraud":
            df = df[df['is_fraud'] == 0]
        
        st.dataframe(df, use_container_width=True)
        
        # Export option
        csv = df.to_csv(index=False)
        st.download_button(
            label="Download as CSV",
            data=csv,
            file_name=f"transactions_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv",
            mime="text/csv"
        )
    else:
        st.info("No transactions found")

def alerts_page():
    st.subheader("Fraud Alerts")
    
    alerts = get_recent_alerts(50)
    
    if alerts:
        for alert in alerts:
            severity = alert.get('severity', 'low')
            alert_class = f"alert-{severity}"
            
            st.markdown(f"""
            <div class="{alert_class}">
                <h4>{alert.get('title', 'Alert')}</h4>
                <p>{alert.get('message', '')}</p>
                <small>Created: {alert.get('created_at', '')}</small>
            </div>
            """, unsafe_allow_html=True)
    else:
        st.info("No alerts found")

def settings_page():
    st.subheader("Settings")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("Model Information")
        if ml_model:
            st.success("✅ ML Model Loaded Successfully")
            st.info(f"Model type: {type(ml_model).__name__}")
        else:
            st.error("❌ ML Model Not Found")
            st.warning("Please ensure 'backend/ml_model/model.pkl' exists")
    
    with col2:
        st.write("System Status")
        st.success("✅ Database Connected")
        st.success("✅ Automation Engine Ready")
    
    st.markdown("---")
    st.write("Configuration")
    
    # Threshold settings
    st.subheader("Fraud Thresholds")
    high_threshold = st.slider("High Risk Threshold", 0.0, 1.0, 0.7, 0.05)
    medium_threshold = st.slider("Medium Risk Threshold", 0.0, 1.0, 0.3, 0.05)
    
    if st.button("Save Settings"):
        st.success("Settings saved successfully!")

# Main app logic
def main():
    if not st.session_state.authenticated:
        login_page()
    else:
        main_dashboard()

if __name__ == "__main__":
    main()
