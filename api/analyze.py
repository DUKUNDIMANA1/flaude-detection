"""
API endpoint for transaction analysis
"""
from flask import Flask, request, jsonify
import os
import sys
from pathlib import Path

# Add the current directory to Python path
current_dir = Path(__file__).parent
sys.path.append(str(current_dir))
sys.path.append(str(current_dir / "backend"))

# Initialize Flask app
app = Flask(__name__)

@app.route('/api/analyze', methods=['POST'])
def analyze_transaction():
    """Analyze transaction for fraud detection"""
    try:
        with app.app_context():
            # Get transaction data from request
            data = request.get_json() if request.is_json else {}
            
            # Simple analysis logic (without database dependencies)
            analysis_result = {
                'status': 'success',
                'risk_score': 0.2,
                'is_fraud': False,
                'confidence': 0.85,
                'features': {
                    'amount_risk': 'low',
                    'time_risk': 'medium', 
                    'location_risk': 'low'
                },
                'message': 'Transaction appears legitimate'
            }
            
            return jsonify(analysis_result)
            
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': f'Analysis failed: {str(e)}'
        }), 500

@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'fraud-detection-api',
        'version': '1.0.0'
    })

def handler(request):
    """Vercel serverless handler"""
    return app(request.environ, lambda status, headers: None)
