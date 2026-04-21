#!/bin/bash

# ============================================
# FULL JENKINS BACKUP (For OLD Non-Docker Jenkins)
# Usage: ./01-backup-full.sh
# Works on: Traditional Jenkins installed via RPM/APT/WAR
# ============================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR_NAME="jenkins-full-backup-${TIMESTAMP}"
BACKUP_DIR="/tmp/${BACKUP_DIR_NAME}"

mkdir -p "$BACKUP_DIR"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Jenkins Backup (Non-Docker / Traditional)${NC}"
echo -e "${GREEN}========================================${NC}"

# Step 1: Find Jenkins Home Directory (Non-Docker)
echo -e "${YELLOW}[1/6] Locating Jenkins home directory...${NC}"

# Common locations for traditional Jenkins
if [ -d "/var/lib/jenkins" ]; then
    JENKINS_HOME="/var/lib/jenkins"
elif [ -d "/var/jenkins_home" ]; then
    JENKINS_HOME="/var/jenkins_home"
elif [ -d "$HOME/.jenkins" ]; then
    JENKINS_HOME="$HOME/.jenkins"
elif [ -n "$JENKINS_HOME" ]; then
    JENKINS_HOME="$JENKINS_HOME"
else
    echo -e "${RED}Error: Could not find Jenkins home directory${NC}"
    echo -e "${YELLOW}Please run: find / -name 'config.xml' 2>/dev/null | grep jenkins${NC}"
    exit 1
fi

echo -e "${GREEN}Jenkins home found at: $JENKINS_HOME${NC}"

# Step 2: Find Jenkins WAR file and version
echo -e "${YELLOW}[2/6] Detecting Jenkins version...${NC}"

# Try to find Jenkins version
if [ -f "/usr/lib/jenkins/jenkins.war" ]; then
    JENKINS_WAR="/usr/lib/jenkins/jenkins.war"
elif [ -f "/usr/share/jenkins/jenkins.war" ]; then
    JENKINS_WAR="/usr/share/jenkins/jenkins.war"
else
    JENKINS_WAR=$(find / -name "jenkins.war" 2>/dev/null | head -1)
fi

if [ -n "$JENKINS_WAR" ]; then
    JENKINS_VERSION=$(java -jar "$JENKINS_WAR" --version 2>/dev/null || echo "Unknown")
else
    JENKINS_VERSION="Unknown (check manually at http://server:8080/manage)"
fi

echo -e "${GREEN}Jenkins version: $JENKINS_VERSION${NC}"

# Step 3: Check Jenkins service status
echo -e "${YELLOW}[3/6] Checking Jenkins service...${NC}"

if systemctl is-active --quiet jenkins 2>/dev/null; then
    echo -e "${GREEN}Jenkins service is running${NC}"
    echo -e "${YELLOW}Note: Backup can be taken while Jenkins is running (hot backup)${NC}"
elif pgrep -f "jenkins.war" > /dev/null; then
    echo -e "${GREEN}Jenkins process is running${NC}"
else
    echo -e "${YELLOW}Warning: Jenkins does not appear to be running${NC}"
fi

# Step 4: Backup Jenkins home directory
echo -e "${YELLOW}[4/6] Backing up Jenkins home directory...${NC}"
echo -e "${YELLOW}This may take several minutes depending on size...${NC}"

# Create backup of entire Jenkins home
cp -r "$JENKINS_HOME" "$BACKUP_DIR/jenkins-data"

# Create compressed archive of data
tar -czf "$BACKUP_DIR/jenkins-data.tar.gz" -C "$BACKUP_DIR" jenkins-data
rm -rf "$BACKUP_DIR/jenkins-data"

DATA_SIZE=$(du -h "$BACKUP_DIR/jenkins-data.tar.gz" | cut -f1)
echo -e "${GREEN}Data backup complete. Size: $DATA_SIZE${NC}"

# Step 5: Create Docker image of Jenkins (using same version)
echo -e "${YELLOW}[5/6] Creating Docker image with same Jenkins version...${NC}"

# Create a Dockerfile that matches the old Jenkins version
cat > "$BACKUP_DIR/Dockerfile" << EOF
# Dockerfile for Jenkins version: $JENKINS_VERSION
FROM jenkins/jenkins:$JENKINS_VERSION

# Switch to root to install additional packages if needed
USER root

# Install any plugins that were in the old Jenkins
# (Plugins will be restored from data backup)

# Switch back to jenkins user
USER jenkins

# Copy the Jenkins data backup will be mounted as volume during restore
EOF

echo -e "${GREEN}Dockerfile created for version: $JENKINS_VERSION${NC}"

# Step 6: Create a restore script specifically for this backup
echo -e "${YELLOW}[6/6] Creating restore instructions...${NC}"

cat > "$BACKUP_DIR/RESTORE-INSTRUCTIONS.txt" << EOF
========================================
JENKINS RESTORE INSTRUCTIONS
========================================
Backup created on: $TIMESTAMP
Original Jenkins version: $JENKINS_VERSION
Original Jenkins home: $JENKINS_HOME

TO RESTORE THIS BACKUP INTO DOCKER:

Step 1: Copy this entire backup folder to target server with Docker

Step 2: Load or pull the Jenkins image:
   docker pull jenkins/jenkins:$JENKINS_VERSION
   OR build from Dockerfile: docker build -t jenkins-restore .

Step 3: Extract the data:
   tar -xzf jenkins-data.tar.gz

Step 4: Run Docker container with restored data:
   docker run -d --name jenkins-restored -p 8080:8080 -v \$(pwd)/jenkins-data:/var/jenkins_home jenkins/jenkins:$JENKINS_VERSION

Step 5: Get admin password:
   docker exec jenkins-restored cat /var/jenkins_home/secrets/initialAdminPassword

Step 6: Access Jenkins at: http://SERVER_IP:8080

NOTE: If the exact version is not available on Docker Hub, use the closest LTS version.
The data backup contains all plugins and configurations.
========================================
EOF

# Step 7: Create final package
echo -e "${YELLOW}Creating final backup package...${NC}"
FINAL_FILE="$(pwd)/${BACKUP_DIR_NAME}.tar.gz"
tar -czf "$FINAL_FILE" -C /tmp "$BACKUP_DIR_NAME"
rm -rf "$BACKUP_DIR"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}FULL BACKUP COMPLETE!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Backup file: $FINAL_FILE${NC}"
echo -e "${GREEN}Backup size: $(du -h "$FINAL_FILE" | cut -f1)${NC}"
echo -e ""
echo -e "${YELLOW}This backup contains:${NC}"
echo -e "  - Complete Jenkins data (jobs, configs, plugins, credentials)"
echo -e "  - Original Jenkins version: $JENKINS_VERSION"
echo -e "  - Dockerfile for recreation"
echo -e "  - Restore instructions"
echo -e ""
echo -e "${YELLOW}Original Jenkins location (non-Docker): $JENKINS_HOME${NC}"
echo -e "${YELLOW}To restore, follow instructions in the backup package${NC}"