#!/bin/bash
set -e

# --- Base dependencies ---
dnf update -y
dnf install -y git python3 python3-pip java-21-amazon-corretto

# --- Node.js ---
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
dnf install -y nodejs

# --- pm2 (process manager for both apps) ---
npm install -g pm2

# --- Clone the app and start it FIRST, so app deployment never depends on Jenkins succeeding ---
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

echo "App setup complete" > /home/ec2-user/setup-done.txt

# --- Jenkins install is best-effort from here on: don't let a Jenkins failure mark the whole script as failed ---
set +e

curl -fsSL https://pkg.jenkins.io/redhat-stable/jenkins.repo -o /etc/yum.repos.d/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
dnf install -y jenkins
usermod -aG wheel jenkins
systemctl enable jenkins
systemctl start jenkins

echo "Jenkins setup attempted" > /home/ec2-user/jenkins-setup-done.txt
