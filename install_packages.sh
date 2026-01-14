#!/bin/bash
#
# Declarative package installer
# Reads packages.txt and installs packages by category
# Safe to run multiple times (idempotent)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_FILE="$SCRIPT_DIR/packages.txt"
BREWFILE="$SCRIPT_DIR/Brewfile"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Parse packages.txt into arrays by section
declare -a BREW_PACKAGES=()
declare -a CASK_PACKAGES=()
declare -a RUSTUP_PACKAGES=()
declare -a NVM_PACKAGES=()
declare -a TAP_PACKAGES=()

parse_packages_file() {
    local current_section=""
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines
        [[ -z "$line" ]] && continue
        
        # Check for section headers
        if [[ "$line" =~ ^#[[:space:]]*(.+)$ ]]; then
            current_section="${BASH_REMATCH[1]}"
            continue
        fi
        
        # Skip inline comments
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Add to appropriate array based on section
        case "$current_section" in
            brew)
                BREW_PACKAGES+=("$line")
                ;;
            cask)
                CASK_PACKAGES+=("$line")
                ;;
            rustup)
                RUSTUP_PACKAGES+=("$line")
                ;;
            nvm)
                NVM_PACKAGES+=("$line")
                ;;
            tap)
                TAP_PACKAGES+=("$line")
                ;;
        esac
    done < "$PACKAGES_FILE"
}

# Check if Homebrew is installed
ensure_homebrew() {
    if ! command -v brew &> /dev/null; then
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add brew to PATH for Apple Silicon
        if [[ -f /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    else
        log_success "Homebrew already installed"
    fi
}

# Install brew taps
install_taps() {
    for tap in "${TAP_PACKAGES[@]}"; do
        if brew tap | grep -q "^${tap}$"; then
            log_success "Tap $tap already added"
        else
            log_info "Adding tap: $tap"
            brew tap "$tap"
        fi
    done
}

# Install brew packages (idempotent)
install_brew_packages() {
    log_info "Installing brew packages..."
    
    for package in "${BREW_PACKAGES[@]}"; do
        if brew list --formula "$package" &> /dev/null; then
            log_success "$package already installed"
        else
            log_info "Installing $package..."
            brew install "$package"
        fi
    done
}

# Install cask packages (idempotent)
install_cask_packages() {
    log_info "Installing cask packages..."
    
    for package in "${CASK_PACKAGES[@]}"; do
        if brew list --cask "$package" &> /dev/null; then
            log_success "$package already installed"
        else
            log_info "Installing $package..."
            brew install --cask "$package"
        fi
    done
}

# Install Rust via rustup (idempotent)
install_rustup() {
    if [[ ${#RUSTUP_PACKAGES[@]} -eq 0 ]]; then
        return
    fi
    
    log_info "Setting up Rust..."
    
    if command -v rustup &> /dev/null; then
        log_success "Rustup already installed"
        rustup update
    else
        log_info "Installing rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    fi
}

# Install nvm (idempotent)
install_nvm() {
    if [[ ${#NVM_PACKAGES[@]} -eq 0 ]]; then
        return
    fi
    
    log_info "Setting up nvm..."
    
    if [[ -d "$HOME/.nvm" ]]; then
        log_success "nvm already installed"
    else
        log_info "Installing nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    fi
}

# Generate Brewfile from packages.txt
generate_brewfile() {
    log_info "Generating Brewfile..."
    
    cat > "$BREWFILE" << 'EOF'
# Generated from packages.txt
# Run: brew bundle --file=Brewfile

EOF

    # Add taps
    for tap in "${TAP_PACKAGES[@]}"; do
        echo "tap \"$tap\"" >> "$BREWFILE"
    done
    
    [[ ${#TAP_PACKAGES[@]} -gt 0 ]] && echo "" >> "$BREWFILE"
    
    # Add brew packages
    echo "# Formulae" >> "$BREWFILE"
    for package in "${BREW_PACKAGES[@]}"; do
        echo "brew \"$package\"" >> "$BREWFILE"
    done
    
    echo "" >> "$BREWFILE"
    
    # Add casks
    echo "# Casks" >> "$BREWFILE"
    for package in "${CASK_PACKAGES[@]}"; do
        echo "cask \"$package\"" >> "$BREWFILE"
    done
    
    log_success "Brewfile generated at $BREWFILE"
}

# Print summary
print_summary() {
    echo ""
    echo "========================================"
    echo "Installation Summary"
    echo "========================================"
    echo "Brew packages: ${#BREW_PACKAGES[@]}"
    echo "Cask packages: ${#CASK_PACKAGES[@]}"
    echo "Taps: ${#TAP_PACKAGES[@]}"
    echo "Rustup: ${#RUSTUP_PACKAGES[@]} (rust toolchain)"
    echo "NVM: ${#NVM_PACKAGES[@]} (node version manager)"
    echo "========================================"
    echo ""
    echo "Brewfile generated at: $BREWFILE"
    echo "You can also run: brew bundle --file=$BREWFILE"
    echo ""
}

main() {
    log_info "Starting package installation from $PACKAGES_FILE"
    
    if [[ ! -f "$PACKAGES_FILE" ]]; then
        log_error "packages.txt not found at $PACKAGES_FILE"
        exit 1
    fi
    
    parse_packages_file
    ensure_homebrew
    install_taps
    install_brew_packages
    install_cask_packages
    install_rustup
    install_nvm
    generate_brewfile
    print_summary
    
    log_success "All packages installed successfully!"
}

main "$@"
