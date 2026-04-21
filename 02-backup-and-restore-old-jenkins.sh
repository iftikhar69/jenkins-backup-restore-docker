#!/bin/bash

# ============================================
# SCRIPT 2: Backup Old Jenkins & Restore to Docker
# Purpose: Backup existing non-Docker Jenkins and restore into Docker
# Usage: ./02-backup-and-restore-old-jenkins.sh
# ============================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Script 2: Backup Old Jenkins & Restore to Docker${NC}"
echo -e "${GREEN}========================================${NC}"

# ============================================
# PART A: BACKUP OLD JENKINS (Non-Docker)
# ============================================

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}PART A: Backing up Old Jenkins${NC}"
echo -e "${YELLOW}========================================${NC}"

# Step A1: Find Jenkins Home Directory
echo -e "${YELLOW}[A1/6] Locating Jenkins home directory...${NC}"

if [ -d "/var/lib/jenkins" ]; then
    JENKINS_HOME="/var/lib/jenkins"
elif [ -d "/var/jenkins_home" ]; then
    JENKINS_HOME="/var/jenkins_home"
elif [ -d "$HOME/.jenkins" ]; then
    JENKINS_HOME="$HOME/.jenkins"
else
    echo -e "${RED}Error: Could not find Jenkins home directory${NC}"
    echo -e "${YELLOW}Please run: sudo find / -name 'config.xml' 2>/dev/null | grep jenkins${NC}"
    exit 1
fi

echo -e "${GREEN}Jenkins home found at: $JENKINS_HOME${NC}"

# Step A2: Detect Jenkins Version
echo -e "${YELLOW}[A2/6] Detecting Jenkins version...${NC}"

JENKINS_WAR=$(find / -name "jenkins.war" 2>/dev/null | head -1)
if [ -n "$JENKINS_WAR" ]; then
    JENKINS_VERSION=$(java -jar "$JENKINS_WAR" --version 2>/dev/null || echo "Unknown")
else
    JENKINS_VERSION="Unknown"
fi
echo -e "${GREEN}Jenkins version: $JENKINS_VERSION${NC}"

# Step A3: Create timestamped backup
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="jenkins-backup-${TIMESTAMP}"
BACKUP_PATH="/tmp/${BACKUP_NAME}"

mkdir -p "$BACKUP_PATH"

echo -e "${YELLOW}[A3/6] Copying Jenkins data...${NC}"
sudo cp -r "$JENKINS_HOME" "$BACKUP_PATH/jenkins-data"

echo -e "${YELLOW}[A4/6] Compressing backup...${NC}"
tar -czf "$BACKUP_PATH/jenkins-data.tar.gz" -C "$BACKUP_PATH" jenkins-data
rm -rf "$BACKUP_PATH/jenkins-data"

# Step A4: Create manifest
echo -e "${YELLOW}[A5/6] Creating manifest...${NC}"
cat > "$BACKUP_PATH/manifest.txt" << EOF
Jenkins Backup Manifest
=======================
Backup Date: $TIMESTAMP
Source Jenkins Home: $JENKINS_HOME
Jenkins Version: $JENKINS_VERSION
Backup Size: $(du -sh "$BACKUP_PATH/jenkins-data.tar.gz" | cut -f1)
EOF

# Step A5: Create final backup package
echo -e "${YELLOW}[A6/6] Creating final backup package...${NC}"
FINAL_BACKUP="$(pwd)/${BACKUP_NAME}.tar.gz"
tar -czf "$FINAL_BACKUP" -C /tmp "$BACKUP_NAME"
rm -rf "$BACKUP_PATH"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}BACKUP COMPLETE!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Backup file: $FINAL_BACKUP${NC}"
echo -e "${GREEN}Backup size: $(du -h "$FINAL_BACKUP" | cut -f1)${NC}"

# ============================================
# PART B: RESTORE INTO DOCKER
# ============================================

echo -e ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}PART B: Restoring into Docker Container${NC}"
echo -e "${YELLOW}========================================${NC}"

# Step B1: Check Docker
echo -e "${YELLOW}[B1/5] Checking Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker not installed. Please install Docker first.${NC}"
    exit 1
fi
echo -e "${GREEN}Docker found${NC}"

# Step B2: Ask for restore port
echo -e "${YELLOW}[B2/5] Configure restore port...${NC}"
read -p "Enter port for restored Jenkins (default: 8082): " RESTORE_PORT
RESTORE_PORT=${RESTORE_PORT:-8082}

# Step B3: Extract backup for restore
echo -e "${YELLOW}[B3/5] Preparing backup for restore...${NC}"
RESTORE_DIR="/tmp/jenkins-restore-${TIMESTAMP}"
mkdir -p "$RESTORE_DIR"
tar -xzf "$FINAL_BACKUP" -C "$RESTORE_DIR"

# Find the extracted data
DATA_DIR=$(find "$RESTORE_DIR" -type d -name "jenkins-data" | head -1)
if [ -z "$DATA_DIR" ]; then
    # Try to find the data in the extracted folder
    DATA_DIR=$(find "$RESTORE_DIR" -type d -name "jenkins-data" 2>/dev/null | head -1)
    if [ -z "$DATA_DIR" ]; then
        tar -xzf "$RESTORE_DIR"/*/jenkins-data.tar.gz -C "$RESTORE_DIR" 2>/dev/null || true
        DATA_DIR=$(find "$RESTORE_DIR" -type d -name "jenkins-data" | head -1)
    fi
fi

echo -e "${GREEN}Data directory: $DATA_DIR${NC}"

# Step B4: Stop existing restored container if any
echo -e "${YELLOW}[B4/5] Cleaning up...${NC}"
docker rm -f jenkins-restored 2>/dev/null || true

# Step B5: Run Docker container with restored data
echo -e "${YELLOW}[B5/5] Starting restored Jenkins in Docker...${NC}"

# Determine which image to use
if [ "$JENKINS_VERSION" != "Unknown" ] && [ "$JENKINS_VERSION" != "lts-jdk11" ]; then
    JENKINS_IMAGE="jenkins/jenkins:${JENKINS_VERSION}"
else
    JENKINS_IMAGE="jenkins/jenkins:lts-jdk11"
fi

echo -e "${GREEN}Using Docker image: $JENKINS_IMAGE${NC}"

docker run -d \
  --name jenkins-restored \
  --restart unless-stopped \
  -p ${RESTORE_PORT}:8080 \
  -p 50001:50000 \
  -v ${DATA_DIR}:/var/jenkins_home \
  ${JENKINS_IMAGE}

# Step B6: Wait and show access info
echo -e "${YELLOW}Waiting for Jenkins to start (30 seconds)...${NC}"
sleep 30

SERVER_IP=$(hostname -I | awk '{print $1}')

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}RESTORE COMPLETE!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e ""
echo -e "${GREEN}Restored Jenkins is running at:${NC}"
echo -e "${GREEN}  http://${SERVER_IP}:${RESTORE_PORT}${NC}"
echo -e ""
echo -e "${YELLOW}To get the admin password:${NC}"
echo -e "  docker exec jenkins-restored cat /var/jenkins_home/secrets/initialAdminPassword"
echo -e ""
echo -e "${YELLOW}To check logs:${NC}"
echo -e "  docker logs jenkins-restored"
echo -e ""
echo -e "${YELLOW}To stop restored Jenkins:${NC}"
echo -e "  docker stop jenkins-restored"
echo -e ""
echo -e "${YELLOW}To start restored Jenkins again:${NC}"
echo -e "  docker start jenkins-restored"
echo -e ""
echo -e "${GREEN}Original old Jenkins on Server A is still running and unaffected.${NC}"