#!/bin/bash

# ============================================
# SCRIPT 1: Install Fresh Jenkins & Create Dummy App
# Purpose: For testing and learning on sandbox
# Usage: ./01-install-jenkins-with-dummy-app.sh
# ============================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Script 1: Install Jenkins & Create Dummy App${NC}"
echo -e "${GREEN}========================================${NC}"

# Step 1: Check if Docker is installed
echo -e "${YELLOW}[1/8] Checking Docker installation...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker not found. Installing Docker...${NC}"
    
    # For Ubuntu/Debian
    if command -v apt &> /dev/null; then
        sudo apt update
        sudo apt install docker.io -y
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker $USER
    # For RHEL/OEL
    elif command -v yum &> /dev/null; then
        sudo yum install docker -y
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker $USER
    fi
    echo -e "${GREEN}Docker installed. Please logout and login again, then re-run this script.${NC}"
    exit 0
fi
echo -e "${GREEN}Docker found: $(docker --version)${NC}"

# Step 2: Ask for port
echo -e "${YELLOW}[2/8] Configure Jenkins port...${NC}"
read -p "Enter port for Jenkins (default: 8080): " JENKINS_PORT
JENKINS_PORT=${JENKINS_PORT:-8080}

# Step 3: Ask for Jenkins version
echo -e "${YELLOW}[3/8] Jenkins version...${NC}"
read -p "Enter Jenkins version (default: lts-jdk11): " JENKINS_VERSION
JENKINS_VERSION=${JENKINS_VERSION:-lts-jdk11}

# Step 4: Create a directory for Jenkins data
echo -e "${YELLOW}[4/8] Creating Jenkins data directory...${NC}"
mkdir -p ~/jenkins-data
echo -e "${GREEN}Data directory: ~/jenkins-data${NC}"

# Step 5: Run Jenkins container
echo -e "${YELLOW}[5/8] Starting Jenkins container...${NC}"
docker run -d \
  --name jenkins-demo \
  --restart unless-stopped \
  -p ${JENKINS_PORT}:8080 \
  -p 50000:50000 \
  -v ~/jenkins-data:/var/jenkins_home \
  jenkins/jenkins:${JENKINS_VERSION}

echo -e "${GREEN}Jenkins container started: jenkins-demo${NC}"

# Step 6: Wait for Jenkins to start
echo -e "${YELLOW}[6/8] Waiting for Jenkins to start (45 seconds)...${NC}"
sleep 45

# Step 7: Get initial password
echo -e "${YELLOW}[7/8] Getting admin password...${NC}"
PASSWORD=$(docker exec jenkins-demo cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null)
echo -e "${GREEN}Admin password: $PASSWORD${NC}"

# Save password to file
echo "Jenkins Admin Password: $PASSWORD" > ~/jenkins-password.txt
echo "Jenkins URL: http://$(hostname -I | awk '{print $1}'):${JENKINS_PORT}" >> ~/jenkins-password.txt

# Step 8: Create a dummy job using Jenkins CLI or REST API
echo -e "${YELLOW}[8/8] Creating dummy job...${NC}"

# Wait a bit more for Jenkins to fully initialize
sleep 30

# Create a simple job configuration XML
cat > ~/dummy-job-config.xml << 'EOF'
<?xml version='1.1' encoding='UTF-8'?>
<project>
  <description>This is a dummy test job created by the setup script</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <scm class="hudson.scm.NullSCM"/>
  <canRoam>true</canRoam>
  <disabled>false</disabled>
  <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
  <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
  <triggers/>
  <concurrentBuild>false</concurrentBuild>
  <builders>
    <hudson.tasks.Shell>
      <command>echo "========================================="
echo "DUMMY APP BUILD SUCCESSFUL!"
echo "========================================="
echo "Current date: $(date)"
echo "Hostname: $(hostname)"
echo "========================================="
echo "This job was created automatically by Script 1"
echo "========================================="</command>
      <configuredLocalRules/>
    </hudson.tasks.Shell>
  </builders>
  <publishers/>
  <buildWrappers/>
</project>
EOF

# Create the job using Jenkins CLI (download CLI if needed)
echo -e "${YELLOW}Creating dummy job via Jenkins CLI...${NC}"

# Download Jenkins CLI
wget -q http://localhost:${JENKINS_PORT}/jnlpJars/jenkins-cli.jar -O ~/jenkins-cli.jar 2>/dev/null || true

# Wait for Jenkins to be fully ready
sleep 10

# Create job using Jenkins CLI (more reliable than API)
java -jar ~/jenkins-cli.jar -s http://localhost:${JENKINS_PORT} -auth admin:${PASSWORD} create-job dummy-test-job < ~/dummy-job-config.xml 2>/dev/null && echo -e "${GREEN}Dummy job created successfully!${NC}" || echo -e "${YELLOW}Note: Job creation requires Jenkins setup completion. Please create 'dummy-test-job' manually in the web interface after setup.${NC}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}INSTALLATION COMPLETE!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e ""
echo -e "${GREEN}Jenkins is running at:${NC}"
echo -e "${GREEN}  http://$(hostname -I | awk '{print $1}'):${JENKINS_PORT}${NC}"
echo -e ""
echo -e "${GREEN}Admin password: ${YELLOW}${PASSWORD}${NC}"
echo -e "${GREEN}Password saved to: ~/jenkins-password.txt${NC}"
echo -e ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Open browser and go to the URL above"
echo -e "2. Enter the admin password"
echo -e "3. Click 'Install suggested plugins' or 'Select plugins'"
echo -e "4. Create admin user (or continue as admin)"
echo -e "5. Look for 'dummy-test-job' in the dashboard"
echo -e ""
echo -e "${YELLOW}To build the dummy job manually:${NC}"
echo -e "  - Click on 'dummy-test-job' → 'Build Now'"
echo -e "  - Check console output"
echo -e ""
echo -e "${YELLOW}To test backup/restore:${NC}"
echo -e "  - Run Script 2 to backup this Jenkins"
echo -e "  - Then restore it into a new container"