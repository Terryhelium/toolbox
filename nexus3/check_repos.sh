#!/bin/bash

# 软件源检测脚本 - 为迁移到Nexus做准备
# Author: Monica Assistant
# Date: $(date +%Y-%m-%d)

echo "========================================="
echo "Linux 软件源检测脚本"
echo "========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 输出函数
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

# 检测Linux发行版
detect_distro() {
    print_header "系统信息检测"
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "发行版: $NAME"
        echo "版本: $VERSION"
        echo "ID: $ID"
        echo "版本ID: $VERSION_ID"
        DISTRO=$ID
        VERSION_ID=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        DISTRO="rhel"
        echo "发行版: $(cat /etc/redhat-release)"
    elif [ -f /etc/debian_version ]; then
        DISTRO="debian"
        echo "发行版: Debian $(cat /etc/debian_version)"
    else
        print_error "无法检测Linux发行版"
        exit 1
    fi
    
    echo "内核版本: $(uname -r)"
    echo "架构: $(uname -m)"
}

# 检测系统软件包管理器源
check_system_repos() {
    print_header "系统软件包源检测"
    
    case $DISTRO in
        "ubuntu"|"debian")
            print_info "APT 软件源配置:"
            if [ -f /etc/apt/sources.list ]; then
                echo "主配置文件: /etc/apt/sources.list"
                grep -v "^#" /etc/apt/sources.list | grep -v "^$" | while read line; do
                    echo "  $line"
                done
            fi
            
            if [ -d /etc/apt/sources.list.d ]; then
                echo "额外源目录: /etc/apt/sources.list.d/"
                for file in /etc/apt/sources.list.d/*.list; do
                    if [ -f "$file" ]; then
                        echo "  文件: $(basename $file)"
                        grep -v "^#" "$file" | grep -v "^$" | while read line; do
                            echo "    $line"
                        done
                    fi
                done
            fi
            ;;
            
        "centos"|"rhel"|"fedora"|"rocky"|"almalinux")
            print_info "YUM/DNF 软件源配置:"
            if [ -d /etc/yum.repos.d ]; then
                for file in /etc/yum.repos.d/*.repo; do
                    if [ -f "$file" ]; then
                        echo "仓库文件: $(basename $file)"
                        grep -E "^\[|^baseurl|^mirrorlist|^metalink" "$file" | while read line; do
                            echo "  $line"
                        done
                    fi
                done
            fi
            ;;
            
        "opensuse"|"sles")
            print_info "Zypper 软件源配置:"
            if command -v zypper >/dev/null 2>&1; then
                zypper lr -u
            fi
            ;;
            
        "arch")
            print_info "Pacman 软件源配置:"
            if [ -f /etc/pacman.conf ]; then
                grep -E "^\[|^Server" /etc/pacman.conf
            fi
            ;;
    esac
}

# 检测Docker源
check_docker_repos() {
    print_header "Docker 软件源检测"
    
    case $DISTRO in
        "ubuntu"|"debian")
            if [ -f /etc/apt/sources.list.d/docker.list ]; then
                print_info "Docker APT 源:"
                cat /etc/apt/sources.list.d/docker.list
            elif grep -r "docker" /etc/apt/sources.list.d/ 2>/dev/null; then
                print_info "在其他APT源文件中找到Docker源:"
                grep -r "docker" /etc/apt/sources.list.d/
            else
                print_warning "未找到Docker APT源配置"
            fi
            ;;
            
        "centos"|"rhel"|"fedora"|"rocky"|"almalinux")
            if [ -f /etc/yum.repos.d/docker-ce.repo ]; then
                print_info "Docker YUM 源:"
                cat /etc/yum.repos.d/docker-ce.repo
            else
                print_warning "未找到Docker YUM源配置"
            fi
            ;;
    esac
    
    # 检查Docker Hub镜像源
    if command -v docker >/dev/null 2>&1; then
        print_info "Docker 守护进程配置:"
        if [ -f /etc/docker/daemon.json ]; then
            echo "配置文件: /etc/docker/daemon.json"
            cat /etc/docker/daemon.json
        else
            print_warning "未找到Docker daemon.json配置文件"
        fi
    fi
}

# 检测Python包管理器源
check_python_repos() {
    print_header "Python 包管理器源检测"
    
    # pip配置
    print_info "pip 配置检测:"
    pip_configs=(
        "$HOME/.pip/pip.conf"
        "$HOME/.config/pip/pip.conf"
        "/etc/pip.conf"
    )
    
    found_pip_config=false
    for config in "${pip_configs[@]}"; do
        if [ -f "$config" ]; then
            echo "找到pip配置: $config"
            cat "$config"
            found_pip_config=true
        fi
    done
    
    if [ "$found_pip_config" = false ]; then
        print_warning "未找到pip配置文件，使用默认PyPI源"
        echo "默认源: https://pypi.org/simple/"
    fi
    
    # conda配置
    if command -v conda >/dev/null 2>&1; then
        print_info "Conda 配置:"
        conda config --show channels
    fi
    
    # poetry配置
    if command -v poetry >/dev/null 2>&1; then
        print_info "Poetry 配置:"
        poetry config --list | grep -i url || echo "使用默认PyPI源"
    fi
}

# 检测Java相关源
check_java_repos() {
    print_header "Java 相关源检测"
    
    # Maven配置
    maven_configs=(
        "$HOME/.m2/settings.xml"
        "/etc/maven/settings.xml"
        "/usr/share/maven/conf/settings.xml"
    )
    
    print_info "Maven 配置检测:"
    found_maven_config=false
    for config in "${maven_configs[@]}"; do
        if [ -f "$config" ]; then
            echo "找到Maven配置: $config"
            grep -A 10 -B 2 "<mirror>\|<repository>" "$config" | head -20
            found_maven_config=true
        fi
    done
    
    if [ "$found_maven_config" = false ]; then
        print_warning "未找到Maven配置，使用默认中央仓库"
        echo "默认源: https://repo1.maven.org/maven2/"
    fi
    
    # Gradle配置
    gradle_configs=(
        "$HOME/.gradle/init.gradle"
        "$HOME/.gradle/gradle.properties"
    )
    
    print_info "Gradle 配置检测:"
    found_gradle_config=false
    for config in "${gradle_configs[@]}"; do
        if [ -f "$config" ]; then
            echo "找到Gradle配置: $config"
            cat "$config"
            found_gradle_config=true
        fi
    done
    
    if [ "$found_gradle_config" = false ]; then
        print_warning "未找到Gradle配置，使用默认仓库"
    fi
}

# 检测Node.js相关源
check_nodejs_repos() {
    print_header "Node.js 相关源检测"
    
    if command -v npm >/dev/null 2>&1; then
        print_info "NPM 配置:"
        echo "当前registry: $(npm config get registry)"
        echo "NPM 配置文件位置:"
        npm config list -l | grep "config" | head -5
    fi
    
    if command -v yarn >/dev/null 2>&1; then
        print_info "Yarn 配置:"
        echo "当前registry: $(yarn config get registry)"
    fi
    
    if command -v pnpm >/dev/null 2>&1; then
        print_info "PNPM 配置:"
        echo "当前registry: $(pnpm config get registry)"
    fi
}

# 检测其他常用软件源
check_other_repos() {
    print_header "其他软件源检测"
    
    # Ruby Gems
    if command -v gem >/dev/null 2>&1; then
        print_info "Ruby Gems 源:"
        gem sources -l
    fi
    
    # Go模块代理
    if command -v go >/dev/null 2>&1; then
        print_info "Go 模块代理:"
        go env GOPROXY
        go env GOSUMDB
    fi
    
    # Rust Cargo
    if command -v cargo >/dev/null 2>&1; then
        print_info "Rust Cargo 配置:"
        if [ -f "$HOME/.cargo/config.toml" ]; then
            cat "$HOME/.cargo/config.toml"
        elif [ -f "$HOME/.cargo/config" ]; then
            cat "$HOME/.cargo/config"
        else
            echo "使用默认crates.io源"
        fi
    fi
    
    # Helm仓库
    if command -v helm >/dev/null 2>&1; then
        print_info "Helm 仓库:"
        helm repo list 2>/dev/null || echo "未配置Helm仓库"
    fi
}

# 生成迁移建议
generate_migration_suggestions() {
    print_header "Nexus 迁移建议"
    
    echo "基于检测结果，以下是迁移到Nexus的建议:"
    echo ""
    echo "1. 系统包管理器:"
    case $DISTRO in
        "ubuntu"|"debian")
            echo "   - 修改 /etc/apt/sources.list"
            echo "   - 更新 /etc/apt/sources.list.d/ 下的源文件"
            echo "   - 配置Nexus APT代理仓库"
            ;;
        "centos"|"rhel"|"fedora"|"rocky"|"almalinux")
            echo "   - 修改 /etc/yum.repos.d/ 下的.repo文件"
            echo "   - 配置Nexus YUM代理仓库"
            ;;
    esac
    
    echo ""
    echo "2. Docker:"
    echo "   - 配置 /etc/docker/daemon.json 中的 registry-mirrors"
    echo "   - 设置Nexus Docker代理仓库"
    
    echo ""
    echo "3. Python:"
    echo "   - 配置pip: ~/.pip/pip.conf 或 ~/.config/pip/pip.conf"
    echo "   - 设置Nexus PyPI代理仓库"
    
    echo ""
    echo "4. Java:"
    echo "   - Maven: 修改 ~/.m2/settings.xml"
    echo "   - Gradle: 配置 ~/.gradle/init.gradle"
    echo "   - 设置Nexus Maven代理仓库"
    
    echo ""
    echo "5. Node.js:"
    echo "   - NPM: npm config set registry <nexus-npm-url>"
    echo "   - 设置Nexus NPM代理仓库"
}

# 主函数
main() {
    detect_distro
    check_system_repos
    check_docker_repos
    check_python_repos
    check_java_repos
    check_nodejs_repos
    check_other_repos
    generate_migration_suggestions
    
    echo ""
    print_info "检测完成！建议将此报告保存，用于Nexus迁移规划。"
}

# 执行主函数
main