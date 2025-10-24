#!/bin/bash

# ArchWSL2 Configuration Template Generator
# Generates optimized wsl.conf configurations for different use cases

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

print_header() {
    echo -e "${CYAN}$1${NC}"
}

# Configuration templates
generate_development_config() {
    cat << 'EOF'
# ArchWSL2 Development Configuration
# Optimized for software development

[automount]
# Enable automatic mounting of Windows drives
enabled = true
# Mount options for Windows drives
options = "metadata,umask=22,fmask=11"
# Mount Windows drives to /mnt/
mountFsTab = true

[network]
# Generate hosts file
generateHosts = true
# Generate resolv.conf
generateResolvConf = true

[interop]
# Enable Windows interoperability
enabled = false
# Append Windows PATH to Linux PATH
appendWindowsPath = false

[user]
# Default user (will be set by setup script)
# default = username

[boot]
# Enable systemd (Windows 11 only)
systemd = true
# Command to run at boot (optional)
# command = "systemctl start docker.service"

# Custom settings for development
# These are not standard WSL settings but commonly used
# in custom startup scripts
EOF
}

generate_gaming_config() {
    cat << 'EOF'
# ArchWSL2 Gaming Configuration
# Optimized for gaming and GPU workloads

[automount]
# Enable automatic mounting of Windows drives
enabled = true
# Mount options optimized for gaming
options = "metadata,umask=22,fmask=11"
mountFsTab = true

[network]
# Generate hosts file
generateHosts = true
# Generate resolv.conf
generateResolvConf = true

[interop]
# Enable Windows interoperability for game launchers
enabled = true
# Append Windows PATH for game executables
appendWindowsPath = true

[user]
# Default user
# default = username

[boot]
# Enable systemd
systemd = true
# Preload gaming-related services
command = "systemctl start dbus.service"

# Gaming-specific optimizations
# Note: These would need custom implementation in startup scripts
EOF
}

generate_server_config() {
    cat << 'EOF'
# ArchWSL2 Server Configuration
# Optimized for server and container workloads

[automount]
# Disable automatic mounting for security
enabled = false
# If enabled, use secure mount options
# options = "metadata,umask=077,fmask=077"
# mountFsTab = false

[network]
# Generate hosts file
generateHosts = true
# Generate resolv.conf
generateResolvConf = true

[interop]
# Disable Windows interoperability for security
enabled = false
# Don't append Windows PATH
appendWindowsPath = false

[user]
# Default user
# default = username

[boot]
# Enable systemd
systemd = true
# Start server services at boot
command = "systemctl start sshd.service docker.service"

# Server-specific security settings
EOF
}

generate_minimal_config() {
    cat << 'EOF'
# ArchWSL2 Minimal Configuration
# Lightweight setup for basic usage

[automount]
# Basic mount settings
enabled = true
options = "metadata"
mountFsTab = true

[network]
# Basic network settings
generateHosts = true
generateResolvConf = true

[interop]
# Basic interoperability
enabled = true
appendWindowsPath = false

[user]
# Default user
# default = username

[boot]
# Enable systemd
systemd = true

# Minimal configuration - no extra services
EOF
}

generate_desktop_config() {
    cat << 'EOF'
# ArchWSL2 Desktop Configuration
# Optimized for GUI applications and desktop usage

[automount]
# Enable automatic mounting
enabled = true
# Mount options for desktop usage
options = "metadata,umask=22,fmask=11"
mountFsTab = true

[network]
# Generate hosts file
generateHosts = true
# Generate resolv.conf
generateResolvConf = true

[interop]
# Enable Windows interoperability
enabled = true
# Append Windows PATH for desktop integration
appendWindowsPath = true

[user]
# Default user
# default = username

[boot]
# Enable systemd
systemd = true
# Start desktop services
command = "systemctl start dbus.service systemd-user-sessions.service"

# Desktop-specific settings
# Note: WSLg should be configured separately
EOF
}

# Function to generate custom configuration
generate_custom_config() {
    local automount_enabled="${1:-true}"
    local interop_enabled="${2:-true}"
    local append_path="${3:-false}"
    local systemd_enabled="${4:-true}"
    local boot_command="${5:-}"
    
    cat << EOF
# ArchWSL2 Custom Configuration
# Generated with custom parameters

[automount]
enabled = $automount_enabled
options = "metadata,umask=22,fmask=11"
mountFsTab = true

[network]
generateHosts = true
generateResolvConf = true

[interop]
enabled = $interop_enabled
appendWindowsPath = $append_path

[user]
# default = username

[boot]
systemd = $systemd_enabled
EOF

    if [[ -n "$boot_command" ]]; then
        echo "command = \"$boot_command\""
    fi
    
    echo ""
}

# Function to create startup script
create_startup_script() {
    local config_type="$1"
    local output_dir="$2"
    
    local script_file="$output_dir/wsl-startup.sh"
    
    cat > "$script_file" << 'EOF'
#!/bin/bash

# ArchWSL2 Startup Script
# Runs custom commands when WSL starts

# Check if we're running in WSL
if [[ ! -f /proc/version ]] || ! grep -q "Microsoft\|WSL" /proc/version; then
    echo "This script is designed to run in WSL"
    exit 1
fi

# Function to start services based on configuration
start_services() {
    local config_type="$1"
    
    case "$config_type" in
        "development")
            # Development-specific services
            if command -v docker &> /dev/null; then
                sudo systemctl start docker.service &> /dev/null || true
            fi
            if command -v sshd &> /dev/null; then
                sudo systemctl start sshd.service &> /dev/null || true
            fi
            ;;
        "gaming")
            # Gaming-specific services
            if command -v dbus &> /dev/null; then
                sudo systemctl start dbus.service &> /dev/null || true
            fi
            ;;
        "server")
            # Server-specific services
            if command -v sshd &> /dev/null; then
                sudo systemctl start sshd.service &> /dev/null || true
            fi
            if command -v docker &> /dev/null; then
                sudo systemctl start docker.service &> /dev/null || true
            fi
            ;;
        "desktop")
            # Desktop-specific services
            if command -v dbus &> /dev/null; then
                sudo systemctl start dbus.service &> /dev/null || true
            fi
            if command -v systemd-user-sessions &> /dev/null; then
                sudo systemctl start systemd-user-sessions.service &> /dev/null || true
            fi
            ;;
    esac
}

# Main execution
config_type="$1"
if [[ -z "$config_type" ]]; then
    config_type="minimal"
fi

start_services "$config_type"

# Custom user commands can be added here
# For example:
# if [[ -f "$HOME/.wslrc" ]]; then
#     source "$HOME/.wslrc"
# fi
EOF
    
    chmod +x "$script_file"
    print_success "Created startup script: $script_file"
}

# Function to display configuration options
show_config_options() {
    print_header "Available Configuration Templates:"
    echo
    echo "1. development   - Optimized for software development"
    echo "   • Disables Windows interop for cleaner environment"
    echo "   • Enables Docker and SSH services"
    echo "   • Secure mount options"
    echo
    echo "2. gaming        - Optimized for gaming and GPU workloads"
    echo "   • Enables Windows interop for game launchers"
    echo "   • Starts D-Bus service"
    echo "   • Windows PATH integration"
    echo
    echo "3. server        - Optimized for server and container workloads"
    echo "   • Disables automount for security"
    echo "   • Disables Windows interop"
    echo "   • Starts SSH and Docker services"
    echo
    echo "4. minimal       - Lightweight setup for basic usage"
    echo "   • Basic configuration only"
    echo "   • Minimal resource usage"
    echo
    echo "5. desktop       - Optimized for GUI applications"
    echo "   • Enables Windows interop"
    echo "   • Starts desktop services"
    echo "   • Windows PATH integration"
    echo
    echo "6. custom        - Interactive custom configuration"
    echo "   • Choose specific options"
    echo "   • Tailored to your needs"
    echo
}

# Function to interactively create custom config
interactive_custom_config() {
    print_info "Creating custom configuration interactively..."
    echo
    
    # Automount settings
    echo "Automount settings:"
    read -p "Enable automount? (y/N): " automount_input
    local automount_enabled="true"
    [[ "$automount_input" =~ ^[Nn]$ ]] && automount_enabled="false"
    
    # Interop settings
    echo
    echo "Interoperability settings:"
    read -p "Enable Windows interop? (Y/n): " interop_input
    local interop_enabled="true"
    [[ "$interop_input" =~ ^[Nn]$ ]] && interop_enabled="false"
    
    read -p "Append Windows PATH? (y/N): " path_input
    local append_path="false"
    [[ "$path_input" =~ ^[Yy]$ ]] && append_path="true"
    
    # Systemd settings
    echo
    echo "Boot settings:"
    read -p "Enable systemd? (Y/n): " systemd_input
    local systemd_enabled="true"
    [[ "$systemd_input" =~ ^[Nn]$ ]] && systemd_enabled="false"
    
    # Boot command
    echo
    read -p "Boot command (optional, press Enter to skip): " boot_command
    
    echo
    print_info "Custom configuration summary:"
    echo "  Automount: $automount_enabled"
    echo "  Interop: $interop_enabled"
    echo "  Append Windows PATH: $append_path"
    echo "  Systemd: $systemd_enabled"
    [[ -n "$boot_command" ]] && echo "  Boot command: $boot_command"
    echo
    
    read -p "Generate this configuration? (Y/n): " confirm
    [[ "$confirm" =~ ^[Nn]$ ]] && return 1
    
    generate_custom_config "$automount_enabled" "$interop_enabled" "$append_path" "$systemd_enabled" "$boot_command"
    return 0
}

# Function to display usage
usage() {
    cat << EOF
ArchWSL2 Configuration Template Generator

Usage: $0 [OPTIONS] [TYPE]

TYPES:
    development   - Development-optimized configuration
    gaming        - Gaming-optimized configuration
    server        - Server-optimized configuration
    minimal       - Minimal configuration
    desktop       - Desktop-optimized configuration
    custom        - Interactive custom configuration

OPTIONS:
    -o, --output DIR       Output directory (default: current directory)
    -s, --startup          Generate startup script
    -l, --list             List available configurations
    -i, --interactive      Interactive mode
    -h, --help             Show this help message

EXAMPLES:
    $0 development                    # Generate development config
    $0 -o /tmp gaming                 # Generate gaming config to /tmp
    $0 --startup server               # Generate server config with startup script
    $0 custom                         # Interactive custom configuration

EOF
}

# Main execution
main() {
    local output_dir="."
    local generate_startup=false
    local list_only=false
    local interactive=false
    local config_type=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -o|--output)
                output_dir="$2"
                shift 2
                ;;
            -s|--startup)
                generate_startup=true
                shift
                ;;
            -l|--list)
                list_only=true
                shift
                ;;
            -i|--interactive)
                interactive=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            development|gaming|server|minimal|desktop|custom)
                config_type="$1"
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                print_error "Unknown configuration type: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Create output directory if it doesn't exist
    mkdir -p "$output_dir"
    
    # List configurations if requested
    if [[ "$list_only" == true ]]; then
        show_config_options
        exit 0
    fi
    
    # Interactive mode
    if [[ "$interactive" == true && -z "$config_type" ]]; then
        show_config_options
        echo
        read -p "Select configuration type (1-6): " selection
        case "$selection" in
            1) config_type="development" ;;
            2) config_type="gaming" ;;
            3) config_type="server" ;;
            4) config_type="minimal" ;;
            5) config_type="desktop" ;;
            6) config_type="custom" ;;
            *) print_error "Invalid selection"; exit 1 ;;
        esac
    fi
    
    # If no configuration type specified, show help
    if [[ -z "$config_type" ]]; then
        print_error "Configuration type is required"
        usage
        exit 1
    fi
    
    print_info "Generating $config_type configuration..."
    
    # Generate configuration
    local config_file="$output_dir/wsl.conf"
    case "$config_type" in
        development)
            generate_development_config > "$config_file"
            ;;
        gaming)
            generate_gaming_config > "$config_file"
            ;;
        server)
            generate_server_config > "$config_file"
            ;;
        minimal)
            generate_minimal_config > "$config_file"
            ;;
        desktop)
            generate_desktop_config > "$config_file"
            ;;
        custom)
            if ! interactive_custom_config > "$config_file"; then
                print_error "Custom configuration cancelled"
                exit 1
            fi
            ;;
    esac
    
    print_success "Configuration generated: $config_file"
    
    # Generate startup script if requested
    if [[ "$generate_startup" == true ]]; then
        create_startup_script "$config_type" "$output_dir"
    fi
    
    print_info "To use this configuration:"
    print_info "1. Copy $config_file to /etc/wsl.conf in your ArchWSL2 instance"
    print_info "2. Restart WSL: wsl --shutdown"
    print_info "3. Restart your ArchWSL2 instance"
}

# Run main function with all arguments
main "$@"