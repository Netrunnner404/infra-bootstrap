#!/bin/bash
set -euo pipefail

fail() {
    echo "❌ $1"
    exit 1
}

is_container() {
    [ -f /.dockerenv ] || grep -qaE 'docker|containerd' /proc/1/cgroup 2>/dev/null
}

echo "VERIFY SERVER CONFIGURATION"

echo
echo "=== 1. Checking user: devops ==="
id devops &>/dev/null || fail "User 'devops' not found"
echo "✅ User 'devops' exists"

echo
echo "=== 2. Checking SSH settings ==="
sshd_config="/etc/ssh/sshd_config"
[ -f "$sshd_config" ] || fail "File $sshd_config not found"

grep -E '^PermitRootLogin no' "$sshd_config" &>/dev/null || fail "Root login is allowed"
echo "✅ Root login is disabled"

grep -E '^PasswordAuthentication no' "$sshd_config" &>/dev/null || fail "Password authentication is allowed"
echo "✅ Password authentication is disabled"

echo
echo "=== 3. Checking unattended upgrades ==="
auto_upgrades_file="/etc/apt/apt.conf.d/20auto-upgrades"
[ -f "$auto_upgrades_file" ] || fail "File $auto_upgrades_file not found"

grep -q 'APT::Periodic::Unattended-Upgrade "1";' "$auto_upgrades_file" || fail "Unattended upgrades are not configured"
echo "✅ Unattended upgrades are enabled"

echo
echo "=== 4. Checking infrastructure directories ==="
for dir in /opt/docker /opt/docker/stacks /opt/backups /opt/logs; do
    [ -d "$dir" ] || fail "$dir does not exist"
    echo "✅ $dir exists"
done

echo
echo "=== 5. Checking Docker ==="
command -v docker &>/dev/null || fail "Docker is not installed"
echo "✅ Docker is installed"
docker --version

pgrep dockerd &>/dev/null || fail "Docker daemon is not running"
echo "✅ Docker daemon is running"

echo
echo "=== 6. Checking fail2ban ==="
command -v fail2ban-client &>/dev/null || fail "fail2ban is not installed"
echo "✅ fail2ban is installed"

if is_container; then
    echo "ℹ️ Skipping fail2ban runtime check inside a container"
else
    fail2ban-client status &>/dev/null || fail "fail2ban is not running"
    echo "✅ fail2ban is running"
fi

echo
echo "=== 7. Checking firewall (ufw) ==="
command -v ufw &>/dev/null || fail "ufw is not installed"

ufw status | grep -q "Status: active" || fail "Firewall is disabled"
echo "✅ Firewall is enabled"

for port in 22 80 443; do
    ufw status | grep -q "$port" || fail "Port $port is closed"
    echo "✅ Port $port is open"
done

echo
echo "VERIFY COMPLETE"