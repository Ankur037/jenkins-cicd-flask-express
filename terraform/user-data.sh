#!/bin/bash
set -e

# --- Base dependencies ---
dnf update -y
dnf install -y git python3 python3-pip java-17-amazon-corretto

# --- Node.js ---
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
dnf install -y nodejs

# --- pm2 (process manager for both apps) ---
npm install -g pm2

# --- Jenkins ---
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
dnf install -y jenkins
systemctl enable jenkins
systemctl start jenkins

# --- Give jenkins user access to run pm2/npm/python (needed for pipeline deploy stages) ---
usermod -aG wheel jenkins

# --- Clone the app and do an initial manual start (Jenkins pipelines will manage restarts later) ---
cd /home/ec2-user
git clone https://github.com/Ankur037/jenkins-cicd-flask-express.git
cd jenkins-cicd-flask-express

cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
pm2 start venv/bin/python --name flask-backend --interpreter none -- app.py
deactivate

cd ../frontend
npm install
BACKEND_URL=http://localhost:5000 pm2 start server.js --name express-frontend

pm2 save
pm2 startup systemd -u ec2-user --hp /home/ec2-user | tail -1 > /tmp/pm2-startup-cmd.sh
bash /tmp/pm2-startup-cmd.sh || true

echo "Setup complete" > /home/ec2-user/setup-done.txt
