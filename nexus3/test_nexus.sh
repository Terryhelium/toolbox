#!/bin/bash

# Nexus 配置测试脚本
# 快速验证各个软件源的配置是否正常工作

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

# 测试网络连接
test_network() {
    print_header "测试网络连接"
    
    print_info "测试Nexus服务器连接..."
    if curl -s --connect-timeout 5 "${NEXUS_BASE_URL}/service/rest/v1/status" >/dev/null 2>&1; then
        print_success "✓ Nexus服务器连接正常"
        return 0
    else
        print_error "✗ 无法连接到Nexus服务器"
        return 1
    fi
}

# 测试APT配置
test_apt() {
    print_header "测试APT配置"
    
    print_info "检查APT源配置..."
    if grep -q "192.168.31.217" /etc/apt/sources.list 2>/dev/null; then
        print_success "✓ APT源已配置为使用Nexus"
        
        print_info "测试APT更新..."
        if timeout 30 apt update >/dev/null 2>&1; then
            print_success "✓ APT更新成功"
            
            print_info "测试包搜索..."
            if apt search curl 2>/dev/null | grep -q "curl"; then
                print_success "✓ APT包搜索正常"
            else
                print_warning "✗ APT包搜索可能有问题"
            fi
        else
            print_warning "✗ APT更新失败或超时"
        fi
    else
        print_warning "✗ APT源未配置或未使用Nexus"
    fi
}

# 测试Docker配置
test_docker() {
    print_header "测试Docker配置"
    
    if ! command -v docker >/dev/null 2>&1; then
        print_warning "Docker未安装，跳过测试"
        return 0
    fi
    
    print_info "检查Docker配置..."
    if [ -f /etc/docker/daemon.json ] && grep -q "192.168.31.217" /etc/docker/daemon.json 2>/dev/null; then
        print_success "✓ Docker已配置为使用Nexus镜像仓库"
        
        print_info "检查Docker服务状态..."
        if systemctl is-active --quiet docker; then
            print_success "✓ Docker服务运行正常"
            
            print_info "测试Docker镜像拉取..."
            if timeout 60 docker pull hello-world >/dev/null 2>&1; then
                print_success "✓ Docker镜像拉取成功"
                docker rmi hello-world >/dev/null 2>&1 || true
            else
                print_warning "✗ Docker镜像拉取失败或超时"
            fi
        else
            print_warning "✗ Docker服务未运行"
        fi
    else
        print_warning "✗ Docker未配置或未使用Nexus"
    fi
}

# 测试Python pip配置
test_pip() {
    print_header "测试Python pip配置"
    
    if ! command -v pip >/dev/null 2>&1 && ! command -v pip3 >/dev/null 2>&1; then
        print_warning "pip未安装，跳过测试"
        return 0
    fi
    
    print_info "检查pip配置..."
    local pip_cmd="pip"
    if ! command -v pip >/dev/null 2>&1; then
        pip_cmd="pip3"
    fi
    
    if $pip_cmd config list 2>/dev/null | grep -q "192.168.31.217"; then
        print_success "✓ pip已配置为使用Nexus"
        
        print_info "测试pip包搜索..."
        if timeout 30 $pip_cmd search requests >/dev/null 2>&1 || timeout 30 $pip_cmd index versions requests >/dev/null 2>&1; then
            print_success "✓ pip包搜索正常"
        else
            print_info "测试pip包信息获取..."
            if timeout 30 $pip_cmd show requests >/dev/null 2>&1; then
                print_success "✓ pip包信息获取正常"
            else
                print_warning "✗ pip包搜索可能有问题"
            fi
        fi
    else
        print_warning "✗ pip未配置或未使用Nexus"
    fi
}

# 测试Maven配置
test_maven() {
    print_header "测试Maven配置"
    
    if ! command -v mvn >/dev/null 2>&1; then
        print_warning "Maven未安装，跳过测试"
        return 0
    fi
    
    print_info "检查Maven配置..."
    if [ -f ~/.m2/settings.xml ] && grep -q "192.168.31.217" ~/.m2/settings.xml 2>/dev/null; then
        print_success "✓ Maven已配置为使用Nexus"
        
        print_info "测试Maven配置有效性..."
        if timeout 30 mvn help:effective-settings >/dev/null 2>&1; then
            print_success "✓ Maven配置有效"
        else
            print_warning "✗ Maven配置可能有问题"
        fi
    else
        print_warning "✗ Maven未配置或未使用Nexus"
    fi
}

# 测试NPM配置
test_npm() {
    print_header "测试NPM配置"
    
    if ! command -v npm >/dev/null 2>&1; then
        print_warning "NPM未安装，跳过测试"
        return 0
    fi
    
    print_info "检查NPM配置..."
    if npm config get registry 2>/dev/null | grep -q "192.168.31.217"; then
        print_success "✓ NPM已配置为使用Nexus"
        
        print_info "测试NPM包信息获取..."
        if timeout 30 npm info express >/dev/null 2>&1; then
            print_success "✓ NPM包信息获取正常"
        else
            print_warning "✗ NPM包信息获取可能有问题"
        fi
    else
        print_warning "✗ NPM未配置或未使用Nexus"
    fi
}

# 生成测试报告
generate_test_report() {
    print_header "生成测试报告"
    
    local report_file="/tmp/nexus_test_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
Nexus 配置测试报告
==================
测试时间: $(date)
测试服务器: ${NEXUS_BASE_URL}

测试结果汇总:
EOF
    
    # 重新运行测试并记录结果
    echo "" >> "$report_file"
    echo "1. 网络连接测试:" >> "$report_file"
    if curl -s --connect-timeout 5 "${NEXUS_BASE_URL}/service/rest/v1/status" >/dev/null 2>&1; then
        echo "   ✓ 通过" >> "$report_file"
    else
        echo "   ✗ 失败" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "2. APT配置测试:" >> "$report_file"
    if grep -q "192.168.31.217" /etc/apt/sources.list 2>/dev/null; then
        echo "   ✓ 已配置" >> "$report_file"
        if timeout 10 apt update >/dev/null 2>&1; then
            echo "   ✓ 更新成功" >> "$report_file"
        else
            echo "   ✗ 更新失败" >> "$report_file"
        fi
    else
        echo "   ✗ 未配置" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "3. Docker配置测试:" >> "$report_file"
    if command -v docker >/dev/null 2>&1; then
        if [ -f /etc/docker/daemon.json ] && grep -q "192.168.31.217" /etc/docker/daemon.json 2>/dev/null; then
            echo "   ✓ 已配置" >> "$report_file"
        else
            echo "   ✗ 未配置" >> "$report_file"
        fi
    else
        echo "   - 未安装" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "4. Python pip配置测试:" >> "$report_file"
    if command -v pip >/dev/null 2>&1 || command -v pip3 >/dev/null 2>&1; then
        local pip_cmd="pip"
        if ! command -v pip >/dev/null 2>&1; then
            pip_cmd="pip3"
        fi
        if $pip_cmd config list 2>/dev/null | grep -q "192.168.31.217"; then
            echo "   ✓ 已配置" >> "$report_file"
        else
            echo "   ✗ 未配置" >> "$report_file"
        fi
    else
        echo "   - 未安装" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "5. Maven配置测试:" >> "$report_file"
    if command -v mvn >/dev/null 2>&1; then
        if [ -f ~/.m2/settings.xml ] && grep -q "192.168.31.217" ~/.m2/settings.xml 2>/dev/null; then
            echo "   ✓ 已配置" >> "$report_file"
        else
            echo "   ✗ 未配置" >> "$report_file"
        fi
    else
        echo "   - 未安装" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "6. NPM配置测试:" >> "$report_file"
    if command -v npm >/dev/null 2>&1; then
        if npm config get registry 2>/dev/null | grep -q "192.168.31.217"; then
            echo "   ✓ 已配置" >> "$report_file"
        else
            echo "   ✗ 未配置" >> "$report_file"
        fi
    else
        echo "   - 未安装" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "建议:" >> "$report_file"
    echo "- 如果测试失败，请检查Nexus服务器状态" >> "$report_file"
    echo "- 确保相应的代理仓库已创建并在线" >> "$report_file"
    echo "- 检查网络连接和防火墙设置" >> "$report_file"
    echo "- 查看详细的配置指南和故障排除信息" >> "$report_file"
    
    print_success "测试报告已生成: $report_file"
    cat "$report_file"
}

# 快速修复常见问题
quick_fix() {
    print_header "快速修复常见问题"
    
    print_info "1. 检查并修复APT源配置..."
    if ! grep -q "192.168.31.217" /etc/apt/sources.list 2>/dev/null; then
        print_warning "APT源未配置，请运行配置脚本"
    fi
    
    print_info "2. 检查并修复Docker配置..."
    if command -v docker >/dev/null 2>&1; then
        if ! systemctl is-active --quiet docker; then
            print_info "尝试启动Docker服务..."
            systemctl start docker 2>/dev/null && print_success "✓ Docker服务已启动" || print_warning "✗ Docker服务启动失败"
        fi
    fi
    
    print_info "3. 清理缓存..."
    # 清理APT缓存
    apt clean 2>/dev/null && print_info "✓ APT缓存已清理"
    
    # 清理pip缓存
    if command -v pip >/dev/null 2>&1; then
        pip cache purge 2>/dev/null && print_info "✓ pip缓存已清理"
    fi
    
    # 清理NPM缓存
    if command -v npm >/dev/null 2>&1; then
        npm cache clean --force 2>/dev/null && print_info "✓ NPM缓存已清理"
    fi
    
    print_success "快速修复完成"
}

# 主函数
main() {
    echo "Nexus 配置测试脚本"
    echo "服务器: ${NEXUS_BASE_URL}"
    echo ""
    
    test_network || exit 1
    test_apt
    test_docker
    test_pip
    test_maven
    test_npm
    generate_test_report
    
    print_header "测试完成"
    print_info "如果发现问题，可以运行 './test_nexus.sh fix' 进行快速修复"
}

# 处理命令行参数
case "${1:-}" in
    "network")
        test_network
        ;;
    "apt")
        test_apt
        ;;
    "docker")
        test_docker
        ;;
    "python")
        test_pip
        ;;
    "java")
        test_maven
        ;;
    "nodejs")
        test_npm
        ;;
    "report")
        generate_test_report
        ;;
    "fix")
        quick_fix
        ;;
    *)
        main
        ;;
esac