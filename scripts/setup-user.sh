#!/bin/bash

# ArchWSL2 User Setup Script
# Automates user creation and configuration for ArchWSL2

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

# Function to validate username
validate_username() {
    local username="$1"
    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        print_error "Invalid username: $username"
        print_error "Username must start with a letter or underscore, and contain only letters, numbers, underscores, and hyphens"
        return 1
    fi
    return 0
}

# Function to check if user exists
user_exists() {
    local username="$1"
    id "$username" &>/dev/null
}

# Function to create user with proper configuration
create_user() {
    local username="$1"
    local password="$2"
    local setup_ssh="${3:-false}"
    local setup_dev="${4:-false}"
    
    print_info "Creating user: $username"
    
    # Create user with proper groups
    useradd -m -g users -G wheel,adm,log,systemd-journal -s /bin/bash "$username"
    
    # Set password
    echo "$username:$password" | chpasswd
    
    # Configure sudo
    echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel
    
    # Create user directories
    mkdir -p "/home/$username/.local/bin"
    mkdir -p "/home/$username/.config"
    
    # Set proper ownership
    chown -R "$username:users" "/home/$username"
    
    # Setup basic bash profile for user
    cat > "/home/$username/.bashrc" << 'EOF'
# ~/.bashrc

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Basic aliases
alias ls='ls --color=auto'
alias ll='ls -la'
alias la='ls -la'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'

# PS1 configuration
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Enable bash completion
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
EOF
    
    chown "$username:users" "/home/$username/.bashrc"
    
    if [[ "$setup_ssh" == "true" ]]; then
        setup_ssh_keys "$username"
    fi
    
    if [[ "$setup_dev" == "true" ]]; then
        setup_dev_environment "$username"
    fi
    
    print_success "User $username created successfully"
}

# Function to setup SSH keys
setup_ssh_keys() {
    local username="$1"
    print_info "Setting up SSH keys for $username"
    
    sudo -u "$username" mkdir -p "/home/$username/.ssh"
    sudo -u "$username" chmod 700 "/home/$username/.ssh"
    
    # Generate SSH key pair
    sudo -u "$username" ssh-keygen -t ed25519 -f "/home/$username/.ssh/id_ed25519" -N "" -C "$username@archwsl2"
    
    # Add to authorized_keys
    sudo -u "$username" cp "/home/$username/.ssh/id_ed25519.pub" "/home/$username/.ssh/authorized_keys"
    sudo -u "$username" chmod 600 "/home/$username/.ssh/authorized_keys"
    
    print_success "SSH keys generated for $username"
}

# Function to setup development environment
setup_dev_environment() {
    local username="$1"
    print_info "Setting up development environment for $username"
    
    # Install development packages
    pacman -S --noconfirm --needed git vim nano code curl wget base-devel
    
    # Create development directories
    sudo -u "$username" mkdir -p "/home/$username/Projects"
    sudo -u "$username" mkdir -p "/home/$username/.local/share"
    
    # Setup git configuration
    sudo -u "$username" git config --global init.defaultBranch main
    sudo -u "$username" git config --global pull.rebase false
    
    print_success "Development environment setup for $username"
}

# Function to set user as default in wsl.conf
set_default_user() {
    local username="$1"
    print_info "Setting $username as default user"
    
    if ! grep -q '\[user\]' /etc/wsl.conf; then
        echo -e '\n[user]' >> /etc/wsl.conf
    fi
    
    # Remove existing default user setting
    sed -i '/^default =/d' /etc/wsl.conf
    
    # Add new default user setting
    sed -i '/\[user\]/a default = '"$username" /etc/wsl.conf
    
    print_success "Default user set to $username"
    print_warning "You must restart WSL for this change to take effect"
}

# Function to display usage
usage() {
    cat << EOF
ArchWSL2 User Setup Script

Usage: $0 [OPTIONS] <username>

OPTIONS:
    -p, --password PASSWORD    Set user password (will prompt if not provided)
    -s, --ssh                 Setup SSH keys for the user
    -d, --dev                 Setup development environment
    -h, --help               Show this help message

EXAMPLES:
    $0 myuser
    $0 -p mypass -s -d myuser
    $0 --ssh --dev myuser

EOF
}

# Main execution
main() {
    local username=""
    local password=""
    local setup_ssh=false
    local setup_dev=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--password)
                password="$2"
                shift 2
                ;;
            -s|--ssh)
                setup_ssh=true
                shift
                ;;
            -d|--dev)
                setup_dev=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                if [[ -z "$username" ]]; then
                    username="$1"
                else
                    print_error "Multiple usernames provided"
                    usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Validate username
    if [[ -z "$username" ]]; then
        print_error "Username is required"
        usage
        exit 1
    fi
    
    validate_username "$username"
    
    # Check if user already exists
    if user_exists "$username"; then
        print_error "User $username already exists"
        exit 1
    fi
    
    # Prompt for password if not provided
    if [[ -z "$password" ]]; then
        read -s -p "Enter password for $username: " password
        echo
        read -s -p "Confirm password: " password_confirm
        echo
        if [[ "$password" != "$password_confirm" ]]; then
            print_error "Passwords do not match"
            exit 1
        fi
    fi
    
    # Check password strength
    if [[ ${#password} -lt 8 ]]; then
        print_warning "Password is less than 8 characters - consider using a stronger password"
    fi
    
    check_root
    
    print_info "Starting user setup for $username"
    
    create_user "$username" "$password" "$setup_ssh" "$setup_dev"
    set_default_user "$username"
    
    print_success "Setup completed successfully!"
    print_info "Restart WSL to apply changes: wsl --shutdown"
}

# Run main function with all arguments
main "$@"
