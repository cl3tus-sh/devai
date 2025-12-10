#!/bin/bash

# GPU Setup Script for DevAI
# Checks and installs NVIDIA Container Toolkit if needed

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== DevAI - GPU Setup ===${NC}\n"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Please do not run this script as root${NC}"
    echo "Run it as your regular user (it will ask for sudo when needed)"
    exit 1
fi

# Step 1: Check for NVIDIA GPU
echo -e "${BLUE}[1/5] Checking for NVIDIA GPU...${NC}"
if ! command -v nvidia-smi &> /dev/null; then
    echo -e "${RED}Error: nvidia-smi not found${NC}"
    echo "Please install NVIDIA drivers first:"
    echo "  Ubuntu/Debian: sudo apt install nvidia-driver-XXX"
    echo "  Arch: sudo pacman -S nvidia nvidia-utils"
    exit 1
fi

nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
echo -e "${GREEN}✓ NVIDIA GPU detected${NC}\n"

# Step 2: Check Docker
echo -e "${BLUE}[2/5] Checking Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker not found${NC}"
    echo "Please install Docker first"
    exit 1
fi

docker --version
echo -e "${GREEN}✓ Docker is installed${NC}\n"

# Step 3: Check for NVIDIA Container Toolkit
echo -e "${BLUE}[3/5] Checking NVIDIA Container Toolkit...${NC}"
if docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi &> /dev/null; then
    echo -e "${GREEN}✓ NVIDIA Container Toolkit is already installed and working${NC}\n"
    echo -e "${GREEN}You're all set! Run 'make start-gpu' to start with GPU support${NC}"
    exit 0
fi

echo -e "${YELLOW}NVIDIA Container Toolkit not found or not working${NC}\n"

# Step 4: Install NVIDIA Container Toolkit
echo -e "${BLUE}[4/5] Installing NVIDIA Container Toolkit...${NC}"

# Detect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    OS_LIKE=$ID_LIKE
else
    echo -e "${RED}Cannot detect OS${NC}"
    exit 1
fi

# Check if it's an Arch-based system (either directly or via ID_LIKE)
if [[ "$OS" =~ ^(arch|manjaro|endeavouros|garuda|artix)$ ]] || [[ "$OS_LIKE" =~ arch ]]; then
    echo "Detected Arch-based system: $OS"
    sudo pacman -S --needed --noconfirm nvidia-container-toolkit

elif [[ "$OS" =~ ^(ubuntu|debian|pop|linuxmint|elementary)$ ]] || [[ "$OS_LIKE" =~ debian|ubuntu ]]; then
    echo "Detected Debian/Ubuntu based system: $OS"

    # Add NVIDIA repository
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

    sudo apt-get update
    sudo apt-get install -y nvidia-container-toolkit

elif [[ "$OS" =~ ^(fedora|rhel|centos|rocky|alma)$ ]] || [[ "$OS_LIKE" =~ fedora|rhel ]]; then
    echo "Detected RedHat based system: $OS"
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | \
        sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo
    sudo yum install -y nvidia-container-toolkit

else
    echo -e "${RED}Unsupported OS: $OS${NC}"
    echo "Please install nvidia-container-toolkit manually"
    echo "See: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html"
    exit 1
fi

echo -e "${GREEN}✓ NVIDIA Container Toolkit installed${NC}\n"

# Step 5: Configure Docker and restart
echo -e "${BLUE}[5/5] Configuring Docker...${NC}"
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

echo -e "${GREEN}✓ Docker configured and restarted${NC}\n"

# Verify installation
echo -e "${BLUE}Verifying installation...${NC}"
if docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi; then
    echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✓ GPU support is ready!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "Run: ${BLUE}make start-gpu${NC} to start Ollama with GPU support"
else
    echo -e "\n${RED}✗ Verification failed${NC}"
    echo "Please check the Docker logs and try again"
    exit 1
fi
