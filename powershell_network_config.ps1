# 检查管理员权限
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "此脚本需要管理员权限运行！" -ForegroundColor Red
    Start-Process PowerShell -Verb RunAs "-File `"$PSCommandPath`""
    exit
}

# 主函数
function Show-NetworkConfig {
    Clear-Host
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "        网络配置工具" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host ""
    
    # 获取网络适配器
    $adapters = Get-NetAdapter -Physical | Where-Object {$_.Status -eq "Up"}
    if ($adapters.Count -eq 0) {
        Write-Host "未找到可用的网络适配器！" -ForegroundColor Red
        pause
        return
    }
    
    # 选择网络适配器
    if ($adapters.Count -gt 1) {
        Write-Host "检测到多个网络适配器：" -ForegroundColor Yellow
        for ($i = 0; $i -lt $adapters.Count; $i++) {
            Write-Host "$($i+1). $($adapters[$i].Name) - $($adapters[$i].InterfaceDescription)" -ForegroundColor White
        }
        
        do {
            $selection = Read-Host "请选择网络适配器 (1-$($adapters.Count))"
            $adapterIndex = [int]$selection - 1
        } while ($adapterIndex -lt 0 -or $adapterIndex -ge $adapters.Count)
        
        $selectedAdapter = $adapters[$adapterIndex]
    } else {
        $selectedAdapter = $adapters[0]
        Write-Host "使用网络适配器: $($selectedAdapter.Name)" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "1. 设置为DHCP自动获取" -ForegroundColor White
    Write-Host "2. 设置静态IP地址" -ForegroundColor White
    Write-Host "3. 显示当前网络配置" -ForegroundColor White
    Write-Host "4. 退出" -ForegroundColor White
    Write-Host ""
    
    $choice = Read-Host "请选择操作 (1-4)"
    
    switch ($choice) {
        "1" { Set-DHCPConfig -AdapterName $selectedAdapter.Name }
        "2" { Set-StaticConfig -AdapterName $selectedAdapter.Name }
        "3" { Show-CurrentConfig -AdapterName $selectedAdapter.Name }
        "4" { exit }
        default { 
            Write-Host "无效选择！" -ForegroundColor Red 
            Start-Sleep 2
            Show-NetworkConfig
        }
    }
}

# 设置DHCP
function Set-DHCPConfig {
    param([string]$AdapterName)
    
    try {
        Write-Host "正在设置为DHCP自动获取..." -ForegroundColor Yellow
        
        # 移除现有IP配置
        Remove-NetIPAddress -InterfaceAlias $AdapterName -Confirm:$false -ErrorAction SilentlyContinue
        Remove-NetRoute -InterfaceAlias $AdapterName -Confirm:$false -ErrorAction SilentlyContinue
        
        # 设置为DHCP
        Set-NetIPInterface -InterfaceAlias $AdapterName -Dhcp Enabled
        Set-DnsClientServerAddress -InterfaceAlias $AdapterName -ResetServerAddresses
        
        Write-Host "DHCP设置完成！" -ForegroundColor Green
        Write-Host "正在更新IP配置..." -ForegroundColor Yellow
        
        # 更新DHCP配置
        ipconfig /renew
        
        Show-CurrentConfig -AdapterName $AdapterName
        
    } catch {
        Write-Host "设置DHCP时出错: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "按任意键继续"
    Show-NetworkConfig
}

# 设置静态IP
function Set-StaticConfig {
    param([string]$AdapterName)
    
    Write-Host "=== 静态IP配置 ===" -ForegroundColor Cyan
    
    # 输入验证函数
    function Test-IPAddress {
        param([string]$IP)
        return [System.Net.IPAddress]::TryParse($IP, [ref]$null)
    }
    
    # 获取IP地址
    do {
        $ipAddress = Read-Host "请输入IP地址"
        if (-not (Test-IPAddress $ipAddress)) {
            Write-Host "IP地址格式不正确！" -ForegroundColor Red
        }
    } while (-not (Test-IPAddress $ipAddress))
    
    # 获取子网掩码
    do {
        $subnetMask = Read-Host "请输入子网掩码 (默认: 255.255.255.0)"
        if ([string]::IsNullOrEmpty($subnetMask)) {
            $subnetMask = "255.255.255.0"
        }
        if (-not (Test-IPAddress $subnetMask)) {
            Write-Host "子网掩码格式不正确！" -ForegroundColor Red
        }
    } while (-not (Test-IPAddress $subnetMask))
    
    # 计算前缀长度
    $prefixLength = ([convert]::ToString(([System.Net.IPAddress]$subnetMask).Address, 2) -replace '0').Length
    
    # 获取网关
    do {
        $gateway = Read-Host "请输入网关地址"
        if (-not (Test-IPAddress $gateway)) {
            Write-Host "网关地址格式不正确！" -ForegroundColor Red
        }
    } while (-not (Test-IPAddress $gateway))
    
    # 获取DNS
    $dns1 = Read-Host "请输入首选DNS (可选)"
    $dns2 = Read-Host "请输入备用DNS (可选)"
    
    try {
        Write-Host "正在设置静态IP配置..." -ForegroundColor Yellow
        
        # 移除现有配置
        Remove-NetIPAddress -InterfaceAlias $AdapterName -Confirm:$false -ErrorAction SilentlyContinue
        Remove-NetRoute -InterfaceAlias $AdapterName -Confirm:$false -ErrorAction SilentlyContinue
        
        # 设置静态IP
        New-NetIPAddress -InterfaceAlias $AdapterName -IPAddress $ipAddress -PrefixLength $prefixLength -DefaultGateway $gateway
        
        # 设置DNS
        $dnsServers = @()
        if (![string]::IsNullOrEmpty($dns1) -and (Test-IPAddress $dns1)) {
            $dnsServers += $dns1
        }
        if (![string]::IsNullOrEmpty($dns2) -and (Test-IPAddress $dns2)) {
            $dnsServers += $dns2
        }
        
        if ($dnsServers.Count -gt 0) {
            Set-DnsClientServerAddress -InterfaceAlias $AdapterName -ServerAddresses $dnsServers
        }
        
        Write-Host "静态IP设置完成！" -ForegroundColor Green
        Show-CurrentConfig -AdapterName $AdapterName
        
    } catch {
        Write-Host "设置静态IP时出错: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "按任意键继续"
    Show-NetworkConfig
}

# 显示当前配置
function Show-CurrentConfig {
    param([string]$AdapterName)
    
    Write-Host ""
    Write-Host "=== 当前网络配置 ===" -ForegroundColor Cyan
    
    $adapter = Get-NetAdapter -Name $AdapterName
    $ipConfig = Get-NetIPConfiguration -InterfaceAlias $AdapterName
    $ipAddress = Get-NetIPAddress -InterfaceAlias $AdapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue
    $dnsServers = Get-DnsClientServerAddress -InterfaceAlias $AdapterName -AddressFamily IPv4
    
    Write-Host "适配器名称: $($adapter.Name)" -ForegroundColor White
    Write-Host "物理地址: $($adapter.MacAddress)" -ForegroundColor White
    Write-Host "连接状态: $($adapter.Status)" -ForegroundColor White
    
    if ($ipAddress) {
        Write-Host "IP地址: $($ipAddress.IPAddress)" -ForegroundColor White
        Write-Host "子网掩码: $($ipAddress.PrefixLength)" -ForegroundColor White
        
        if ($ipConfig.IPv4DefaultGateway) {
            Write-Host "默认网关: $($ipConfig.IPv4DefaultGateway.NextHop)" -ForegroundColor White
        }
        
        Write-Host "DHCP启用: $($ipAddress.PrefixOrigin -eq 'Dhcp')" -ForegroundColor White
    } else {
        Write-Host "未分配IP地址" -ForegroundColor Red
    }
    
    if ($dnsServers.ServerAddresses) {
        Write-Host "DNS服务器: $($dnsServers.ServerAddresses -join ', ')" -ForegroundColor White
    }
    
    Write-Host ""
}

# 启动主程序
Show-NetworkConfig
