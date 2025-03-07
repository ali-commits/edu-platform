#!/bin/bash
# ─────────────────────────────────────────────────────────────────
# Demo Environment Manager Script
# ─────────────────────────────────────────────────────────────────
# This script helps manage the demo environment for Greats Language Center
# It provides commands to start, stop, and manage the demo services

set -e

# Colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to display usage information
show_usage() {
  echo -e "${YELLOW}Demo Environment Manager${NC}"
  echo "Usage: $0 [command]"
  echo ""
  echo "Commands:"
  echo "  start       - Start the demo environment"
  echo "  stop        - Stop the demo environment"
  echo "  restart     - Restart the demo environment"
  echo "  status      - Check status of demo services"
  echo "  logs        - View logs from demo services"
  echo "  reset       - Reset the demo environment (WARNING: Deletes all data)"
  echo "  help        - Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 start    - Start all demo services"
  echo "  $0 logs moodle-demo  - View logs for the Moodle demo service"
}

# Function to start the demo environment
start_demo() {
  echo -e "${GREEN}Starting demo environment...${NC}"
  docker compose -f docker-compose-demo.yaml --env-file .env.demo up -d
  echo -e "${GREEN}Demo environment started!${NC}"
  echo -e "Demo services are available at:"
  echo -e "  - openSIS: ${YELLOW}https://\${OPENSIS_DEMO_DOMAIN}${NC}"
  echo -e "  - Moodle: ${YELLOW}https://\${MOODLE_DEMO_DOMAIN}${NC}"
  echo -e "  - RosarioSIS: ${YELLOW}https://\${ROSARIO_DEMO_DOMAIN}${NC}"
}

# Function to stop the demo environment
stop_demo() {
  echo -e "${YELLOW}Stopping demo environment...${NC}"
  docker compose -f docker-compose-demo.yaml --env-file .env.demo down
  echo -e "${GREEN}Demo environment stopped!${NC}"
}

# Function to restart the demo environment
restart_demo() {
  stop_demo
  start_demo
}

# Function to check status of demo services
check_status() {
  echo -e "${YELLOW}Checking status of demo services...${NC}"
  docker compose -f docker-compose-demo.yaml --env-file .env.demo ps
}

# Function to view logs
view_logs() {
  if [ -z "$1" ]; then
    echo -e "${YELLOW}Viewing logs for all demo services...${NC}"
    docker compose -f docker-compose-demo.yaml --env-file .env.demo logs --tail=100 -f
  else
    echo -e "${YELLOW}Viewing logs for $1...${NC}"
    docker compose -f docker-compose-demo.yaml --env-file .env.demo logs --tail=100 -f "$1"
  fi
}

# Function to reset the demo environment
reset_demo() {
  echo -e "${RED}WARNING: This will delete all demo data and reset the environment!${NC}"
  read -p "Are you sure you want to continue? (y/n): " confirm

  if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    echo -e "${YELLOW}Stopping demo services...${NC}"
    docker compose -f docker-compose-demo.yaml --env-file .env.demo down

    echo -e "${YELLOW}Removing demo volumes...${NC}"
    docker volume rm moodle-db-demo-data moodle-demo-data opensis-db-demo-data opensis-demo-data rosario-db-demo-data rosario-demo-data

    echo -e "${GREEN}Demo environment has been reset!${NC}"
    echo -e "You can start a fresh demo environment with: $0 start"
  else
    echo -e "${YELLOW}Reset cancelled.${NC}"
  fi
}

# Main script logic
case "$1" in
  start)
    start_demo
    ;;
  stop)
    stop_demo
    ;;
  restart)
    restart_demo
    ;;
  status)
    check_status
    ;;
  logs)
    view_logs "$2"
    ;;
  reset)
    reset_demo
    ;;
  help|--help|-h)
    show_usage
    ;;
  *)
    show_usage
    exit 1
    ;;
esac

exit 0
