# Jenkins CI/CD Pipeline — Flask Backend + Express Frontend on EC2

Feedback App (Express frontend + Flask backend) deployed on a single EC2 instance, with two Jenkins pipelines automating deployment on every push to GitHub.

## Architecture

```
GitHub (push to main)
        │  webhook (POST /github-webhook/)
        ▼
   Jenkins (:8080) ── runs on the same EC2 instance
        │  Checkout → Install Deps → Test → pm2 restart
        ▼
 ┌──────────────────────────────┐
 │  EC2 instance (t3.micro)     │
 │  ┌─────────────┐ ┌─────────┐ │
 │  │ Express :3000│→│Flask:5000│ │   both managed by pm2 (ec2-user),
 │  └─────────────┘ └─────────┘ │   pm2 registered as a systemd service
 └──────────────────────────────┘
```

## Repository Structure

```
jenkins-cicd-flask-express/
├── backend/          Flask API + Jenkinsfile
├── frontend/          Express server + form + Jenkinsfile
└── terraform/         EC2 provisioning (main.tf, variables.tf, outputs.tf, user-data.sh)
```

## Part 1: EC2 Provisioning

Provisioned via Terraform (`terraform/`), reusing the pattern from the earlier Terraform assignment. `user_data` installs Python, Node.js, pm2, and Jenkins (Java 21 — required by current Jenkins releases), clones this repo, and starts both apps under pm2. pm2 is registered as a systemd service (`pm2-ec2-user`) so both apps survive instance reboots.

**Security group:** ports 22 (SSH), 3000 (Express), 5000 (Flask), 8080 (Jenkins) — all open to the internet.

**Process management:** `pm2 list` on the instance shows both `flask-backend` and `express-frontend` as `online`, owned by `ec2-user`, persisted via `pm2 save` + `pm2 startup systemd`.

## Part 2: Jenkins CI/CD

### Pipelines
Two separate pipeline jobs, each pointed at this same repo but a different `Jenkinsfile` path:
- `flask-backend-pipeline` → `backend/Jenkinsfile`
- `express-frontend-pipeline` → `frontend/Jenkinsfile`

### Pipeline stages (both apps)
1. **Checkout** — pulls latest `main` from GitHub
2. **Install Dependencies** — `pip install -r requirements.txt` (backend) / `npm install` (frontend)
3. **Test** — lightweight sanity check (Python import check / Node boot check) — no fake test suite invented, since testing stages were an optional enhancement and neither app has a dedicated test framework
4. **Deploy** — `pm2 restart` if the process already exists, otherwise `pm2 start`, then `pm2 save`

### Why `sudo -u ec2-user`
Jenkins runs pipeline steps as the `jenkins` OS user, which has its own separate pm2 daemon. Left unchecked, this creates a second, independent set of pm2-managed processes competing for the same ports as the ones managed under `ec2-user` (the ones with systemd persistence configured). The Jenkinsfiles explicitly run all `pm2` commands as `sudo -u ec2-user` so deployments always target the single, persistent process set. This required adding `jenkins ALL=(ec2-user) NOPASSWD: ALL` to sudoers.

### GitHub Webhook
Configured at `https://github.com/Ankur037/jenkins-cicd-flask-express/settings/hooks`, payload URL `http://<ec2-public-ip>:8080/github-webhook/`, triggering on push events. Both pipeline jobs have **"GitHub hook trigger for GITScm polling"** enabled. Verified end-to-end: a push to `main` triggers an automatic build with no manual intervention.

## Notable Issues Resolved During Setup

| Issue | Fix |
|---|---|
| `t2.micro` not free-tier eligible in this account/region | Switched to `t3.micro` |
| EBS volume smaller than AMI snapshot requires | Bumped root volume to 30GB |
| Accidentally launched ECS-optimized AL2023 variant, missing `wget` | Switched Jenkins repo download to `curl`; tightened AMI filter |
| Jenkins 2.568 requires Java 21, we installed Java 17 | Switched to `java-21-amazon-corretto` |
| Jenkins built-in node marked offline ("disk space below threshold on /tmp") | `/tmp` was a 457MB tmpfs, permanently under Jenkins' 1GB threshold; masked `tmp.mount` so `/tmp` falls back to the 30GB root disk |
| pm2 processes didn't survive reboot | Original `pm2 save` ran as `root` during `user_data`, saving to the wrong user's dump file; apps were restarted and saved as `ec2-user`, matching the `pm2 startup systemd` service |
| Jenkins pipeline created a duplicate, competing pm2 process | Jenkinsfiles updated to run all `pm2` commands as `sudo -u ec2-user` |

## Running It Yourself

```bash
cd terraform
ssh-keygen -t rsa -b 2048 -f terraform-key -N ""
terraform init
terraform plan
terraform apply
```

Wait ~5 minutes for `user_data` to finish (Jenkins install is the slowest part), then:
```bash
terraform output
# grab the Jenkins initial admin password:
ssh -i terraform-key ec2-user@<public-ip>
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Unlock Jenkins, install suggested plugins + the NodeJS plugin, create both pipeline jobs pointing at this repo, add the GitHub webhook, and push to `main` to see it all work end-to-end.
