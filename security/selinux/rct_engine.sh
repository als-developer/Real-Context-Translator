#!/bin/bash
# SELinux policy installation script for RCT-Engine

# Check if SELinux is enabled
if ! command -v getenforce &>/dev/null; then
    echo "SELinux not installed. Skipping."
    exit 0
fi

if [ "$(getenforce)" = "Disabled" ]; then
    echo "SELinux is disabled. Skipping policy installation."
    exit 0
fi

# Install required packages
sudo yum install -y selinux-policy-devel checkpolicy semodule-utils

# Compile the policy
echo "Compiling SELinux policy..."
make -f /usr/share/selinux/devel/Makefile rct_engine.pp

# Install the policy
echo "Installing SELinux policy module..."
sudo semodule -i rct_engine.pp

# Set file contexts
echo "Setting file contexts..."
sudo semanage fcontext -a -t rct_engine_exec_t "/opt/rct-engine/bin(/.*)?"
sudo semanage fcontext -a -t rct_engine_log_t "/var/log/rct-engine(/.*)?"
sudo semanage fcontext -a -t rct_engine_var_t "/var/lib/rct-engine(/.*)?"

# Apply contexts
sudo restorecon -Rv /opt/rct-engine /var/log/rct-engine /var/lib/rct-engine

# Set boolean flags
sudo setsebool -P httpd_can_network_connect 1

echo "SELinux policy installed successfully"
