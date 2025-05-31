#!/bin/bash

# GARBAGE Project Deployment Script
# This script automates the deployment of all GARBAGE project contracts

# Text colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== GARBAGE Project Deployment Script ===${NC}"

# Hardcoded RPC URL for Flow testnet
RPC_URL="https://testnet.evm.nodes.onflow.org"

# Check for .env file and load it
if [ -f .env ]; then
  echo -e "${YELLOW}Loading environment variables from .env file${NC}"
  source .env
else
  echo -e "${YELLOW}No .env file found. Creating one from template...${NC}"
  if [ -f .env.example ]; then
    cp .env.example .env
    echo -e "${YELLOW}.env file created. Please edit it with your private key and run this script again.${NC}"
    echo -e "${YELLOW}Edit the file using: nano .env${NC}"
    exit 1
  else
    echo -e "${RED}Error: .env.example file not found${NC}"
    echo -e "${YELLOW}Please create a .env file with your PRIVATE_KEY=${NC}"
    exit 1
  fi
fi

# Validate private key
if [ -z "$PRIVATE_KEY" ]; then
  echo -e "${RED}Error: PRIVATE_KEY not found in .env file${NC}"
  echo -e "${YELLOW}Please add your private key to the .env file:${NC}"
  echo -e "${YELLOW}PRIVATE_KEY=your_private_key_here${NC}"
  exit 1
fi

echo -e "${GREEN}Starting deployment to Flow testnet (${RPC_URL})...${NC}"

# Run the deployment script with optimized settings
forge script script/TrashSystem.s.sol:TrashSystemScript \
  --rpc-url $RPC_URL \
  --broadcast \
  --slow \
  --legacy \
  --gas-price 1000000000 \
  --timeout 300

# Check if deployment was successful
if [ $? -eq 0 ]; then
  echo -e "${GREEN}=== Deployment completed successfully! ===${NC}"
  echo -e "${YELLOW}Note: Contract addresses are displayed in the output above.${NC}"
  echo -e "${YELLOW}You may want to save these addresses for future reference.${NC}"
else
  echo -e "${RED}=== Deployment failed! ===${NC}"
  echo -e "${YELLOW}Please check the error messages above.${NC}"
  exit 1
fi

# Optional: Extract contract addresses from the output
# This would require parsing the forge output, which can be added if needed

echo -e "${GREEN}=== Thank you for using the GARBAGE Project Deployment Script ===${NC}"
