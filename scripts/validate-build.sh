#!/bin/bash

# ArchWSL2 Build Validation Script
# Validates the build process and checks for common issues

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REQUIRED_SPACE_GB=5
MIN_DOCKER_VERSION="20.10.0"

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

# Function to check system requirements
check_system_requirements() {
    print_info "Checking system requirements..."
    
    local errors=0
    
    # Check available disk space
    local available_space
    available_space=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $available_space -lt $REQUIRED_SPACE_GB ]]; then
        print_error "Insufficient disk space. Required: ${REQUIRED_SPACE_GB}GB, Available: ${available_space}GB"
        ((errors++))
    else
        print_success "Disk space check passed (${available_space}GB available)"
    fi
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        ((errors++))
    else
        print_success "Docker is installed"
        
        # Check Docker version
        local docker_version
        docker_version=$(docker --version | sed 's/.*version //;s/,.*//')
        if ! printf '%s\n' "$MIN_DOCKER_VERSION" "$docker_version" | sort -V -C; then
            print_warning "Docker version $docker_version is older than recommended $MIN_DOCKER_VERSION"
        else
            print_success "Docker version $docker_version meets requirements"
        fi
        
        # Check if Docker daemon is running
        if ! docker info &> /dev/null; then
            print_error "Docker daemon is not running"
            ((errors++))
        else
            print_success "Docker daemon is running"
        fi
    fi
    
    # Check required tools
    local required_tools=("tar" "zip" "unzip" "jq" "curl")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            print_error "Required tool '$tool' is not installed"
            ((errors++))
        else
            print_success "Tool '$tool' is available"
        fi
    done
    
    if [[ $errors -gt 0 ]]; then
        print_error "System requirements check failed with $errors errors"
        exit 1
    fi
    
    print_success "All system requirements met"
}

# Function to validate project structure
validate_project_structure() {
    print_info "Validating project structure..."
    
    local required_files=(
        "Makefile"
        "wsl.conf"
        "wsl-distribution.conf"
        "bash_profile"
        "archlinux.ico"
        "setcap-iputils.hook"
        "wslg-init.service"
        "LICENSE"
        "README.md"
    )
    
    local errors=0
    for file in "${required_files[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/$file" ]]; then
            print_error "Required file '$file' is missing"
            ((errors++))
        else
            print_success "Found required file: $file"
        fi
    done
    
    # Check for scripts directory
    if [[ ! -d "$PROJECT_ROOT/scripts" ]]; then
        print_warning "Scripts directory not found (optional)"
    fi
    
    if [[ $errors -gt 0 ]]; then
        print_error "Project structure validation failed with $errors errors"
        exit 1
    fi
    
    print_success "Project structure validation passed"
}

# Function to validate configuration files
validate_configurations() {
    print_info "Validating configuration files..."
    
    local errors=0
    
    # Validate wsl.conf
    if [[ -f "$PROJECT_ROOT/wsl.conf" ]]; then
        if grep -q "systemd=true" "$PROJECT_ROOT/wsl.conf"; then
            print_success "wsl.conf has systemd enabled"
        else
            print_warning "systemd is not enabled in wsl.conf"
        fi
    fi
    
    # Validate Makefile
    if [[ -f "$PROJECT_ROOT/Makefile" ]]; then
        # Check for required targets
        local required_targets=("all" "clean" "zip")
        for target in "${required_targets[@]}"; do
            if grep -q "^$target:" "$PROJECT_ROOT/Makefile"; then
                print_success "Makefile has target: $target"
            else
                print_error "Makefile missing target: $target"
                ((errors++))
            fi
        done
    fi
    
    # Validate service file
    if [[ -f "$PROJECT_ROOT/wslg-init.service" ]]; then
        if grep -q "\[Service\]" "$PROJECT_ROOT/wslg-init.service"; then
            print_success "wslg-init.service has proper structure"
        else
            print_error "wslg-init.service is malformed"
            ((errors++))
        fi
    fi
    
    if [[ $errors -gt 0 ]]; then
        print_error "Configuration validation failed with $errors errors"
        exit 1
    fi
    
    print_success "Configuration validation passed"
}

# Function to test Docker build
test_docker_build() {
    print_info "Testing Docker build process..."
    
    cd "$PROJECT_ROOT"
    
    # Check if we can pull the base image
    if ! docker pull archlinux:base-devel &> /dev/null; then
        print_error "Failed to pull archlinux:base-devel image"
        exit 1
    fi
    print_success "Successfully pulled archlinux:base-devel image"
    
    # Test container creation
    local container_name="archwsl-test-$$"
    if ! docker run --name "$container_name" --rm archlinux:base-devel echo "Docker test successful" &> /dev/null; then
        print_error "Docker container test failed"
        exit 1
    fi
    print_success "Docker container test passed"
}

# Function to validate build artifacts
validate_artifacts() {
    print_info "Validating build artifacts..."
    
    cd "$PROJECT_ROOT"
    
    # Check if rootfs.tar.gz exists
    if [[ ! -f "rootfs.tar.gz" ]]; then
        print_warning "rootfs.tar.gz not found - this is expected before build"
    else
        # Validate tar.gz file integrity
        if ! tar -tzf rootfs.tar.gz &> /dev/null; then
            print_error "rootfs.tar.gz is corrupted"
            exit 1
        fi
        print_success "rootfs.tar.gz integrity validated"
        
        # Check file size
        local file_size
        file_size=$(du -h rootfs.tar.gz | cut -f1)
        print_info "rootfs.tar.gz size: $file_size"
    fi
    
    # Check if ArchWSL2.zip exists
    if [[ ! -f "ArchWSL2.zip" ]]; then
        print_warning "ArchWSL2.zip not found - this is expected before build"
    else
        # Validate zip file integrity
        if ! unzip -t ArchWSL2.zip &> /dev/null; then
            print_error "ArchWSL2.zip is corrupted"
            exit 1
        fi
        print_success "ArchWSL2.zip integrity validated"
        
        # Check required files in zip
        local zip_files
        zip_files=$(unzip -l ArchWSL2.zip | tail -n +4 | head -n -2 | awk '{print $4}')
        local required_zip_files=("Arch.exe" "rootfs.tar.gz")
        
        for file in "${required_zip_files[@]}"; do
            if echo "$zip_files" | grep -q "^$file$"; then
                print_success "Found required file in zip: $file"
            else
                print_error "Missing required file in zip: $file"
                exit 1
            fi
        done
    fi
}

# Function to run build with validation
run_validated_build() {
    print_info "Running validated build process..."
    
    cd "$PROJECT_ROOT"
    
    # Clean previous build
    print_info "Cleaning previous build artifacts..."
    make clean
    
    # Run build with error checking
    print_info "Starting build process..."
    if make; then
        print_success "Build completed successfully"
    else
        print_error "Build failed"
        exit 1
    fi
    
    # Validate final artifacts
    validate_artifacts
    
    print_success "Build validation completed successfully"
}

# Function to display usage
usage() {
    cat << EOF
ArchWSL2 Build Validation Script

Usage: $0 [OPTIONS]

OPTIONS:
    -c, --check-only        Only run checks without building
    -b, --build             Run full build with validation
    -s, --system            Check system requirements only
    -p, --project           Check project structure only
    -f, --config            Check configurations only
    -d, --docker            Test Docker setup only
    -a, --artifacts         Validate artifacts only
    -v, --verbose           Enable verbose output
    -h, --help              Show this help message

EXAMPLES:
    $0 --check-only         # Run all checks without building
    $0 --build              # Run full build with validation
    $0 --system --docker    # Check system and Docker setup only

EOF
}

# Main execution
main() {
    local check_only=false
    local run_build=false
    local check_system=false
    local check_project=false
    local check_config=false
    local check_docker=false
    local check_artifacts=false
    local verbose=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--check-only)
                check_only=true
                shift
                ;;
            -b|--build)
                run_build=true
                shift
                ;;
            -s|--system)
                check_system=true
                shift
                ;;
            -p|--project)
                check_project=true
                shift
                ;;
            -f|--config)
                check_config=true
                shift
                ;;
            -d|--docker)
                check_docker=true
                shift
                ;;
            -a|--artifacts)
                check_artifacts=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                set -x
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
    
    # If no specific checks requested, run all checks
    if [[ "$check_system" == false && "$check_project" == false && "$check_config" == false && "$check_docker" == false && "$check_artifacts" == false ]]; then
        check_system=true
        check_project=true
        check_config=true
        check_docker=true
        check_artifacts=true
    fi
    
    print_info "Starting ArchWSL2 build validation..."
    
    # Run requested checks
    if [[ "$check_system" == true ]]; then
        check_system_requirements
    fi
    
    if [[ "$check_project" == true ]]; then
        validate_project_structure
    fi
    
    if [[ "$check_config" == true ]]; then
        validate_configurations
    fi
    
    if [[ "$check_docker" == true ]]; then
        test_docker_build
    fi
    
    if [[ "$check_artifacts" == true ]]; then
        validate_artifacts
    fi
    
    # Run build if requested
    if [[ "$run_build" == true ]]; then
        run_validated_build
    elif [[ "$check_only" == true ]]; then
        print_success "All validation checks completed successfully"
    fi
    
    print_success "Build validation completed!"
}

# Run main function with all arguments
main "$@"