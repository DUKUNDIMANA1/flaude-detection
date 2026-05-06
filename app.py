"""
Flask Application for Fraud Detection
"""
from flask import Flask, render_template, request, jsonify, session
import os
import sys
from pathlib import Path

# Add the current directory to Python path
current_dir = Path(__file__).parent
sys.path.append(str(current_dir))
sys.path.append(str(current_dir / "backend"))

app = Flask(__name__)
app.secret_key = 'fraud-detection-secret-2024'

# Mock data for demonstration
def mock_fraud_analysis(transaction_data):
    """Mock fraud detection analysis"""
    amount = float(transaction_data.get('amount', 0))
    category = transaction_data.get('category', 'retail')
    failed_attempts = int(transaction_data.get('failed_attempts', 0))
    channel = transaction_data.get('channel', 'online')
    avg_amount = float(transaction_data.get('avg_amount', 0))
    
    risk_score = 0
    risk_factors = []
    
    # Risk analysis logic
    if amount > 1000:
        risk_score += 0.3
        risk_factors.append('High amount transaction')
    
    if failed_attempts > 0:
        risk_score += 0.2 * failed_attempts
        risk_factors.append(f'{failed_attempts} failed attempts')
    
    if channel == 'online' and amount > 500:
        risk_score += 0.25
        risk_factors.append('High-value online transaction')
    
    if avg_amount > 0 and amount > avg_amount * 3:
        risk_score += 0.2
        risk_factors.append('Amount significantly higher than average')
    
    is_fraud = risk_score > 0.5
    confidence = min(risk_score * 2, 0.95)
    
    return {
        'status': 'success',
        'risk_score': risk_score,
        'is_fraud': is_fraud,
        'confidence': confidence,
        'risk_factors': risk_factors,
        'recommendation': 'Flag for manual review' if is_fraud else 'Transaction appears legitimate'
    }

@app.route('/')
def dashboard():
    """Main dashboard page"""
    return render_template('dashboard.html')

@app.route('/analyze')
def analyze_page():
    """Analyze transaction page"""
    return render_template('analyze.html')

@app.route('/api/analyze', methods=['POST'])
def analyze_transaction():
    """API endpoint for transaction analysis"""
    try:
        with app.app_context():
            data = request.get_json()
            result = mock_fraud_analysis(data)
            return jsonify(result)
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': f'Analysis failed: {str(e)}'
        }), 500

@app.route('/api/health')
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'fraud-detection-api',
        'version': '1.0.0'
    })

# Vercel serverless handler
def handler(request):
    """Main Vercel handler function"""
    return app(request.environ, lambda status, headers: None)

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
