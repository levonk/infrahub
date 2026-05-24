#!/bin/bash
# Helper script for colored output
set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo_color() {
    local color=$1
    local message=$2
    case $color in
        "blue") echo -e "${BLUE}${message}${NC}" ;;
        "green") echo -e "${GREEN}${message}${NC}" ;;
        "yellow") echo -e "${YELLOW}${message}${NC}" ;;
        "red") echo -e "${RED}${message}${NC}" ;;
        *) echo "$message" ;;
    esac
}

# Call the function with the provided arguments
echo_color "$1" "$2"
