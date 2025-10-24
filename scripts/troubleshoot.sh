#!/bin/bash

# ArchWSL2 Troubleshooting Helper Script
# Diagnoses and helps resolve common ArchWSL2 issues

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_ROOT/troubleshoot.log"
TEMP_DIR="/tmp/archwsl2-troubleshoot-$$"

# Print functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo -e "${CYAN}$1${NC}" | tee -a "$LOG_FILE"
}

print_step() {
    echo -e "${MAGENTA}▶ $1${NC}" | tee -a "$LOG_FILE"
}

# Function to initialize troubleshooting
init_troubleshoot() {
    mkdir -p "$TEMP_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "ArchWSL2 Troubleshooting Session - $(date)" > "$LOG_FILE"
    print_info "Troubleshooting log: $LOG_FILE"
    print_info "Working directory: $TEMP_DIR"
}

# Function to check if we're running in WSL
check_wsl_environment() {
    print_header "Checking WSL Environment"
    
    if [[ ! -f /proc/version ]]; then
        print_error "Cannot read /proc/version"
        return 1
    fi
    
    if grep -q "Microsoft\|WSL" /proc/version; then
        local wsl_version
        wsl_version=$(grep -o "WSL[0-9]" /proc/version | head -1)
        print_success "Running in WSL ($wsl_version)"
        
        # Get Windows version
        local windows_build
        windows_build=$(uname -r | grep -o "Microsoft.*" | sed 's/Microsoft //')
        print_info "Windows build: $windows_build"
        
        return 0
    else
        print_warning "Not running in WSL environment"
        return 1
    fi
}

# Function to check system resources
check_system_resources() {
    print_header "Checking System Resources"
    
    # Memory usage
    local mem_total
    local mem_available
    mem_total=$(free -h | awk 'NR==2{print $2}')
    mem_available=$(free -h | awk 'NR==2{print $7}')
    print_info "Memory: $mem_available available / $mem_total total"
    
    # Disk space
    local disk_usage
    disk_usage=$(df -h / | awk 'NR==2{print $3 "/" $2 " (" $5 ")"}')
    print_info "Disk usage: $disk_usage"
    
    # CPU info
    local cpu_cores
    cpu_cores=$(nproc)
    print_info "CPU cores: $cpu_cores"
    
    # Check for resource warnings
    local mem_percent
    mem_percent=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    if [[ $mem_percent -gt 90 ]]; then
        print_warning "High memory usage: ${mem_percent}%"
    fi
    
    local disk_percent
    disk_percent=$(df / | awk 'NR==2{print $5}' | sed 's/%//')
    if [[ $disk_percent -gt 90 ]]; then
        print_warning "High disk usage: ${disk_percent}%"
    fi
}

# Function to check network connectivity
check_network() {
    print_header "Checking Network Connectivity"
    
    # Check internet connectivity
    if ping -c 1 8.8.8.8 &> /dev/null; then
        print_success "Internet connectivity: OK"
    else
        print_error "No internet connectivity"
        return 1
    fi
    
    # Check DNS resolution
    if nslookup google.com &> /dev/null; then
        print_success "DNS resolution: OK"
    else
        print_warning "DNS resolution issues detected"
    fi
    
    # Check pacman mirrors
    if command -v pacman &> /dev/null; then
        print_info "Testing pacman mirrors..."
        if timeout 10 pacman -Sy &> /dev/null; then
            print_success "Pacman mirrors: OK"
        else
            print_warning "Pacman mirror issues detected"
        fi
    fi
}

# Function to check WSL configuration
check_wsl_config() {
    print_header "Checking WSL Configuration"
    
    # Check wsl.conf
    if [[ -f /etc/wsl.conf ]]; then
        print_info "Found /etc/wsl.conf"
        
        # Check systemd
        if grep -q "systemd=true" /etc/wsl.conf; then
            print_success "systemd is enabled"
            
            # Check if systemd is actually running
            if command -v systemctl &> /dev/null && systemctl is-active --quiet; then
                print_success "systemd is running"
            else
                print_warning "systemd is enabled but not running"
            fi
        else
            print_warning "systemd is not enabled"
        fi
        
        # Check automount settings
        if grep -q "enabled = true" /etc/wsl.conf; then
            print_success "automount is enabled"
        else
            print_info "automount is disabled or not configured"
        fi
        
        # Check interop settings
        if grep -q "appendWindowsPath = true" /etc/wsl.conf; then
            print_info "Windows PATH integration is enabled"
        fi
    else
        print_warning "/etc/wsl.conf not found"
    fi
    
    # Check wsl-distribution.conf
    if [[ -f /etc/wsl-distribution.conf ]]; then
        print_info "Found /etc/wsl-distribution.conf"
    else
        print_warning "/etc/wsl-distribution.conf not found"
    fi
}

# Function to check services
check_services() {
    print_header "Checking Services"
    
    # Check systemd services if available
    if command -v systemctl &> /dev/null; then
        local services=("sshd" "docker" "dbus" "systemd-journald")
        
        for service in "${services[@]}"; do
            if systemctl is-enabled "$service" &> /dev/null; then
                if systemctl is-active "$service" &> /dev/null; then
                    print_success "Service $service: enabled and running"
                else
                    print_warning "Service $service: enabled but not running"
                fi
            else
                print_info "Service $service: not enabled"
            fi
        done
    else
        print_info "systemd not available, checking traditional services..."
        
        # Check SSH daemon
        if pgrep sshd &> /dev/null; then
            print_success "SSH daemon is running"
        else
            print_info "SSH daemon is not running"
        fi
    fi
}

# Function to check package management
check_package_management() {
    print_header "Checking Package Management"
    
    if command -v pacman &> /dev/null; then
        print_success "pacman is available"
        
        # Check database
        if pacman -Q &> /dev/null; then
            print_success "pacman database is accessible"
        else
            print_error "pacman database issues detected"
        fi
        
        # Check for pending updates
        local updates
        updates=$(pacman -Qu | wc -l)
        if [[ $updates -gt 0 ]]; then
            print_warning "$updates package updates available"
        else
            print_success "System is up to date"
        fi
        
        # Check for broken packages
        if pacman -Qk 2>&1 | grep -q "missing file"; then
            print_warning "Some packages have missing files"
        fi
    else
        print_error "pacman not found"
    fi
    
    # Check AUR helpers
    local aur_helpers=("paru" "yay" "pacaur")
    for helper in "${aur_helpers[@]}"; do
        if command -v "$helper" &> /dev/null; then
            print_success "AUR helper found: $helper"
            break
        fi
    done
}

# Function to check file system
check_filesystem() {
    print_header "Checking File System"
    
    # Check critical directories
    local critical_dirs=("/etc" "/usr" "/var" "/home" "/tmp")
    for dir in "${critical_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local dir_size
            dir_size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            print_info "Directory $dir: $dir_size"
        else
            print_error "Critical directory missing: $dir"
        fi
    done
    
    # Check permissions
    if [[ -w /etc ]]; then
        print_success "Write permissions to /etc"
    else
        print_warning "No write permissions to /etC"
    fi
    
    # Check disk health
    if command -v df &> /dev/null; then
        df -h | grep -E "Filesystem|/dev/" | tee -a "$LOG_FILE"
    fi
}

# Function to check GPU and graphics
check_graphics() {
    print_header "Checking Graphics Support"
    
    # Check for WSLg
    if [[ -n "${DISPLAY:-}" ]]; then
        print_success "DISPLAY variable is set: $DISPLAY"
        
        # Check if X11 applications work
        if command -v xeyes &> /dev/null; then
            print_info "X11 applications available"
        fi
        
        # Check for GPU drivers
        if lspci &> /dev/null; then
            local gpu_info
            gpu_info=$(lspci | grep -i vga || echo "No GPU detected via lspci")
            print_info "GPU: $gpu_info"
        fi
        
        # Check for DirectX/WSL2 GPU support
        if command -v dxdiag &> /dev/null; then
            print_info "DirectX diagnostic tool available"
        fi
    else
        print_info "No DISPLAY variable set (WSLg not available or not configured)"
    fi
    
    # Check for OpenGL
    if command -v glxinfo &> /dev/null; then
        if glxinfo | grep -q "direct rendering: Yes"; then
            print_success "OpenGL direct rendering is available"
        fi
    fi
}

# Function to check common issues
check_common_issues() {
    print_header "Checking Common Issues"
    
    # Check for locale issues
    if locale 2>&1 | grep -q "Cannot set LC"; then
        print_warning "Locale configuration issues detected"
        print_info "Try: sudo locale-gen"
    fi
    
    # Check for time sync issues
    local timedatectl_output
    timedatectl_output=$(timedatectl 2>/dev/null || echo "timedatectl not available")
    if echo "$timedatectl_output" | grep -q "NTP synchronized: no"; then
        print_warning "Time synchronization issues"
    fi
    
    # Check for systemd user services
    if command -v systemctl &> /dev/null; then
        local failed_services
        failed_services=$(systemctl --user list-units --failed | wc -l)
        if [[ $failed_services -gt 0 ]]; then
            print_warning "$failed_services failed user services"
        fi
    fi
    
    # Check for permission issues in /tmp
    if [[ ! -w /tmp ]]; then
        print_error "No write permissions to /tmp"
    fi
    
    # Check for DNS issues in resolv.conf
    if [[ -f /etc/resolv.conf ]]; then
        local nameservers
        nameservers=$(grep -c "^nameserver" /etc/resolv.conf)
        if [[ $nameservers -eq 0 ]]; then
            print_warning "No nameservers configured in resolv.conf"
        fi
    fi
}

# Function to generate fixes
generate_fixes() {
    print_header "Generating Fix Suggestions"
    
    local fixes_file="$TEMP_DIR/fixes.txt"
    
    cat > "$fixes_file" << 'EOF'
# ArchWSL2 Troubleshooting Fixes

## Network Issues
- Check Windows firewall settings
- Restart WSL: wsl --shutdown
- Reset network: wsl --shutdown && netsh winsock reset
- Update WSL: wsl --update

## Performance Issues
- Increase WSL memory in .wslconfig
- Move WSL to faster drive (SSD)
- Disable unnecessary services
- Clear package cache: sudo pacman -Scc

## Service Issues
- Restart systemd: sudo systemctl daemon-reload
- Reset service: sudo systemctl restart <service>
- Check service logs: journalctl -u <service>

## Package Issues
- Refresh package database: sudo pacman -Sy
- Update keyring: sudo pacman -Sy archlinux-keyring
- Clear cache: sudo pacman -Scc
- Reinstall broken package: sudo pacman -S <package>

## Graphics/WSLg Issues
- Restart WSLg: Restart Windows
- Update Windows graphics drivers
- Check Windows version compatibility
- Set DISPLAY=:0 in ~/.bashrc

## Permission Issues
- Fix ownership: sudo chown -R user:group /path
- Fix permissions: chmod 755 /path
- Check SELinux/AppArmor status

## systemd Issues
- Check status: systemctl status
- Enable service: sudo systemctl enable <service>
- Check journal: journalctl -xe
EOF
    
    print_success "Fix suggestions generated: $fixes_file"
    
    # Display some quick fixes based on common issues
    echo
    print_step "Quick Fixes:"
    
    # Network fixes
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        echo "  • Network issues detected:"
        echo "    - Restart WSL: wsl --shutdown"
        echo "    - Check Windows firewall"
        echo "    - Reset network: netsh winsock reset (in Windows)"
    fi
    
    # Memory fixes
    local mem_percent
    mem_percent=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    if [[ $mem_percent -gt 90 ]]; then
        echo "  • High memory usage:"
        echo "    - Clear package cache: sudo pacman -Scc"
        echo "    - Restart services: sudo systemctl restart"
        echo "    - Increase WSL memory in .wslconfig"
    fi
    
    # systemd fixes
    if command -v systemctl &> /dev/null && ! systemctl is-active --quiet; then
        echo "  • systemd issues:"
        echo "    - Check systemd version: systemctl --version"
        echo "    - Restart WSL: wsl --shutdown"
        echo "    - Verify WSL version supports systemd"
    fi
}

# Function to collect diagnostic information
collect_diagnostics() {
    print_header "Collecting Diagnostic Information"
    
    local diag_file="$TEMP_DIR/diagnostics.txt"
    
    {
        echo "=== ArchWSL2 Diagnostic Information ==="
        echo "Generated: $(date)"
        echo
        
        echo "--- System Information ---"
        uname -a
        echo
        
        echo "--- WSL Information ---"
        cat /proc/version
        echo
        
        echo "--- Memory Usage ---"
        free -h
        echo
        
        echo "--- Disk Usage ---"
        df -h
        echo
        
        echo "--- Environment Variables ---"
        env | grep -E "(WSL|DISPLAY|PATH)" | sort
        echo
        
        if command -v systemctl &> /dev/null; then
            echo "--- Systemd Status ---"
            systemctl status --no-pager -l
            echo
        fi
        
        if [[ -f /etc/wsl.conf ]]; then
            echo "--- wsl.conf ---"
            cat /etc/wsl.conf
            echo
        fi
        
        echo "--- Network Configuration ---"
        ip addr show
        echo
        cat /etc/resolv.conf
        echo
        
        if command -v pacman &> /dev/null; then
            echo "--- Package Information ---"
            pacman -Qi pacman 2>/dev/null || echo "pacman info not available"
            echo
            echo "--- Pending Updates ---"
            pacman -Qu || echo "No updates available"
            echo
        fi
        
    } > "$diag_file"
    
    print_success "Diagnostic information collected: $diag_file"
}

# Function to display usage
usage() {
    cat << EOF
ArchWSL2 Troubleshooting Helper Script

Usage: $0 [OPTIONS]

OPTIONS:
    -q, --quick              Run quick diagnostics only
    -f, --full               Run comprehensive diagnostics (default)
    -n, --network            Focus on network issues
    -s, --services           Focus on service issues
    -p, --packages           Focus on package management issues
    -g, --graphics           Focus on graphics/WSLg issues
    -c, --collect-only       Only collect diagnostics, no fixes
    -o, --output DIR         Custom output directory
    -r, --report             Generate detailed report
    -h, --help               Show this help message

EXAMPLES:
    $0                       # Full troubleshooting
    $0 --quick               # Quick diagnostics
    $0 --network             # Network troubleshooting
    $0 --collect-only        # Collect diagnostics only

EOF
}

# Main execution
main() {
    local quick=false
    local full=true
    local network_only=false
    local services_only=false
    local packages_only=false
    local graphics_only=false
    local collect_only=false
    local custom_output=""
    local generate_report=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -q|--quick)
                quick=true
                full=false
                shift
                ;;
            -f|--full)
                full=true
                shift
                ;;
            -n|--network)
                network_only=true
                full=false
                shift
                ;;
            -s|--services)
                services_only=true
                full=false
                shift
                ;;
            -p|--packages)
                packages_only=true
                full=false
                shift
                ;;
            -g|--graphics)
                graphics_only=true
                full=false
                shift
                ;;
            -c|--collect-only)
                collect_only=true
                shift
                ;;
            -o|--output)
                custom_output="$2"
                TEMP_DIR="$custom_output"
                shift 2
                ;;
            -r|--report)
                generate_report=true
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
                print_error "Unexpected argument: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Initialize
    init_troubleshoot
    
    print_header "ArchWSL2 Troubleshooting Started"
    
    # Run diagnostics based on options
    if [[ "$network_only" == true ]]; then
        check_wsl_environment
        check_network
    elif [[ "$services_only" == true ]]; then
        check_wsl_environment
        check_services
    elif [[ "$packages_only" == true ]]; then
        check_wsl_environment
        check_package_management
    elif [[ "$graphics_only" == true ]]; then
        check_wsl_environment
        check_graphics
    elif [[ "$quick" == true ]]; then
        check_wsl_environment
        check_network
        check_system_resources
    elif [[ "$full" == true ]]; then
        check_wsl_environment
        check_system_resources
        check_network
        check_wsl_config
        check_services
        check_package_management
        check_filesystem
        check_graphics
        check_common_issues
    fi
    
    # Generate fixes and collect diagnostics
    if [[ "$collect_only" == false ]]; then
        generate_fixes
    fi
    
    collect_diagnostics
    
    # Generate detailed report if requested
    if [[ "$generate_report" == true ]]; then
        local report_file="$PROJECT_ROOT/troubleshoot-report-$(date +%Y%m%d_%H%M%S).txt"
        cp "$LOG_FILE" "$report_file"
        cat "$TEMP_DIR/diagnostics.txt" >> "$report_file"
        cat "$TEMP_DIR/fixes.txt" >> "$report_file"
        print_success "Detailed report generated: $report_file"
    fi
    
    print_header "Troubleshooting Completed"
    print_info "Files created in: $TEMP_DIR"
    print_info "Log file: $LOG_FILE"
    
    # Cleanup
    rm -rf "$TEMP_DIR"
}

# Run main function with all arguments
main "$@"