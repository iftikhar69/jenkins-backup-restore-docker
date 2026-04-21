## For Old (Non-Docker) Jenkins on Server A

### Step 1: Locate Jenkins on Server A

SSH into Server A and run:

```bash
# Find Jenkins home directory
sudo find / -name "config.xml" 2>/dev/null | grep jenkins

# Find Jenkins version
sudo find / -name "jenkins.war" 2>/dev/null | xargs java -jar --version

```
Step 2: Run Backup Script on Server A
```bash
# Copy the backup script to Server A
scp 01-backup-full.sh user@server-a:/tmp/

# SSH into Server A
ssh user@server-a

# Run backup
cd /tmp
chmod +x 01-backup-full.sh
sudo ./01-backup-full.sh   # May need sudo to read /var/lib/jenkins
```
Step 3: Copy Backup to Safe Location
```bash
# Copy backup from Server A to your local/sandbox
scp user@server-a:/tmp/jenkins-full-backup-*.tar.gz ./
```
Step 4: Restore into Docker (on Sandbox)
```bash
./02-restore-full.sh jenkins-full-backup-*.tar.gz
```

---

## Summary of Changes for Client

| Old Script | New Script |
|------------|------------|
| Assumes Jenkins in Docker | Works with traditional Jenkins |
| Backs up Docker image | Backs up Jenkins data + records version |
| Only works on Docker | Works on ANY Jenkins installation |

---

**Do you want me to:**
1. Create the final package with these updated scripts?
2. Update the GitHub repository with these changes?
3. Write the final message to client explaining the old Jenkins support?
