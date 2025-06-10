#!/bin/bash

# Nexus 软件源配置脚本
# 用于将各种软件源配置指向本地Nexus服务器

# 配置变量 - 请根据实际情况修改
NEXUS_HOST="your-nexus-server.com"
NEXUS_PORT="8081"
NEXUS_USERNAME="admin"
NEXUS_PASSWORD="your-password"

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

# 检查Nexus连接
check_nexus_connection() {
    print_header "检查Nexus连接"
    
    if curl -s -f "http://${NEXUS_HOST}:${NEXUS_PORT}/service/rest/v1/status" >/dev/null; then
        print_info "Nexus服务器连接正常"
        return 0
    else
        print_warning "无法连接到Nexus服务器，请检查配置"
        return 1
    fi
}

# 配置系统包管理器
configure_system_repos() {
    print_header "配置系统软件包源"
    
    # 检测发行版
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    fi
    
    case $DISTRO in
        "ubuntu"|"debian")
            print_info "配置APT源..."
            # 备份原配置
            sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup.$(date +%Y%m%d)
            
            # 创建新的sources.list
            cat << EOF | sudo tee /etc/apt/sources.list
# Nexus APT Repository
deb http://${NEXUS_HOST}:${NEXUS_PORT}/repository/apt-proxy/ $VERSION_CODENAME main restricted universe multiverse
deb http://${NEXUS_HOST}:${NEXUS_PORT}/repository/apt-proxy/ $VERSION_CODENAME-updates main restricted universe multiverse
deb http://${NEXUS_HOST}:${NEXUS_PORT}/repository/apt-proxy/ $VERSION_CODENAME-security main restricted universe multiverse
EOF
            print_info "APT源配置完成"
            ;;
            
        "centos"|"rhel"|"rocky"|"almalinux")
            print_info "配置YUM源..."
            # 备份并配置YUM源
            sudo mkdir -p /etc/yum.repos.d/backup
            sudo mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup/
            
            cat << EOF | sudo tee /etc/yum.repos.d/nexus.repo
[nexus-base]
name=Nexus Base Repository
baseurl=http://${NEXUS_HOST}:${NEXUS_PORT}/repository/yum-proxy/\$releasever/\$basearch/
enabled=1
gpgcheck=0

[nexus-updates]
name=Nexus Updates Repository
baseurl=http://${NEXUS_HOST}:${NEXUS_PORT}/repository/yum-updates/\$releasever/\$basearch/
enabled=1
gpgcheck=0

[nexus-extras]
name=Nexus Extras Repository
baseurl=http://${NEXUS_HOST}:${NEXUS_PORT}/repository/yum-extras/\$releasever/\$basearch/
enabled=1
gpgcheck=0
EOF
            print_info "YUM源配置完成"
            ;;
            
        "fedora")
            print_info "配置DNF源..."
            sudo mkdir -p /etc/yum.repos.d/backup
            sudo mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup/
            
            cat << EOF | sudo tee /etc/yum.repos.d/nexus.repo
[nexus-fedora]
name=Nexus Fedora Repository
baseurl=http://${NEXUS_HOST}:${NEXUS_PORT}/repository/fedora-proxy/\$releasever/Everything/\$basearch/os/
enabled=1
gpgcheck=0

[nexus-updates]
name=Nexus Fedora Updates
baseurl=http://${NEXUS_HOST}:${NEXUS_PORT}/repository/fedora-updates/\$releasever/Everything/\$basearch/
enabled=1
gpgcheck=0
EOF
            print_info "DNF源配置完成"
            ;;
    esac
}

# 配置Docker
configure_docker() {
    print_header "配置Docker源"
    
    # 创建docker配置目录
    sudo mkdir -p /etc/docker
    
    # 备份原配置
    if [ -f /etc/docker/daemon.json ]; then
        sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup.$(date +%Y%m%d)
    fi
    
    # 配置Docker daemon
    cat << EOF | sudo tee /etc/docker/daemon.json
{
    "registry-mirrors": [
        "http://${NEXUS_HOST}:${NEXUS_PORT}/repository/docker-proxy/"
    ],
    "insecure-registries": [
        "${NEXUS_HOST}:${NEXUS_PORT}"
    ]
}
EOF
    
    print_info "Docker配置完成，需要重启Docker服务"
    sudo systemctl restart docker 2>/dev/null || print_warning "请手动重启Docker服务"
}

# 配置Python pip
configure_python() {
    print_header "配置Python pip源"
    
    # 创建pip配置目录
    mkdir -p ~/.pip
    mkdir -p ~/.config/pip
    
    # 配置pip
    cat << EOF > ~/.pip/pip.conf
[global]
index-url = http://${NEXUS_HOST}:${NEXUS_PORT}/repository/pypi-proxy/simple/
trusted-host = ${NEXUS_HOST}

[install]
trusted-host = ${NEXUS_HOST}
EOF
    
    # 也创建新格式的配置
    cp ~/.pip/pip.conf ~/.config/pip/pip.conf
    
    print_info "pip配置完成"
    
    # 配置conda（如果存在）
    if command -v conda >/dev/null 2>&1; then
        print_info "配置Conda源..."
        conda config --add channels http://${NEXUS_HOST}:${NEXUS_PORT}/repository/conda-proxy/
        conda config --set show_channel_urls yes
    fi
}

# 配置Java Maven
configure_maven() {
    print_header "配置Maven源"
    
    # 创建Maven配置目录
    mkdir -p ~/.m2
    
    # 备份原配置
    if [ -f ~/.m2/settings.xml ]; then
        cp ~/.m2/settings.xml ~/.m2/settings.xml.backup.$(date +%Y%m%d)
    fi
    
    # 配置Maven settings.xml
    cat << EOF > ~/.m2/settings.xml
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 
          http://maven.apache.org/xsd/settings-1.0.0.xsd">
    
    <mirrors>
        <mirror>
            <id>nexus</id>
            <mirrorOf>*</mirrorOf>
            <name>Nexus Repository</name>
            <url>http://${NEXUS_HOST}:${NEXUS_PORT}/repository/maven-public/</url>
        </mirror>
    </mirrors>
    
    <servers>
        <server>
            <id>nexus</id>
            <username>${NEXUS_USERNAME}</username>
            <password>${NEXUS_PASSWORD}</password>
        </server>
    </servers>
    
</settings>
EOF
    
    print_info "Maven配置完成"
}

# 配置Gradle
configure_gradle() {
    print_header "配置Gradle源"
    
    # 创建Gradle配置目录
    mkdir -p ~/.gradle
    
    # 配置Gradle
    cat << EOF > ~/.gradle/init.gradle
allprojects {
    repositories {
        maven {
            url "http://${NEXUS_HOST}:${NEXUS_PORT}/repository/maven-public/"
            allowInsecureProtocol = true
        }
    }
}
EOF
    
    print_info "Gradle配置完成"
}

# 配置Node.js NPM
configure_nodejs() {
    print_header "配置Node.js NPM源"
    
    if command -v npm >/dev/null 2>&1; then
        npm config set registry http://${NEXUS_HOST}:${NEXUS_PORT}/repository/npm-proxy/
        print_info "NPM配置完成"
    fi
    
    if command -v yarn >/dev/null 2>&1; then
        yarn config set registry http://${NEXUS_HOST}:${NEXUS_PORT}/repository/npm-proxy/
        print_info "Yarn配置完成"
    fi
    
    if command -v pnpm >/dev/null 2>&1; then
        pnpm config set registry http://${NEXUS_HOST}:${NEXUS_PORT}/repository/npm-proxy/
        print_info "PNPM配置完成"
    fi
}

# 配置其他软件源
configure_others() {
    print_header "配置其他软件源"
    
    # Ruby Gems
    if command -v gem >/dev/null 2>&1; then
        gem sources --clear-all
        gem sources -a http://${NEXUS_HOST}:${NEXUS_PORT}/repository/rubygems-proxy/
        print_info "Ruby Gems配置完成"
    fi
    
    # Go模块代理
    if command -v go >/dev/null 2>&1; then
        go env -w GOPROXY=http://${NEXUS_HOST}:${NEXUS_PORT}/repository/go-proxy/,direct
        go env -w GOSUMDB=off
        print_info "Go模块代理配置完成"
    fi
    
    # Rust Cargo
    if command -v cargo >/dev/null 2>&1; then
        mkdir -p ~/.cargo
        cat << EOF > ~/.cargo/config.toml
[source.crates-io]
replace-with = "nexus"

[source.nexus]
registry = "http://${NEXUS_HOST}:${NEXUS_PORT}/repository/cargo-proxy/"
EOF
        print_info "Rust Cargo配置完成"
    fi
}

# 验证配置
verify_configuration() {
    print_header "验证配置"
    
    echo "正在验证各软件源配置..."
    
    # 验证系统包管理器
    case $(. /etc/os-release; echo $ID) in
        "ubuntu"|"debian")
            if apt update >/dev/null 2>&1; then
                print_info "APT源验证成功"
            else
                print_warning "APT源可能有问题"
            fi
            ;;
        "centos"|"rhel"|"fedora"|"rocky"|"almalinux")
            if yum check-update >/dev/null 2>&1 || dnf check-update >/dev/null 2>&1; then
                print_info "YUM/DNF源验证成功"
            else
                print_warning "YUM/DNF源可能有问题"
            fi
            ;;
    esac
    
    # 验证pip
    if command -v pip >/dev/null 2>&1; then
        if pip search requests >/dev/null 2>&1 || pip index versions requests >/dev/null 2>&1; then
            print_info "pip源验证成功"
        else
            print_warning "pip源可能有问题"
        fi
    fi
    
    # 验证npm
    if command -v npm >/dev/null 2>&1; then
        if npm ping >/dev/null 2>&1; then
            print_info "NPM源验证成功"
        else
            print_warning "NPM源可能有问题"
        fi
    fi
}

# 显示使用说明
show_usage() {
    echo "使用说明:"
    echo "1. 修改脚本顶部的NEXUS_HOST、NEXUS_PORT等变量"
    echo "2. 确保Nexus服务器已正确配置相应的代理仓库"
    echo "3. 运行脚本: ./configure_nexus.sh"
    echo ""
    echo "支持的操作:"
    echo "  --check     : 仅检查Nexus连接"
    echo "  --system    : 仅配置系统包管理器"
    echo "  --docker    : 仅配置Docker"
    echo "  --python    : 仅配置Python"
    echo "  --java      : 仅配置Java相关"
    echo "  --nodejs    : 仅配置Node.js"
    echo "  --others    : 仅配置其他软件源"
    echo "  --verify    : 仅验证配置"
    echo "  --all       : 配置所有软件源（默认）"
}

# 主函数
main() {
    case ${1:-"--all"} in
        "--check")
            check_nexus_connection
            ;;
        "--system")
            configure_system_repos
            ;;
        "--docker")
            configure_docker
            ;;
        "--python")
            configure_python
            ;;
        "--java")
            configure_maven
            configure_gradle
            ;;
        "--nodejs")
            configure_nodejs
            ;;
        "--others")
            configure_others
            ;;
        "--verify")
            verify_configuration
            ;;
        "--help"|"-h")
            show_usage
            ;;
        "--all"|*)
            print_info "开始配置所有软件源到Nexus..."
            check_nexus_connection || exit 1
            configure_system_repos
            configure_docker
            configure_python
            configure_maven
            configure_gradle
            configure_nodejs
            configure_others
            verify_configuration
            print_info "所有配置完成！"
            ;;
    esac
}

# 检查是否以root身份运行某些操作
if [[ $EUID -eq 0 ]]; then
    print_warning "检测到以root身份运行，某些用户配置可能不会生效"
fi

# 执行主函数
main "$@"