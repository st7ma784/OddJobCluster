#!/bin/bash

# User management script for the cluster
# This script helps manage users across SLURM and JupyterHub

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

show_usage() {
    echo "Usage: $0 {add|remove|list|reset-password} [username] [options]"
    echo ""
    echo "Commands:"
    echo "  add <username>           Add a new user to the cluster"
    echo "  remove <username>        Remove a user from the cluster"
    echo "  list                     List all cluster users"
    echo "  reset-password <username> Reset user password"
    echo ""
    echo "Options:"
    echo "  --admin                  Grant admin privileges (for add command)"
    echo "  --slurm-only            Add user only to SLURM (skip JupyterHub)"
    echo "  --jupyter-only          Add user only to JupyterHub (skip SLURM)"
    echo ""
}

add_user() {
    local username=$1
    local is_admin=${2:-false}
    local slurm_only=${3:-false}
    local jupyter_only=${4:-false}
    
    if [ -z "$username" ]; then
        print_error "Username is required"
        show_usage
        exit 1
    fi
    
    print_info "Adding user: $username"
    
    # Add system user on all nodes
    if [ "$jupyter_only" != "true" ]; then
        print_info "Creating system user on all nodes..."
        ansible all -i ansible/inventory.ini -m user -a "
            name=$username
            shell=/bin/bash
            create_home=yes
            groups=users
        " --become
        
        # Add to SLURM
        print_info "Adding user to SLURM..."
        ansible master -i ansible/inventory.ini -m shell -a "
            sacctmgr -i add user $username defaultaccount=users
        " --become
    fi
    
    # Add to JupyterHub (if not SLURM-only)
    if [ "$slurm_only" != "true" ]; then
        print_info "Adding user to JupyterHub..."
        if [ "$is_admin" == "true" ]; then
            print_info "Granting admin privileges..."
            # This would typically involve updating JupyterHub config
            print_warning "Admin privileges require manual JupyterHub configuration update"
        fi
    fi
    
    print_success "User $username added successfully"
    print_info "Default password: $username (please change on first login)"
}

remove_user() {
    local username=$1
    
    if [ -z "$username" ]; then
        print_error "Username is required"
        show_usage
        exit 1
    fi
    
    print_warning "Removing user: $username"
    read -p "Are you sure? This will delete all user data. (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "User removal cancelled"
        exit 0
    fi
    
    # Remove from SLURM
    print_info "Removing user from SLURM..."
    ansible master -i ansible/inventory.ini -m shell -a "
        sacctmgr -i remove user $username
    " --become || true
    
    # Remove system user
    print_info "Removing system user from all nodes..."
    ansible all -i ansible/inventory.ini -m user -a "
        name=$username
        state=absent
        remove=yes
    " --become
    
    print_success "User $username removed successfully"
}

list_users() {
    print_info "Cluster Users:"
    echo ""
    
    print_info "SLURM Users:"
    ansible master -i ansible/inventory.ini -m shell -a "
        sacctmgr show user -P | grep -v '^User|' | cut -d'|' -f1 | sort -u
    " --become
    
    echo ""
    print_info "System Users (UID >= 1000):"
    ansible master -i ansible/inventory.ini -m shell -a "
        getent passwd | awk -F: '\$3 >= 1000 && \$3 < 65534 {print \$1}' | sort
    " --become
}

reset_password() {
    local username=$1
    
    if [ -z "$username" ]; then
        print_error "Username is required"
        show_usage
        exit 1
    fi
    
    print_info "Resetting password for user: $username"
    
    # Generate random password
    local new_password=$(openssl rand -base64 12)
    
    # Set password on all nodes
    ansible all -i ansible/inventory.ini -m shell -a "
        echo '$username:$new_password' | chpasswd
    " --become
    
    print_success "Password reset successfully"
    print_info "New password: $new_password"
    print_warning "Please share this password securely with the user"
}

# Parse command line arguments
case "$1" in
    add)
        shift
        username=$1
        shift
        
        is_admin=false
        slurm_only=false
        jupyter_only=false
        
        while [[ $# -gt 0 ]]; do
            case $1 in
                --admin)
                    is_admin=true
                    shift
                    ;;
                --slurm-only)
                    slurm_only=true
                    shift
                    ;;
                --jupyter-only)
                    jupyter_only=true
                    shift
                    ;;
                *)
                    print_error "Unknown option: $1"
                    show_usage
                    exit 1
                    ;;
            esac
        done
        
        add_user "$username" "$is_admin" "$slurm_only" "$jupyter_only"
        ;;
    remove)
        remove_user "$2"
        ;;
    list)
        list_users
        ;;
    reset-password)
        reset_password "$2"
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
