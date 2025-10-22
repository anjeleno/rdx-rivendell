#!/bin/bash
# Test desktop environment detection

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Detect desktop environment
detect_desktop_environment() {
    print_info "Detecting desktop environment..."
    
    if [ "$XDG_CURRENT_DESKTOP" ]; then
        DESKTOP_ENV="$XDG_CURRENT_DESKTOP"
        print_info "Desktop environment: $DESKTOP_ENV"
        
        if [[ "$DESKTOP_ENV" == *"MATE"* ]]; then
            print_warning "MATE desktop detected - using enhanced launcher compatibility"
        fi
    else
        print_warning "Desktop environment not detected"
    fi
    
    # Additional checks
    print_info "Environment variables:"
    echo "  XDG_CURRENT_DESKTOP: ${XDG_CURRENT_DESKTOP:-'(not set)'}"
    echo "  DESKTOP_SESSION: ${DESKTOP_SESSION:-'(not set)'}"
    echo "  XDG_SESSION_DESKTOP: ${XDG_SESSION_DESKTOP:-'(not set)'}"
}

echo "🎯 RDX Desktop Environment Detection Test"
echo "=============================================="
detect_desktop_environment