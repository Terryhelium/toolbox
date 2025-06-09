#!/bin/bash

# Ubuntu 24.04 Filebeat 离线配置脚本
# 服务器信息: 100.69.1.134
# 用户名: elastic
# 密码: ElkStack2024!

set -e

echo "=========================================="
echo "Ubuntu Filebeat 离线配置脚本"
echo "=========================================="

# 检查是否为 root 用户
if [[ $EUID -ne 0 ]]; then
 echo "请使用 sudo 运行此脚本"
 exit 1
fi

# 检查 Filebeat 是否已安装
echo "检查 Filebeat 安装状态..."
if ! command -v filebeat &> /dev/null; then
  echo "❌ Filebeat 未安装！请先安装 Filebeat"
  echo "安装命令: sudo dpkg -i filebeat-*.deb"
  exit 1
else
  echo "✅ Filebeat 已安装"
  filebeat version
fi

# 检查配置文件是否存在
if [ ! -f /etc/filebeat/filebeat.yml ]; then
  echo "❌ Filebeat 配置文件不存在！"
  exit 1
fi

# 备份原始配置文件
echo "备份原始配置文件..."
cp /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.yml.backup.$(date +%Y%m%d_%H%M%S)

# 创建新的配置文件
echo "创建 Filebeat 配置文件..."
cat > /etc/filebeat/filebeat.yml << 'EOF'
# Filebeat 配置文件
# 服务器: 100.69.1.134

filebeat.inputs:
- type: log
enabled: true
paths:
  - /var/log/*.log
  - /var/log/messages
  - /var/log/syslog
  - /var/log/auth.log
  - /var/log/kern.log
  - /var/log/daemon.log
fields:
  logtype: system
  os: ubuntu
  hostname: "${HOSTNAME}"
fields_under_root: true

- type: log
enabled: true
paths:
  - /var/log/apache2/*.log
  - /var/log/nginx/*.log
fields:
  logtype: webserver
  os: ubuntu
  hostname: "${HOSTNAME}"
fields_under_root: true

# 输出到 Elasticsearch
output.elasticsearch:
hosts: ["100.69.1.134:9200"]
username: "elastic"
password: "ElkStack2024!"
index: "filebeat-ubuntu-%{+yyyy.MM.dd}"

# Kibana 设置
setup.kibana:
host: "100.69.1.134:5601"
username: "elastic"
password: "ElkStack2024!"

# 日志设置
logging.level: info
logging.to_files: true
logging.files:
path: /var/log/filebeat
name: filebeat
keepfiles: 7
permissions: 0644

# 处理器设置
processors:
- add_host_metadata:
    when.not.contains.tags: forwarded
- add_cloud_metadata: ~
- add_docker_metadata: ~
EOF

# 设置配置文件权限
chmod 600 /etc/filebeat/filebeat.yml
chown root:root /etc/filebeat/filebeat.yml

# 测试配置文件
echo "测试 Filebeat 配置..."
if filebeat test config; then
  echo "✅ 配置文件语法正确"
else
  echo "❌ 配置文件语法错误"
  exit 1
fi

# 测试连接到 Elasticsearch
echo "测试连接到 Elasticsearch..."
if timeout 10 filebeat test output; then
  echo "✅ 成功连接到 Elasticsearch"
else
  echo "⚠️  无法连接到 Elasticsearch，但配置已完成"
fi

# 检查服务状态
echo "检查 Filebeat 服务状态..."
if systemctl is-active --quiet filebeat; then
  echo "✅ Filebeat 服务正在运行"
  echo "重启服务以应用新配置..."
  systemctl restart filebeat
else
  echo "⚠️  Filebeat 服务未运行，正在启动..."
  systemctl enable filebeat
  systemctl start filebeat
fi

# 等待服务启动
sleep 3

# 最终状态检查
echo "=========================================="
echo "最终状态检查:"
echo "=========================================="

# 检查服务状态
if systemctl is-active --quiet filebeat; then
  echo "✅ Filebeat 服务: 运行中"
else
  echo "❌ Filebeat 服务: 未运行"
fi

# 检查服务是否开机自启
if systemctl is-enabled --quiet filebeat; then
  echo "✅ 开机自启: 已启用"
else
  echo "⚠️  开机自启: 未启用"
  systemctl enable filebeat
fi

# 显示最近日志
echo "=========================================="
echo "最近的 Filebeat 日志:"
echo "=========================================="
if [ -f /var/log/filebeat/filebeat ]; then
  tail -n 10 /var/log/filebeat/filebeat
else
  journalctl -u filebeat -n 10 --no-pager
fi

echo "=========================================="
echo "Ubuntu Filebeat 配置完成！"
echo "服务器: 100.69.1.134"
echo "用户名: elastic"
echo "=========================================="
echo "常用命令:"
echo "查看状态: sudo systemctl status filebeat"
echo "查看日志: sudo tail -f /var/log/filebeat/filebeat"
echo "重启服务: sudo systemctl restart filebeat"
echo "测试配置: sudo filebeat test config"
echo "测试输出: sudo filebeat test output"
echo "=========================================="
EOF