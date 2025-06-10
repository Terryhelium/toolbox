#!/bin/bash

# 增强版Linux软件源检测脚本
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

print_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}    增强版Linux软件源检测脚本           ${NC}"
echo -e "${CYAN}=========================================${NC}"
echo

# 系统信息
print_step "系统信息检测"
echo "发行版: $(lsb_release -d 2>/dev/null | cut -f2 || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "版本: $(lsb_release -r 2>/dev/null | cut -f2 || cat /etc/os-release | grep VERSION_ID | cut -d'"' -f2)"
echo "内核: $(uname -r)"
echo "架构: $(uname -m)"
echo "时间: $(date)"
echo

# APT源检测
print_step "APT软件源检测"
if [ -f "/etc/apt/sources.list" ]; then
    print_info "主配置文件: /etc/apt/sources.list"
    grep -v "^#" /etc/apt/sources.list | grep -v "^$" | while read line; do
        echo "  $line"
    done
    echo
fi

if [ -d "/etc/apt/sources.list.d" ]; then
    print_info "额外源目录: /etc/apt/sources.list.d/"
    for file in /etc/apt/sources.list.d/*; do
        if [ -f "$file" ]; then
            echo "  文件: $(basename "$file")"
            grep -v "^#" "$file" 2>/dev/null | grep -v "^$" | while read line; do
                echo "    $line"
            done
        fi
    done
    echo
fi

# Docker详细检测
print_step "Docker详细检测"

# 检查Docker服务状态
echo -n "Docker服务状态: "
if systemctl is-active docker >/dev/null 2>&1; then
    print_success "运行中"
else
    print_error "未运行"
fi

# 检查Docker版本
echo -n "Docker版本: "
if command -v docker >/dev/null 2>&1; then
    docker --version
else
    print_error "Docker未安装"
fi

# 检查Docker daemon配置
print_info "Docker daemon配置:"
if [ -f "/etc/docker/daemon.json" ]; then
    echo "配置文件: /etc/docker/daemon.json"
    cat /etc/docker/daemon.json | jq . 2>/dev/null || cat /etc/docker/daemon.json
else
    print_warning "未找到 /etc/docker/daemon.json"
fi
echo

# 测试Docker registry连接
print_step "Docker Registry连接测试"

# 测试Nexus Docker代理
NEXUS_DOCKER_URL="192.168.31.217:8082"
echo -n "测试Nexus Docker代理 ($NEXUS_DOCKER_URL) ... "
if curl -s --connect-timeout 10 "http://$NEXUS_DOCKER_URL/v2/" >/dev/null 2>&1; then
    print_success "可访问"
else
    print_error "不可访问"
fi

# 测试Docker Hub连接
echo -n "测试Docker Hub直连 ... "
if curl -s --connect-timeout 10 "https://registry-1.docker.io/v2/" >/dev/null 2>&1; then
    print_success "可访问"
else
    print_error "不可访问"
fi

# 测试Nexus Docker Hub代理
echo -n "测试Nexus Docker Hub代理 ... "
if curl -s --connect-timeout 10 "http://$NEXUS_DOCKER_URL/repository/docker-hub/v2/" >/dev/null 2>&1; then
    print_success "可访问"
else
    print_error "不可访问"
fi

echo

# Docker镜像测试
print_step "Docker镜像拉取测试"

# 清理可能的缓存
echo "清理Docker缓存..."
docker system prune -f >/dev/null 2>&1 || true

# 测试小镜像拉取
echo -n "测试拉取 hello-world 镜像 ... "
if timeout 60 docker pull hello-world >/dev/null 2>&1; then
    print_success "成功"
    docker images hello-world
else
    print_error "失败"
    echo "详细错误信息:"
    docker pull hello-world 2>&1 | head -10
fi

echo

# 网络连通性测试
print_step "网络连通性测试"

# 测试本地Nexus
echo -n "本地Nexus (192.168.31.217:8082) ... "
if ping -c 1 192.168.31.217 >/dev/null 2>&1; then
    print_success "可达"
else
    print_error "不可达"
fi

# 测试DNS解析
echo -n "DNS解析 (registry-1.docker.io) ... "
if nslookup registry-1.docker.io >/dev/null 2>&1; then
    print_success "正常"
else
    print_error "失败"
fi

# 测试外网连接
echo -n "外网连接 (8.8.8.8) ... "
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    print_success "正常"
else
    print_error "失败"
fi

echo

# Docker daemon日志检查
print_step "Docker daemon日志检查"
print_info "最近的Docker daemon日志:"
journalctl -u docker --no-pager -n 20 --since "10 minutes ago" 2>/dev/null | tail -10 || echo "无法获取日志"

echo

# Nexus仓库状态检查
print_step "Nexus仓库状态检查"

NEXUS_URL="http://192.168.31.217:8082"
REPOS=("docker-hub" "docker-apt" "debian-bullseye" "debian-security" "pypi-proxy" "maven-central")

for repo in "${REPOS[@]}"; do
    echo -n "$repo ... "
    response=$(curl -s -w "%{http_code}" --connect-timeout 10 "${NEXUS_URL}/repository/${repo}/" -o /dev/null 2>/dev/null)
    
    if [ "$response" = "200" ]; then
        print_success "正常"
    else
        print_error "异常 (HTTP: $response)"
    fi
done

echo

# 问题诊断和建议
print_step "问题诊断和修复建议"

echo "基于检测结果的问题分析:"
echo "========================="

# 检查Docker配置问题
if [ -f "/etc/docker/daemon.json" ]; then
    if grep -q "registry-mirrors" /etc/docker/daemon.json; then
        print_info "✓ Docker镜像代理已配置"
    else
        print_warning "✗ Docker镜像代理未配置"
    fi
    
    if grep -q "insecure-registries" /etc/docker/daemon.json; then
        print_info "✓ 不安全注册表已配置"
    else
        print_warning "✗ 不安全注册表未配置"
    fi
else
    print_error "✗ Docker daemon配置文件不存在"
fi

echo
print_info "修复建议:"
echo "1. 重启Docker服务: systemctl restart docker"
echo "2. 检查Nexus Docker代理配置"
echo "3. 验证网络连接"
echo "4. 清理Docker缓存: docker system prune -a"
echo

# 生成修复脚本
print_step "生成Docker修复脚本"

cat > /tmp/fix_docker_nexus.sh << 'FIXEOF'
#!/bin/bash
# Docker Nexus修复脚本

echo "开始修复Docker Nexus配置..."

# 1. 停止Docker服务
echo "停止Docker服务..."
systemctl stop docker

# 2. 清理Docker缓存
echo "清理Docker缓存..."
docker system prune -a -f 2>/dev/null || true

# 3. 重新配置daemon.json
echo "重新配置daemon.json..."
cat > /etc/docker/daemon.json << 'EOF'
{
  "registry-mirrors": [
    "http://192.168.31.217:8082/repository/docker-hub/"
  ],
  "insecure-registries": [
    "192.168.31.217:8082"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "dns": ["8.8.8.8", "8.8.4.4"],
  "max-concurrent-downloads": 3,
  "max-concurrent-uploads": 5
}
EOF

# 4. 启动Docker服务
echo "启动Docker服务..."
systemctl start docker
systemctl enable docker

# 5. 等待服务启动
echo "等待Docker服务启动..."
sleep 10

# 6. 测试镜像拉取
echo "测试镜像拉取..."
if docker pull hello-world; then
    echo "✅ Docker修复成功！"
else
    echo "❌ Docker修复失败，请检查网络和Nexus配置"
fi
FIXEOF

chmod +x /tmp/fix_docker_nexus.sh
print_success "修复脚本已生成: /tmp/fix_docker_nexus.sh"

echo
print_info "检测完成！如需修复Docker问题，请运行: /tmp/fix_docker_nexus.sh"