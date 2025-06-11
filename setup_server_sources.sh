#!/bin/bash

# 完整的服务器源配置脚本
# 用途：统一配置APT源和Docker镜像源
# 基于工作服务器配置生成

set -e  # 遇到错误立即退出

echo "=========================================="
echo "开始配置服务器源 - $(date)"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   log_error "此脚本需要root权限运行"
   exit 1
fi

# 1. 备份原有配置
BACKUP_DIR="/root/sources_backup_$(date +%Y%m%d_%H%M%S)"
log_info "创建备份目录: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# 备份APT配置
if [ -f /etc/apt/sources.list ]; then
    cp /etc/apt/sources.list "$BACKUP_DIR/"
    log_info "已备份 /etc/apt/sources.list"
fi

if [ -d /etc/apt/sources.list.d ]; then
    cp -r /etc/apt/sources.list.d "$BACKUP_DIR/"
    log_info "已备份 /etc/apt/sources.list.d/"
fi

# 备份Docker配置
if [ -f /etc/docker/daemon.json ]; then
    cp /etc/docker/daemon.json "$BACKUP_DIR/"
    log_info "已备份 /etc/docker/daemon.json"
fi

# 2. 清理现有源配置
log_info "清理现有APT源配置..."

# 清空主源文件
> /etc/apt/sources.list

# 删除所有第三方源
if [ -d /etc/apt/sources.list.d ]; then
    rm -f /etc/apt/sources.list.d/*
    log_info "已清理所有第三方源"
fi

# 3. 应用新的APT源配置
log_info "配置新的APT源..."

# 写入主源文件
cat > /etc/apt/sources.list << 'EOF'
# Ubuntu Noble - Nexus3代理 (临时配置)
deb http://10.19.26.136:8082/repository/ubuntu-noble-aliyun-proxy/ noble main restricted universe multiverse
deb http://10.19.26.136:8082/repository/ubuntu-noble-aliyun-proxy/ noble-updates main restricted universe multiverse
deb http://10.19.26.136:8082/repository/ubuntu-noble-aliyun-proxy/ noble-backports main restricted universe multiverse
deb http://10.19.26.136:8082/repository/ubuntu-noble-aliyun-proxy/ noble-security main restricted universe multiverse
EOF

# 创建sources.list.d目录（如果不存在）
mkdir -p /etc/apt/sources.list.d

# 写入Zabbix源
cat > /etc/apt/sources.list.d/zabbix-nexus.list << 'EOF'
# Zabbix 7.0 Repository via Nexus3
deb http://10.19.26.136:8082/repository/zabbix-7-ubuntu-24.04/ noble main
EOF

log_info "APT源配置完成"

# 4. 配置Docker镜像源
log_info "配置Docker镜像源..."

# 创建Docker配置目录
mkdir -p /etc/docker

# 写入Docker配置
cat > /etc/docker/daemon.json << 'EOF'
{
  "registry-mirrors": [
    "http://10.19.26.136:8082/repository/docker-hub-proxy/"
  ]
}
EOF

log_info "Docker镜像源配置完成"

# 5. 更新APT缓存
log_info "清理APT缓存..."
apt clean
apt autoclean

log_info "更新APT软件包索引..."
if apt update; then
    log_info "APT更新成功"
else
    log_error "APT更新失败，请检查网络连接"
    exit 1
fi

# 6. 重启Docker服务（如果Docker已安装）
if systemctl is-active --quiet docker 2>/dev/null; then
    log_info "重启Docker服务以应用新配置..."
    systemctl restart docker
    if systemctl is-active --quiet docker; then
        log_info "Docker服务重启成功"
    else
        log_warn "Docker服务重启失败，请手动检查"
    fi
elif command -v docker >/dev/null 2>&1; then
    log_warn "Docker已安装但服务未运行，请手动启动: systemctl start docker"
else
    log_info "Docker未安装，跳过Docker服务配置"
fi

# 7. 验证配置
echo ""
echo "=========================================="
echo "配置验证"
echo "=========================================="

log_info "当前APT源配置:"
echo "--- /etc/apt/sources.list ---"
cat /etc/apt/sources.list
echo ""

log_info "第三方源:"
echo "--- /etc/apt/sources.list.d/ ---"
ls -la /etc/apt/sources.list.d/ 2>/dev/null || echo "无第三方源文件"
echo ""

if [ -f /etc/apt/sources.list.d/zabbix-nexus.list ]; then
    echo "--- Zabbix源内容 ---"
    cat /etc/apt/sources.list.d/zabbix-nexus.list
    echo ""
fi

log_info "Docker配置:"
echo "--- /etc/docker/daemon.json ---"
cat /etc/docker/daemon.json 2>/dev/null || echo "Docker配置文件不存在"
echo ""

log_info "APT策略 (前10行):"
apt policy | head -10

echo ""
echo "=========================================="
echo "配置完成 - $(date)"
echo "=========================================="
log_info "备份文件位置: $BACKUP_DIR"
log_info "如需回滚，请手动恢复备份文件"

# 8. 可选：测试网络连接
echo ""
read -p "是否测试网络连接？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "测试Nexus连接..."
    if curl -s --connect-timeout 5 http://10.19.26.136:8082/ >/dev/null; then
        log_info "✅ Nexus服务器连接正常"
    else
        log_warn "⚠️  Nexus服务器连接失败，请检查网络"
    fi
    
    log_info "测试APT源..."
    if apt-cache policy ubuntu-keyring >/dev/null 2>&1; then
        log_info "✅ APT源工作正常"
    else
        log_warn "⚠️  APT源可能有问题"
    fi
fi

log_info "脚本执行完成！"