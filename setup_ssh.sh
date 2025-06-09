#!/bin/bash

# SSH自动安装配置脚本
# 支持主流Linux发行版

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否以root权限运行
check_root() {
  if [[ $EUID -ne 0 ]]; then
      log_error "此脚本需要root权限运行"
      log_info "请使用: sudo $0"
      exit 1
  fi
}

# 识别Linux发行版
detect_os() {
  log_info "正在识别操作系统..."
  
  if [[ -f /etc/os-release ]]; then
      . /etc/os-release
      OS=$NAME
      VER=$VERSION_ID
      DISTRO=$ID
  elif type lsb_release >/dev/null 2>&1; then
      OS=$(lsb_release -si)
      VER=$(lsb_release -sr)
      DISTRO=$(echo $OS | tr '[:upper:]' '[:lower:]')
  elif [[ -f /etc/redhat-release ]]; then
      OS=$(cat /etc/redhat-release | awk '{print $1}')
      VER=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+')
      DISTRO="rhel"
  else
      log_error "无法识别操作系统"
      exit 1
  fi
  
  log_success "检测到系统: $OS $VER"
}

# 更新包管理器
update_packages() {
  log_info "更新包管理器..."
  
  case $DISTRO in
      ubuntu|debian)
          apt update -y
          ;;
      centos|rhel|fedora|rocky|almalinux)
          if command -v dnf >/dev/null 2>&1; then
              dnf update -y
          else
              yum update -y
          fi
          ;;
      opensuse*|sles)
          zypper refresh
          ;;
      arch)
          pacman -Sy
          ;;
      *)
          log_warning "未知发行版，跳过包更新"
          ;;
  esac
}

# 检查SSH是否已安装
check_ssh_installed() {
  log_info "检查SSH服务状态..."
  
  if command -v sshd >/dev/null 2>&1; then
      log_success "SSH服务已安装"
      return 0
  else
      log_warning "SSH服务未安装"
      return 1
  fi
}

# 安装SSH服务
install_ssh() {
  log_info "正在安装SSH服务..."
  
  case $DISTRO in
      ubuntu|debian)
          apt install -y openssh-server
          ;;
      centos|rhel|fedora|rocky|almalinux)
          if command -v dnf >/dev/null 2>&1; then
              dnf install -y openssh-server
          else
              yum install -y openssh-server
          fi
          ;;
      opensuse*|sles)
          zypper install -y openssh
          ;;
      arch)
          pacman -S --noconfirm openssh
          ;;
      *)
          log_error "不支持的发行版: $DISTRO"
          exit 1
          ;;
  esac
  
  log_success "SSH服务安装完成"
}

# 配置SSH
configure_ssh() {
  log_info "配置SSH服务..."
  
  # 备份原配置文件
  if [[ -f /etc/ssh/sshd_config ]]; then
      cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)
      log_info "已备份原配置文件"
  fi
  
  # SSH配置参数
  SSH_CONFIG="/etc/ssh/sshd_config"
  
  # 基本配置
  sed -i 's/#Port 22/Port 22/' $SSH_CONFIG
  sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' $SSH_CONFIG
  sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' $SSH_CONFIG
  sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' $SSH_CONFIG
  
  # 如果配置项不存在，则添加
  if ! grep -q "^PermitRootLogin" $SSH_CONFIG; then
      echo "PermitRootLogin yes" >> $SSH_CONFIG
  fi
  
  if ! grep -q "^PasswordAuthentication" $SSH_CONFIG; then
      echo "PasswordAuthentication yes" >> $SSH_CONFIG
  fi
  
  if ! grep -q "^PubkeyAuthentication" $SSH_CONFIG; then
      echo "PubkeyAuthentication yes" >> $SSH_CONFIG
  fi
  
  log_success "SSH配置完成"
}

# 获取正确的SSH服务名称
get_ssh_service_name() {
  case $DISTRO in
      ubuntu|debian)
          if systemctl list-unit-files | grep -q "^ssh.service"; then
              echo "ssh"
          elif systemctl list-unit-files | grep -q "^sshd.service"; then
              echo "sshd"
          else
              echo "ssh"  # 默认使用ssh
          fi
          ;;
      *)
          echo "sshd"
          ;;
  esac
}

# 启动并启用SSH服务
start_ssh_service() {
  log_info "启动SSH服务..."
  
  # 检测系统使用的init系统
  if command -v systemctl >/dev/null 2>&1; then
      # systemd - 获取正确的服务名称
      local ssh_service=$(get_ssh_service_name)
      log_info "使用服务名称: $ssh_service"
      
      # 启用服务
      if systemctl enable $ssh_service 2>/dev/null; then
          log_success "$ssh_service 服务已设置为开机自启"
      else
          log_warning "$ssh_service 服务启用失败，尝试手动启动"
      fi
      
      # 启动服务
      if systemctl start $ssh_service 2>/dev/null; then
          log_success "$ssh_service 服务已启动"
      else
          log_warning "$ssh_service 服务启动可能失败，检查状态..."
      fi
      
      # 显示服务状态
      systemctl status $ssh_service --no-pager --lines=5 || true
      
  elif command -v service >/dev/null 2>&1; then
      # SysV init
      case $DISTRO in
          ubuntu|debian)
              service ssh start
              if command -v update-rc.d >/dev/null 2>&1; then
                  update-rc.d ssh enable
              fi
              ;;
          *)
              service sshd start
              if command -v chkconfig >/dev/null 2>&1; then
                  chkconfig sshd on 2>/dev/null || true
              fi
              ;;
      esac
      log_success "SSH服务已启动"
  else
      log_error "无法启动SSH服务，请手动启动"
      exit 1
  fi
}

# 配置防火墙（仅在防火墙已启用时配置）
configure_firewall() {
  log_info "检查防火墙状态..."
  
  local firewall_configured=false
  
  # 检查firewalld
  if command -v firewall-cmd >/dev/null 2>&1; then
      if systemctl is-active --quiet firewalld 2>/dev/null; then
          log_info "检测到firewalld正在运行，配置SSH访问..."
          firewall-cmd --permanent --add-service=ssh
          firewall-cmd --reload
          log_success "firewalld已配置SSH访问"
          firewall_configured=true
      else
          log_info "firewalld已安装但未启用，跳过配置"
      fi
  fi
  
  # 检查ufw（仅在firewalld未配置时检查）
  if ! $firewall_configured && command -v ufw >/dev/null 2>&1; then
      # 检查ufw是否启用
      if ufw status | grep -q "Status: active"; then
          log_info "检测到ufw正在运行，配置SSH访问..."
          ufw allow ssh
          log_success "ufw已配置SSH访问"
          firewall_configured=true
      else
          log_info "ufw已安装但未启用，跳过配置"
      fi
  fi
  
  # 检查iptables（仅在其他防火墙未配置时检查）
  if ! $firewall_configured && command -v iptables >/dev/null 2>&1; then
      # 检查iptables是否有规则（简单判断是否在使用）
      local iptables_rules=$(iptables -L | wc -l)
      if [ $iptables_rules -gt 8 ]; then  # 默认空规则通常是8行左右
          log_info "检测到iptables规则，配置SSH访问..."
          # 检查SSH规则是否已存在
          if ! iptables -C INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null; then
              iptables -A INPUT -p tcp --dport 22 -j ACCEPT
              log_success "iptables已配置SSH访问"
              
              # 尝试保存iptables规则
              if command -v iptables-save >/dev/null 2>&1; then
                  case $DISTRO in
                      ubuntu|debian)
                          if [[ -d /etc/iptables ]]; then
                              iptables-save > /etc/iptables/rules.v4 2>/dev/null && \
                              log_info "iptables规则已保存到 /etc/iptables/rules.v4" || \
                              log_warning "无法保存iptables规则，重启后可能失效"
                          fi
                          ;;
                      centos|rhel|fedora|rocky|almalinux)
                          if [[ -d /etc/sysconfig ]]; then
                              iptables-save > /etc/sysconfig/iptables 2>/dev/null && \
                              log_info "iptables规则已保存到 /etc/sysconfig/iptables" || \
                              log_warning "无法保存iptables规则，重启后可能失效"
                          fi
                          ;;
                  esac
              fi
          else
              log_info "iptables SSH规则已存在"
          fi
          firewall_configured=true
      else
          log_info "iptables未配置规则，跳过配置"
      fi
  fi
  
  # 如果没有检测到任何活跃的防火墙
  if ! $firewall_configured; then
      log_info "未检测到活跃的防火墙服务，无需配置"
      log_warning "建议检查网络安全策略，确保SSH访问安全"
  fi
}

# 验证SSH服务状态
verify_ssh_service() {
  log_info "验证SSH服务状态..."
  
  local ssh_service=$(get_ssh_service_name)
  
  # 检查服务是否运行
  if systemctl is-active --quiet $ssh_service 2>/dev/null; then
      log_success "SSH服务正在运行"
  else
      log_warning "SSH服务可能未正常运行"
  fi
  
  # 检查端口是否监听
  if command -v ss >/dev/null 2>&1; then
      if ss -tlnp | grep -q ":22 "; then
          log_success "SSH端口22正在监听"
      else
          log_warning "SSH端口22未监听"
      fi
  elif command -v netstat >/dev/null 2>&1; then
      if netstat -tlnp | grep -q ":22 "; then
          log_success "SSH端口22正在监听"
      else
          log_warning "SSH端口22未监听"
      fi
  fi
}

# 显示连接信息
show_connection_info() {
  log_info "SSH服务配置完成！"
  echo
  echo "=== 连接信息 ==="
  echo "SSH端口: 22"
  echo "Root登录: 已启用"
  echo "密码认证: 已启用"
  echo "公钥认证: 已启用"
  echo
  echo "本机IP地址:"
  ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print "  " $2}' | cut -d'/' -f1
  echo
  echo "连接命令示例:"
  echo "  ssh root@<服务器IP>"
  echo
}

# 安全建议
security_recommendations() {
  log_warning "=== 安全建议 ==="
  echo "1. 修改默认SSH端口 (编辑 /etc/ssh/sshd_config 中的 Port 参数)"
  echo "2. 禁用root密码登录，使用密钥认证"
  echo "3. 设置强密码策略"
  echo "4. 启用SSH密钥认证并禁用密码认证"
  echo "5. 配置fail2ban防止暴力破解"
  echo "6. 定期更新系统和SSH服务"
  echo "7. 使用非标准用户进行日常操作"
  echo "8. 如果需要防火墙保护，建议启用并配置适当规则"
  echo
  echo "密钥生成命令:"
  echo "  ssh-keygen -t rsa -b 4096 -C 'your_email@example.com'"
  echo
  echo "将公钥复制到服务器:"
  echo "  ssh-copy-id root@<服务器IP>"
  echo
  echo "启用防火墙示例:"
  echo "  # Ubuntu/Debian:"
  echo "  sudo ufw enable"
  echo "  sudo ufw allow ssh"
  echo
  echo "  # CentOS/RHEL/Fedora:"
  echo "  sudo systemctl enable firewalld"
  echo "  sudo systemctl start firewalld"
  echo "  sudo firewall-cmd --permanent --add-service=ssh"
  echo "  sudo firewall-cmd --reload"
  echo
  echo "重启SSH服务命令:"
  local ssh_service=$(get_ssh_service_name)
  echo "  sudo systemctl restart $ssh_service"
  echo
}

# 主函数
main() {
  echo "=== SSH自动安装配置脚本 ==="
  echo
  
  check_root
  detect_os
  update_packages
  
  if ! check_ssh_installed; then
      install_ssh
  fi
  
  configure_ssh
  start_ssh_service
  verify_ssh_service
  configure_firewall
  show_connection_info
  security_recommendations
  
  log_success "脚本执行完成！"
}

# 执行主函数
main "$@"
