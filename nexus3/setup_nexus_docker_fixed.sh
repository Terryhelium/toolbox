#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_header() {
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}    $1"
    echo -e "${CYAN}=========================================${NC}"
    echo
}

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

# Nexus配置
NEXUS_URL="http://192.168.31.217:8082"
NEXUS_USER="admin"
NEXUS_PASS="march23$"

print_header "修复Docker Hub代理仓库创建"

print_info "1. 检查当前Docker仓库状态..."
echo "当前Docker仓库列表:"
curl -s -u "${NEXUS_USER}:${NEXUS_PASS}" \
  "${NEXUS_URL}/service/rest/v1/repositories" | \
  jq -r '.[] | select(.format=="docker") | "\(.name) (\(.format)) - \(.type) - Port: \(.docker.httpPort // \"N/A\")"' 2>/dev/null || {
    echo "Docker仓库列表:"
    curl -s -u "${NEXUS_USER}:${NEXUS_PASS}" \
      "${NEXUS_URL}/service/rest/v1/repositories" | \
      grep -A10 -B2 '"format"[[:space:]]*:[[:space:]]*"docker"'
}
echo

print_info "2. 删除已有的docker-private仓库（如果存在）..."
curl -s -u "${NEXUS_USER}:${NEXUS_PASS}" \
  -X DELETE \
  "${NEXUS_URL}/service/rest/v1/repositories/docker-private" 2>/dev/null
echo "清理完成"
echo

print_info "3. 创建Docker Hub代理仓库（修复版本）..."

# 修复后的Docker Hub代理仓库配置
docker_hub_proxy_config='{
  "name": "docker-hub",
  "online": true,
  "storage": {
    "blobStoreName": "default",
    "strictContentTypeValidation": true
  },
  "proxy": {
    "remoteUrl": "https://registry-1.docker.io",
    "contentMaxAge": 1440,
    "metadataMaxAge": 1440
  },
  "negativeCache": {
    "enabled": true,
    "timeToLive": 1440
  },
  "httpClient": {
    "blocked": false,
    "autoBlock": true,
    "connection": {
      "retries": 0,
      "userAgentSuffix": "string",
      "timeout": 60,
      "enableCircularRedirects": false,
      "enableCookies": false,
      "useTrustStore": false
    }
  },
  "dockerProxy": {
    "indexType": "HUB",
    "useTrustStoreForIndexAccess": false
  },
  "docker": {
    "v1Enabled": false,
    "forceBasicAuth": true,
    "httpPort": 8083
  }
}'

echo "创建docker-hub代理仓库..."
create_response=$(curl -s -w "\n%{http_code}" -u "${NEXUS_USER}:${NEXUS_PASS}" \
  -H "Content-Type: application/json" \
  -X POST \
  "${NEXUS_URL}/service/rest/v1/repositories/docker/proxy" \
  -d "$docker_hub_proxy_config")

http_code=$(echo "$create_response" | tail -n1)
response_body=$(echo "$create_response" | head -n -1)

if [ "$http_code" = "201" ]; then
    print_success "✅ docker-hub代理仓库创建成功！"
elif [ "$http_code" = "400" ] && echo "$response_body" | grep -q "already exists"; then
    print_warning "⚠️  docker-hub仓库已存在"
else
    print_error "❌ 创建失败 (HTTP: $http_code)"
    echo "响应: $response_body"
    echo "尝试备用配置..."
    
    # 备用配置（简化版本）
    docker_hub_simple_config='{
      "name": "docker-hub",
      "online": true,
      "storage": {
        "blobStoreName": "default",
        "strictContentTypeValidation": true
      },
      "proxy": {
        "remoteUrl": "https://registry-1.docker.io",
        "contentMaxAge": 1440,
        "metadataMaxAge": 1440
      },
      "negativeCache": {
        "enabled": true,
        "timeToLive": 1440
      },
      "httpClient": {
        "blocked": false,
        "autoBlock": true
      },
      "docker": {
        "v1Enabled": false,
        "forceBasicAuth": true,
        "httpPort": 8083
      }
    }'
    
    echo "尝试简化配置..."
    create_simple_response=$(curl -s -w "\n%{http_code}" -u "${NEXUS_USER}:${NEXUS_PASS}" \
      -H "Content-Type: application/json" \
      -X POST \
      "${NEXUS_URL}/service/rest/v1/repositories/docker/proxy" \
      -d "$docker_hub_simple_config")
    
    simple_http_code=$(echo "$create_simple_response" | tail -n1)
    simple_response_body=$(echo "$create_simple_response" | head -n -1)
    
    if [ "$simple_http_code" = "201" ]; then
        print_success "✅ docker-hub代理仓库（简化版）创建成功！"
    else
        print_error "❌ 简化配置也失败 (HTTP: $simple_http_code)"
        echo "响应: $simple_response_body"
    fi
fi
echo

print_info "4. 创建Docker私有仓库..."

# Docker私有仓库配置
docker_private_config='{
  "name": "docker-private",
  "online": true,
  "storage": {
    "blobStoreName": "default",
    "strictContentTypeValidation": true,
    "writePolicy": "allow_once"
  },
  "docker": {
    "v1Enabled": false,
    "forceBasicAuth": true,
    "httpPort": 8084
  }
}'

echo "创建docker-private私有仓库..."
create_private_response=$(curl -s -w "\n%{http_code}" -u "${NEXUS_USER}:${NEXUS_PASS}" \
  -H "Content-Type: application/json" \
  -X POST \
  "${NEXUS_URL}/service/rest/v1/repositories/docker/hosted" \
  -d "$docker_private_config")

http_code_private=$(echo "$create_private_response" | tail -n1)
response_body_private=$(echo "$create_private_response" | head -n -1)

if [ "$http_code_private" = "201" ]; then
    print_success "✅ docker-private私有仓库创建成功！"
elif [ "$http_code_private" = "400" ] && echo "$response_body_private" | grep -q "already exists"; then
    print_warning "⚠️  docker-private仓库已存在"
else
    print_error "❌ 创建失败 (HTTP: $http_code_private)"
    echo "响应: $response_body_private"
fi
echo

print_info "5. 等待仓库初始化完成..."
sleep 3

print_info "6. 创建Docker Group仓库..."

# Docker Group仓库配置
docker_group_config='{
  "name": "docker-group",
  "online": true,
  "storage": {
    "blobStoreName": "default",
    "strictContentTypeValidation": true
  },
  "group": {
    "memberNames": ["docker-hub", "docker-private"]
  },
  "docker": {
    "v1Enabled": false,
    "forceBasicAuth": true,
    "httpPort": 8085
  }
}'

echo "创建docker-group组合仓库..."
create_group_response=$(curl -s -w "\n%{http_code}" -u "${NEXUS_USER}:${NEXUS_PASS}" \
  -H "Content-Type: application/json" \
  -X POST \
  "${NEXUS_URL}/service/rest/v1/repositories/docker/group" \
  -d "$docker_group_config")

http_code_group=$(echo "$create_group_response" | tail -n1)
response_body_group=$(echo "$create_group_response" | head -n -1)

if [ "$http_code_group" = "201" ]; then
    print_success "✅ docker-group组合仓库创建成功！"
elif [ "$http_code_group" = "400" ] && echo "$response_body_group" | grep -q "already exists"; then
    print_warning "⚠️  docker-group仓库已存在"
else
    print_error "❌ 创建失败 (HTTP: $http_code_group)"
    echo "响应: $response_body_group"
    
    # 如果docker-hub不存在，只创建包含docker-private的group
    if echo "$response_body_group" | grep -q "does not exist: docker-hub"; then
        print_info "尝试创建仅包含docker-private的组合仓库..."
        docker_group_simple_config='{
          "name": "docker-group",
          "online": true,
          "storage": {
            "blobStoreName": "default",
            "strictContentTypeValidation": true
          },
          "group": {
            "memberNames": ["docker-private"]
          },
          "docker": {
            "v1Enabled": false,
            "forceBasicAuth": true,
            "httpPort": 8085
          }
        }'
        
        create_simple_group_response=$(curl -s -w "\n%{http_code}" -u "${NEXUS_USER}:${NEXUS_PASS}" \
          -H "Content-Type: application/json" \
          -X POST \
          "${NEXUS_URL}/service/rest/v1/repositories/docker/group" \
          -d "$docker_group_simple_config")
        
        simple_group_http_code=$(echo "$create_simple_group_response" | tail -n1)
        
        if [ "$simple_group_http_code" = "201" ]; then
            print_success "✅ docker-group（仅私有仓库）创建成功！"
        else
            print_error "❌ 简化组合仓库创建也失败"
        fi
    fi
fi
echo

print_info "7. 验证最终仓库状态..."
echo "Docker仓库列表:"
curl -s -u "${NEXUS_USER}:${NEXUS_PASS}" \
  "${NEXUS_URL}/service/rest/v1/repositories" | \
  jq -r '.[] | select(.format=="docker") | "\(.name) (\(.format)) - \(.type) - Port: \(.docker.httpPort // \"N/A\")"' 2>/dev/null || {
    echo "使用基础检查:"
    curl -s -u "${NEXUS_USER}:${NEXUS_PASS}" \
      "${NEXUS_URL}/service/rest/v1/repositories" | \
      grep -A5 -B2 '"format"[[:space:]]*:[[:space:]]*"docker"'
}
echo

print_header "Docker客户端配置"

print_info "8. 生成Docker配置文件..."

# 生成新的daemon.json
cat > /tmp/daemon.json << EOF
{
  "registry-mirrors": [
    "http://192.168.31.217:8082/repository/docker-hub/",
    "https://docker.mirrors.ustc.edu.cn/",
    "https://hub-mirror.c.163.com/"
  ],
  "insecure-registries": [
    "192.168.31.217:8082",
    "192.168.31.217:8083",
    "192.168.31.217:8084",
    "192.168.31.217:8085"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

print_success "Docker配置已生成:"
cat /tmp/daemon.json
echo

print_info "9. 应用配置步骤..."
echo "要应用新配置，请执行:"
echo "sudo cp /tmp/daemon.json /etc/docker/daemon.json"
echo "sudo systemctl restart docker"
echo

print_header "测试步骤"

print_info "10. 完整测试流程..."

cat << 'EOF'
# 1. 应用Docker配置
sudo cp /tmp/daemon.json /etc/docker/daemon.json
sudo systemctl restart docker

# 2. 登录到Nexus Docker仓库
docker login 192.168.31.217:8083 -u admin -p march23$
docker login 192.168.31.217:8084 -u admin -p march23$

# 3. 测试拉取镜像（通过代理）
docker pull nginx:alpine

# 4. 测试推送到私有仓库
docker tag nginx:alpine 192.168.31.217:8084/my-nginx:latest
docker push 192.168.31.217:8084/my-nginx:latest

# 5. 验证镜像存储
docker images | grep nginx

# 6. 检查Nexus存储
curl -s -u admin:march23$ \
  "http://192.168.31.217:8082/service/rest/v1/components?repository=docker-private" | \
  jq -r '.items[].name' 2>/dev/null || echo "检查Nexus Web界面"
EOF

print_header "完成"
print_success "修复版Nexus Docker仓库配置完成！"
print_info "现在您可以："
echo "1. 🔄 通过docker-hub代理仓库拉取公共镜像"
echo "2. 📦 使用docker-private仓库存储私有镜像"
echo "3. 🎯 通过docker-group仓库统一访问（如果创建成功）"
echo "4. 🌐 Web界面: http://192.168.31.217:8082"
echo
print_warning "注意: 如果docker-hub代理仓库创建失败，您仍可以使用docker-private仓库存储私有镜像"
