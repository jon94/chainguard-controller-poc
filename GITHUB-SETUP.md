# GitHub Repository Setup Commands

## Step 1: Initialize Git Repository
```bash
cd /Users/jonathan.lim/chainguard-controller-poc
git init
git branch -M main
```

## Step 2: Add All Files and Make Initial Commit
```bash
# Add all files to staging
git add .

# Make initial commit
git commit -m "Initial commit: Chainguard Image Policy Controller MVP

- Custom Kubernetes controller built with Kubebuilder
- ImagePolicy CRD for monitoring DockerHub repositories
- Real-time compliance monitoring with 10-second check intervals
- Demo application and comprehensive documentation
- Ready for Chainguard Enterprise Sales Engineer interview"
```

## Step 3: Create GitHub Repository
You have two options:

### Option A: Using GitHub CLI (if installed)
```bash
# Install GitHub CLI if not already installed
brew install gh

# Login to GitHub
gh auth login

# Create repository
gh repo create jon94/chainguard-controller-poc --public --description "Kubernetes controller for monitoring container image digest compliance - Chainguard interview MVP"

# Push to GitHub
git remote add origin https://github.com/jon94/chainguard-controller-poc.git
git push -u origin main
```

### Option B: Manual GitHub Creation
1. Go to https://github.com/new
2. Repository name: `chainguard-controller-poc`
3. Description: `Kubernetes controller for monitoring container image digest compliance - Chainguard interview MVP`
4. Set to Public
5. Don't initialize with README (we already have one)
6. Click "Create repository"

Then run:
```bash
git remote add origin https://github.com/jon94/chainguard-controller-poc.git
git push -u origin main
```

## Step 4: Verify Repository
```bash
# Check remote
git remote -v

# Check status
git status

# View commit history
git log --oneline
```

## Step 5: Future GitHub Actions Setup (Optional)
When you're ready to set up CI/CD, you'll need to add these secrets to your GitHub repository:

1. Go to: https://github.com/jon94/chainguard-controller-poc/settings/secrets/actions
2. Add these secrets:
   - `DOCKERHUB_USERNAME`: `jonlimpw`
   - `DOCKERHUB_TOKEN`: Your DockerHub access token

## Repository Structure
After pushing, your GitHub repository will contain:
```
chainguard-controller-poc/
├── .gitignore                    # Git ignore rules
├── README.md                     # Main documentation
├── DEMO-SCRIPT.md               # Interview demo guide
├── PROJECT-SUMMARY.md           # Project overview
├── COMMANDS.md                  # Command reference
├── GITHUB-SETUP.md             # This file
├── controller/                  # Kubebuilder project
│   ├── api/v1/                 # CRD definitions
│   ├── internal/controller/    # Controller logic
│   ├── config/                 # Kubernetes manifests
│   └── cmd/                    # Main application
├── demo-app/                   # Sample application
└── scripts/                    # Demo and deployment scripts
```

## Next Steps
1. ✅ Repository created and code committed
2. 🔄 Set up GitHub Actions for CI/CD (optional)
3. 🎯 Practice demo for Chainguard interview
4. 🚀 Deploy to GKE and run demo

Your Chainguard Controller MVP is now ready for version control and collaboration! 🎉
