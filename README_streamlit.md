# FraudGuard - Streamlit Deployment

Deploy your fraud detection system on Streamlit Cloud or run locally.

## Quick Start

### 1. Install Dependencies
```bash
pip install -r requirements_streamlit.txt
```

### 2. Run Locally
```bash
streamlit run streamlit_app.py
```

### 3. Deploy on Streamlit Cloud

#### Option A: GitHub Repository (Recommended)
1. Push your project to GitHub
2. Go to [Streamlit Cloud](https://share.streamlit.io/)
3. Click "New app"
4. Connect your GitHub repository
5. Select `streamlit_app.py` as main file
6. Click "Deploy"

#### Option B: Direct Upload
1. Go to [Streamlit Cloud](https://share.streamlit.io/)
2. Click "New app"
3. Choose "Paste your code"
4. Copy-paste `streamlit_app.py` content
5. Deploy

## Features

### 🏠 Dashboard
- Real-time fraud statistics
- Interactive charts and metrics
- Recent transaction monitoring
- Fraud trend analysis

### 🔍 Transaction Analysis
- Real-time fraud scoring
- ML model predictions
- Rule-based automation
- Risk level assessment

### 📊 Transaction History
- Filterable transaction list
- CSV export functionality
- Fraud status tracking

### 🚨 Fraud Alerts
- Real-time alert monitoring
- Severity-based color coding
- Alert history

### ⚙️ Settings
- Model status monitoring
- Threshold configuration
- System health checks

## Authentication

**Default Login:**
- Email: `admin@test.com`
- Password: `password123`

## Configuration

### Environment Variables (Optional)
Set these in Streamlit Cloud secrets or locally:
- `DATABASE_URL`: Path to your SQLite database
- `MODEL_PATH`: Path to your ML model file

### File Structure
```
fraud-detection-app/
├── streamlit_app.py              # Main Streamlit app
├── requirements_streamlit.txt      # Streamlit dependencies
├── backend/
│   ├── ml_model/
│   │   └── model.pkl           # ML model file
│   ├── fraud_detection.db        # SQLite database
│   └── automation/
│       └── engine.py            # Automation rules
└── README_streamlit.md          # This file
```

## Customization

### Adding New Rules
Edit `backend/automation/rules.py` to add custom fraud detection rules.

### Updating ML Model
Replace `backend/ml_model/model.pkl` with your trained model.

### Custom Styling
Modify the CSS in `streamlit_app.py` under the "Custom CSS" section.

## Troubleshooting

### Common Issues

1. **ML Model Not Found**
   - Ensure `backend/ml_model/model.pkl` exists
   - Check file permissions

2. **Database Connection Error**
   - Verify `backend/fraud_detection.db` exists
   - Check SQLite file permissions

3. **Dependencies Missing**
   - Run `pip install -r requirements_streamlit.txt`
   - Ensure Python 3.8+ is installed

4. **Streamlit Cloud Deployment Issues**
   - Check that all files are in the repository
   - Verify `streamlit_app.py` is the main file
   - Check Streamlit Cloud logs for errors

### Performance Tips

1. **Large Datasets**
   - Use pagination for transaction history
   - Consider data aggregation for dashboard

2. **ML Model Loading**
   - Model is cached using `@st.cache_resource`
   - First load may be slower

3. **Database Optimization**
   - Add indexes to frequently queried columns
   - Consider using PostgreSQL for production

## Security Notes

- Change default credentials in production
- Use environment variables for sensitive data
- Enable HTTPS in production
- Regular security audits recommended

## Support

For issues:
1. Check Streamlit Cloud logs
2. Verify all dependencies are installed
3. Test locally before deploying

## License

This project is for educational purposes. Use responsibly.
