# GitHub Repository Setup Instructions

## Step 1: Create GitHub Repository
1. Go to https://github.com
2. Click the "+" button in the top right corner
3. Select "New repository"
4. Repository name: `fraud-detection-streamlit`
5. Description: `Real-time fraud detection dashboard with ML integration`
6. Choose **Public** (required for free Streamlit Cloud deployment)
7. **Do NOT** initialize with README, .gitignore, or license
8. Click "Create repository"

## Step 2: Push Your Code
After creating the repository, GitHub will show you setup commands. Use these:

```bash
git remote add origin https://github.com/YOUR_USERNAME/fraud-detection-streamlit.git
git branch -M main
git push -u origin main
```

Replace `YOUR_USERNAME` with your actual GitHub username.

## Step 3: Deploy to Streamlit Cloud
1. Go to https://share.streamlit.io/
2. Click "New app"
3. Connect your GitHub repository
4. Main file path: `streamlit_app.py`
5. Click "Deploy"

## Alternative: Use Different Repository Name
If you want to use a different repository name, update the remote URL:

```bash
git remote set-url origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
git push -u origin main
```

## Current Status
- [x] Git repository initialized locally
- [x] All files committed
- [ ] GitHub repository created
- [ ] Code pushed to GitHub
- [ ] Deployed to Streamlit Cloud
