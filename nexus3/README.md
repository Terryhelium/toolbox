# Linux 软件源迁移到 Nexus 完整指南

## 概述

本指南包含两个主要脚本，帮助您将Linux系统的各种软件源迁移到本地Nexus服务器：

1. `check_repos.sh` - 软件源检测脚本
2. `configure_nexus.sh` - Nexus配置脚本

## 脚本功能

### check_repos.sh 功能
- 自动检测Linux发行版本和架构
- 检查系统软件包管理器源配置（APT/YUM/DNF/Zypper/Pacman）
- 检测Docker相关源配置
- 检查Python包管理器源（pip/conda/poetry）
- 检测Java相关源（Maven/Gradle）
- 检查Node.js相关源（NPM/Yarn/PNPM）
- 检测其他常用软件源（Ruby/Go/Rust/Helm）
- 生成Nexus迁移建议

### configure_nexus.sh 功能
- 检查Nexus服务器连接状态
- 配置系统包管理器指向Nexus
- 配置Docker registry mirrors
- 配置Python pip源
- 配置Java Maven和Gradle源
- 配置Node.js NPM源
- 配置其他软件源
- 验证配置是否生效

## 使用步骤

### 第一步：检测现有软件源

```bash
# 给脚本执行权限
chmod +x check_repos.sh

# 运行检测脚本
./check_repos.sh

# 将输出保存到文件以便分析
./check_repos.sh > repo_analysis.txt 2>&1
```

### 第二步：准备Nexus服务器

在运行配置脚本之前，确保您的Nexus服务器已经配置了以下代理仓库：

#### 必需的Nexus仓库配置：

1. **APT代理仓库** (适用于Ubuntu/Debian)
   - Name: `apt-proxy`
   - Remote storage: `http://archive.ubuntu.com/ubuntu/` 或相应的镜像

2. **YUM代理仓库** (适用于CentOS/RHEL/Rocky/AlmaLinux)
   - Name: `yum-proxy`
   - Remote storage: `http://mirror.centos.org/centos/` 或相应的镜像

3. **Docker代理仓库**
   - Name: `docker-proxy`
   - Remote storage: `https://registry-1.docker.io`

4. **PyPI代理仓库**
   - Name: `pypi-proxy`
   - Remote storage: `https://pypi.org/`

5. **Maven代理仓库**
   - Name: `maven-proxy`
   - Remote storage: `https://repo1.maven.org/maven2/`

6. **NPM代理仓库**
   - Name: `npm-proxy`
   - Remote storage: `https://registry.npmjs.org/`

7. **其他可选仓库**：
   - RubyGems: `rubygems-proxy`
   - Go modules: `go-proxy`
   - Rust Cargo: `cargo-proxy`

### 第三步：配置Nexus脚本

编辑 `configure_nexus.sh` 脚本，修改顶部的配置变量：

```bash
# 配置变量 - 请根据实际情况修改
NEXUS_HOST="your-nexus-server.com"          # 您的Nexus服务器地址
NEXUS_PORT="8081"                           # Nexus端口
NEXUS_USERNAME="admin"                      # Nexus用户名
NEXUS_PASSWORD="your-password"              # Nexus密码
```

### 第四步：运行配置脚本

```bash
# 给脚本执行权限
chmod +x configure_nexus.sh

# 首先测试Nexus连接
./configure_nexus.sh --check

# 配置所有软件源
./configure_nexus.sh --all

# 或者分别配置不同的软件源
./configure_nexus.sh --system    # 仅配置系统包管理器
./configure_nexus.sh --docker    # 仅配置Docker
./configure_nexus.sh --python    # 仅配置Python
./configure_nexus.sh --java      # 仅配置Java相关
./configure_nexus.sh --nodejs    # 仅配置Node.js
./configure_nexus.sh --others    # 仅配置其他软件源

# 验证配置
./configure_nexus.sh --verify
```

## 支持的Linux发行版

- **Ubuntu** (16.04+)
- **Debian** (9+)
- **CentOS** (7+)
- **RHEL** (7+)
- **Rocky Linux**
- **AlmaLinux**
- **Fedora** (30+)
- **openSUSE**
- **Arch Linux**

## 支持的软件包管理器

### 系统级
- APT (Ubuntu/Debian)
- YUM/DNF (CentOS/RHEL/Fedora)
- Zypper (openSUSE)
- Pacman (Arch Linux)

### 语言特定
- **Python**: pip, conda, poetry
- **Java**: Maven, Gradle
- **Node.js**: npm, yarn, pnpm
- **Ruby**: gem
- **Go**: go modules
- **Rust**: cargo
- **Kubernetes**: helm

## 配置文件备份

脚本会自动备份原有配置文件：

- APT: `/etc/apt/sources.list.backup.YYYYMMDD`
- YUM: `/etc/yum.repos.d/backup/`
- Docker: `/etc/docker/daemon.json.backup.YYYYMMDD`
- Maven: `~/.m2/settings.xml.backup.YYYYMMDD`

## 故障排除

### 常见问题

1. **Nexus连接失败**
   ```bash
   # 检查网络连接
   curl -v http://your-nexus-server:8081/service/rest/v1/status
   
   # 检查防火墙设置
   sudo ufw status
   sudo firewall-cmd --list-all
   ```

2. **权限问题**
   ```bash
   # 某些配置需要sudo权限
   sudo ./configure_nexus.sh --system
   ```

3. **Docker配置问题**
   ```bash
   # 重启Docker服务
   sudo systemctl restart docker
   
   # 检查Docker配置
   docker info | grep -i registry
   ```

4. **包管理器更新失败**
   ```bash
   # Ubuntu/Debian
   sudo apt update --allow-insecure-repositories
   
   # CentOS/RHEL
   sudo yum clean all && sudo yum makecache
   ```

### 回滚配置

如果需要回滚到原始配置：

```bash
# APT回滚
sudo cp /etc/apt/sources.list.backup.* /etc/apt/sources.list

# YUM回滚
sudo rm /etc/yum.repos.d/nexus.repo
sudo mv /etc/yum.repos.d/backup/*.repo /etc/yum.repos.d/

# Docker回滚
sudo cp /etc/docker/daemon.json.backup.* /etc/docker/daemon.json
sudo systemctl restart docker

# Maven回滚
cp ~/.m2/settings.xml.backup.* ~/.m2/settings.xml
```

## 验证配置

### 系统包管理器
```bash
# Ubuntu/Debian
apt update && apt search curl

# CentOS/RHEL/Fedora
yum check-update || dnf check-update
```

### Docker
```bash
# 拉取测试镜像
docker pull hello-world

# 检查registry配置
docker info | grep -A5 "Registry Mirrors"
```

### Python
```bash
# 测试pip安装
pip install --dry-run requests

# 检查pip配置
pip config list
```

### Java
```bash
# Maven测试
mvn help:effective-settings

# Gradle测试
gradle dependencies --configuration compileClasspath
```

### Node.js
```bash
# NPM测试
npm config get registry
npm search express

# Yarn测试
yarn config get registry
```

## 性能优化建议

1. **网络优化**
   - 确保Nexus服务器与客户端之间的网络延迟较低
   - 考虑在不同地理位置部署多个Nexus实例

2. **存储优化**
   - 为Nexus配置足够的磁盘空间
   - 定期清理不需要的缓存

3. **缓存策略**
   - 合理配置各仓库的缓存时间
   - 对于稳定版本，可以设置较长的缓存时间

## 安全考虑

1. **HTTPS配置**
   - 生产环境建议配置HTTPS
   - 更新脚本中的URL为https://

2. **认证配置**
   - 为不同的仓库配置适当的访问权限
   - 定期更新Nexus密码

3. **网络安全**
   - 限制Nexus服务器的网络访问
   - 配置防火墙规则

## 监控和维护

1. **日志监控**
   ```bash
   # 查看Nexus日志
   tail -f /opt/sonatype/nexus/log/nexus.log
   ```

2. **磁盘空间监控**
   ```bash
   # 检查磁盘使用情况
   df -h /opt/sonatype/nexus/
   ```

3. **定期维护**
   - 定期清理不需要的组件
   - 更新Nexus到最新版本
   - 备份重要配置

## 联系和支持

如果在使用过程中遇到问题，可以：

1. 检查Nexus官方文档
2. 查看相关软件包管理器的文档
3. 检查系统日志文件

---

**注意**: 在生产环境中使用前，请先在测试环境中验证所有配置。