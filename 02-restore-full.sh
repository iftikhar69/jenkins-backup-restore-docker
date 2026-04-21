#!/bin/bash

# ============================================
# FULL JENKINS RESTORE (Image + Data)
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

# FIX: Get absolute path to handle spaces in folder names
BACKUP_FILE=$(readlink -f "$1")

if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}Error: Backup file not found: $BACKUP_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Full Jenkins Restore (Image + Data)${NC}"
echo -e "${GREEN}========================================${NC}"

# Step 1: Extract backup
echo -e "${YELLOW}[1/6] Extracting backup...${NC}"
RESTORE_DIR="/tmp/jenkins-restore-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESTORE_DIR"
tar -xzf "$BACKUP_FILE" -C "$RESTORE_DIR"

# FIX: Find the actual backup folder inside the extraction
BACKUP_CONTENT=$(find "$RESTORE_DIR" -maxdepth 1 -type d -name "jenkins-full-backup-*" | head -1)
echo -e "${GREEN}Backup content found at: $BACKUP_CONTENT${NC}"

# Step 2: Load the Docker image
echo -e "${YELLOW}[2/6] Loading Docker image...${NC}"
# FIX: Use quotes and the correct variable path
docker load -i "$BACKUP_CONTENT/jenkins-image.tar"
IMAGE_NAME=$(docker images --format "{{.Repository}}:{{.Tag}}" | head -n 1)
echo -e "${GREEN}Image loaded: $IMAGE_NAME${NC}"

# Step 3: Ask for port
echo -e "${YELLOW}[3/6] Configure Jenkins port...${NC}"
read -p "Enter port for Jenkins (default: 8080): " JENKINS_PORT
JENKINS_PORT=${JENKINS_PORT:-8080}

# Step 4: Stop and remove existing Jenkins container
echo -e "${YELLOW}[4/6] Cleaning up existing Jenkins container...${NC}"
# FIX: Force remove to avoid the "Conflict" error you had
docker rm -f jenkins-restored 2>/dev/null || true

# Step 5: Extract data backup
echo -e "${YELLOW}[5/6] Preparing data backup...${NC}"
tar -xzf "$BACKUP_CONTENT/jenkins-data.tar.gz" -C "$BACKUP_CONTENT"
DATA_DIR="$BACKUP_CONTENT/jenkins-data"

# Step 6: Run new container with restored image and data
echo -e "${YELLOW}[6/6] Starting restored Jenkins...${NC}"
# FIX: Added quotes to the volume path to handle spaces
docker run -d \
  --name jenkins-restored \
  --restart unless-stopped \
  -p "${JENKINS_PORT}:8080" \
  -p 50000:50000 \
  -v "${DATA_DIR}:/var/jenkins_home" \
  "$IMAGE_NAME"

# Step 7: Display access info
echo -e "${YELLOW}Waiting for Jenkins to start (20s)...${NC}"
sleep 20
SERVER_IP=$(hostname -I | awk '{print $1}')

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}RESTORE COMPLETE!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Jenkins is running at: http://${SERVER_IP}:${JENKINS_PORT}${NC}"
echo -e ""
echo -e "${YELLOW}To check logs: docker logs -f jenkins-restored${NC}"
