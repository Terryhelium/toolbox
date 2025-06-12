#!/bin/bash
# 一键配置 Nexus 仓库脚本（2025-06-12 更新）

# 1. 备份并禁用所有现有仓库
sudo mkdir -p /etc/yum.repos.d/backup
sudo mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup/ 2>/dev/null

# 2. 配置 Zabbix 仓库
sudo tee /etc/yum.repos.d/zabbix_nexus.repo <<'EOF'
[zabbix-nexus]
name=Zabbix 7 (RHEL8 Compatible)
baseurl=http://10.19.26.136:8082/repository/zabbix-rhel8/
enabled=1
gpgcheck=0
EOF

# 3. 配置 Kylin 仓库
sudo tee /etc/yum.repos.d/kylin_nexus.repo <<'EOF'
[kylin-nexus]
name=Kylin V10SP3 Nexus Mirror
baseurl=http://10.19.26.136:8082/repository/kylin-v10sp3/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-kylin
EOF

# 4. 清理缓存并验证
sudo yum clean all && sudo yum makecache

# 5. 输出结果
echo -e "\n\033[32m[SUCCESS] 仓库配置完成！当前激活仓库：\033[0m"
sudo yum repolist enabled
