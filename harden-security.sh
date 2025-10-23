#!/bin/bash

# Security Hardening Script for InfinieEdge Demo Platform

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[SECURITY]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "🔒 InfinieEdge Demo Platform - Security Hardening"
echo "================================================"

# Create secrets directory
create_secrets() {
    print_status "Creating secrets directory..."
    
    mkdir -p secrets
    chmod 700 secrets
    
    # Generate random passwords
    openssl rand -base64 32 > secrets/postgres_root_password
    openssl rand -base64 32 > secrets/postgres_user_password  
    openssl rand -base64 32 > secrets/redis_password
    openssl rand -hex 32 > secrets/aegis_api_key
    openssl rand -hex 32 > secrets/spear_token
    openssl rand -hex 32 > secrets/yomo_secret
    
    # Set proper permissions
    chmod 600 secrets/*
    
    print_success "Secrets created and secured"
}

# Generate TLS certificates
generate_certificates() {
    print_status "Generating TLS certificates..."
    
    mkdir -p certs
    chmod 700 certs
    
    # Generate CA key and certificate
    openssl genrsa -out certs/ca-key.pem 4096
    openssl req -new -x509 -days 365 -key certs/ca-key.pem -sha256 -out certs/ca-cert.pem -subj "/C=US/ST=CA/L=San Francisco/O=InfinieEdge/CN=InfinieEdge-CA"
    
    # Generate server key and certificate signing request
    openssl genrsa -out certs/server-key.pem 4096
    openssl req -subj "/C=US/ST=CA/L=San Francisco/O=InfinieEdge/CN=localhost" -sha256 -new -key certs/server-key.pem -out certs/server.csr
    
    # Create extensions file for server certificate
    cat > certs/server-extfile.cnf << EOF
subjectAltName = DNS:localhost,IP:127.0.0.1,IP:0.0.0.0
extendedKeyUsage = serverAuth
EOF
    
    # Generate server certificate
    openssl x509 -req -days 365 -sha256 -in certs/server.csr -CA certs/ca-cert.pem -CAkey certs/ca-key.pem -out certs/server-cert.pem -extfile certs/server-extfile.cnf -CAcreateserial
    
    # Set permissions
    chmod 400 certs/ca-key.pem certs/server-key.pem
    chmod 444 certs/ca-cert.pem certs/server-cert.pem
    
    # Copy to secrets
    cp certs/server-cert.pem secrets/ssl_cert
    cp certs/server-key.pem secrets/ssl_key
    cp certs/ca-cert.pem secrets/ca_cert
    
    print_success "TLS certificates generated"
}

# Scan Docker images for vulnerabilities
scan_images() {
    print_status "Scanning Docker images for vulnerabilities..."
    
    # Check if trivy is installed
    if ! command -v trivy &> /dev/null; then
        print_warning "Trivy not installed. Installing..."
        
        # Install trivy based on OS
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo apt-get update
            sudo apt-get install -y wget apt-transport-https gnupg lsb-release
            wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
            echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
            sudo apt-get update
            sudo apt-get install -y trivy
        else
            print_warning "Please install Trivy manually for vulnerability scanning"
            return
        fi
    fi
    
    # Scan base images
    local images=("ubuntu:22.04" "golang:1.23-alpine" "node:18-alpine" "python:3.11-slim" "redis:7-alpine" "postgres:15-alpine" "nginx:alpine")
    
    for image in "${images[@]}"; do
        print_status "Scanning $image..."
        trivy image --severity HIGH,CRITICAL --format table "$image" || print_warning "Scan failed for $image"
    done
    
    print_success "Image scanning completed"
}

# Set up file system security
setup_filesystem_security() {
    print_status "Setting up filesystem security..."
    
    # Create security directories
    mkdir -p security/{policies,configs,logs}
    chmod 700 security
    
    # Create AppArmor profile
    cat > security/policies/docker-infiniedge << 'EOF'
#include <tunables/global>

profile docker-infiniedge flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>
  
  # Deny access to sensitive files
  deny /proc/sys/** rw,
  deny /sys/** rw,
  deny /etc/shadow r,
  deny /etc/passwd w,
  
  # Allow necessary capabilities
  capability chown,
  capability setuid,
  capability setgid,
  capability net_bind_service,
  
  # Network access
  network inet tcp,
  network inet udp,
  
  # File system access
  /app/** r,
  /tmp/** rw,
  /var/log/** w,
}
EOF
    
    # Create seccomp profile
    cat > security/policies/seccomp-profile.json << 'EOF'
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": ["SCMP_ARCH_X86_64"],
  "syscalls": [
    {
      "names": [
        "read", "write", "open", "close", "stat", "fstat", "lstat", "poll",
        "lseek", "mmap", "mprotect", "munmap", "brk", "rt_sigaction",
        "rt_sigprocmask", "rt_sigreturn", "ioctl", "pread64", "pwrite64",
        "readv", "writev", "access", "pipe", "select", "sched_yield",
        "mremap", "msync", "mincore", "madvise", "shmget", "shmat", "shmctl",
        "dup", "dup2", "pause", "nanosleep", "getitimer", "alarm", "setitimer",
        "getpid", "sendfile", "socket", "connect", "accept", "sendto",
        "recvfrom", "sendmsg", "recvmsg", "shutdown", "bind", "listen",
        "getsockname", "getpeername", "socketpair", "setsockopt", "getsockopt",
        "clone", "fork", "vfork", "execve", "exit", "wait4", "kill", "uname",
        "semget", "semop", "semctl", "shmdt", "msgget", "msgsnd", "msgrcv",
        "msgctl", "fcntl", "flock", "fsync", "fdatasync", "truncate",
        "ftruncate", "getdents", "getcwd", "chdir", "fchdir", "rename",
        "mkdir", "rmdir", "creat", "link", "unlink", "symlink", "readlink",
        "chmod", "fchmod", "chown", "fchown", "lchown", "umask", "gettimeofday",
        "getrlimit", "getrusage", "sysinfo", "times", "ptrace", "getuid",
        "syslog", "getgid", "setuid", "setgid", "geteuid", "getegid",
        "setpgid", "getppid", "getpgrp", "setsid", "setreuid", "setregid",
        "getgroups", "setgroups", "setresuid", "getresuid", "setresgid",
        "getresgid", "getpgid", "setfsuid", "setfsgid", "getsid", "capget",
        "capset", "rt_sigpending", "rt_sigtimedwait", "rt_sigqueueinfo",
        "rt_sigsuspend", "sigaltstack", "utime", "mknod", "uselib",
        "personality", "ustat", "statfs", "fstatfs", "sysfs", "getpriority",
        "setpriority", "sched_setparam", "sched_getparam",
        "sched_setscheduler", "sched_getscheduler", "sched_get_priority_max",
        "sched_get_priority_min", "sched_rr_get_interval", "mlock", "munlock",
        "mlockall", "munlockall", "vhangup", "modify_ldt", "pivot_root",
        "_sysctl", "prctl", "arch_prctl", "adjtimex", "setrlimit", "chroot",
        "sync", "acct", "settimeofday", "mount", "umount2", "swapon",
        "swapoff", "reboot", "sethostname", "setdomainname", "iopl", "ioperm",
        "create_module", "init_module", "delete_module", "get_kernel_syms",
        "query_module", "quotactl", "nfsservctl", "getpmsg", "putpmsg",
        "afs_syscall", "tuxcall", "security", "gettid", "readahead",
        "setxattr", "lsetxattr", "fsetxattr", "getxattr", "lgetxattr",
        "fgetxattr", "listxattr", "llistxattr", "flistxattr", "removexattr",
        "lremovexattr", "fremovexattr", "tkill", "time", "futex",
        "sched_setaffinity", "sched_getaffinity", "set_thread_area",
        "io_setup", "io_destroy", "io_getevents", "io_submit", "io_cancel",
        "get_thread_area", "lookup_dcookie", "epoll_create", "epoll_ctl_old",
        "epoll_wait_old", "remap_file_pages", "getdents64", "set_tid_address",
        "restart_syscall", "semtimedop", "fadvise64", "timer_create",
        "timer_settime", "timer_gettime", "timer_getoverrun", "timer_delete",
        "clock_settime", "clock_gettime", "clock_getres", "clock_nanosleep",
        "exit_group", "epoll_wait", "epoll_ctl", "tgkill", "utimes",
        "vserver", "mbind", "set_mempolicy", "get_mempolicy", "mq_open",
        "mq_unlink", "mq_timedsend", "mq_timedreceive", "mq_notify",
        "mq_getsetattr", "kexec_load", "waitid", "add_key", "request_key",
        "keyctl", "ioprio_set", "ioprio_get", "inotify_init", "inotify_add_watch",
        "inotify_rm_watch", "migrate_pages", "openat", "mkdirat", "mknodat",
        "fchownat", "futimesat", "newfstatat", "unlinkat", "renameat",
        "linkat", "symlinkat", "readlinkat", "fchmodat", "faccessat",
        "pselect6", "ppoll", "unshare", "set_robust_list", "get_robust_list",
        "splice", "tee", "sync_file_range", "vmsplice", "move_pages",
        "utimensat", "epoll_pwait", "signalfd", "timerfd_create", "eventfd",
        "fallocate", "timerfd_settime", "timerfd_gettime", "accept4",
        "signalfd4", "eventfd2", "epoll_create1", "dup3", "pipe2", "inotify_init1",
        "preadv", "pwritev", "rt_tgsigqueueinfo", "perf_event_open", "recvmmsg",
        "fanotify_init", "fanotify_mark", "prlimit64", "name_to_handle_at",
        "open_by_handle_at", "clock_adjtime", "syncfs", "sendmmsg", "setns",
        "getcpu", "process_vm_readv", "process_vm_writev", "kcmp",
        "finit_module"
      ],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
EOF
    
    chmod 644 security/policies/*
    print_success "Filesystem security configured"
}

# Create monitoring and logging configuration
setup_monitoring() {
    print_status "Setting up monitoring and logging..."
    
    # Create Prometheus configuration
    cat > monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "rules/*.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  - job_name: 'infiniedge-services'
    static_configs:
      - targets:
        - 'aegis-edge-ai:5000'
        - 'spear-platform:9090'
        - 'yomo-serverless:9000'
        - 'shifu-gateway:8080'
        - 'edge-whisper:3000'
        - 'eda-platform:8000'
        - 'aiops-platform:8001'
        - 'transformers-service:7000'
        - 'megatron-lm:6000'
        - 'whisper-finetune:4000'
    scrape_interval: 10s
    metrics_path: /metrics
    
  - job_name: 'infrastructure'
    static_configs:
      - targets:
        - 'shared-redis:6379'
        - 'shared-postgres:5432'
        - 'nginx-gateway:80'
EOF

    # Create Grafana dashboard
    mkdir -p monitoring/grafana/dashboards
    cat > monitoring/grafana/dashboards/infiniedge-overview.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "InfinieEdge Platform Overview",
    "tags": ["infiniedge"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Service Health",
        "type": "stat",
        "targets": [
          {
            "expr": "up{job=\"infiniedge-services\"}",
            "legendFormat": "{{instance}}"
          }
        ]
      },
      {
        "id": 2,
        "title": "CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(container_cpu_usage_seconds_total[5m])",
            "legendFormat": "{{name}}"
          }
        ]
      },
      {
        "id": 3,
        "title": "Memory Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "container_memory_usage_bytes",
            "legendFormat": "{{name}}"
          }
        ]
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "5s"
  }
}
EOF

    # Create logging configuration
    cat > monitoring/fluent-bit.conf << 'EOF'
[SERVICE]
    Flush         1
    Log_Level     info
    Daemon        off
    Parsers_File  parsers.conf

[INPUT]
    Name              forward
    Listen            0.0.0.0
    Port              24224

[INPUT]
    Name              docker
    Tag               docker.*
    Docker_Mode       on

[FILTER]
    Name              grep
    Match             docker.*
    Regex             container_name ^infiniedge-.*

[OUTPUT]
    Name              stdout
    Match             *

[OUTPUT]
    Name              file
    Match             docker.*
    Path              /var/log/infiniedge/
    File              services.log
EOF

    print_success "Monitoring and logging configured"
}

# Main execution
main() {
    print_status "Starting security hardening process..."
    
    create_secrets
    generate_certificates
    setup_filesystem_security
    
    # Create monitoring directory
    mkdir -p monitoring
    setup_monitoring
    
    scan_images
    
    print_success "Security hardening completed!"
    print_status "Next steps:"
    echo "  1. Review generated secrets in ./secrets/ directory"
    echo "  2. Run './manage-demo.sh build' to build hardened images"
    echo "  3. Run './test-security.sh' to validate security measures"
}

main "$@"