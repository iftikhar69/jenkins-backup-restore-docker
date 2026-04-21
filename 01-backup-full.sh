#!/bin/bash

# ============================================
# FULL JENKINS BACKUP (Image + Data)
# Usage: ./01-backup-full.sh
# ============================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
# FIX: Use a unique directory name to avoid mixing backups
BACKUP_DIR_NAME="jenkins-full-backup-${TIMESTAMP}"
BACKUP_DIR="/tmp/${BACKUP_DIR_NAME}"

mkdir -p "$BACKUP_DIR"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Full Jenkins Backup (Image + Data)${NC}"
echo -e "${GREEN}========================================${NC}"

# Step 1: Find the running Jenkins container
echo -e "${YELLOW}[1/5] Finding Jenkins container...${NC}"
# FIX: Added quotes and more robust container detection
CONTAINER_NAME=$(docker ps --format "{{.Names}}" | grep jenkins | head -n 1)

if [ -z "$CONTAINER_NAME" ]; then
    echo -e "${YELLOW}No running Jenkins container found. Please provide container name:${NC}"
    docker ps
    read -p "Container name: " CONTAINER_NAME
fi

echo -e "${GREEN}Found container: $CONTAINER_NAME${NC}"

# Step 2: Get the image name
IMAGE_NAME=$(docker inspect "$CONTAINER_NAME" --format='{{.Config.Image}}')
echo -e "${GREEN}Image name: $IMAGE_NAME${NC}"

# Step 3: Save Docker image to tar file
echo -e "${YELLOW}[2/5] Saving Docker image...${NC}"
docker save "$IMAGE_NAME" -o "$BACKUP_DIR/jenkins-image.tar"
echo -e "${GREEN}Image saved: $BACKUP_DIR/jenkins-image.tar${NC}"
echo -e "${GREEN}Image size: $(du -h "$BACKUP_DIR/jenkins-image.tar" | cut -f1)${NC}"

# Step 4: Backup Jenkins home directory (data)
echo -e "${YELLOW}[3/5] Backing up Jenkins data...${NC}"
docker cp "$CONTAINER_NAME":/var/jenkins_home "$BACKUP_DIR/jenkins-data"
tar -czf "$BACKUP_DIR/jenkins-data.tar.gz" -C "$BACKUP_DIR" jenkins-data
rm -rf "$BACKUP_DIR/jenkins-data"
echo -e "${GREEN}Data backup: $BACKUP_DIR/jenkins-data.tar.gz${NC}"

# Step 5: Create manifest file (info about backup)
echo -e "${YELLOW}[4/5] Creating manifest...${NC}"
cat > "$BACKUP_DIR/manifest.txt" << EOF
Jenkins Full Backup Manifest
=============================
Backup Date: $TIMESTAMP
Container Name: $CONTAINER_NAME
Image Name: $IMAGE_NAME
Jenkins Version: $(docker exec "$CONTAINER_NAME" java -jar /usr/share/jenkins/jenkins.war --version 2>/dev/null || echo "Unknown")
EOF

# Step 6: Combine everything into one file
echo -e "${YELLOW}[5/5] Creating final backup package...${NC}"
# FIX: Save to current directory so the user can find it easily
FINAL_FILE="$(pwd)/${BACKUP_DIR_NAME}.tar.gz"
tar -czf "$FINAL_FILE" -C /tmp "$BACKUP_DIR_NAME"
rm -rf "$BACKUP_DIR"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}FULL BACKUP COMPLETE!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Backup file: $FINAL_FILE${NC}"
echo -e ""
echo -e "${YELLOW}This backup contains:${NC}"
echo -e "  - Docker image (can be loaded on any Docker host)"
echo -e "  - Jenkins data (jobs, configs, plugins, credentials)"
echo -e "  - Manifest file with details"
