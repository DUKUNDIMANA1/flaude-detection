# Vercel Deployment Guide

## Overview
This fraud detection dashboard is configured for deployment on Vercel.

## Project Structure
- `streamlit_app.py` - Main Streamlit dashboard
- `backend/` - Flask API and database
- `api/index.py` - Vercel serverless function entry point
- `vercel.json` - Vercel configuration
- `requirements.txt` - Python dependencies

## Deployment Steps

### 1. Install Vercel CLI
```bash
npm install -g vercel
```

### 2. Login to Vercel
```bash
vercel login
```

### 3. Deploy from Project Root
```bash
cd fraud-detection-app
vercel --prod
```

### 4. Environment Variables
Set these in Vercel dashboard:
- `SECRET_KEY` (generate new one)
- `JWT_SECRET_KEY` (generate new one)
- `DATABASE_URL=sqlite:///fraud_detection.db`

### 5. Database Setup
The SQLite database will be created automatically on first deployment.

## Features Deployed
- Real-time fraud detection dashboard
- Transaction monitoring
- Alert system
- Analytics and reporting
- User management

## Notes
- Streamlit runs in headless mode on Vercel
- Database is SQLite (file-based)
- Static files served from `/web` directory
- CORS enabled for API access

## Troubleshooting
If deployment fails:
1. Check Python version compatibility
2. Verify all dependencies in requirements.txt
3. Ensure environment variables are set
4. Check Vercel function logs
