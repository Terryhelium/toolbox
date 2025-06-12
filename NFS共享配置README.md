# NFS共享配置指南  
`最后更新：2025-06-12`  
![NFS Logo](https://example.com/nfs-logo.png) *适用于银河麒麟/CentOS/RHEL/Ubuntu等Linux系统*

---

## 📌 快速开始
```bash
# 客户端一键挂载（临时生效）
sudo mount -t nfs <服务器IP>:/共享目录 /本地挂载点
```

---

## 🖥️ **服务端配置**
### 1. 安装必要组件
```bash
# RHEL/CentOS/银河麒麟
sudo yum install -y nfs-utils rpcbind

# Ubuntu/Debian
sudo apt-get install nfs-kernel-server
```

### 2. 创建共享目录
```bash
sudo mkdir -p /data/nfs_share
sudo chown nobody:nobody /data/nfs_share  # 确保匿名访问权限
sudo chmod 1777 /data/nfs_share           # 粘滞位防误删
```

### 3. 配置共享规则
编辑 `/etc/exports` 文件：
```bash
/data/nfs_share 10.19.26.0/24(rw,sync,no_subtree_check)  # 允许内网读写
```
生效配置：
```bash
sudo exportfs -arv
sudo systemctl restart nfs-server
```

### 4. 防火墙设置
```bash
sudo firewall-cmd --permanent --add-service={nfs,mountd,rpc-bind}
sudo firewall-cmd --permanent --add-port=2049/tcp
sudo firewall-cmd --reload
```

---

## 💻 **客户端操作**
### 基础挂载命令
```bash
# 查看服务端共享列表
showmount -e <服务器IP>

# 临时挂载
sudo mount -t nfs <服务器IP>:/data/nfs_share /mnt/nfs_client
```

### 永久挂载配置
编辑 `/etc/fstab` 添加：
```bash
<服务器IP>:/data/nfs_share  /mnt/nfs_client  nfs  defaults,_netdev  0  0
```
执行挂载：
```bash
sudo mount -a
```

---

## 🔍 **故障排查指南**
### 常见错误处理
| 错误现象 | 解决方案 |
|---------|----------|
| `No route to host` | 检查IP拼写/防火墙/网络连通性 |
| `Access denied` | 验证`/etc/exports`权限配置 |
| `Stale file handle` | 强制卸载后重新挂载 |

### 诊断命令包
```bash
# 服务端检查
rpcinfo -p <服务器IP>  # 查看RPC服务注册
sudo exportfs -v       # 验证共享配置

# 客户端调试
sudo mount -v -t nfs -o debug <IP>:/share /mnt  # 详细日志模式
```

---

## 📂 目录结构建议
```
/nfs_share/
├── public    # 公共可写目录（chmod 1777）
├── group1    # 部门专用目录（chown :group1）
└── secure    # 只读目录（ro配置）
```

---

## ⚠️ 安全注意事项
1. 生产环境建议使用`all_squash`映射匿名用户
2. 避免使用`no_root_squash`除非必要
3. 通过`hosts.allow`限制客户端IP范围

---

## 📜 版本记录
| 版本 | 日期       | 修改内容         |
|------|------------|------------------|
| v1.0 | 2025-06-12 | 初始版本发布     |
| v1.1 | 2025-06-15 | 增加安全建议章节 |

