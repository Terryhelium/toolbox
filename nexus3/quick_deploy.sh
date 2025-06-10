#!/bin/bash

# 快速部署脚本 - 一键设置Nexus软件源迁移环境
# 使用方法: ./quick_deploy.sh [nexus_host] [nexus_port]

set -e

# 默认配置
DEFAULT_NEXUS_HOST="localhost"
DEFAULT_NEXUS_PORT="8081"
NEXUS_HOST="${1:-$DEFAULT_NEXUS_HOST}"
NEXUS_PORT="${2:-$DEFAULT_NEXUS_PORT}"

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

# 检查依赖
check_dependencies() {
    print_header "检查系统依赖"
    
    local deps=("curl" "wget" "git")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "缺少依赖: ${missing_deps[*]}"
        print_info "请安装缺少的依赖后重新运行"
        
        # 检测包管理器并提供安装建议
        if command -v apt >/dev/null 2>&1; then
            echo "Ubuntu/Debian: sudo apt update && sudo apt install ${missing_deps[*]}"
        elif command -v yum >/dev/null 2>&1; then
            echo "CentOS/RHEL: sudo yum install ${missing_deps[*]}"
        elif command -v dnf >/dev/null 2>&1; then
            echo "Fedora: sudo dnf install ${missing_deps[*]}"
        fi
        exit 1
    fi
    
    print_info "所有依赖已满足"
}

# 创建工作目录
setup_workspace() {
    print_header "设置工作环境"
    
    local workspace="$HOME/nexus-migration"
    
    if [ -d "$workspace" ]; then
        print_warning "工作目录已存在: $workspace"
        read -p "是否要覆盖现有配置? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "取消部署"
            exit 0
        fi
        rm -rf "$workspace"
    fi
    
    mkdir -p "$workspace"
    cd "$workspace"
    
    print_info "工作目录创建完成: $workspace"
    echo "export NEXUS_WORKSPACE=$workspace" >> ~/.bashrc
}

# 下载脚本文件（模拟从您的系统获取）
download_scripts() {
    print_header "准备脚本文件"
    
    # 这里我们直接创建脚本，实际使用时可以从git仓库下载
    print_info "创建检测脚本..."
    
    # 创建简化版的检测脚本
    cat << 'EOF' > check_repos.sh
#!/bin/bash
# 软件源检测脚本 (简化版)

echo "=== Linux 软件源检测报告 ==="
echo "检测时间: $(date)"
echo "系统信息: $(uname -a)"

if [ -f /etc/os-release ]; then
    echo "发行版信息:"
    cat /etc/os-release | head -5
fi

echo -e "\n=== 系统包管理器 ==="
if command -v apt >/dev/null 2>&1; then
    echo "APT源配置:"
    grep -v "^#" /etc/apt/sources.list 2>/dev/null | head -5
fi

if command -v yum >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then
    echo "YUM/DNF源配置:"
    ls /etc/yum.repos.d/*.repo 2>/dev/null | head -3
fi

echo -e "\n=== Docker配置 ==="
if [ -f /etc/docker/daemon.json ]; then
    echo "Docker daemon配置存在"
else
    echo "Docker daemon配置不存在"
fi

echo -e "\n=== Python配置 ==="
if [ -f ~/.pip/pip.conf ]; then
    echo "pip配置存在"
elif [ -f ~/.config/pip/pip.conf ]; then
    echo "pip配置存在 (新格式)"
else
    echo "pip配置不存在"
fi

echo -e "\n=== Java配置 ==="
if [ -f ~/.m2/settings.xml ]; then
    echo "Maven配置存在"
else
    echo "Maven配置不存在"
fi

echo -e "\n=== Node.js配置 ==="
if command -v npm >/dev/null 2>&1; then
    echo "NPM registry: $(npm config get registry 2>/dev/null || echo '未配置')"
fi

echo -e "\n检测完成！"
EOF

    chmod +x check_repos.sh
    print_info "检测脚本创建完成"
    
    # 创建配置脚本模板
    print_info "创建配置脚本模板..."
    
    cat << EOF > configure_nexus.sh
#!/bin/bash

# Nexus 软件源配置脚本
NEXUS_HOST="$NEXUS_HOST"
NEXUS_PORT="$NEXUS_PORT"
NEXUS_USERNAME="admin"
NEXUS_PASSWORD="admin123"

# 基本配置函数
configure_apt() {
    if command -v apt >/dev/null 2>&1; then
        echo "配置APT源..."
        sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup.\$(date +%Y%m%d) 2>/dev/null || true
        echo "APT源备份完成"
    fi
}

configure_docker() {
    if command -v docker >/dev/null 2>&1; then
        echo "配置Docker源..."
        sudo mkdir -p /etc/docker
        sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup.\$(date +%Y%m%d) 2>/dev/null || true
        
        cat << DOCKER_EOF | sudo tee /etc/docker/daemon.json
{
    "registry-mirrors": [
        "http://\${NEXUS_HOST}:\${NEXUS_PORT}/repository/docker-proxy/"
    ],
    "insecure-registries": [
        "\${NEXUS_HOST}:\${NEXUS_PORT}"
    ]
}
DOCKER_EOF
        echo "Docker配置完成"
    fi
}

configure_pip() {
    echo "配置Python pip源..."
    mkdir -p ~/.pip ~/.config/pip
    
    cat << PIP_EOF > ~/.pip/pip.conf
[global]
index-url = http://\${NEXUS_HOST}:\${NEXUS_PORT}/repository/pypi-proxy/simple/
trusted-host = \${NEXUS_HOST}
PIP_EOF
    
    cp ~/.pip/pip.conf ~/.config/pip/pip.conf
    echo "pip配置完成"
}

configure_maven() {
    echo "配置Maven源..."
    mkdir -p ~/.m2
    cp ~/.m2/settings.xml ~/.m2/settings.xml.backup.\$(date +%Y%m%d) 2>/dev/null || true
    
    cat << MAVEN_EOF > ~/.m2/settings.xml
<?xml version="1.0" encoding="UTF-8"?>
<settings>
    <mirrors>
        <mirror>
            <id>nexus</id>
            <mirrorOf>*</mirrorOf>
            <name>Nexus Repository</name>
            <url>http://\${NEXUS_HOST}:\${NEXUS_PORT}/repository/maven-public/</url>
        </mirror>
    </mirrors>
</settings>
MAVEN_EOF
    echo "Maven配置完成"
}

configure_npm() {
    if command -v npm >/dev/null 2>&1; then
        echo "配置NPM源..."
        npm config set registry http://\${NEXUS_HOST}:\${NEXUS_PORT}/repository/npm-proxy/
        echo "NPM配置完成"
    fi
}

# 主配置函数
main() {
    echo "开始配置Nexus软件源..."
    echo "Nexus服务器: \${NEXUS_HOST}:\${NEXUS_PORT}"
    
    configure_docker
    configure_pip
    configure_maven
    configure_npm
    
    echo "配置完成！"
}

case "\${1:-all}" in
    "docker") configure_docker ;;
    "python") configure_pip ;;
    "java") configure_maven ;;
    "nodejs") configure_npm ;;
    *) main ;;
esac
EOF

    chmod +x configure_nexus.sh
    print_info "配置脚本创建完成"
}

# 创建配置文件
create_config() {
    print_header "创建配置文件"
    
    cat << EOF > nexus.conf
# Nexus服务器配置
NEXUS_HOST=$NEXUS_HOST
NEXUS_PORT=$NEXUS_PORT
NEXUS_USERNAME=admin
NEXUS_PASSWORD=admin123

# 工作目录
WORKSPACE=$(pwd)

# 创建时间
CREATED=$(date)
EOF
    
    print_info "配置文件创建完成: nexus.conf"
}

# 测试Nexus连接
test_nexus_connection() {
    print_header "测试Nexus连接"
    
    local nexus_url="http://$NEXUS_HOST:$NEXUS_PORT"
    
    print_info "测试连接到: $nexus_url"
    
    if curl -s -f "$nexus_url/service/rest/v1/status" >/dev/null 2>&1; then
        print_info "✓ Nexus服务器连接成功"
        return 0
    else
        print_warning "✗ 无法连接到Nexus服务器"
        print_info "请确保:"
        print_info "1. Nexus服务器正在运行"
        print_info "2. 网络连接正常"
        print_info "3. 防火墙设置正确"
        return 1
    fi
}

# 创建使用指南
create_usage_guide() {
    print_header "创建使用指南"
    
    cat << EOF > USAGE.md
# Nexus软件源迁移使用指南

## 快速开始

1. **检测当前配置**
   \`\`\`bash
   ./check_repos.sh
   \`\`\`

2. **配置所有软件源**
   \`\`\`bash
   ./configure_nexus.sh
   \`\`\`

3. **单独配置特定软件源**
   \`\`\`bash
   ./configure_nexus.sh docker   # 仅配置Docker
   ./configure_nexus.sh python   # 仅配置Python
   ./configure_nexus.sh java     # 仅配置Java
   ./configure_nexus.sh nodejs   # 仅配置Node.js
   \`\`\`

## 配置信息

- Nexus服务器: $NEXUS_HOST:$NEXUS_PORT
- 工作目录: $(pwd)
- 配置文件: nexus.conf

## 验证配置

### Docker
\`\`\`bash
docker info | grep -A5 "Registry Mirrors"
\`\`\`

### Python pip
\`\`\`bash
pip config list
\`\`\`

### Maven
\`\`\`bash
mvn help:effective-settings
\`\`\`

### NPM
\`\`\`bash
npm config get registry
\`\`\`

## 故障排除

如果遇到问题，请检查:
1. Nexus服务器是否正常运行
2. 网络连接是否正常
3. 相应的代理仓库是否已在Nexus中配置

EOF
    
    print_info "使用指南创建完成: USAGE.md"
}

# 显示部署结果
show_summary() {
    print_header "部署完成"
    
    echo "工作目录: $(pwd)"
    echo "可用脚本:"
    echo "  - check_repos.sh     : 检测现有软件源配置"
    echo "  - configure_nexus.sh : 配置软件源到Nexus"
    echo "  - nexus.conf         : Nexus服务器配置"
    echo "  - USAGE.md           : 使用指南"
    echo ""
    echo "Nexus服务器: $NEXUS_HOST:$NEXUS_PORT"
    echo ""
    echo "下一步操作:"
    echo "1. 运行 ./check_repos.sh 检测当前配置"
    echo "2. 根据需要修改 nexus.conf 中的配置"
    echo "3. 运行 ./configure_nexus.sh 开始配置"
    echo ""
    echo "详细使用方法请查看 USAGE.md"
}

# 主函数
main() {
    echo "Nexus软件源迁移 - 快速部署脚本"
    echo "Nexus服务器: $NEXUS_HOST:$NEXUS_PORT"
    echo ""
    
    check_dependencies
    setup_workspace
    download_scripts
    create_config
    test_nexus_connection
    create_usage_guide
    show_summary
    
    print_info "部署完成！请查看上述说明开始使用。"
}

# 显示帮助
show_help() {
    echo "使用方法: $0 [nexus_host] [nexus_port]"
    echo ""
    echo "参数:"
    echo "  nexus_host    Nexus服务器地址 (默认: localhost)"
    echo "  nexus_port    Nexus服务器端口 (默认: 8081)"
    echo ""
    echo "示例:"
    echo "  $0                           # 使用默认配置"
    echo "  $0 nexus.company.com         # 指定服务器地址"
    echo "  $0 nexus.company.com 8080    # 指定服务器和端口"
}

# 处理命令行参数
case "${1:-}" in
    "-h"|"--help")
        show_help
        exit 0
        ;;
    *)
        main
        ;;
esac