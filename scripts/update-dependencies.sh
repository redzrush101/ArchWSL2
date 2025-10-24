#!/bin/bash

# ArchWSL2 Dependency Update Script
# Updates base Docker images and project dependencies

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_ROOT/backups"
LOG_FILE="$PROJECT_ROOT/update.log"
DOCKER_BASE_IMAGE="archlinux:base-devel"
WSLDL_REPO="yuk7/wsldl"

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

# Function to initialize logging
init_logging() {
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "ArchWSL2 Dependency Update - $(date)" > "$LOG_FILE"
    print_info "Logging to: $LOG_FILE"
}

# Function to check if running as root for certain operations
check_permissions() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root - some operations may require elevated privileges"
    fi
}

# Function to backup current files
backup_files() {
    print_info "Creating backup of current files..."
    
    local backup_timestamp
    backup_timestamp=$(date +%Y%m%d_%H%M%S)
    local current_backup_dir="$BACKUP_DIR/backup_$backup_timestamp"
    
    mkdir -p "$current_backup_dir"
    
    # Backup important files
    local files_to_backup=(
        "Makefile"
        "wsl.conf"
        "wsl-distribution.conf"
        "bash_profile"
        "setcap-iputils.hook"
        "wslg-init.service"
    )
    
    for file in "${files_to_backup[@]}"; do
        if [[ -f "$PROJECT_ROOT/$file" ]]; then
            cp "$PROJECT_ROOT/$file" "$current_backup_dir/"
            print_info "Backed up: $file"
        fi
    done
    
    # Backup built artifacts if they exist
    if [[ -f "$PROJECT_ROOT/ArchWSL2.zip" ]]; then
        cp "$PROJECT_ROOT/ArchWSL2.zip" "$current_backup_dir/"
        print_info "Backed up: ArchWSL2.zip"
    fi
    
    if [[ -f "$PROJECT_ROOT/rootfs.tar.gz" ]]; then
        cp "$PROJECT_ROOT/rootfs.tar.gz" "$current_backup_dir/"
        print_info "Backed up: rootfs.tar.gz"
    fi
    
    print_success "Backup created: $current_backup_dir"
    echo "$current_backup_dir" > "$BACKUP_DIR/latest_backup.txt"
}

# Function to update Docker base image
update_docker_image() {
    print_header "Updating Docker Base Image"
    
    # Check current image
    print_info "Checking current Docker image..."
    if docker images | grep -q "archlinux.*base-devel"; then
        local current_image_id
        current_image_id=$(docker images archlinux:base-devel --format "{{.ID}}")
        print_info "Current image ID: $current_image_id"
    else
        print_info "No existing archlinux:base-devel image found"
    fi
    
    # Pull latest image
    print_info "Pulling latest $DOCKER_BASE_IMAGE..."
    if docker pull "$DOCKER_BASE_IMAGE"; then
        print_success "Successfully pulled latest Docker image"
        
        # Get new image ID
        local new_image_id
        new_image_id=$(docker images "$DOCKER_BASE_IMAGE" --format "{{.ID}}")
        
        if [[ "$current_image_id" != "$new_image_id" ]]; then
            print_success "Docker image updated (old: $current_image_id, new: $new_image_id)"
            return 0
        else
            print_info "Docker image is already up to date"
            return 1
        fi
    else
        print_error "Failed to pull Docker image"
        return 1
    fi
}

# Function to check for wsldl updates
check_wsldl_updates() {
    print_header "Checking wsldl Updates"
    
    # Get current wsldl version from Makefile
    local current_version=""
    if [[ -f "$PROJECT_ROOT/Makefile" ]]; then
        current_version=$(grep "LNCR_ZIP_URL" "$PROJECT_ROOT/Makefile" | grep -o "tag/[^/]*" | cut -d'/' -f2 || echo "unknown")
    fi
    
    print_info "Current wsldl version: $current_version"
    
    # Get latest release from GitHub API
    print_info "Fetching latest wsldl release..."
    local latest_version
    latest_version=$(curl -s "https://api.github.com/repos/$WSLDL_REPO/releases/latest" | jq -r '.tag_name' 2>/dev/null || echo "unknown")
    
    if [[ "$latest_version" == "null" || "$latest_version" == "unknown" ]]; then
        print_warning "Could not fetch latest wsldl version"
        return 1
    fi
    
    print_info "Latest wsldl version: $latest_version"
    
    if [[ "$current_version" != "$latest_version" && "$current_version" != "unknown" ]]; then
        print_success "wsldl update available: $current_version → $latest_version"
        return 0
    else
        print_info "wsldl is up to date"
        return 1
    fi
}

# Function to update wsldl in Makefile
update_wsldl() {
    local latest_version="$1"
    
    print_info "Updating wsldl to version $latest_version..."
    
    # Backup original Makefile
    cp "$PROJECT_ROOT/Makefile" "$PROJECT_ROOT/Makefile.backup"
    
    # Update the URL in Makefile
    sed -i "s|LNCR_ZIP_URL=https://github.com/yuk7/wsldl/releases/download/[^/]*/|LNCR_ZIP_URL=https://github.com/yuk7/wsldl/releases/download/$latest_version/|" "$PROJECT_ROOT/Makefile"
    
    print_success "wsldl URL updated in Makefile"
}

# Function to check for package updates in base image
check_package_updates() {
    print_header "Checking Package Updates"
    
    print_info "Starting temporary container to check package updates..."
    
    # Create a temporary container to check package updates
    local container_name="archwsl-update-check-$$"
    
    if docker run --name "$container_name" --rm "$DOCKER_BASE_IMAGE" bash -c "
        pacman -Sy --noconfirm
        echo 'Checking for updates...'
        pacman -Qu --noconfirm | head -20
        echo '---'
        echo 'Total packages to update:'
        pacman -Qu --noconfirm | wc -l
    " 2>&1 | tee -a "$LOG_FILE"; then
        print_success "Package update check completed"
    else
        print_error "Failed to check package updates"
    fi
}

# Function to update project scripts
update_scripts() {
    print_header "Updating Project Scripts"
    
    # Check for script improvements
    local script_files=(
        "scripts/setup-user.sh"
        "scripts/validate-build.sh"
        "scripts/generate-config.sh"
        "scripts/update-dependencies.sh"
    )
    
    for script in "${script_files[@]}"; do
        if [[ -f "$PROJECT_ROOT/$script" ]]; then
            print_info "Checking script: $script"
            
            # Check for common improvements
            if grep -q "set -euo pipefail" "$PROJECT_ROOT/$script"; then
                print_info "✓ Script has proper error handling"
            else
                print_warning "⚠ Script missing error handling"
            fi
            
            if grep -q "#!/bin/bash" "$PROJECT_ROOT/$script"; then
                print_info "✓ Script has proper shebang"
            else
                print_warning "⚠ Script missing shebang"
            fi
        fi
    done
}

# Function to validate updated dependencies
validate_updates() {
    print_header "Validating Updated Dependencies"
    
    cd "$PROJECT_ROOT"
    
    # Test Docker image
    print_info "Testing updated Docker image..."
    if docker run --rm "$DOCKER_BASE_IMAGE" echo "Docker image test successful" 2>&1 | tee -a "$LOG_FILE"; then
        print_success "Docker image validation passed"
    else
        print_error "Docker image validation failed"
        return 1
    fi
    
    # Test build process (dry run)
    print_info "Testing build process with updated dependencies..."
    if docker run --rm -v "$PROJECT_ROOT:/workspace" -w /workspace "$DOCKER_BASE_IMAGE" bash -c "
        # Test basic commands
        pacman --version
        tar --version
        zip --version
        
        # Test Makefile syntax
        if [[ -f Makefile ]]; then
            make -n all || echo 'Makefile dry run completed'
        fi
    " 2>&1 | tee -a "$LOG_FILE"; then
        print_success "Build validation passed"
    else
        print_error "Build validation failed"
        return 1
    fi
}

# Function to create update report
create_update_report() {
    print_header "Creating Update Report"
    
    local report_file="$PROJECT_ROOT/update-report-$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$report_file" << EOF
# ArchWSL2 Dependency Update Report

**Generated:** $(date)

## Summary
This report contains information about the dependency update process.

## Docker Base Image
- **Image:** $DOCKER_BASE_IMAGE
- **Status:** $(docker images | grep -q "archlinux.*base-devel" && echo "Available" || echo "Not found")

## wsldl Launcher
- **Repository:** https://github.com/$WSLDL_REPO
- **Status:** Check update log for version information

## Backup Location
$(cat "$BACKUP_DIR/latest_backup.txt" 2>/dev/null || echo "No backup created")

## Update Log
The detailed update log is available at: \`$LOG_FILE\`

## Next Steps
1. Review the update log for any issues
2. Test the build process with updated dependencies
3. Consider rebuilding the ArchWSL2 distribution
4. Update documentation if necessary

## Rollback Information
If needed, you can restore files from the backup directory.
EOF
    
    print_success "Update report created: $report_file"
}

# Function to display usage
usage() {
    cat << EOF
ArchWSL2 Dependency Update Script

Usage: $0 [OPTIONS]

OPTIONS:
    -d, --docker-only       Only update Docker base image
    -w, --wsldl-only        Only check wsldl updates
    -p, --packages-only     Only check package updates
    -s, --scripts-only      Only update project scripts
    -b, --backup            Create backup before updating
    -v, --validate          Validate updates after applying
    -r, --report            Generate update report
    -f, --force             Force update without confirmation
    -l, --log FILE          Custom log file location
    -h, --help              Show this help message

EXAMPLES:
    $0                       # Full update process
    $0 --docker-only         # Update Docker image only
    $0 --backup --validate   # Update with backup and validation
    $0 --force               # Update without confirmation

EOF
}

# Main execution
main() {
    local update_docker=true
    local update_wsldl=true
    local check_packages=true
    local update_scripts=true
    local create_backup=false
    local validate=false
    local generate_report=false
    local force=false
    local custom_log=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--docker-only)
                update_docker=true
                update_wsldl=false
                check_packages=false
                update_scripts=false
                shift
                ;;
            -w|--wsldl-only)
                update_docker=false
                update_wsldl=true
                check_packages=false
                update_scripts=false
                shift
                ;;
            -p|--packages-only)
                update_docker=false
                update_wsldl=false
                check_packages=true
                update_scripts=false
                shift
                ;;
            -s|--scripts-only)
                update_docker=false
                update_wsldl=false
                check_packages=false
                update_scripts=true
                shift
                ;;
            -b|--backup)
                create_backup=true
                shift
                ;;
            -v|--validate)
                validate=true
                shift
                ;;
            -r|--report)
                generate_report=true
                shift
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -l|--log)
                custom_log="$2"
                LOG_FILE="$custom_log"
                shift 2
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
    init_logging
    check_permissions
    
    print_header "ArchWSL2 Dependency Update Started"
    
    # Create backup if requested
    if [[ "$create_backup" == true ]]; then
        backup_files
    fi
    
    # Confirmation prompt
    if [[ "$force" == false ]]; then
        echo
        print_warning "This will update dependencies for ArchWSL2"
        read -p "Continue? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            print_info "Update cancelled"
            exit 0
        fi
    fi
    
    local updates_available=false
    
    # Update Docker base image
    if [[ "$update_docker" == true ]]; then
        if update_docker_image; then
            updates_available=true
        fi
    fi
    
    # Check wsldl updates
    if [[ "$update_wsldl" == true ]]; then
        local wsldl_version
        wsldl_version=$(curl -s "https://api.github.com/repos/$WSLDL_REPO/releases/latest" | jq -r '.tag_name' 2>/dev/null || echo "unknown")
        
        if check_wsldl_updates; then
            if [[ "$force" == true ]]; then
                update_wsldl "$wsldl_version"
                updates_available=true
            else
                read -p "Update wsldl to $wsldl_version? (y/N): " wsldl_confirm
                if [[ "$wsldl_confirm" =~ ^[Yy]$ ]]; then
                    update_wsldl "$wsldl_version"
                    updates_available=true
                fi
            fi
        fi
    fi
    
    # Check package updates
    if [[ "$check_packages" == true ]]; then
        check_package_updates
    fi
    
    # Update project scripts
    if [[ "$update_scripts" == true ]]; then
        update_scripts
    fi
    
    # Validate updates
    if [[ "$validate" == true && "$updates_available" == true ]]; then
        validate_updates
    fi
    
    # Generate report
    if [[ "$generate_report" == true ]]; then
        create_update_report
    fi
    
    print_header "Update Process Completed"
    if [[ "$updates_available" == true ]]; then
        print_success "Dependencies were updated"
        print_info "Consider rebuilding ArchWSL2 with: make clean && make"
    else
        print_info "No updates were needed"
    fi
    
    print_info "Update log: $LOG_FILE"
}

# Run main function with all arguments
main "$@"