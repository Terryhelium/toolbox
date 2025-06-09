#!/bin/bash

# Linux防火墙管理脚本 - 完整优化版
# 版本: 2.0
# 支持多种Linux发行版和防火墙工具

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 全局变量
SELECTED_FIREWALL=""
SCRIPT_VERSION="2.0"
BACKUP_DIR="/tmp/firewall_backup"

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}========================================${NC}"
}

print_separator() {
    echo -e "${CYAN}----------------------------------------${NC}"
}

# 等待用户按键
pause() {
    echo
    read -p "按回车键继续..." -r
}

# 确认操作
confirm_action() {
    local message="$1"
    local default="${2:-n}"
    
    if [[ $default == "y" ]]; then
        read -p "$message [Y/n]: " -r reply
        reply=${reply:-y}
    else
        read -p "$message [y/N]: " -r reply
        reply=${reply:-n}
    fi
    
    [[ $reply =~ ^[Yy]$ ]]
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要root权限运行"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 检测Linux发行版
detect_linux_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
        DISTRO_NAME=$PRETTY_NAME
    elif [[ -f /etc/redhat-release ]]; then
        DISTRO="rhel"
        DISTRO_NAME=$(cat /etc/redhat-release)
    elif [[ -f /etc/debian_version ]]; then
        DISTRO="debian"
        DISTRO_NAME="Debian $(cat /etc/debian_version)"
    else
        DISTRO="unknown"
        DISTRO_NAME="Unknown Linux"
    fi
    
    print_info "检测到的系统: $DISTRO_NAME"
    print_info "发行版ID: $DISTRO"
    print_info "版本: $VERSION"
    print_info "内核版本: $(uname -r)"
    print_info "架构: $(uname -m)"
}

# 检查防火墙工具是否安装
check_firewall_tools() {
    declare -A FIREWALLS
    
    if command -v ufw >/dev/null 2>&1; then
        FIREWALLS["ufw"]="UFW (Uncomplicated Firewall)"
    fi
    
    if command -v firewall-cmd >/dev/null 2>&1; then
        FIREWALLS["firewalld"]="FirewallD"
    fi
    
    if command -v iptables >/dev/null 2>&1; then
        FIREWALLS["iptables"]="IPTables"
    fi
    
    if command -v nft >/dev/null 2>&1; then
        FIREWALLS["nftables"]="NFTables"
    fi
    
    if [[ -f /etc/csf/csf.conf ]]; then
        FIREWALLS["csf"]="CSF (ConfigServer Security & Firewall)"
    fi
    
    echo "${!FIREWALLS[@]}"
}

# 检查防火墙状态
check_firewall_status() {
    local fw=$1
    case $fw in
        "ufw")
            if ufw status 2>/dev/null | grep -q "Status: active"; then
                echo "active"
            else
                echo "inactive"
            fi
            ;;
        "firewalld")
            if systemctl is-active --quiet firewalld 2>/dev/null; then
                echo "active"
            else
                echo "inactive"
            fi
            ;;
        "iptables")
            if iptables -L 2>/dev/null | grep -q "Chain INPUT"; then
                local input_policy=$(iptables -L INPUT 2>/dev/null | head -1 | grep -o "policy [A-Z]*" | cut -d' ' -f2)
                local rule_count=$(iptables -L INPUT 2>/dev/null | grep -c -E "(ACCEPT|DROP|REJECT)")
                if [[ $input_policy != "ACCEPT" ]] || [[ $rule_count -gt 3 ]]; then
                    echo "active"
                else
                    echo "inactive"
                fi
            else
                echo "inactive"
            fi
            ;;
        "nftables")
            if systemctl is-active --quiet nftables 2>/dev/null; then
                echo "active"
            else
                echo "inactive"
            fi
            ;;
        "csf")
            if [[ -f /etc/csf/csf.conf ]] && grep -q "TESTING = \"0\"" /etc/csf/csf.conf 2>/dev/null; then
                echo "active"
            else
                echo "inactive"
            fi
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# 获取防火墙推荐度
get_firewall_recommendation() {
    local fw=$1
    case $DISTRO in
        "ubuntu"|"debian")
            case $fw in
                "ufw") echo "★★★★★ 推荐" ;;
                "iptables") echo "★★★☆☆ 适用" ;;
                "nftables") echo "★★★☆☆ 现代" ;;
                "firewalld") echo "★★☆☆☆ 可用" ;;
                *) echo "★☆☆☆☆ 一般" ;;
            esac
            ;;
        "centos"|"rhel"|"fedora"|"rocky"|"almalinux")
            case $fw in
                "firewalld") echo "★★★★★ 推荐" ;;
                "iptables") echo "★★★☆☆ 传统" ;;
                "nftables") echo "★★★★☆ 现代" ;;
                "ufw") echo "★★☆☆☆ 可用" ;;
                *) echo "★☆☆☆☆ 一般" ;;
            esac
            ;;
        *)
            case $fw in
                "iptables") echo "★★★★☆ 通用" ;;
                "nftables") echo "★★★★☆ 现代" ;;
                *) echo "★★★☆☆ 适用" ;;
            esac
            ;;
    esac
}

# 显示防火墙状态
show_firewall_status() {
    print_header "当前防火墙状态"
    
    local available_firewalls=($(check_firewall_tools))
    
    if [[ ${#available_firewalls[@]} -eq 0 ]]; then
        print_warning "未检测到任何防火墙工具"
        echo
        print_info "建议安装适合您系统的防火墙："
        show_installation_commands
        return
    fi
    
    declare -A FIREWALL_NAMES=(
        ["ufw"]="UFW (Uncomplicated Firewall)"
        ["firewalld"]="FirewallD"
        ["iptables"]="IPTables"
        ["nftables"]="NFTables"
        ["csf"]="CSF (ConfigServer Security & Firewall)"
    )
    
    printf "%-35s %-10s %s\n" "防火墙" "状态" "推荐度"
    print_separator
    
    for fw in "${available_firewalls[@]}"; do
        local status=$(check_firewall_status $fw)
        local name=${FIREWALL_NAMES[$fw]}
        local recommendation=$(get_firewall_recommendation $fw)
        
        if [[ $status == "active" ]]; then
            printf "%-35s ${GREEN}%-10s${NC} %s\n" "$name" "已启用" "$recommendation"
        else
            printf "%-35s ${YELLOW}%-10s${NC} %s\n" "$name" "未启用" "$recommendation"
        fi
    done
    
    echo
    print_info "提示: ★ 越多表示越适合当前系统"
}

# 选择防火墙 - 优化版
select_firewall() {
    local available_firewalls=($(check_firewall_tools))
    
    if [[ ${#available_firewalls[@]} -eq 0 ]]; then
        print_error "未检测到任何防火墙工具，请先安装"
        echo
        if confirm_action "是否查看安装命令?"; then
            show_installation_commands
            pause
        fi
        return 1
    fi
    
    while true; do
        print_header "选择要管理的防火墙"
        
        declare -A FIREWALL_NAMES=(
            ["ufw"]="UFW (Uncomplicated Firewall)"
            ["firewalld"]="FirewallD"
            ["iptables"]="IPTables"
            ["nftables"]="NFTables"
            ["csf"]="CSF (ConfigServer Security & Firewall)"
        )
        
        local i=1
        declare -A menu_options
        
        for fw in "${available_firewalls[@]}"; do
            local status=$(check_firewall_status $fw)
            local name=${FIREWALL_NAMES[$fw]}
            local recommendation=$(get_firewall_recommendation $fw)
            
            if [[ $status == "active" ]]; then
                printf "%d) %-35s [${GREEN}%s${NC}] %s\n" $i "$name" "$status" "$recommendation"
            else
                printf "%d) %-35s [${YELLOW}%s${NC}] %s\n" $i "$name" "$status" "$recommendation"
            fi
            
            menu_options[$i]=$fw
            ((i++))
        done
        
        echo
        echo "0) 返回主菜单"
        echo "h) 显示帮助"
        echo
        read -p "请选择防火墙 (0-$((i-1)), h): " choice
        
        case $choice in
            0)
                return 1
                ;;
            h|H)
                show_firewall_help
                pause
                continue
                ;;
            *)
                if [[ -n ${menu_options[$choice]} ]]; then
                    SELECTED_FIREWALL=${menu_options[$choice]}
                    print_success "已选择: ${FIREWALL_NAMES[$SELECTED_FIREWALL]}"
                    return 0
                else
                    print_error "无效选择，请输入 0-$((i-1)) 或 h"
                    sleep 1
                fi
                ;;
        esac
    done
}

# 显示防火墙帮助信息
show_firewall_help() {
    print_header "防火墙选择帮助"
    
    echo -e "${CYAN}各防火墙特点:${NC}"
    echo
    echo -e "${GREEN}UFW (Uncomplicated Firewall):${NC}"
    echo "  • Ubuntu/Debian 默认推荐"
    echo "  • 语法简单，易于使用"
    echo "  • 适合桌面和简单服务器"
    echo
    echo -e "${GREEN}FirewallD:${NC}"
    echo "  • CentOS/RHEL/Fedora 默认"
    echo "  • 支持区域概念，动态规则"
    echo "  • 适合企业级服务器"
    echo
    echo -e "${GREEN}IPTables:${NC}"
    echo "  • 传统Linux防火墙"
    echo "  • 功能强大，配置复杂"
    echo "  • 适合高级用户"
    echo
    echo -e "${GREEN}NFTables:${NC}"
    echo "  • IPTables的现代替代品"
    echo "  • 性能更好，语法更清晰"
    echo "  • 适合新系统"
    echo
    echo -e "${YELLOW}建议:${NC}"
    echo "  • 新手用户: 选择带★★★★★的推荐防火墙"
    echo "  • 高级用户: 可根据需求选择"
    echo "  • 生产环境: 建议使用系统默认推荐的防火墙"
}

# 管理防火墙状态 - 优化版
manage_firewall_status() {
    local fw=$1
    
    while true; do
        local current_status=$(check_firewall_status $fw)
        declare -A FIREWALL_NAMES=(
            ["ufw"]="UFW (Uncomplicated Firewall)"
            ["firewalld"]="FirewallD"
            ["iptables"]="IPTables"
            ["nftables"]="NFTables"
            ["csf"]="CSF (ConfigServer Security & Firewall)"
        )
        
        print_header "管理防火墙: ${FIREWALL_NAMES[$fw]:-$fw}"
        print_info "当前状态: $current_status"
        
        echo
        echo "1) 启用防火墙"
        echo "2) 禁用防火墙"
        echo "3) 重启防火墙"
        echo "4) 查看详细状态"
        echo "5) 添加端口规则"
        echo "6) 删除端口规则"
        echo "7) 显示手动命令"
        echo "0) 返回上级菜单"
        echo
        
        read -p "请选择操作 (0-7): " action
        
        case $action in
            1)
                if [[ $current_status == "active" ]]; then
                    print_warning "防火墙已经启用"
                else
                    if confirm_action "确定要启用防火墙吗?" "y"; then
                        enable_firewall $fw
                    fi
                fi
                pause
                ;;
            2)
                if [[ $current_status == "inactive" ]]; then
                    print_warning "防火墙已经禁用"
                else
                    print_warning "禁用防火墙可能会带来安全风险！"
                    if confirm_action "确定要禁用防火墙吗?"; then
                        disable_firewall $fw
                    fi
                fi
                pause
                ;;
            3)
                if confirm_action "确定要重启防火墙吗?"; then
                    restart_firewall $fw
                fi
                pause
                ;;
            4)
                show_detailed_status $fw
                pause
                ;;
            5)
                add_port_rules $fw
                ;;
            6)
                remove_port_rules $fw
                pause
                ;;
            7)
                show_manual_commands $fw
                pause
                ;;
            0)
                return
                ;;
            *)
                print_error "无效选择，请输入 0-7"
                sleep 1
                ;;
        esac
    done
}

# 启用防火墙
enable_firewall() {
    local fw=$1
    print_info "正在启用 $fw..."
    
    case $fw in
        "ufw")
            ufw --force enable
            systemctl enable ufw 2>/dev/null
            ;;
        "firewalld")
            systemctl start firewalld
            systemctl enable firewalld
            ;;
        "iptables")
            # 设置基本安全规则
            iptables -P INPUT DROP
            iptables -P FORWARD DROP
            iptables -P OUTPUT ACCEPT
            iptables -A INPUT -i lo -j ACCEPT
            iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
            iptables -A INPUT -p tcp --dport 22 -j ACCEPT  # 保留SSH
            
            # 保存规则
            if command -v iptables-save >/dev/null 2>&1; then
                iptables-save > /etc/iptables/rules.v4 2>/dev/null || 
                iptables-save > /etc/sysconfig/iptables 2>/dev/null
            fi
            
            systemctl start iptables 2>/dev/null || service iptables start 2>/dev/null
            systemctl enable iptables 2>/dev/null || chkconfig iptables on 2>/dev/null
            ;;
        "nftables")
            systemctl start nftables
            systemctl enable nftables
            ;;
        "csf")
            if [[ -f /etc/csf/csf.conf ]]; then
                sed -i 's/TESTING = "1"/TESTING = "0"/' /etc/csf/csf.conf
                csf -r
            fi
            ;;
    esac
    
    print_success "$fw 已启用"
}

# 禁用防火墙
disable_firewall() {
    local fw=$1
    print_warning "正在禁用 $fw..."
    
    case $fw in
        "ufw")
            ufw --force disable
            ;;
        "firewalld")
            systemctl stop firewalld
            systemctl disable firewalld
            ;;
        "iptables")
            iptables -F
            iptables -X
            iptables -P INPUT ACCEPT
            iptables -P FORWARD ACCEPT
            iptables -P OUTPUT ACCEPT
            systemctl stop iptables 2>/dev/null || service iptables stop 2>/dev/null
            ;;
        "nftables")
            nft flush ruleset 2>/dev/null
            systemctl stop nftables
            systemctl disable nftables
            ;;
        "csf")
            if [[ -f /etc/csf/csf.conf ]]; then
                sed -i 's/TESTING = "0"/TESTING = "1"/' /etc/csf/csf.conf
                csf -f
            fi
            ;;
    esac
    
    print_success "$fw 已禁用"
}

# 重启防火墙
restart_firewall() {
    local fw=$1
    print_info "正在重启 $fw..."
    
    case $fw in
        "ufw")
            ufw --force reload
            ;;
        "firewalld")
            systemctl restart firewalld
            ;;
        "iptables")
            systemctl restart iptables 2>/dev/null || service iptables restart 2>/dev/null
            ;;
        "nftables")
            systemctl restart nftables
            ;;
        "csf")
            csf -r
            ;;
    esac
    
    print_success "$fw 已重启"
}

# 添加端口规则
add_port_rules() {
    local fw=$1
    
    while true; do
        print_header "添加端口规则"
        
        echo "常用端口预设:"
        echo "1) SSH (22)"
        echo "2) HTTP (80)"
        echo "3) HTTPS (443)"
        echo "4) FTP (21, 20)"
        echo "5) MySQL (3306)"
        echo "6) PostgreSQL (5432)"
        echo "7) 自定义单个端口"
        echo "8) 批量添加端口"
        echo "0) 返回上级菜单"
        echo
        
        read -p "请选择 (0-8): " port_choice
        
        case $port_choice in
            1) add_single_port $fw 22 "SSH" "tcp" ;;
            2) add_single_port $fw 80 "HTTP" "tcp" ;;
            3) add_single_port $fw 443 "HTTPS" "tcp" ;;
            4) 
                add_single_port $fw 21 "FTP-Control" "tcp"
                add_single_port $fw 20 "FTP-Data" "tcp"
                ;;
            5) add_single_port $fw 3306 "MySQL" "tcp" ;;
            6) add_single_port $fw 5432 "PostgreSQL" "tcp" ;;
            7) add_custom_port $fw ;;
            8) add_batch_ports $fw ;;
            0) return ;;
            *) 
                print_error "无效选择，请输入 0-8"
                sleep 1
                ;;
        esac
        
        if [[ $port_choice != 0 ]]; then
            echo
            if ! confirm_action "是否继续添加其他端口?"; then
                break
            fi
        fi
    done
}

# 删除端口规则
remove_port_rules() {
    local fw=$1
    
    print_header "删除端口规则"
    
    echo "当前开放的端口:"
    show_open_ports $fw
    echo
    
    read -p "请输入要删除的端口号: " port
    read -p "协议 (tcp/udp/both) [tcp]: " protocol
    protocol=${protocol:-tcp}
    
    if [[ $port =~ ^[0-9]+$ ]] && [[ $port -ge 1 ]] && [[ $port -le 65535 ]]; then
        if confirm_action "确定要删除端口 $port ($protocol) 吗?"; then
            remove_single_port $fw $port $protocol
        fi
    else
        print_error "无效的端口号"
    fi
}

# 显示开放的端口
show_open_ports() {
    local fw=$1
    
    case $fw in
        "ufw")
            ufw status numbered 2>/dev/null | grep -E "^\[.*\]" | head -10
            ;;
        "firewalld")
            echo "开放的端口:"
            firewall-cmd --list-ports 2>/dev/null
            echo "允许的服务:"
            firewall-cmd --list-services 2>/dev/null
            ;;
        "iptables")
            echo "INPUT链规则:"
            iptables -L INPUT -n --line-numbers 2>/dev/null | grep -E "(ACCEPT|tcp|udp)" | head -10
            ;;
        *)
            print_warning "暂不支持显示 $fw 的端口列表"
            ;;
    esac
}

# 添加单个端口
add_single_port() {
    local fw=$1
    local port=$2
    local service=$3
    local default_protocol=${4:-""}
    
    if [[ -z $default_protocol ]]; then
        read -p "协议 (tcp/udp/both) [tcp]: " protocol
        protocol=${protocol:-tcp}
    else
        protocol=$default_protocol
    fi
    
    case $fw in
        "ufw")
            if [[ $protocol == "both" ]]; then
                ufw allow $port/tcp
                ufw allow $port/udp
            else
                ufw allow $port/$protocol
            fi
            ;;
        "firewalld")
            if [[ $protocol == "both" ]]; then
                firewall-cmd --permanent --add-port=$port/tcp
                firewall-cmd --permanent --add-port=$port/udp
            else
                firewall-cmd --permanent --add-port=$port/$protocol
            fi
            firewall-cmd --reload
            ;;
        "iptables")
            if [[ $protocol == "both" ]]; then
                iptables -A INPUT -p tcp --dport $port -j ACCEPT
                iptables -A INPUT -p udp --dport $port -j ACCEPT
            else
                iptables -A INPUT -p $protocol --dport $port -j ACCEPT
            fi
            ;;
        "nftables")
            if [[ $protocol == "both" ]]; then
                nft add rule inet filter input tcp dport $port accept 2>/dev/null
                nft add rule inet filter input udp dport $port accept 2>/dev/null
            else
                nft add rule inet filter input $protocol dport $port accept 2>/dev/null
            fi
            ;;
    esac
    
    print_success "已添加端口 $port ($service) - $protocol"
}

# 删除单个端口
remove_single_port() {
    local fw=$1
    local port=$2
    local protocol=$3
    
    case $fw in
        "ufw")
            if [[ $protocol == "both" ]]; then
                ufw delete allow $port/tcp 2>/dev/null
                ufw delete allow $port/udp 2>/dev/null
            else
                ufw delete allow $port/$protocol 2>/dev/null
            fi
            ;;
        "firewalld")
            if [[ $protocol == "both" ]]; then
                firewall-cmd --permanent --remove-port=$port/tcp 2>/dev/null
                firewall-cmd --permanent --remove-port=$port/udp 2>/dev/null
            else
                firewall-cmd --permanent --remove-port=$port/$protocol 2>/dev/null
            fi
            firewall-cmd --reload
            ;;
        "iptables")
            if [[ $protocol == "both" ]]; then
                iptables -D INPUT -p tcp --dport $port -j ACCEPT 2>/dev/null
                iptables -D INPUT -p udp --dport $port -j ACCEPT 2>/dev/null
            else
                iptables -D INPUT -p $protocol --dport $port -j ACCEPT 2>/dev/null
            fi
            ;;
    esac
    
    print_success "已删除端口 $port - $protocol"
}

# 添加自定义端口
add_custom_port() {
    local fw=$1
    
    read -p "请输入端口号: " port
    read -p "请输入服务名称: " service
    
    if [[ $port =~ ^[0-9]+$ ]] && [[ $port -ge 1 ]] && [[ $port -le 65535 ]]; then
        add_single_port $fw $port "$service"
    else
        print_error "无效的端口号"
    fi
}

# 批量添加端口
add_batch_ports() {
    local fw=$1
    
    echo "请输入端口列表 (用空格分隔，如: 80 443 3306):"
    read -p "端口: " ports
    
    read -p "协议 (tcp/udp/both) [tcp]: " protocol
    protocol=${protocol:-tcp}
    
    for port in $ports; do
        if [[ $port =~ ^[0-9]+$ ]] && [[ $port -ge 1 ]] && [[ $port -le 65535 ]]; then
            add_single_port $fw $port "Custom" $protocol
        else
            print_warning "跳过无效端口: $port"
        fi
    done
}

# 显示详细状态
show_detailed_status() {
    local fw=$1
    
    print_header "详细防火墙状态"
    
    case $fw in
        "ufw")
            ufw status verbose 2>/dev/null
            ;;
        "firewalld")
            echo "=== FirewallD 状态 ==="
            firewall-cmd --state 2>/dev/null
            echo
            echo "=== 活动区域 ==="
            firewall-cmd --get-active-zones 2>/dev/null
            echo
            echo "=== 开放端口 ==="
            firewall-cmd --list-ports 2>/dev/null
            echo
            echo "=== 允许的服务 ==="
            firewall-cmd --list-services 2>/dev/null
            ;;
        "iptables")
            echo "=== IPTables 规则 ==="
            iptables -L -n --line-numbers 2>/dev/null
            ;;
        "nftables")
            echo "=== NFTables 规则 ==="
            nft list ruleset 2>/dev/null
            ;;
        "csf")
            echo "=== CSF 状态 ==="
            csf -l 2>/dev/null
            ;;
    esac
}

# 显示安装命令
show_installation_commands() {
    print_header "防火墙安装命令"
    
    case $DISTRO in
        "ubuntu"|"debian")
            echo -e "${GREEN}Ubuntu/Debian 系统:${NC}"
            echo "  UFW (推荐):     sudo apt update && sudo apt install ufw"
            echo "  IPTables:       sudo apt update && sudo apt install iptables-persistent"
            echo "  NFTables:       sudo apt update && sudo apt install nftables"
            echo "  FirewallD:      sudo apt update && sudo apt install firewalld"
            ;;
        "centos"|"rhel"|"fedora"|"rocky"|"almalinux")
            echo -e "${GREEN}CentOS/RHEL/Fedora 系统:${NC}"
            echo "  FirewallD (推荐): sudo dnf install firewalld (或 yum install firewalld)"
            echo "  IPTables:         sudo dnf install iptables-services"
            echo "  NFTables:         sudo dnf install nftables"
            echo "  UFW:              sudo dnf install ufw"
            ;;
        *)
            echo -e "${GREEN}通用安装命令:${NC}"
            echo "  请根据您的包管理器选择:"
            echo "  - apt: apt install [package]"
            echo "  - yum: yum install [package]"
            echo "  - dnf: dnf install [package]"
            echo "  - pacman: pacman -S [package]"
            ;;
    esac
}

# 显示手动命令
show_manual_commands() {
    local fw=$1
    
    print_header "手动命令参考"
    
    case $fw in
        "ufw")
            echo -e "${CYAN}UFW 常用命令:${NC}"
            echo "  启用:           sudo ufw enable"
            echo "  禁用:           sudo ufw disable"
            echo "  状态:           sudo ufw status"
            echo "  详细状态:       sudo ufw status verbose"
            echo "  允许端口:       sudo ufw allow 80/tcp"
            echo "  删除规则:       sudo ufw delete allow 80/tcp"
            echo "  重置:           sudo ufw --force reset"
            echo "  允许IP:         sudo ufw allow from 192.168.1.100"
            echo "  拒绝端口:       sudo ufw deny 23"
            ;;
        "firewalld")
            echo -e "${CYAN}FirewallD 常用命令:${NC}"
            echo "  启动:           sudo systemctl start firewalld"
            echo "  停止:           sudo systemctl stop firewalld"
            echo "  状态:           sudo firewall-cmd --state"
            echo "  开放端口:       sudo firewall-cmd --permanent --add-port=80/tcp"
            echo "  删除端口:       sudo firewall-cmd --permanent --remove-port=80/tcp"
            echo "  重载配置:       sudo firewall-cmd --reload"
            echo "  列出端口:       sudo firewall-cmd --list-ports"
            echo "  列出服务:       sudo firewall-cmd --list-services"
            echo "  添加服务:       sudo firewall-cmd --permanent --add-service=http"
            ;;
        "iptables")
            echo -e "${CYAN}IPTables 常用命令:${NC}"
            echo "  查看规则:       sudo iptables -L -n"
            echo "  允许端口:       sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT"
            echo "  删除规则:       sudo iptables -D INPUT -p tcp --dport 80 -j ACCEPT"
            echo "  保存规则:       sudo iptables-save > /etc/iptables/rules.v4"
            echo "  恢复规则:       sudo iptables-restore < /etc/iptables/rules.v4"
            echo "  清空规则:       sudo iptables -F"
            echo "  设置默认策略:   sudo iptables -P INPUT DROP"
            ;;
        "nftables")
            echo -e "${CYAN}NFTables 常用命令:${NC}"
            echo "  查看规则:       sudo nft list ruleset"
            echo "  添加规则:       sudo nft add rule inet filter input tcp dport 80 accept"
            echo "  删除规则:       sudo nft delete rule inet filter input handle [number]"
            echo "  清空规则:       sudo nft flush ruleset"
            echo "  保存配置:       sudo nft list ruleset > /etc/nftables.conf"
            ;;
        "csf")
            echo -e "${CYAN}CSF 常用命令:${NC}"
            echo "  启动:           sudo csf -s"
            echo "  停止:           sudo csf -f"
            echo "  重启:           sudo csf -r"
            echo "  状态:           sudo csf -l"
            echo "  允许IP:         sudo csf -a 192.168.1.100"
            echo "  拒绝IP:         sudo csf -d 192.168.1.100"
            echo "  测试模式:       编辑 /etc/csf/csf.conf 设置 TESTING = \"1\""
            ;;
    esac
}

# 主菜单
main_menu() {
    while true; do
        clear
        print_header "Linux 防火墙管理工具 v$SCRIPT_VERSION"
        
        detect_linux_distro
        echo
        
        echo "1) 显示防火墙状态"
        echo "2) 选择并管理防火墙"
        echo "3) 快速安全配置"
        echo "4) 系统信息"
        echo "5) 帮助文档"
        echo "0) 退出"
        echo
        
        read -p "请选择操作 (0-5): " main_choice
        
        case $main_choice in
            1)
                show_firewall_status
                pause
                ;;
            2)
                if select_firewall; then
                    manage_firewall_status $SELECTED_FIREWALL
                fi
                ;;
            3)
                quick_security_setup
                ;;
            4)
                show_system_info
                pause
                ;;
            5)
                show_help_documentation
                pause
                ;;
            0)
                print_info "感谢使用 Linux 防火墙管理工具！"
                exit 0
                ;;
            *)
                print_error "无效选择，请输入 0-5"
                sleep 1
                ;;
        esac
    done
}

# 快速安全配置
quick_security_setup() {
    print_header "快速安全配置"
    
    local available_firewalls=($(check_firewall_tools))
    
    if [[ ${#available_firewalls[@]} -eq 0 ]]; then
        print_error "未检测到防火墙工具，请先安装"
        show_installation_commands
        pause
        return
    fi
    
    # 选择推荐的防火墙
    local recommended_fw=""
    case $DISTRO in
        "ubuntu"|"debian")
            if [[ " ${available_firewalls[@]} " =~ " ufw " ]]; then
                recommended_fw="ufw"
            fi
            ;;
        "centos"|"rhel"|"fedora"|"rocky"|"almalinux")
            if [[ " ${available_firewalls[@]} " =~ " firewalld " ]]; then
                recommended_fw="firewalld"
            fi
            ;;
    esac
    
    if [[ -z $recommended_fw ]]; then
        recommended_fw=${available_firewalls[0]}
    fi
    
    print_info "推荐使用: $recommended_fw"
    
    if confirm_action "是否使用推荐配置进行快速安全设置?" "y"; then
        print_info "正在进行快速安全配置..."
        
        # 启用防火墙
        enable_firewall $recommended_fw
        
        # 添加基本端口
        print_info "添加基本服务端口..."
        add_single_port $recommended_fw 22 "SSH" "tcp"
        add_single_port $recommended_fw 80 "HTTP" "tcp"
        add_single_port $recommended_fw 443 "HTTPS" "tcp"
        
        print_success "快速安全配置完成！"
        print_info "已开放端口: SSH(22), HTTP(80), HTTPS(443)"
        
        if confirm_action "是否查看详细状态?"; then
            show_detailed_status $recommended_fw
        fi
    fi
    
    pause
}

# 显示系统信息
show_system_info() {
    print_header "系统信息"
    
    echo -e "${CYAN}系统基本信息:${NC}"
    echo "  操作系统:       $DISTRO_NAME"
    echo "  内核版本:       $(uname -r)"
    echo "  架构:           $(uname -m)"
    echo "  主机名:         $(hostname)"
    echo "  运行时间:       $(uptime -p 2>/dev/null || uptime)"
    echo
    
    echo -e "${CYAN}网络信息:${NC}"
    echo "  IP地址:"
    ip addr show 2>/dev/null | grep -E "inet [0-9]" | grep -v "127.0.0.1" | awk '{print "    " $2}' | head -5
    echo
    
    echo -e "${CYAN}防火墙工具状态:${NC}"
    local available_firewalls=($(check_firewall_tools))
    if [[ ${#available_firewalls[@]} -eq 0 ]]; then
        echo "    未检测到防火墙工具"
    else
        for fw in "${available_firewalls[@]}"; do
            local status=$(check_firewall_status $fw)
            printf "    %-15s %s\n" "$fw:" "$status"
        done
    fi
    echo
    
    echo -e "${CYAN}服务状态:${NC}"
    for service in sshd ssh firewalld ufw iptables nftables; do
        if systemctl list-unit-files 2>/dev/null | grep -q "^$service.service"; then
            local status=$(systemctl is-active $service 2>/dev/null)
            printf "    %-15s %s\n" "$service:" "$status"
        fi
    done
}

# 显示帮助文档
show_help_documentation() {
    print_header "帮助文档"
    
    echo -e "${CYAN}脚本功能说明:${NC}"
    echo "  1. 自动检测系统和可用的防火墙工具"
    echo "  2. 提供统一的防火墙管理界面"
    echo "  3. 支持多种防火墙: UFW, FirewallD, IPTables, NFTables, CSF"
    echo "  4. 提供安全配置建议和快速设置"
    echo "  5. 显示详细的系统和防火墙状态"
    echo
    
    echo -e "${CYAN}使用建议:${NC}"
    echo "  • 新手用户建议使用快速安全配置"
    echo "  • 生产环境请谨慎操作，建议先备份配置"
    echo "  • 远程操作时请确保SSH端口(22)已开放"
    echo "  • 不同防火墙工具不建议同时启用"
    echo
    
    echo -e "${CYAN}常见问题:${NC}"
    echo "  Q: 为什么选择0没有退出选项？"
    echo "  A: 现在已优化，0表示返回上级菜单或退出"
    echo
    echo "  Q: 如何确保SSH连接不被断开？"
    echo "  A: 脚本会自动保留SSH端口(22)的访问权限"
    echo
    echo "  Q: 多个防火墙工具冲突怎么办？"
    echo "  A: 建议只启用一个防火墙工具，其他保持禁用状态"
    echo
    
    echo -e "${CYAN}安全提醒:${NC}"
    echo "  ⚠️  修改防火墙规则前请确保了解其影响"
    echo "  ⚠️  远程操作时务必保持SSH端口开放"
    echo "  ⚠️  生产环境建议在维护窗口期进行操作"
    echo "  ⚠️  重要服务器建议制定防火墙策略文档"
}

# 脚本入口点
main() {
    # 检查root权限
    check_root
    
    # 显示欢迎信息
    clear
    print_header "欢迎使用 Linux 防火墙管理工具"
    print_info "版本: $SCRIPT_VERSION"
    print_info "支持系统: Ubuntu, Debian, CentOS, RHEL, Fedora, Rocky, AlmaLinux"
    print_info "支持防火墙: UFW, FirewallD, IPTables, NFTables, CSF"
    echo
    
    # 检测系统环境
    detect_linux_distro
    echo
    
    # 进入主菜单
    main_menu
}

# 脚本执行入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

