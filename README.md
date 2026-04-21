# Jenkins Backup & Restore to Docker

## Two Scripts

| Script | What it does |
|--------|--------------|
| `01-install-jenkins-with-dummy-app.sh` | Install fresh Jenkins + create dummy job (for testing) |
| `02-backup-and-restore-old-jenkins.sh` | Backup your old Jenkins + restore into Docker |

---

## Prerequisites

- Linux server (Ubuntu, RHEL, OEL8)
- Internet connection
- 2GB free disk space

---

## Script 1: Install Jenkins with Dummy App (For Testing)

### Step 1: Run the script

```
chmod +x 01-install-jenkins-with-dummy-app.sh
```
```
./01-install-jenkins-with-dummy-app.sh

```
Step 2: Enter port when asked
text

Enter port for Jenkins (default: 8080): 8080

Step 3: Enter Jenkins version
text

Enter Jenkins version (default: lts-jdk11): lts-jdk11

Step 4: Wait for completion (about 2 minutes)

Step 5: Get the admin password from output or file
```
bash
cat ~/jenkins-password.txt
```

Step 6: Open browser
text
http://YOUR_SERVER_IP:8080

Step 7: Enter password and complete setup

Step 8: Create dummy test job manually
- Go to "New Item" in Jenkins dashboard
- Enter name: "dummy-test-job"
- Select "Freestyle project"
- In build steps, add "Execute shell" with:
```
echo "========================================="
echo "DUMMY APP BUILD SUCCESSFUL!"
echo "========================================="
echo "Current date: $(date)"
echo "Hostname: $(hostname)"
echo "========================================="
echo "This job was created manually"
echo "========================================="
```
- Save and build the job

✅ Done! You now have a test Jenkins with a dummy job.

---

## Testing the Scripts

### Test Script 1 (Fresh Install)
- Run `./01-install-jenkins-with-dummy-app.sh`
- Access http://YOUR_SERVER_IP:8080
- Complete setup and create dummy job manually
- Verify job runs successfully

### Test Script 2 (Backup & Restore)
For testing purposes, you can use the Jenkins from Script 1:

1. Run Script 1 to create test Jenkins
2. Copy the data: `sudo cp -r ~/jenkins-data/* /var/lib/jenkins/` (create directory if needed)
3. Run Script 2 to backup: `sudo ./02-backup-and-restore-old-jenkins.sh`
4. Run Script 2 again to restore: `./02-backup-and-restore-old-jenkins.sh` (enter port 8082)
5. Access restored Jenkins at http://YOUR_SERVER_IP:8082

---

Part A: On Server A (Your Old Jenkins)

Step 1: Copy script to Server A
```

scp 02-backup-and-restore-old-jenkins.sh user@server-a-ip:/tmp/
```

Step 2: SSH into Server A
```

ssh user@server-a-ip
```
Step 3: Run the backup script
```

cd /tmp
chmod +x 02-backup-and-restore-old-jenkins.sh
sudo ./02-backup-and-restore-old-jenkins.sh
```
Step 4: Wait for backup to complete

The script will create: jenkins-backup-YYYYMMDD_HHMMSS.tar.gz

Step 5: Copy backup to safe location

# Copy to your local machine
scp /tmp/jenkins-backup-*.tar.gz user@your-machine:/backup/
✅ Backup complete! Your production Jenkins is still running.


Part B: Restore into Docker (On Sandbox or Same Server)

Step 1: Copy backup file to target server
```

scp jenkins-backup-*.tar.gz user@target-server:/tmp/
```

Step 2: SSH into target server
```

ssh user@target-server
cd /tmp
```

Step 3: Run the same script again (it will detect backup)
```
bash
./02-backup-and-restore-old-jenkins.sh
```

Step 4: Enter port for restored Jenkins

text
Enter port for restored Jenkins (default: 8082): 8082

Step 5: Wait for restore to complete (about 1 minute)

Step 6: Get the admin password
```

docker exec jenkins-restored cat /var/jenkins_home/secrets/initialAdminPassword
```

Step 7: Open browser

text
http://TARGET_SERVER_IP:8082

Step 8: Enter password and verify your jobs are restored

✅ Restore complete! Your old Jenkins is now running in Docker with all configurations.

Quick Commands Summary
Script 1 (Test Jenkins)
```
./01-install-jenkins-with-dummy-app.sh
# Output: http://SERVER:8080
# Password: cat ~/jenkins-password.txt

```

Script 2 (Backup Old Jenkins)
```
sudo ./02-backup-and-restore-old-jenkins.sh
# Creates: jenkins-backup-TIMESTAMP.tar.gz

```

Script 2 (Restore to Docker)
```
./02-backup-and-restore-old-jenkins.sh
# Enter port: 8082
# Access: http://SERVER:8082

```

Common Issues & Fixes
Problem	Solution
Permission denied	Use sudo
Docker not found	sudo apt install docker.io or sudo yum install docker
Port already in use	Choose different port (e.g., 9090)
Can't access browser	Open firewall: sudo ufw allow 8082

Files Created
File	Location	Purpose
jenkins-backup-*.tar.gz	Current directory	Backup file
jenkins-password.txt	~/	Admin password (Script 1)
jenkins-data/	~/	Jenkins data (Script 1)

Need Help?

Check container logs:
```

docker logs jenkins-restored
```