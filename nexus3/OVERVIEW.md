# Nexus软件源迁移工具集

本工具集包含以下文件：

## 核心脚本
1. **check_repos.sh** - 软件源检测脚本
   - 检测当前系统的所有软件源配置
   - 分析哪些源可以迁移到Nexus
   - 生成迁移建议报告

2. **configure_nexus.sh** - Nexus配置脚本
   - 自动配置各种软件源指向Nexus
   - 支持APT、YUM、Docker、Python、Java、Node.js等
   - 提供单独配置和批量配置选项

3. **quick_deploy.sh** - 快速部署脚本
   - 一键设置整个迁移环境
   - 自动检查依赖和创建工作目录
   - 生成配置文件和使用指南

## 文档
4. **README.md** - 详细使用文档
   - 完整的使用指南
   - 故障排除方法
   - 支持的系统和软件列表

## 使用流程

### 方式一：快速部署（推荐新用户）
```bash
# 下载并运行快速部署脚本
chmod +x quick_deploy.sh
./quick_deploy.sh your-nexus-server.com 8081
```

### 方式二：手动配置（推荐有经验用户）
```bash
# 1. 检测现有配置
chmod +x check_repos.sh
./check_repos.sh

# 2. 修改Nexus配置
nano configure_nexus.sh  # 修改NEXUS_HOST等变量

# 3. 运行配置
chmod +x configure_nexus.sh
./configure_nexus.sh --all
```

## 特性

✅ 支持多种Linux发行版（Ubuntu、CentOS、Fedora等）
✅ 支持多种包管理器（APT、YUM、DNF等）
✅ 支持开发工具源（Docker、Python、Java、Node.js等）
✅ 自动备份原有配置
✅ 提供配置验证功能
✅ 详细的错误处理和日志输出
✅ 模块化设计，支持单独配置特定软件源

## 安全注意事项

- 脚本会备份原有配置文件
- 建议先在测试环境验证
- 生产环境建议使用HTTPS
- 定期更新Nexus密码

开始使用请查看 README.md 获取详细说明。