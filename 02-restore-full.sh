#!/bin/bash

# ============================================
# RESTORE OLD JENKINS BACKUP INTO DOCKER
# Usage: ./02-restore-full.sh <backup-file.tar.gz>
# ============================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [ -z "$1" ]; then
    echo -e "${RED}Error: Please provide backup file${NC}"
    echo -e "${YELLOW}Usage: $0 <jenkins-full-backup-YYYYMMDD_HHMMSS.tar.gz>${NC}"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}Error: Backup file not found: $BACKUP_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Restoring Old Jenkins Backup into Docker${NC}"
echo -e "${GREEN}========================================${NC}"

# Step 1: Extract backup
echo -e "${YELLOW}[1/6] Extracting backup...${NC}"
RESTORE_DIR="/tmp/jenkins-restore-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESTORE_DIR"
tar -xzf "$BACKUP_FILE" -C "$RESTORE_DIR"

# Find the actual backup folder
BACKUP_CONTENT=$(find "$RESTORE_DIR" -maxdepth 1 -type d -name "jenkins-full-backup-*" | head -1)
echo -e "${GREEN}Backup content found at: $BACKUP_CONTENT${NC}"

# Step 2: Read the Jenkins version from manifest
echo -e "${YELLOW}[2/6] Reading Jenkins version from backup...${NC}"

if [ -f "$BACKUP_CONTENT/RESTORE-INSTRUCTIONS.txt" ]; then
    JENKINS_VERSION=$(grep "Original Jenkins version:" "$BACKUP_CONTENT/RESTORE-INSTRUCTIONS.txt" | cut -d':' -f2 | xargs)
else
    echo -e "${YELLOW}Could not find version, using latest LTS${NC}"
    JENKINS_VERSION="lts-jdk11"
fi

echo -e "${GREEN}Will use Jenkins version: $JENKINS_VERSION${NC}"

# Step 3: Ask for port
echo -e "${YELLOW}[3/6] Configure Jenkins port...${NC}"
read -p "Enter port for Jenkins (default: 8080): " JENKINS_PORT
JENKINS_PORT=${JENKINS_PORT:-8080}

# Step 4: Extract data backup
echo -e "${YELLOW}[4/6] Preparing data backup...${NC}"
tar -xzf "$BACKUP_CONTENT/jenkins-data.tar.gz" -C "$BACKUP_CONTENT"
DATA_DIR="$BACKUP_CONTENT/jenkins-data"

# Step 5: Clean up existing container
echo -e "${YELLOW}[5/6] Cleaning up existing Jenkins container...${NC}"
docker rm -f jenkins-restored 2>/dev/null || true

# Step 6: Pull and run Jenkins with restored data
echo -e "${YELLOW}[6/6] Starting restored Jenkins...${NC}"

# Try to pull the exact version, if fails use lts
if docker pull jenkins/jenkins:$JENKINS_VERSION 2>/dev/null; then
    JENKINS_IMAGE="jenkins/jenkins:$JENKINS_VERSION"
else
    echo -e "${YELLOW}Warning: Exact version $JENKINS_VERSION not found. Using lts-jdk11${NC}"
    JENKINS_IMAGE="jenkins/jenkins:lts-jdk11"
fi

docker run -d \
  --name jenkins-restored \
  --restart unless-stopped \
  -p ${JENKINS_PORT}:8080 \
  -p 50000:50000 \
  -v ${DATA_DIR}:/var/jenkins_home \
  ${JENKINS_IMAGE}

# Step 7: Display access info
echo -e "${YELLOW}Waiting for Jenkins to start (30 seconds)...${NC}"
sleep 30

SERVER_IP=$(hostname -I | awk '{print $1}')

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}RESTORE COMPLETE!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Jenkins is running at: http://${SERVER_IP}:${JENKINS_PORT}${NC}"
echo -e ""
echo -e "${YELLOW}To get the admin password:${NC}"
echo -e "  docker exec jenkins-restored cat /var/jenkins_home/secrets/initialAdminPassword"
echo -e ""
echo -e "${YELLOW}To check logs:${NC}"
echo -e "  docker logs -f jenkins-restored"