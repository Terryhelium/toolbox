#!/bin/bash

# Nexus 仓库管理脚本
# 功能：检查Nexus状态、查看仓库、创建代理仓库、测试可用性

set -e

# Nexus 配置
NEXUS_HOST="192.168.31.217"
NEXUS_PORT="8082"
NEXUS_USERNAME="admin"
NEXUS_PASSWORD="march23$"
NEXUS_BASE_URL="http://${NEXUS_HOST}:${NEXUS_PORT}"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

# 检查Nexus连接
check_nexus_connection() {
    print_header "检查Nexus服务器连接"
    
    print_info "连接到: $NEXUS_BASE_URL"
    
    # 检查服务器状态
    if curl -s -f "${NEXUS_BASE_URL}/service/rest/v1/status" >/dev/null 2>&1; then
        print_success "✓ Nexus服务器连接成功"
        
        # 获取系统状态
        local status=$(curl -s -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
            "${NEXUS_BASE_URL}/service/rest/v1/status" | jq -r '.state // "unknown"' 2>/dev/null || echo "unknown")
        print_info "服务器状态: $status"
        
        return 0
    else
        print_error "✗ 无法连接到Nexus服务器"
        print_info "请检查："
        print_info "1. 服务器地址: $NEXUS_BASE_URL"
        print_info "2. 网络连接"
        print_info "3. 防火墙设置"
        return 1
    fi
}

# 获取现有仓库列表
get_repositories() {
    print_header "获取现有仓库列表"
    
    local repos=$(curl -s -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
        "${NEXUS_BASE_URL}/service/rest/v1/repositories" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$repos" ]; then
        echo "$repos" | jq -r '.[] | "\(.name) (\(.format)/\(.type)) - \(.url // "N/A")"' 2>/dev/null || {
            print_warning "无法解析仓库信息，显示原始数据："
            echo "$repos" | head -20
        }
        
        # 保存到文件
        echo "$repos" > /tmp/nexus_repos.json
        print_info "仓库信息已保存到: /tmp/nexus_repos.json"
        
        return 0
    else
        print_error "无法获取仓库列表"
        return 1
    fi
}

# 检查特定仓库是否存在
check_repository_exists() {
    local repo_name="$1"
    
    curl -s -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
        "${NEXUS_BASE_URL}/service/rest/v1/repositories/${repo_name}" >/dev/null 2>&1
    return $?
}

# 创建APT代理仓库
create_apt_proxy() {
    local repo_name="$1"
    local remote_url="$2"
    local distribution="$3"
    
    print_info "创建APT代理仓库: $repo_name"
    
    local payload=$(cat <<EOF
{
  "name": "$repo_name",
  "online": true,
  "storage": {
    "blobStoreName": "default",
    "strictContentTypeValidation": true
  },
  "proxy": {
    "remoteUrl": "$remote_url",
    "contentMaxAge": 1440,
    "metadataMaxAge": 1440
  },
  "negativeCache": {
    "enabled": true,
    "timeToLive": 1440
  },
  "httpClient": {
    "blocked": false,
    "autoBlock": true
  },
  "apt": {
    "distribution": "$distribution",
    "flat": false
  }
}
EOF
)
    
    local response=$(curl -s -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
        -H "Content-Type: application/json" \
        -X POST \
        -d "$payload" \
        "${NEXUS_BASE_URL}/service/rest/v1/repositories/apt/proxy")
    
    if [ $? -eq 0 ]; then
        print_success "✓ APT代理仓库 '$repo_name' 创建成功"
        return 0
    else
        print_error "✗ APT代理仓库 '$repo_name' 创建失败"
        echo "Response: $response"
        return 1
    fi
}

# 创建Docker代理仓库
create_docker_proxy() {
    local repo_name="$1"
    local remote_url="$2"
    local http_port="$3"
    
    print_info "创建Docker代理仓库: $repo_name"
    
    local payload=$(cat <<EOF
{
  "name": "$repo_name",
  "online": true,
  "storage": {
    "blobStoreName": "default",
    "strictContentTypeValidation": true
  },
  "proxy": {
    "remoteUrl": "$remote_url",
    "contentMaxAge": 1440,
    "metadataMaxAge": 1440
  },
  "negativeCache": {
    "enabled": true,
    "timeToLive": 1440
  },
  "httpClient": {
    "blocked": false,
    "autoBlock": true
  },
  "docker": {
    "v1Enabled": false,
    "forceBasicAuth": false,
    "httpPort": $http_port,
    "httpsPort": null
  },
  "dockerProxy": {
    "indexType": "HUB",
    "useTrustStoreForIndexAccess": false
  }
}
EOF
)
    
    local response=$(curl -s -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
        -H "Content-Type: application/json" \
        -X POST \
        -d "$payload" \
        "${NEXUS_BASE_URL}/service/rest/v1/repositories/docker/proxy")
    
    if [ $? -eq 0 ]; then
        print_success "✓ Docker代理仓库 '$repo_name' 创建成功"
        return 0
    else
        print_error "✗ Docker代理仓库 '$repo_name' 创建失败"
        echo "Response: $response"
        return 1
    fi
}

# 创建PyPI代理仓库
create_pypi_proxy() {
    local repo_name="$1"
    local remote_url="$2"
    
    print_info "创建PyPI代理仓库: $repo_name"
    
    local payload=$(cat <<EOF
{
  "name": "$repo_name",
  "online": true,
  "storage": {
    "blobStoreName": "default",
    "strictContentTypeValidation": true
  },
  "proxy": {
    "remoteUrl": "$remote_url",
    "contentMaxAge": 1440,
    "metadataMaxAge": 1440
  },
  "negativeCache": {
    "enabled": true,
    "timeToLive": 1440
  },
  "httpClient": {
    "blocked": false,
    "autoBlock": true
  }
}
EOF
)
    
    local response=$(curl -s -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
        -H "Content-Type: application/json" \
        -X POST \
        -d "$payload" \
        "${NEXUS_BASE_URL}/service/rest/v1/repositories/pypi/proxy")
    
    if [ $? -eq 0 ]; then
        print_success "✓ PyPI代理仓库 '$repo_name' 创建成功"
        return 0
    else
        print_error "✗ PyPI代理仓库 '$repo_name' 创建失败"
        echo "Response: $response"
        return 1
    fi
}

# 创建Maven代理仓库
create_maven_proxy() {
    local repo_name="$1"
    local remote_url="$2"
    
    print_info "创建Maven代理仓库: $repo_name"
    
    local payload=$(cat <<EOF
{
  "name": "$repo_name",
  "online": true,
  "storage": {
    "blobStoreName": "default",
    "strictContentTypeValidation": true
  },
  "proxy": {
    "remoteUrl": "$remote_url",
    "contentMaxAge": 1440,
    "metadataMaxAge": 1440
  },
  "negativeCache": {
    "enabled": true,
    "timeToLive": 1440
  },
  "httpClient": {
    "blocked": false,
    "autoBlock": true
  },
  "maven": {
    "versionPolicy": "MIXED",
    "layoutPolicy": "STRICT"
  }
}
EOF
)
    
    local response=$(curl -s -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
        -H "Content-Type: application/json" \
        -X POST \
        -d "$payload" \
        "${NEXUS_BASE_URL}/service/rest/v1/repositories/maven/proxy")
    
    if [ $? -eq 0 ]; then
        print_success "✓ Maven代理仓库 '$repo_name' 创建成功"
        return 0
    else
        print_error "✗ Maven代理仓库 '$repo_name' 创建失败"
        echo "Response: $response"
        return 1
    fi
}

# 创建NPM代理仓库
create_npm_proxy() {
    local repo_name="$1"
    local remote_url="$2"
    
    print_info "创建NPM代理仓库: $repo_name"
    
    local payload=$(cat <<EOF
{
  "name": "$repo_name",
  "online": true,
  "storage": {
    "blobStoreName": "default",
    "strictContentTypeValidation": true
  },
  "proxy": {
    "remoteUrl": "$remote_url",
    "contentMaxAge": 1440,
    "metadataMaxAge": 1440
  },
  "negativeCache": {
    "enabled": true,
    "timeToLive": 1440
  },
  "httpClient": {
    "blocked": false,
    "autoBlock": true
  }
}
EOF
)
    
    local response=$(curl -s -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
        -H "Content-Type: application/json" \
        -X POST \
        -d "$payload" \
        "${NEXUS_BASE_URL}/service/rest/v1/repositories/npm/proxy")
    
    if [ $? -eq 0 ]; then
        print_success "✓ NPM代理仓库 '$repo_name' 创建成功"
        return 0
    else
        print_error "✗ NPM代理仓库 '$repo_name' 创建失败"
        echo "Response: $response"
        return 1
    fi
}

# 根据系统检测结果创建所需仓库
create_required_repositories() {
    print_header "根据系统检测创建所需仓库"
    
    # 基于检测结果创建仓库
    print_info "基于系统检测结果创建代理仓库..."
    
    # 1. Debian APT仓库
    print_info "检查并创建Debian相关仓库..."
    
    if ! check_repository_exists "debian-bullseye"; then
        create_apt_proxy "debian-bullseye" "http://mirrors.ustc.edu.cn/debian/" "bullseye"
    else
        print_info "仓库 'debian-bullseye' 已存在"
    fi
    
    if ! check_repository_exists "debian-security"; then
        create_apt_proxy "debian-security" "http://mirrors.ustc.edu.cn/debian-security/" "bullseye-security"
    else
        print_info "仓库 'debian-security' 已存在"
    fi
    
    # 2. Docker仓库
    print_info "检查并创建Docker仓库..."
    
    if ! check_repository_exists "docker-hub"; then
        create_docker_proxy "docker-hub" "https://registry-1.docker.io" "8083"
    else
        print_info "仓库 'docker-hub' 已存在"
    fi
    
    if ! check_repository_exists "docker-aliyun"; then
        create_docker_proxy "docker-aliyun" "http://mirrors.aliyun.com/docker-ce/" "8084"
    else
        print_info "仓库 'docker-aliyun' 已存在"
    fi
    
    # 3. Python PyPI仓库
    print_info "检查并创建Python仓库..."
    
    if ! check_repository_exists "pypi-proxy"; then
        create_pypi_proxy "pypi-proxy" "https://pypi.org/"
    else
        print_info "仓库 'pypi-proxy' 已存在"
    fi
    
    if ! check_repository_exists "pypi-tsinghua"; then
        create_pypi_proxy "pypi-tsinghua" "https://pypi.tuna.tsinghua.edu.cn/simple/"
    else
        print_info "仓库 'pypi-tsinghua' 已存在"
    fi
    
    # 4. Maven仓库
    print_info "检查并创建Maven仓库..."
    
    if ! check_repository_exists "maven-central"; then
        create_maven_proxy "maven-central" "https://repo1.maven.org/maven2/"
    else
        print_info "仓库 'maven-central' 已存在"
    fi
    
    if ! check_repository_exists "maven-aliyun"; then
        create_maven_proxy "maven-aliyun" "https://maven.aliyun.com/repository/public/"
    else
        print_info "仓库 'maven-aliyun' 已存在"
    fi
    
    # 5. NPM仓库
    print_info "检查并创建NPM仓库..."
    
    if ! check_repository_exists "npm-proxy"; then
        create_npm_proxy "npm-proxy" "https://registry.npmjs.org/"
    else
        print_info "仓库 'npm-proxy' 已存在"
    fi
    
    if ! check_repository_exists "npm-taobao"; then
        create_npm_proxy "npm-taobao" "https://registry.npmmirror.com/"
    else
        print_info "仓库 'npm-taobao' 已存在"
    fi
}

# 测试仓库可用性
test_repository_availability() {
    print_header "测试仓库可用性"
    
    # 测试APT仓库
    print_info "测试APT仓库..."
    local apt_url="${NEXUS_BASE_URL}/repository/debian-bullseye/dists/bullseye/Release"
    if curl -s -f "$apt_url" >/dev/null 2>&1; then
        print_success "✓ APT仓库可用"
    else
        print_warning "✗ APT仓库不可用或未就绪"
    fi
    
    # 测试Docker仓库
    print_info "测试Docker仓库..."
    local docker_url="${NEXUS_BASE_URL}/v2/"
    if curl -s -f "$docker_url" >/dev/null 2>&1; then
        print_success "✓ Docker仓库可用"
    else
        print_warning "✗ Docker仓库不可用或未就绪"
    fi
    
    # 测试PyPI仓库
    print_info "测试PyPI仓库..."
    local pypi_url="${NEXUS_BASE_URL}/repository/pypi-proxy/simple/"
    if curl -s -f "$pypi_url" >/dev/null 2>&1; then
        print_success "✓ PyPI仓库可用"
    else
        print_warning "✗ PyPI仓库不可用或未就绪"
    fi
    
    # 测试Maven仓库
    print_info "测试Maven仓库..."
    local maven_url="${NEXUS_BASE_URL}/repository/maven-central/"
    if curl -s -f "$maven_url" >/dev/null 2>&1; then
        print_success "✓ Maven仓库可用"
    else
        print_warning "✗ Maven仓库不可用或未就绪"
    fi
    
    # 测试NPM仓库
    print_info "测试NPM仓库..."
    local npm_url="${NEXUS_BASE_URL}/repository/npm-proxy/"
    if curl -s -f "$npm_url" >/dev/null 2>&1; then
        print_success "✓ NPM仓库可用"
    else
        print_warning "✗ NPM仓库不可用或未就绪"
    fi
}

# 生成配置建议
generate_configuration_guide() {
    print_header "生成配置建议"
    
    cat << EOF > nexus_config_guide.md
# Nexus 配置指南

基于您的系统检测结果，以下是配置建议：

## 系统配置

### APT 配置 (Debian 11)
\`\`\`bash
# 备份原有配置
sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup

# 修改 /etc/apt/sources.list
sudo tee /etc/apt/sources.list << 'APT_EOF'
deb ${NEXUS_BASE_URL}/repository/debian-bullseye/ bullseye main non-free contrib
deb-src ${NEXUS_BASE_URL}/repository/debian-bullseye/ bullseye main non-free contrib
deb ${NEXUS_BASE_URL}/repository/debian-security/ bullseye-security main
deb-src ${NEXUS_BASE_URL}/repository/debian-security/ bullseye-security main
deb ${NEXUS_BASE_URL}/repository/debian-bullseye/ bullseye-updates main non-free contrib
deb-src ${NEXUS_BASE_URL}/repository/debian-bullseye/ bullseye-updates main non-free contrib
deb ${NEXUS_BASE_URL}/repository/debian-bullseye/ bullseye-backports main non-free contrib
deb-src ${NEXUS_BASE_URL}/repository/debian-bullseye/ bullseye-backports main non-free contrib
APT_EOF

# 更新包列表
sudo apt update
\`\`\`

### Docker 配置
\`\`\`bash
# 修改 /etc/docker/daemon.json
sudo tee /etc/docker/daemon.json << 'DOCKER_EOF'
{
  "registry-mirrors": [
    "${NEXUS_BASE_URL}/repository/docker-hub/"
  ],
  "insecure-registries": [
    "${NEXUS_HOST}:${NEXUS_PORT}"
  ]
}
DOCKER_EOF

# 重启Docker服务
sudo systemctl restart docker
\`\`\`

### Python pip 配置
\`\`\`bash
# 创建配置目录
mkdir -p ~/.pip ~/.config/pip

# 配置pip
tee ~/.pip/pip.conf << 'PIP_EOF'
[global]
index-url = ${NEXUS_BASE_URL}/repository/pypi-proxy/simple/
trusted-host = ${NEXUS_HOST}
PIP_EOF

# 复制到新格式位置
cp ~/.pip/pip.conf ~/.config/pip/pip.conf
\`\`\`

### Maven 配置
\`\`\`bash
# 创建Maven配置目录
mkdir -p ~/.m2

# 配置Maven
tee ~/.m2/settings.xml << 'MAVEN_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<settings>
    <mirrors>
        <mirror>
            <id>nexus</id>
            <mirrorOf>*</mirrorOf>
            <name>Nexus Repository</name>
            <url>${NEXUS_BASE_URL}/repository/maven-central/</url>
        </mirror>
    </mirrors>
</settings>
MAVEN_EOF
\`\`\`

### NPM 配置
\`\`\`bash
# 配置NPM registry
npm config set registry ${NEXUS_BASE_URL}/repository/npm-proxy/
\`\`\`

## 验证配置

### 验证APT
\`\`\`bash
sudo apt update
apt policy
\`\`\`

### 验证Docker
\`\`\`bash
docker info | grep -A5 "Registry Mirrors"
\`\`\`

### 验证pip
\`\`\`bash
pip config list
pip install --dry-run requests
\`\`\`

### 验证Maven
\`\`\`bash
mvn help:effective-settings
\`\`\`

### 验证NPM
\`\`\`bash
npm config get registry
npm info express
\`\`\`

## 故障排除

1. **连接问题**：确保防火墙允许访问端口 ${NEXUS_PORT}
2. **认证问题**：检查Nexus用户权限
3. **代理问题**：确保代理仓库配置正确
4. **缓存问题**：清理本地缓存后重试

## 仓库地址汇总

- APT: ${NEXUS_BASE_URL}/repository/debian-bullseye/
- Docker: ${NEXUS_BASE_URL}/repository/docker-hub/
- PyPI: ${NEXUS_BASE_URL}/repository/pypi-proxy/simple/
- Maven: ${NEXUS_BASE_URL}/repository/maven-central/
- NPM: ${NEXUS_BASE_URL}/repository/npm-proxy/

EOF
    
    print_success "配置指南已生成: nexus_config_guide.md"
}

# 主函数
main() {
    echo "Nexus 仓库管理脚本"
    echo "服务器: $NEXUS_BASE_URL"
    echo "用户: $NEXUS_USERNAME"
    echo ""
    
    # 检查依赖
    if ! command -v curl >/dev/null 2>&1; then
        print_error "需要安装 curl"
        exit 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        print_warning "建议安装 jq 以获得更好的JSON解析体验"
    fi
    
    # 执行主要功能
    check_nexus_connection || exit 1
    get_repositories
    create_required_repositories
    
    # 等待仓库初始化
    print_info "等待仓库初始化..."
    sleep 5
    
    test_repository_availability
    generate_configuration_guide
    
    print_header "脚本执行完成"
    print_success "✓ Nexus仓库检查和创建完成"
    print_info "📖 配置指南已生成: nexus_config_guide.md"
    print_info "🔧 请根据指南配置您的系统"
}

# 处理命令行参数
case "${1:-}" in
    "check")
        check_nexus_connection
        get_repositories
        ;;
    "create")
        create_required_repositories
        ;;
    "test")
        test_repository_availability
        ;;
    "guide")
        generate_configuration_guide
        ;;
    *)
        main
        ;;
esac