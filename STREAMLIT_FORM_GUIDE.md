# Streamlit Cloud Deployment Form Guide

## Form Fields to Fill:

### 1. Repository
```
eugenedukunda/fraud-detection-streamlit
```

### 2. Branch
```
main
```

### 3. Main file path
```
streamlit_app.py
```

### 4. App URL (optional)
```
fraud-guard
```
*(or leave blank for auto-generated URL)*

## Before Filling the Form:

### Step 1: Create GitHub Repository
1. Go to https://github.com
2. Login with: eugenedukunda@gmail.com
3. Click "+" in top right corner
4. Select "New repository"
5. Repository name: `fraud-detection-streamlit`
6. Description: `Real-time fraud detection dashboard with ML integration`
7. Choose **Public** (required for free deployment)
8. **Do NOT** initialize with README, .gitignore, or license
9. Click "Create repository"

### Step 2: Push Code (After Repository Exists)
Once you create the repository, run:
```bash
git push -u origin main
```

### Step 3: Fill Streamlit Form
After code is pushed to GitHub, fill the form with:
- Repository: `eugenedukunda/fraud-detection-streamlit`
- Branch: `main`
- Main file path: `streamlit_app.py`
- App URL: `fraud-guard` (optional)

## Alternative: Direct Code Upload
If you don't want to use GitHub:

1. On Streamlit Cloud, select "Paste your code"
2. Copy entire content of `streamlit_app.py`
3. Paste and click "Deploy"

## Current Status:
- [x] Git repository ready locally
- [x] All files committed
- [x] Remote configured for eugenedukunda
- [ ] GitHub repository created
- [ ] Code pushed to GitHub
- [ ] Form filled and deployed

## Troubleshooting:
- If repository not found: Create it first on GitHub
- If branch error: Use `main` not `master`
- If file not found: Ensure `streamlit_app.py` exists in repo root

## Expected Final URL:
https://fraud-guard.streamlit.app
(or auto-generated if App URL left blank)
