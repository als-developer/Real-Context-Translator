#!/bin/bash
set -euo pipefail

# RCT-Engine Performance Optimization Script
# Applies system-level optimizations for maximum performance

echo "⚡ RCT-Engine Performance Optimization"
echo "=========================================="

# 1. Kernel parameters
optimize_kernel() {
    echo "1. Optimizing kernel parameters..."
    
    cat >> /etc/sysctl.conf << EOF
# RCT-Engine optimizations
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 50000
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 3
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
EOF
    
    sysctl -p
    echo "   ✓ Kernel optimized"
}

# 2. CPU governor for performance
optimize_cpu() {
    echo "2. Optimizing CPU governor..."
    
    # Set to performance mode if available
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null || true
        echo "   ✓ CPU governor set to performance"
    else
        echo "   ⚠️ CPU scaling not available"
    fi
}

# 3. Disable unnecessary services
optimize_services() {
    echo "3. Disabling unnecessary services..."
    
    systemctl disable bluetooth.service 2>/dev/null || true
    systemctl disable cups.service 2>/dev/null || true
    systemctl disable avahi-daemon.service 2>/dev/null || true
    
    echo "   ✓ Unnecessary services disabled"
}

# 4. Increase file descriptor limits
optimize_file_limits() {
    echo "4. Increasing file descriptor limits..."
    
    cat >> /etc/security/limits.conf << EOF
* soft nofile 65535
* hard nofile 65535
root soft nofile 65535
root hard nofile 65535
EOF
    
    ulimit -n 65535
    echo "   ✓ File descriptor limits increased"
}

# 5. Optimize Docker daemon
optimize_docker() {
    echo "5. Optimizing Docker daemon..."
    
    cat > /etc/docker/daemon.json << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "exec-opts": ["native.cgroupdriver=systemd"],
  "iptables": true,
  "ip-forward": true,
  "ip-masq": true,
  "userland-proxy": false
}
EOF
    
    systemctl restart docker
    echo "   ✓ Docker optimized"
}

# 6. Configure huge pages for database
optimize_huge_pages() {
    echo "6. Configuring huge pages for PostgreSQL..."
    
    echo 1024 > /proc/sys/vm/nr_hugepages
    
    cat >> /etc/sysctl.conf << EOF
vm.nr_hugepages = 1024
vm.hugetlb_shm_group = 1000
EOF
    
    echo "   ✓ Huge pages configured"
}

# 7. Network optimization
optimize_network() {
    echo "7. Optimizing network settings..."
    
    # Disable IPv6 if not needed
    # sysctl -w net.ipv6.conf.all.disable_ipv6=1
    # sysctl -w net.ipv6.conf.default.disable_ipv6=1
    
    # Optimize TCP settings
    sysctl -w net.ipv4.tcp_slow_start_after_idle=0
    sysctl -w net.ipv4.tcp_mtu_probing=1
    
    echo "   ✓ Network optimized"
}

# 8. Set up process priority for C++ engine
optimize_cpp_priority() {
    echo "8. Setting C++ engine priority..."
    
    # Find C++ engine PID and set real-time priority
    CPP_PID=$(pgrep -f "rct_core" || true)
    if [ -n "$CPP_PID" ]; then
        chrt -f -p 99 "$CPP_PID"
        renice -20 -p "$CPP_PID"
        echo "   ✓ C++ engine priority set to real-time"
    else
        echo "   ⚠️ C++ engine not running"
    fi
}

# Main
main() {
    optimize_kernel
    optimize_cpu
    optimize_services
    optimize_file_limits
    optimize_docker
    optimize_huge_pages
    optimize_network
    optimize_cpp_priority
    
    echo ""
    echo "=========================================="
    echo "✅ Performance optimization completed"
    echo "=========================================="
}

main
