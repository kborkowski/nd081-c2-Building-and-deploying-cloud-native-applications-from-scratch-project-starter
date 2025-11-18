#!/bin/bash

# NeighborlyAPI - Environment Setup Script for Codespace
# This script installs all required tools for Azure deployment

set -e  # Exit on any error

echo "=========================================="
echo "NeighborlyAPI - Environment Setup"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check Python
echo -e "${YELLOW}Checking Python...${NC}"
if command_exists python; then
    PYTHON_VERSION=$(python --version)
    echo -e "${GREEN}✓ $PYTHON_VERSION installed${NC}"
else
    echo -e "${RED}✗ Python not found${NC}"
    exit 1
fi

# Check Docker
echo -e "${YELLOW}Checking Docker...${NC}"
if command_exists docker; then
    DOCKER_VERSION=$(docker --version)
    echo -e "${GREEN}✓ $DOCKER_VERSION installed${NC}"
else
    echo -e "${RED}✗ Docker not found${NC}"
fi

# Check kubectl
echo -e "${YELLOW}Checking kubectl...${NC}"
if command_exists kubectl; then
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null || echo "kubectl installed")
    echo -e "${GREEN}✓ kubectl installed${NC}"
else
    echo -e "${RED}✗ kubectl not found${NC}"
fi

echo ""
echo "=========================================="
echo "Installing Required Tools..."
echo "=========================================="
echo ""

# Install Azure CLI
echo -e "${YELLOW}Installing Azure CLI...${NC}"
if command_exists az; then
    echo -e "${GREEN}✓ Azure CLI already installed${NC}"
    az --version | head -n 1
else
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    echo -e "${GREEN}✓ Azure CLI installed successfully${NC}"
fi

# Install Azure Functions Core Tools
echo -e "${YELLOW}Installing Azure Functions Core Tools...${NC}"
if command_exists func; then
    echo -e "${GREEN}✓ Azure Functions Core Tools already installed${NC}"
    func --version
else
    wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb
    sudo dpkg -i packages-microsoft-prod.deb
    rm packages-microsoft-prod.deb
    sudo apt-get update > /dev/null 2>&1
    sudo apt-get install -y azure-functions-core-tools-4
    echo -e "${GREEN}✓ Azure Functions Core Tools installed successfully${NC}"
fi

# Install MongoDB Database Tools
echo -e "${YELLOW}Installing MongoDB Database Tools...${NC}"
if command_exists mongoimport; then
    echo -e "${GREEN}✓ MongoDB tools already installed${NC}"
    mongoimport --version | head -n 1
else
    # Install gnupg if not present
    sudo apt-get install -y gnupg curl
    
    # Import MongoDB public GPG key
    curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
        sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
    
    # Create list file
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
        sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
    
    # Install MongoDB tools
    sudo apt-get update > /dev/null 2>&1
    sudo apt-get install -y mongodb-database-tools
    echo -e "${GREEN}✓ MongoDB tools installed successfully${NC}"
fi

echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo -e "${GREEN}All required tools are installed.${NC}"
echo ""
echo "Next steps:"
echo "1. Login to Azure: ${YELLOW}az login --use-device-code${NC}"
echo "2. Check your subscription: ${YELLOW}az account show${NC}"
echo "3. Review DEPLOYMENT_PLAN.md"
echo "4. Start with Phase 1: Azure Resource Provisioning"
echo ""
echo "=========================================="

# Summary of installed tools
echo ""
echo "Installed Tools Summary:"
echo "------------------------"
command_exists python && echo "✓ Python: $(python --version 2>&1)"
command_exists az && echo "✓ Azure CLI: $(az --version 2>&1 | head -n 1)"
command_exists func && echo "✓ Azure Functions: $(func --version 2>&1)"
command_exists mongoimport && echo "✓ MongoDB Tools: $(mongoimport --version 2>&1 | head -n 1)"
command_exists docker && echo "✓ Docker: $(docker --version 2>&1)"
command_exists kubectl && echo "✓ kubectl: installed"
echo ""
