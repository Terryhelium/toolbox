#!/bin/bash

echo "=== 系统环境检测脚本 ==="
echo "执行时间: $(date)"
echo ""

echo "=== 操作系统信息 ==="
cat /etc/os-release
echo ""

echo "=== 系统架构 ==="
uname -m
echo ""

echo "=== CPU 信息 ==="
lscpu | grep -E "Model name|CPU\(s\)|Architecture"
echo ""

echo "=== 内存信息 ==="
free -h
echo ""

echo "=== 磁盘使用情况 ==="
df -h
echo ""

echo "=== 网络接口信息 ==="
ip addr show | grep -E "inet |UP|DOWN" | head -20
echo ""

echo "=== Docker 版本 (如果安装) ==="
if command -v docker &> /dev/null; then
    docker --version
    docker-compose --version 2>/dev/null || echo "docker-compose 未安装"
else
    echo "Docker 未安装"
fi
echo ""

echo "=== Python 版本 (如果安装) ==="
if command -v python3 &> /dev/null; then
    python3 --version
    pip3 --version 2>/dev/null || echo "pip3 未安装"
else
    echo "Python3 未安装"
fi
echo ""

echo "=== Node.js 版本 (如果安装) ==="
if command -v node &> /dev/null; then
    node --version
    npm --version 2>/dev/null || echo "npm 未安装"
else
    echo "Node.js 未安装"
fi
echo ""

echo "=== Java 版本 (如果安装) ==="
if command -v java &> /dev/null; then
    java -version
else
    echo "Java 未安装"
fi
echo ""

echo "=== Maven 版本 (如果安装) ==="
if command -v mvn &> /dev/null; then
    mvn --version | head -1
else
    echo "Maven 未安装"
fi
echo ""

echo "=== Gradle 版本 (如果安装) ==="
if command -v gradle &> /dev/null; then
    gradle --version | head -1
else
    echo "Gradle 未安装"
fi
echo ""

echo "=== Git 版本 (如果安装) ==="
if command -v git &> /dev/null; then
    git --version
else
    echo "Git 未安装"
fi
echo ""

echo "=== 当前 APT 源配置 ==="
if [ -f /etc/apt/sources.list ]; then
    echo "--- /etc/apt/sources.list ---"
    grep -v "^#" /etc/apt/sources.list | grep -v "^$"
fi

if [ -d /etc/apt/sources.list.d/ ]; then
    echo "--- /etc/apt/sources.list.d/ 目录内容 ---"
    ls -la /etc/apt/sources.list.d/
    for file in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
        if [ -f "$file" ]; then
            echo "=== $file ==="
            grep -v "^#" "$file" | grep -v "^$" | head -10
        fi
    done
fi
echo ""

echo "=== Nexus3 服务状态 ==="
if command -v docker &> /dev/null; then
    echo "--- Docker 容器状态 ---"
    docker ps | grep -i nexus || echo "未找到 Nexus 容器"
    echo ""
    echo "--- Docker 网络信息 ---"
    docker network ls
else
    echo "Docker 未安装，检查系统服务"
    systemctl status nexus 2>/dev/null || echo "未找到 nexus 系统服务"
fi
echo ""

echo "=== 网络连通性测试 ==="
echo "测试国内镜像源连通性..."
ping -c 2 mirrors.aliyun.com 2>/dev/null && echo "阿里云镜像: 连通" || echo "阿里云镜像: 不通"
ping -c 2 mirrors.tuna.tsinghua.edu.cn 2>/dev/null && echo "清华镜像: 连通" || echo "清华镜像: 不通"
ping -c 2 mirrors.ustc.edu.cn 2>/dev/null && echo "中科大镜像: 连通" || echo "中科大镜像: 不通"
ping -c 2 registry.npmmirror.com 2>/dev/null && echo "淘宝NPM镜像: 连通" || echo "淘宝NPM镜像: 不通"
echo ""

echo "=== 检测完成 ==="