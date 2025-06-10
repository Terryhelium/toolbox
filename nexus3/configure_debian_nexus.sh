#!/bin/bash

# Debian 11 (bullseye) Nexus 配置脚本
# 基于系统检测结果进行精准配置

set -e

# Nexus 配置
NEXUS_HOST="192.168.31.217"
NEXUS_PORT="8082"
NEXUS_BASE_URL="http://${NEXUS_HOST}:${NEXUS_PORT}"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}\n=== $1 ===${NC}"
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# 备份现有配置
backup_configs() {
    print_header "备份现有配置"
    
    local backup_dir="/root/nexus_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # 备份APT配置
    if [ -f /etc/apt/sources.list ]; then
        cp /etc/apt/sources.list "$backup_dir/sources.list"
        print_info "✓ APT sources.list 已备份"
    fi
    
    if [ -d /etc/apt/sources.list.d ]; then
        cp -r /etc/apt/sources.list.d "$backup_dir/"
        print_info "✓ APT sources.list.d 目录已备份"
    fi
    
    # 备份Docker配置
    if [ -f /etc/docker/daemon.json ]; then
        cp /etc/docker/daemon.json "$backup_dir/daemon.json"
        print_info "✓ Docker daemon.json 已备份"
    fi
    
    # 备份pip配置
    if [ -f ~/.pip/pip.conf ]; then
        mkdir -p "$backup_dir/.pip"
        cp ~/.pip/pip.conf "$backup_dir/.pip/"
        print_info "✓ pip 配置已备份"
    fi
    
    if [ -f ~/.config/pip/pip.conf ]; then
        mkdir -p "$backup_dir/.config/pip"
        cp ~/.config/pip/pip.conf "$backup_dir/.config/pip/"
        print_info "✓ pip 新格式配置已备份"
    fi
    
    print_success "备份完成，保存在: $backup_dir"
    echo "export NEXUS_BACKUP_DIR=$backup_dir" >> ~/.bashrc
}

# 配置APT源
configure_apt() {
    print_header "配置APT软件源"
    
    print_info "配置主要的Debian仓库..."
    
    # 创建新的sources.list
    cat > /etc/apt/sources.list << 'EOF'
# Nexus 代理的 Debian 仓库
deb http://192.168.31.217:8082/repository/debian-bullseye/ bullseye main non-free contrib
deb-src http://192.168.31.217:8082/repository/debian-bullseye/ bullseye main non-free contrib

# Nexus 代理的安全更新
deb http://192.168.31.217:8082/repository/debian-security/ bullseye-security main
deb-src http://192.168.31.217:8082/repository/debian-security/ bullseye-security main

# Nexus 代理的更新仓库
deb http://192.168.31.217:8082/repository/debian-bullseye/ bullseye-updates main non-free contrib
deb-src http://192.168.31.217:8082/repository/debian-bullseye/ bullseye-updates main non-free contrib

# Nexus 代理的 backports
deb http://192.168.31.217:8082/repository/debian-bullseye/ bullseye-backports main non-free contrib
deb-src http://192.168.31.217:8082/repository/debian-bullseye/ bullseye-backports main non-free contrib
EOF
    
    print_success "✓ APT主仓库配置完成"
    
    # 配置Docker APT源
    print_info "配置Docker APT源..."
    if [ -f /etc/apt/sources.list.d/docker.list ]; then
        cat > /etc/apt/sources.list.d/docker.list << 'EOF'
# Nexus 代理的 Docker CE 仓库
deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] http://192.168.31.217:8082/repository/docker-apt/ bullseye stable
EOF
        print_success "✓ Docker APT源配置完成"
    fi
    
    # 测试APT配置
    print_info "测试APT配置..."
    if apt update 2>/dev/null; then
        print_success "✓ APT更新成功"
    else
        print_warning "✗ APT更新失败，可能需要等待仓库同步"
    fi
}

# 配置Docker
configure_docker() {
    print_header "配置Docker"
    
    if ! command -v docker >/dev/null 2>&1; then
        print_warning "Docker未安装，跳过配置"
        return 0
    fi
    
    print_info "配置Docker镜像仓库..."
    
    # 创建Docker配置
    mkdir -p /etc/docker
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
  }
}
EOF
    
    print_success "✓ Docker配置文件已更新"
    
    # 重启Docker服务
    print_info "重启Docker服务..."
    if systemctl restart docker 2>/dev/null; then
        print_success "✓ Docker服务重启成功"
        
        # 测试Docker配置
        print_info "测试Docker配置..."
        if docker info | grep -q "192.168.31.217"; then
            print_success "✓ Docker镜像仓库配置生效"
        else
            print_warning "✗ Docker镜像仓库配置可能未生效"
        fi
    else
        print_error "✗ Docker服务重启失败"
    fi
}

# 配置Python pip
configure_pip() {
    print_header "配置Python pip"
    
    if ! command -v pip >/dev/null 2>&1 && ! command -v pip3 >/dev/null 2>&1; then
        print_warning "pip未安装，跳过配置"
        return 0
    fi
    
    print_info "配置pip软件源..."
    
    # 创建pip配置目录
    mkdir -p ~/.pip ~/.config/pip
    
    # 配置pip
    cat > ~/.pip/pip.conf << 'EOF'
[global]
index-url = http://192.168.31.217:8082/repository/pypi-proxy/simple/
trusted-host = 192.168.31.217
timeout = 60

[install]
trusted-host = 192.168.31.217
EOF
    
    # 复制到新格式位置
    cp ~/.pip/pip.conf ~/.config/pip/pip.conf
    
    print_success "✓ pip配置完成"
    
    # 测试pip配置
    print_info "测试pip配置..."
    if pip config list 2>/dev/null | grep -q "192.168.31.217"; then
        print_success "✓ pip配置生效"
    elif pip3 config list 2>/dev/null | grep -q "192.168.31.217"; then
        print_success "✓ pip3配置生效"
    else
        print_warning "✗ pip配置可能未生效"
    fi
}

# 配置Maven
configure_maven() {
    print_header "配置Maven"
    
    if ! command -v mvn >/dev/null 2>&1; then
        print_info "Maven未安装，创建配置以备将来使用"
    fi
    
    print_info "配置Maven仓库..."
    
    # 创建Maven配置目录
    mkdir -p ~/.m2
    
    # 配置Maven
    cat > ~/.m2/settings.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 
          http://maven.apache.org/xsd/settings-1.0.0.xsd">
    
    <mirrors>
        <mirror>
            <id>nexus-central</id>
            <mirrorOf>central</mirrorOf>
            <name>Nexus Central Repository</name>
            <url>http://192.168.31.217:8082/repository/maven-central/</url>
        </mirror>
        <mirror>
            <id>nexus-public</id>
            <mirrorOf>*</mirrorOf>
            <name>Nexus Public Repository</name>
            <url>http://192.168.31.217:8082/repository/maven-public/</url>
        </mirror>
    </mirrors>
    
    <profiles>
        <profile>
            <id>nexus</id>
            <repositories>
                <repository>
                    <id>central</id>
                    <url>http://192.168.31.217:8082/repository/maven-central/</url>
                    <releases><enabled>true</enabled></releases>
                    <snapshots><enabled>true</enabled></snapshots>
                </repository>
            </repositories>
            <pluginRepositories>
                <pluginRepository>
                    <id>central</id>
                    <url>http://192.168.31.217:8082/repository/maven-central/</url>
                    <releases><enabled>true</enabled></releases>
                    <snapshots><enabled>true</enabled></snapshots>
                </pluginRepository>
            </pluginRepositories>
        </profile>
    </profiles>
    
    <activeProfiles>
        <activeProfile>nexus</activeProfile>
    </activeProfiles>
</settings>
EOF
    
    print_success "✓ Maven配置完成"
    
    # 测试Maven配置
    if command -v mvn >/dev/null 2>&1; then
        print_info "测试Maven配置..."
        if mvn help:effective-settings 2>/dev/null | grep -q "192.168.31.217"; then
            print_success "✓ Maven配置生效"
        else
            print_warning "✗ Maven配置可能未生效"
        fi
    fi
}

# 配置NPM
configure_npm() {
    print_header "配置NPM"
    
    if ! command -v npm >/dev/null 2>&1; then
        print_warning "NPM未安装，跳过配置"
        return 0
    fi
    
    print_info "配置NPM仓库..."
    
    # 配置NPM registry
    npm config set registry http://192.168.31.217:8082/repository/npm-proxy/
    npm config set strict-ssl false
    
    print_success "✓ NPM配置完成"
    
    # 测试NPM配置
    print_info "测试NPM配置..."
    if npm config get registry | grep -q "192.168.31.217"; then
        print_success "✓ NPM配置生效"
    else
        print_warning "✗ NPM配置可能未生效"
    fi
}

# 验证所有配置
verify_configurations() {
    print_header "验证配置"
    
    echo "=== 配置验证报告 ==="
    echo "时间: $(date)"
    echo ""
    
    # 验证APT
    echo "1. APT配置:"
    if grep -q "192.168.31.217" /etc/apt/sources.list 2>/dev/null; then
        echo "   ✓ 主仓库已配置"
    else
        echo "   ✗ 主仓库未配置"
    fi
    
    if [ -f /etc/apt/sources.list.d/docker.list ] && grep -q "192.168.31.217" /etc/apt/sources.list.d/docker.list 2>/dev/null; then
        echo "   ✓ Docker APT源已配置"
    else
        echo "   ✗ Docker APT源未配置"
    fi
    
    # 验证Docker
    echo ""
    echo "2. Docker配置:"
    if [ -f /etc/docker/daemon.json ] && grep -q "192.168.31.217" /etc/docker/daemon.json 2>/dev/null; then
        echo "   ✓ Docker镜像仓库已配置"
    else
        echo "   ✗ Docker镜像仓库未配置"
    fi
    
    # 验证pip
    echo ""
    echo "3. Python pip配置:"
    if [ -f ~/.pip/pip.conf ] && grep -q "192.168.31.217" ~/.pip/pip.conf 2>/dev/null; then
        echo "   ✓ pip配置已设置"
    else
        echo "   ✗ pip配置未设置"
    fi
    
    # 验证Maven
    echo ""
    echo "4. Maven配置:"
    if [ -f ~/.m2/settings.xml ] && grep -q "192.168.31.217" ~/.m2/settings.xml 2>/dev/null; then
        echo "   ✓ Maven配置已设置"
    else
        echo "   ✗ Maven配置未设置"
    fi
    
    # 验证NPM
    echo ""
    echo "5. NPM配置:"
    if command -v npm >/dev/null 2>&1 && npm config get registry 2>/dev/null | grep -q "192.168.31.217"; then
        echo "   ✓ NPM配置已设置"
    else
        echo "   ✗ NPM配置未设置"
    fi
    
    echo ""
    echo "=== 网络连接测试 ==="
    
    # 测试Nexus连接
    if curl -s -f "${NEXUS_BASE_URL}/service/rest/v1/status" >/dev/null 2>&1; then
        echo "✓ Nexus服务器连接正常"
    else
        echo "✗ Nexus服务器连接失败"
    fi
    
    echo ""
    echo "验证完成！"
}

# 生成使用指南
generate_usage_guide() {
    print_header "生成使用指南"
    
    cat > /root/nexus_usage_guide.md << 'EOF'
# Nexus 使用指南

## 配置完成后的使用方法

### APT 包管理
```bash
# 更新包列表
sudo apt update

# 安装软件包
sudo apt install package-name

# 搜索软件包
apt search keyword
```

### Docker 使用
```bash
# 拉取镜像（将通过Nexus代理）
docker pull nginx

# 查看配置的镜像仓库
docker info | grep -A5 "Registry Mirrors"
```

### Python pip 使用
```bash
# 安装Python包（将通过Nexus代理）
pip install requests

# 查看配置
pip config list

# 指定信任主机安装
pip install --trusted-host 192.168.31.217 package-name
```

### Maven 使用
```bash
# 编译项目（将通过Nexus下载依赖）
mvn clean compile

# 查看有效设置
mvn help:effective-settings
```

### NPM 使用
```bash
# 安装包（将通过Nexus代理）
npm install express

# 查看配置
npm config list

# 查看当前registry
npm config get registry
```

## 故障排除

### 1. 连接问题
如果遇到连接问题，检查：
- Nexus服务器是否运行：http://192.168.31.217:8082
- 网络连接是否正常
- 防火墙是否允许8082端口

### 2. 认证问题
如果遇到认证问题：
- 检查Nexus用户权限
- 确认仓库是否允许匿名访问

### 3. 缓存问题
清理本地缓存：
```bash
# APT缓存
sudo apt clean

# Docker缓存
docker system prune

# pip缓存
pip cache purge

# Maven缓存
rm -rf ~/.m2/repository

# NPM缓存
npm cache clean --force
```

### 4. 恢复原始配置
如果需要恢复原始配置：
```bash
# 查看备份目录
echo $NEXUS_BACKUP_DIR

# 恢复APT配置
sudo cp $NEXUS_BACKUP_DIR/sources.list /etc/apt/sources.list

# 恢复Docker配置
sudo cp $NEXUS_BACKUP_DIR/daemon.json /etc/docker/daemon.json
sudo systemctl restart docker

# 恢复pip配置
cp $NEXUS_BACKUP_DIR/.pip/pip.conf ~/.pip/pip.conf
```

## 监控和维护

### 检查Nexus状态
```bash
curl -s http://192.168.31.217:8082/service/rest/v1/status
```

### 查看仓库使用情况
访问Nexus Web界面：http://192.168.31.217:8082
用户名：admin
密码：march23$

### 定期维护
- 定期清理Nexus缓存
- 监控磁盘使用情况
- 更新Nexus版本

## 联系信息
如有问题，请检查：
1. 本指南的故障排除部分
2. Nexus官方文档
3. 系统日志文件
EOF
    
    print_success "使用指南已生成: /root/nexus_usage_guide.md"
}

# 主函数
main() {
    echo "Debian 11 Nexus 配置脚本"
    echo "Nexus服务器: ${NEXUS_BASE_URL}"
    echo ""
    
    # 检查权限
    if [ "$EUID" -ne 0 ]; then
        print_error "请使用root权限运行此脚本"
        exit 1
    fi
    
    # 检查网络连接
    if ! curl -s -f "${NEXUS_BASE_URL}/service/rest/v1/status" >/dev/null 2>&1; then
        print_error "无法连接到Nexus服务器: ${NEXUS_BASE_URL}"
        print_info "请确保："
        print_info "1. Nexus服务器正在运行"
        print_info "2. 网络连接正常"
        print_info "3. 防火墙设置正确"
        exit 1
    fi
    
    print_success "✓ Nexus服务器连接正常"
    
    # 执行配置
    backup_configs
    configure_apt
    configure_docker
    configure_pip
    configure_maven
    configure_npm
    verify_configurations
    generate_usage_guide
    
    print_header "配置完成"
    print_success "✅ 所有软件源已配置为使用Nexus代理"
    print_info "📖 使用指南：/root/nexus_usage_guide.md"
    print_info "💾 配置备份：$NEXUS_BACKUP_DIR"
    print_info "🔧 如有问题，请查看使用指南的故障排除部分"
}

# 处理命令行参数
case "${1:-}" in
    "backup")
        backup_configs
        ;;
    "apt")
        configure_apt
        ;;
    "docker")
        configure_docker
        ;;
    "python")
        configure_pip
        ;;
    "java")
        configure_maven
        ;;
    "nodejs")
        configure_npm
        ;;
    "verify")
        verify_configurations
        ;;
    *)
        main
        ;;
esac