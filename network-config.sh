#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的文本
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

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要root权限运行"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 检测Linux发行版
detect_linux_version() {
    print_info "正在检测Linux发行版..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$NAME
        OS_VERSION=$VERSION
        OS_ID=$ID
    elif [ -f /etc/redhat-release ]; then
        OS_NAME=$(cat /etc/redhat-release)
        OS_ID="rhel"
    elif [ -f /etc/debian_version ]; then
        OS_NAME="Debian $(cat /etc/debian_version)"
        OS_ID="debian"
    else
        OS_NAME="Unknown"
        OS_ID="unknown"
    fi
    
    echo "================================"
    print_success "系统信息："
    echo "  发行版: $OS_NAME"
    echo "  版本: $OS_VERSION"
    echo "  ID: $OS_ID"
    echo "  内核: $(uname -r)"
    echo "  架构: $(uname -m)"
    echo "================================"
}

# 检测网卡当前配置类型（改进版）
detect_interface_config() {
    local interface=$1
    local config_type="Unknown"
    
    # 首先检查是否有DHCP租约
    if [ -f "/var/lib/dhcp/dhclient.leases" ] && grep -q "$interface" /var/lib/dhcp/dhclient.leases 2>/dev/null; then
        config_type="DHCP (dhclient)"
    elif [ -d "/var/lib/NetworkManager" ] && find /var/lib/NetworkManager -name "*$interface*" -type f 2>/dev/null | grep -q .; then
        # 检查NetworkManager配置
        if command -v nmcli &> /dev/null && systemctl is-active --quiet NetworkManager; then
            local nm_method=$(nmcli -t -f ipv4.method connection show "$interface" 2>/dev/null | cut -d: -f2)
            case $nm_method in
                "auto") config_type="DHCP (NetworkManager)" ;;
                "manual") config_type="静态 (NetworkManager)" ;;
                *) 
                    # 通过ip命令检查是否有dynamic标记
                    if ip addr show "$interface" | grep -q "dynamic"; then
                        config_type="DHCP (动态获取)"
                    else
                        config_type="静态 (可能)"
                    fi
                    ;;
            esac
        fi
    # 检查netplan配置
    elif command -v netplan &> /dev/null && [ -d /etc/netplan ]; then
        for file in /etc/netplan/*.yaml /etc/netplan/*.yml; do
            if [ -f "$file" ] && grep -q "$interface" "$file" 2>/dev/null; then
                if grep -A10 "$interface" "$file" | grep -q "dhcp4: true"; then
                    config_type="DHCP (Netplan)"
                elif grep -A10 "$interface" "$file" | grep -q "addresses:"; then
                    config_type="静态 (Netplan)"
                fi
                break
            fi
        done
    # 检查传统配置文件
    elif [ -f "/etc/sysconfig/network-scripts/ifcfg-$interface" ]; then
        local bootproto=$(grep "BOOTPROTO" "/etc/sysconfig/network-scripts/ifcfg-$interface" 2>/dev/null | cut -d= -f2 | tr -d '"')
        case $bootproto in
            "dhcp") config_type="DHCP (ifcfg)" ;;
            "static") config_type="静态 (ifcfg)" ;;
            *) config_type="Unknown (ifcfg)" ;;
        esac
    elif [ -f "/etc/network/interfaces" ]; then
        if grep -A5 "iface $interface" /etc/network/interfaces 2>/dev/null | grep -q "dhcp"; then
            config_type="DHCP (interfaces)"
        elif grep -A5 "iface $interface" /etc/network/interfaces 2>/dev/null | grep -q "static"; then
            config_type="静态 (interfaces)"
        fi
    fi
    
    # 最后通过系统状态判断
    if [ "$config_type" = "Unknown" ]; then
        if ip addr show "$interface" | grep -q "dynamic"; then
            config_type="DHCP (动态获取)"
        elif ip addr show "$interface" | grep -q "inet.*scope global"; then
            config_type="静态 (可能)"
        else
            config_type="未配置"
        fi
    fi
    
    echo "$config_type"
}

# 显示当前网络信息
show_network_info() {
    print_info "当前网络配置信息："
    echo "================================"
    
    # 显示所有网卡及其配置类型
    print_info "网络接口及配置方式："
    declare -a interfaces
    local i=1
    
    for iface in $(ip link show | grep -E "^[0-9]+:" | cut -d: -f2 | tr -d ' ' | grep -v lo); do
        state=$(ip link show "$iface" | grep -o "state [A-Z]*" | cut -d' ' -f2)
        config_type=$(detect_interface_config "$iface")
        
        # 获取IP信息
        ip_info=$(ip addr show "$iface" | grep "inet " | awk '{print $2}' | head -1)
        if [ -z "$ip_info" ]; then
            ip_info="无IP地址"
        fi
        
        echo "  $i. $iface ($state) - $config_type - $ip_info"
        ((i++))
    done
    
    echo ""
    print_info "路由信息："
    ip route show | head -5
    
    echo ""
    print_info "DNS信息："
    if [ -f /etc/resolv.conf ]; then
        grep nameserver /etc/resolv.conf | head -3
    fi
    echo "================================"
}

# 获取用户输入
get_user_input() {
    echo ""
    print_info "请选择要配置的网络接口："
    
    # 构建网卡数组
    declare -a interfaces
    local i=1
    
    for iface in $(ip link show | grep -E "^[0-9]+:" | cut -d: -f2 | tr -d ' ' | grep -v lo); do
        state=$(ip link show "$iface" | grep -o "state [A-Z]*" | cut -d' ' -f2)
        config_type=$(detect_interface_config "$iface")
        ip_info=$(ip addr show "$iface" | grep "inet " | awk '{print $2}' | head -1)
        if [ -z "$ip_info" ]; then
            ip_info="无IP地址"
        fi
        
        echo "  $i. $iface ($state) - $config_type - $ip_info"
        interfaces[$i]=$iface
        ((i++))
    done
    
    echo "  0. 退出脚本"
    echo ""
    read -p "请选择网卡编号 (0-$((i-1))): " choice
    
    # 处理退出选项
    if [ "$choice" = "0" ]; then
        print_info "用户选择退出"
        exit 0
    fi
    
    # 验证选择
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -ge "$i" ]; then
        print_error "无效的选择！"
        exit 1
    fi
    
    INTERFACE=${interfaces[$choice]}
    print_success "已选择网卡: $INTERFACE"
    
    # 显示当前网卡详细信息
    echo ""
    print_info "当前 $INTERFACE 的详细信息："
    current_config=$(detect_interface_config "$INTERFACE")
    current_ip=$(ip addr show "$INTERFACE" | grep "inet " | awk '{print $2}' | head -1)
    current_gateway=$(ip route | grep "default" | grep "$INTERFACE" | awk '{print $3}' | head -1)
    
    echo "  配置方式: $current_config"
    echo "  当前IP: ${current_ip:-无}"
    echo "  当前网关: ${current_gateway:-无}"
    
    # 选择配置类型
    echo ""
    print_info "请选择IP配置方式："
    echo "  1. DHCP (自动获取IP)"
    echo "  2. 静态IP (手动配置)"
    echo "  0. 返回上级菜单"
    echo ""
    read -p "请选择 (0-2): " ip_type
    
    case $ip_type in
        0)
            print_info "返回上级菜单"
            get_user_input
            ;;
        1)
            CONFIG_TYPE="dhcp"
            print_success "已选择DHCP配置"
            ;;
        2)
            CONFIG_TYPE="static"
            print_success "已选择静态IP配置"
            get_static_config
            ;;
        *)
            print_error "无效的选择！"
            exit 1
            ;;
    esac
}

# 获取静态IP配置
get_static_config() {
    echo ""
    print_info "请输入静态IP配置信息："
    
    read -p "请输入IP地址 (例如: 192.168.1.100): " NEW_IP
    read -p "请输入子网掩码位数 (例如: 24): " NETMASK
    read -p "请输入网关地址 (例如: 192.168.1.1): " GATEWAY
    read -p "请输入主DNS服务器 (例如: 8.8.8.8): " DNS1
    read -p "请输入备用DNS服务器 (可选, 例如: 8.8.4.4): " DNS2
    
    # 验证IP地址格式
    if ! [[ $NEW_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        print_error "IP地址格式不正确！"
        exit 1
    fi
    
    # 验证子网掩码
    if ! [[ $NETMASK =~ ^[0-9]+$ ]] || [ "$NETMASK" -lt 1 ] || [ "$NETMASK" -gt 32 ]; then
        print_error "子网掩码位数应在1-32之间！"
        exit 1
    fi
    
    echo ""
    print_info "静态IP配置摘要："
    echo "  网卡: $INTERFACE"
    echo "  IP地址: $NEW_IP/$NETMASK"
    echo "  网关: $GATEWAY"
    echo "  DNS1: $DNS1"
    echo "  DNS2: $DNS2"
}

# 最终确认
confirm_config() {
    echo ""
    print_warning "配置摘要："
    echo "  网卡: $INTERFACE"
    echo "  配置类型: $CONFIG_TYPE"
    
    if [ "$CONFIG_TYPE" = "static" ]; then
        echo "  IP地址: $NEW_IP/$NETMASK"
        echo "  网关: $GATEWAY"
        echo "  DNS1: $DNS1"
        echo "  DNS2: $DNS2"
    fi
    
    echo ""
    read -p "确认应用此配置？(y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_warning "配置已取消"
        exit 0
    fi
}

# Ubuntu/Debian DHCP配置
configure_ubuntu_debian_dhcp() {
    print_info "配置Ubuntu/Debian DHCP..."
    
    if command -v netplan &> /dev/null; then
        # 备份配置
        for file in /etc/netplan/*.yaml /etc/netplan/*.yml; do
            if [ -f "$file" ]; then
                cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
            fi
        done
        
        # 创建新的netplan配置
        cat > /etc/netplan/01-netcfg.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: true
      dhcp6: false
EOF
        
        # 应用配置
        netplan generate
        netplan apply
        print_success "Netplan DHCP配置已应用"
    else
        # 传统interfaces文件
        cp /etc/network/interfaces /etc/network/interfaces.backup.$(date +%Y%m%d_%H%M%S)
        
        # 移除旧配置
        sed -i "/auto $INTERFACE/,/^$/d" /etc/network/interfaces
        sed -i "/iface $INTERFACE/,/^$/d" /etc/network/interfaces
        
        cat >> /etc/network/interfaces << EOF

# DHCP configuration for $INTERFACE
auto $INTERFACE
iface $INTERFACE inet dhcp
EOF
        
        ifdown $INTERFACE 2>/dev/null || true
        ifup $INTERFACE
        print_success "网络配置已重启"
    fi
}

# Ubuntu/Debian 静态IP配置（修复DNS配置）
configure_ubuntu_debian_static() {
    print_info "配置Ubuntu/Debian静态IP..."
    
    if command -v netplan &> /dev/null; then
        # 备份配置
        for file in /etc/netplan/*.yaml /etc/netplan/*.yml; do
            if [ -f "$file" ]; then
                cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
            fi
        done
        
        # 创建DNS配置
        local dns_config="          addresses: [$DNS1"
        if [ -n "$DNS2" ]; then
            dns_config="$dns_config, $DNS2"
        fi
        dns_config="$dns_config]"
        
        cat > /etc/netplan/01-netcfg.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: false
      addresses:
        - $NEW_IP/$NETMASK
      gateway4: $GATEWAY
      nameservers:
$dns_config
EOF
        
        # 验证配置文件
        if netplan generate; then
            netplan apply
            print_success "Netplan静态IP配置已应用"
        else
            print_error "Netplan配置验证失败"
            return 1
        fi
    else
        # 传统interfaces文件
        cp /etc/network/interfaces /etc/network/interfaces.backup.$(date +%Y%m%d_%H%M%S)
        
        # 移除旧配置
        sed -i "/auto $INTERFACE/,/^$/d" /etc/network/interfaces
        sed -i "/iface $INTERFACE/,/^$/d" /etc/network/interfaces
        
        cat >> /etc/network/interfaces << EOF

# Static IP configuration for $INTERFACE
auto $INTERFACE
iface $INTERFACE inet static
    address $NEW_IP
    netmask $(cidr_to_netmask $NETMASK)
    gateway $GATEWAY
    dns-nameservers $DNS1 $DNS2
EOF
        
        ifdown $INTERFACE 2>/dev/null || true
        ifup $INTERFACE
        print_success "网络配置已重启"
    fi
}

# RedHat系列 DHCP配置
configure_redhat_dhcp() {
    print_info "配置RedHat系列DHCP..."
    
    if systemctl is-active --quiet NetworkManager; then
        # 删除现有连接
        nmcli connection delete "$INTERFACE" 2>/dev/null || true
        
        # 创建DHCP连接
        nmcli connection add type ethernet con-name "$INTERFACE" ifname "$INTERFACE"
        nmcli connection modify "$INTERFACE" ipv4.method auto
        nmcli connection up "$INTERFACE"
        
        print_success "NetworkManager DHCP配置完成"
    else
        if [ -f /etc/sysconfig/network-scripts/ifcfg-$INTERFACE ]; then
            cp /etc/sysconfig/network-scripts/ifcfg-$INTERFACE /etc/sysconfig/network-scripts/ifcfg-$INTERFACE.backup.$(date +%Y%m%d_%H%M%S)
        fi
        
        cat > /etc/sysconfig/network-scripts/ifcfg-$INTERFACE << EOF
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=dhcp
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=$INTERFACE
UUID=$(uuidgen)
DEVICE=$INTERFACE
ONBOOT=yes
EOF
        
        ifdown $INTERFACE 2>/dev/null || true
        ifup $INTERFACE
        print_success "网络服务已重启"
    fi
}

# RedHat系列静态IP配置
configure_redhat_static() {
    print_info "配置RedHat系列静态IP..."
    
    if systemctl is-active --quiet NetworkManager; then
        nmcli connection delete "$INTERFACE" 2>/dev/null || true
        
        nmcli connection add type ethernet con-name "$INTERFACE" ifname "$INTERFACE" \
            ip4 "$NEW_IP/$NETMASK" gw4 "$GATEWAY"
        
        nmcli connection modify "$INTERFACE" ipv4.dns "$DNS1"
        if [ -n "$DNS2" ]; then
            nmcli connection modify "$INTERFACE" +ipv4.dns "$DNS2"
        fi
        
        nmcli connection up "$INTERFACE"
        print_success "NetworkManager静态IP配置完成"
    else
        if [ -f /etc/sysconfig/network-scripts/ifcfg-$INTERFACE ]; then
            cp /etc/sysconfig/network-scripts/ifcfg-$INTERFACE /etc/sysconfig/network-scripts/ifcfg-$INTERFACE.backup.$(date +%Y%m%d_%H%M%S)
        fi
        
        cat > /etc/sysconfig/network-scripts/ifcfg-$INTERFACE << EOF
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=static
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=$INTERFACE
UUID=$(uuidgen)
DEVICE=$INTERFACE
ONBOOT=yes
IPADDR=$NEW_IP
PREFIX=$NETMASK
GATEWAY=$GATEWAY
DNS1=$DNS1
DNS2=$DNS2
EOF
        
        ifdown $INTERFACE 2>/dev/null || true
        ifup $INTERFACE
        print_success "网络服务已重启"
    fi
}

# CIDR转换为子网掩码
cidr_to_netmask() {
    local cidr=$1
    local mask=""
    local full_octets=$(($cidr/8))
    local partial_octet=$(($cidr%8))
    
    for ((i=0;i<4;i++)); do
        if [ $i -lt $full_octets ]; then
            mask="${mask}255"
        elif [ $i -eq $full_octets ]; then
            mask="${mask}$((256 - 2**(8-$partial_octet)))"
        else
            mask="${mask}0"
        fi
        if [ $i -lt 3 ]; then
            mask="${mask}."
        fi
    done
    echo $mask
}

# 应用网络配置
apply_network_config() {
    print_info "根据系统类型和配置类型应用网络配置..."
    
    case $OS_ID in
        "ubuntu"|"debian")
            if [ "$CONFIG_TYPE" = "dhcp" ]; then
                configure_ubuntu_debian_dhcp
            else
                configure_ubuntu_debian_static
            fi
            ;;
        "centos"|"rhel"|"fedora"|"rocky"|"almalinux")
            if [ "$CONFIG_TYPE" = "dhcp" ]; then
                configure_redhat_dhcp
            else
                configure_redhat_static
            fi
            ;;
        *)
            print_warning "未识别的系统类型，尝试通用配置方法..."
            if command -v nmcli &> /dev/null; then
                if [ "$CONFIG_TYPE" = "dhcp" ]; then
                    configure_redhat_dhcp
                else
                    configure_redhat_static
                fi
            elif command -v netplan &> /dev/null; then
                if [ "$CONFIG_TYPE" = "dhcp" ]; then
                    configure_ubuntu_debian_dhcp
                else
                    configure_ubuntu_debian_static
                fi
            else
                print_error "无法确定网络配置方法"
                exit 1
            fi
            ;;
    esac
}

# 验证配置
verify_config() {
    print_info "验证网络配置..."
    sleep 5
    
    echo "================================"
    print_info "新的网络配置："
    ip_info=$(ip addr show $INTERFACE | grep "inet ")
    if [ -n "$ip_info" ]; then
        echo "$ip_info"
    else
        print_warning "未获取到IP地址"
    fi
    
    echo ""
    print_info "路由信息："
    ip route show | grep "$INTERFACE" | head -3
    
    echo ""
    print_info "连通性测试："
    
    # 测试网关连通性
    if [ "$CONFIG_TYPE" = "static" ] && [ -n "$GATEWAY" ]; then
        if ping -c 3 -W 3 $GATEWAY > /dev/null 2>&1; then
            print_success "网关连通性测试通过"
        else
            print_warning "网关连通性测试失败"
        fi
    else
        # DHCP情况下测试默认网关
        default_gw=$(ip route | grep default | awk '{print $3}' | head -1)
        if [ -n "$default_gw" ]; then
            if ping -c 3 -W 3 $default_gw > /dev/null 2>&1; then
                print_success "默认网关连通性测试通过"
            else
                print_warning "默认网关连通性测试失败"
            fi
        fi
    fi
    
    # 测试外网连通性
    if ping -c 3 -W 3 8.8.8.8 > /dev/null 2>&1; then
        print_success "外网连通性测试通过"
    else
        print_warning "外网连通性测试失败"
    fi
    
    # 测试DNS解析
    if nslookup google.com > /dev/null 2>&1; then
        print_success "DNS解析测试通过"
    else
        print_warning "DNS解析测试失败"
    fi
    
    echo "================================"
}

# 主函数
main() {
    echo "========================================"
    echo "    Linux网络配置交互脚本 v2.1"
    echo "========================================"
    
    check_root
    detect_linux_version
    show_network_info
    get_user_input
    confirm_config
    apply_network_config
    verify_config
    
    print_success "网络配置完成！"
    print_info "如果遇到问题，可以使用备份文件恢复原始配置"
    
    # 显示备份文件位置
    echo ""
    print_info "配置文件备份位置："
    find /etc -name "*.backup.*" -newer /tmp 2>/dev/null | head -5
}

# 运行主函数
main "$@"
