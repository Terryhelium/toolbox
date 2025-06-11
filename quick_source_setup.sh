#!/bin/bash

# 快速软件源配置脚本 - 简化版
# 适用于快速配置新服务器

NEXUS_HOST="10.19.26.136"

echo "🚀 快速软件源配置工具"
echo "==================="
echo "📅 $(date '+%Y-%m-%d %H:%M:%S')"
echo "🖥️  $(hostname) ($(hostname -I | awk '{print $1}'))"
echo ""

# 检查网络连通性
echo "🌐 检查网络连通性..."
if ! ping -c 2 -W 3 "$NEXUS_HOST" >/dev/null 2>&1; then
    echo "❌ 无法连接到Nexus服务器 ($NEXUS_HOST)"
    echo "请检查网络连接后重试"
    exit 1
fi
echo "✅ 网络连接正常"
echo ""

# 显示当前状态
echo "📋 当前配置状态:"
echo "   APT源: $(grep -c "^deb" /etc/apt/sources.list 2>/dev/null || echo 0) 个"
echo "   Docker: $([ -f /etc/docker/daemon.json ] && echo "已配置" || echo "未配置")"
echo "   pip: $([ -f ~/.pip/pip.conf ] && echo "已配置" || echo "未配置")"
echo "   npm: $(command -v npm >/dev/null 2>&1 && echo "$(npm config get registry)" || echo "未安装")"
echo ""

# 询问是否继续
read -p "是否继续配置？[Y/n]: " confirm
if [[ "$confirm" =~ ^[Nn]$ ]]; then
    echo "配置已取消"
    exit 0
fi

echo ""
echo "⚙️  开始配置软件源..."

# 1. 配置APT源
echo "📦 配置APT源..."
sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup.$(date +%Y%m%d) 2>/dev/null || true

cat << EOF | sudo tee /etc/apt/sources.list.d/nexus.list >/dev/null
# Nexus代理源 - $(date)
deb http://$NEXUS_HOST:8081/repository/ubuntu-proxy/ jammy main restricted universe multiverse
deb http://$NEXUS_HOST:8081/repository/ubuntu-proxy/ jammy-updates main restricted universe multiverse
deb http://$NEXUS_HOST:8081/repository/ubuntu-proxy/ jammy-security main restricted universe multiverse
EOF
echo "   ✅ APT源配置完成"

# 2. 配置Docker源
echo "🐳 配置Docker源..."
sudo mkdir -p /etc/docker
sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup.$(date +%Y%m%d) 2>/dev/null || true

cat << EOF | sudo tee /etc/docker/daemon.json >/dev/null
{
  "registry-mirrors": ["http://$NEXUS_HOST:8083"],
  "insecure-registries": [
    "$NEXUS_HOST:8083", "$NEXUS_HOST:8082", 
    "$NEXUS_HOST:8084", "$NEXUS_HOST:8085"
  ],
  "log-driver": "json-file",
  "log-opts": {"max-size": "10m", "max-file": "3"}
}
EOF
echo "   ✅ Docker源配置完成"

# 3. 配置pip源
echo "🐍 配置pip源..."
mkdir -p ~/.pip
cp ~/.pip/pip.conf ~/.pip/pip.conf.backup.$(date +%Y%m%d) 2>/dev/null || true

cat << EOF > ~/.pip/pip.conf
[global]
index-url = http://$NEXUS_HOST:8081/repository/pypi-proxy/simple/
trusted-host = $NEXUS_HOST
timeout = 120
EOF
echo "   ✅ pip源配置完成"

# 4. 配置npm源
if command -v npm >/dev/null 2>&1; then
    echo "📦 配置npm源..."
    npm config set registry http://$NEXUS_HOST:8081/repository/npm-proxy/
    echo "   ✅ npm源配置完成"
else
    echo "📦 npm未安装，跳过配置"
fi

# 5. 重启服务
echo ""
echo "🔄 重启相关服务..."
if systemctl is-active --quiet docker 2>/dev/null; then
    sudo systemctl restart docker
    echo "   ✅ Docker服务已重启"
fi

# 6. 验证配置
echo ""
echo "🧪 验证配置..."

# 验证APT
if apt-cache policy | grep -q "$NEXUS_HOST" 2>/dev/null; then
    echo "   ✅ APT源验证成功"
else
    echo "   ⚠️  APT源可能需要更新缓存: sudo apt update"
fi

# 验证Docker
if docker info 2>/dev/null | grep -q "Registry Mirrors"; then
    echo "   ✅ Docker源验证成功"
else
    echo "   ⚠️  Docker源可能需要重启服务"
fi

# 验证pip
if pip config list 2>/dev/null | grep -q "$NEXUS_HOST"; then
    echo "   ✅ pip源验证成功"
else
    echo "   ⚠️  pip源配置可能需要检查"
fi

echo ""
echo "🎉 配置完成！"
echo ""
echo "📝 后续建议操作:"
echo "   sudo apt update          # 更新APT缓存"
echo "   docker pull alpine:3.18  # 测试Docker拉取"
echo "   pip install --upgrade pip # 测试pip"
echo ""
echo "📁 备份文件位置:"
echo "   /etc/apt/sources.list.backup.*"
echo "   /etc/docker/daemon.json.backup.*"
echo "   ~/.pip/pip.conf.backup.*"