# 加载必要的程序集
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 检查管理员权限
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    [System.Windows.Forms.MessageBox]::Show("此程序需要管理员权限运行！`n请右键选择'以管理员身份运行'", "权限不足", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    exit
}

# 创建主窗体
$form = New-Object System.Windows.Forms.Form
$form.Text = "网络IP配置工具"
$form.Size = New-Object System.Drawing.Size(480, 520)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# 标题标签
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "网络配置工具"
$lblTitle.Font = New-Object System.Drawing.Font("Microsoft YaHei", 16, [System.Drawing.FontStyle]::Bold)
$lblTitle.Location = New-Object System.Drawing.Point(150, 20)
$lblTitle.Size = New-Object System.Drawing.Size(180, 30)
$lblTitle.TextAlign = "MiddleCenter"
$form.Controls.Add($lblTitle)

# 网络适配器选择
$lblAdapter = New-Object System.Windows.Forms.Label
$lblAdapter.Text = "选择网络适配器:"
$lblAdapter.Font = New-Object System.Drawing.Font("Microsoft YaHei", 10)
$lblAdapter.Location = New-Object System.Drawing.Point(30, 70)
$lblAdapter.Size = New-Object System.Drawing.Size(120, 20)
$form.Controls.Add($lblAdapter)

$cmbAdapter = New-Object System.Windows.Forms.ComboBox
$cmbAdapter.Location = New-Object System.Drawing.Point(30, 95)
$cmbAdapter.Size = New-Object System.Drawing.Size(400, 25)
$cmbAdapter.DropDownStyle = "DropDownList"
$form.Controls.Add($cmbAdapter)

# 加载网络适配器
$adapters = Get-NetAdapter -Physical | Where-Object {$_.Status -eq "Up"}
foreach ($adapter in $adapters) {
    $cmbAdapter.Items.Add("$($adapter.Name) - $($adapter.InterfaceDescription)")
}
if ($cmbAdapter.Items.Count -gt 0) {
    $cmbAdapter.SelectedIndex = 0
}

# 配置方式选择
$grpConfig = New-Object System.Windows.Forms.GroupBox
$grpConfig.Text = "配置方式"
$grpConfig.Font = New-Object System.Drawing.Font("Microsoft YaHei", 10)
$grpConfig.Location = New-Object System.Drawing.Point(30, 140)
$grpConfig.Size = New-Object System.Drawing.Size(400, 60)
$form.Controls.Add($grpConfig)

$rbDHCP = New-Object System.Windows.Forms.RadioButton
$rbDHCP.Text = "自动获取IP地址(DHCP)"
$rbDHCP.Font = New-Object System.Drawing.Font("Microsoft YaHei", 9)
$rbDHCP.Location = New-Object System.Drawing.Point(20, 25)
$rbDHCP.Size = New-Object System.Drawing.Size(160, 20)
$rbDHCP.Checked = $true
$grpConfig.Controls.Add($rbDHCP)

$rbStatic = New-Object System.Windows.Forms.RadioButton
$rbStatic.Text = "使用下面的IP地址"
$rbStatic.Font = New-Object System.Drawing.Font("Microsoft YaHei", 9)
$rbStatic.Location = New-Object System.Drawing.Point(200, 25)
$rbStatic.Size = New-Object System.Drawing.Size(140, 20)
$grpConfig.Controls.Add($rbStatic)

# 静态IP配置面板
$grpStatic = New-Object System.Windows.Forms.GroupBox
$grpStatic.Text = "静态IP配置"
$grpStatic.Font = New-Object System.Drawing.Font("Microsoft YaHei", 10)
$grpStatic.Location = New-Object System.Drawing.Point(30, 220)
$grpStatic.Size = New-Object System.Drawing.Size(400, 180)
$grpStatic.Enabled = $false
$form.Controls.Add($grpStatic)

# IP地址
$lblIP = New-Object System.Windows.Forms.Label
$lblIP.Text = "IP地址:"
$lblIP.Font = New-Object System.Drawing.Font("Microsoft YaHei", 9)
$lblIP.Location = New-Object System.Drawing.Point(20, 30)
$lblIP.Size = New-Object System.Drawing.Size(80, 20)
$grpStatic.Controls.Add($lblIP)

$txtIP = New-Object System.Windows.Forms.TextBox
$txtIP.Location = New-Object System.Drawing.Point(100, 28)
$txtIP.Size = New-Object System.Drawing.Size(130, 22)
$txtIP.Font = New-Object System.Drawing.Font("Consolas", 9)
$grpStatic.Controls.Add($txtIP)

# 子网掩码
$lblMask = New-Object System.Windows.Forms.Label
$lblMask.Text = "子网掩码:"
$lblMask.Font = New-Object System.Drawing.Font("Microsoft YaHei", 9)
$lblMask.Location = New-Object System.Drawing.Point(250, 30)
$lblMask.Size = New-Object System.Drawing.Size(80, 20)
$grpStatic.Controls.Add($lblMask)

$txtMask = New-Object System.Windows.Forms.TextBox
$txtMask.Location = New-Object System.Drawing.Point(250, 50)
$txtMask.Size = New-Object System.Drawing.Size(130, 22)
$txtMask.Font = New-Object System.Drawing.Font("Consolas", 9)
$txtMask.Text = "255.255.255.0"
$grpStatic.Controls.Add($txtMask)

# 默认网关
$lblGateway = New-Object System.Windows.Forms.Label
$lblGateway.Text = "默认网关:"
$lblGateway.Font = New-Object System.Drawing.Font("Microsoft YaHei", 9)
$lblGateway.Location = New-Object System.Drawing.Point(20, 70)
$lblGateway.Size = New-Object System.Drawing.Size(80, 20)
$grpStatic.Controls.Add($lblGateway)

$txtGateway = New-Object System.Windows.Forms.TextBox
$txtGateway.Location = New-Object System.Drawing.Point(100, 68)
$txtGateway.Size = New-Object System.Drawing.Size(130, 22)
$txtGateway.Font = New-Object System.Drawing.Font("Consolas", 9)
$grpStatic.Controls.Add($txtGateway)

# DNS服务器
$lblDNS1 = New-Object System.Windows.Forms.Label
$lblDNS1.Text = "首选DNS:"
$lblDNS1.Font = New-Object System.Drawing.Font("Microsoft YaHei", 9)
$lblDNS1.Location = New-Object System.Drawing.Point(20, 110)
$lblDNS1.Size = New-Object System.Drawing.Size(80, 20)
$grpStatic.Controls.Add($lblDNS1)

$txtDNS1 = New-Object System.Windows.Forms.TextBox
$txtDNS1.Location = New-Object System.Drawing.Point(100, 108)
$txtDNS1.Size = New-Object System.Drawing.Size(130, 22)
$txtDNS1.Font = New-Object System.Drawing.Font("Consolas", 9)
$grpStatic.Controls.Add($txtDNS1)

$lblDNS2 = New-Object System.Windows.Forms.Label
$lblDNS2.Text = "备用DNS:"
$lblDNS2.Font = New-Object System.Drawing.Font("Microsoft YaHei", 9)
$lblDNS2.Location = New-Object System.Drawing.Point(250, 110)
$lblDNS2.Size = New-Object System.Drawing.Size(80, 20)
$grpStatic.Controls.Add($lblDNS2)

$txtDNS2 = New-Object System.Windows.Forms.TextBox
$txtDNS2.Location = New-Object System.Drawing.Point(250, 108)
$txtDNS2.Size = New-Object System.Drawing.Size(130, 22)
$txtDNS2.Font = New-Object System.Drawing.Font("Consolas", 9)
$grpStatic.Controls.Add($txtDNS2)

# 按钮
$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Text = "应用配置"
$btnApply.Font = New-Object System.Drawing.Font("Microsoft YaHei", 10, [System.Drawing.FontStyle]::Bold)
$btnApply.Location = New-Object System.Drawing.Point(100, 430)
$btnApply.Size = New-Object System.Drawing.Size(100, 35)
$btnApply.BackColor = [System.Drawing.Color]::LightBlue
$form.Controls.Add($btnApply)

$btnCurrent = New-Object System.Windows.Forms.Button
$btnCurrent.Text = "当前配置"
$btnCurrent.Font = New-Object System.Drawing.Font("Microsoft YaHei", 10)
$btnCurrent.Location = New-Object System.Drawing.Point(220, 430)
$btnCurrent.Size = New-Object System.Drawing.Size(100, 35)
$form.Controls.Add($btnCurrent)

$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = "退出"
$btnExit.Font = New-Object System.Drawing.Font("Microsoft YaHei", 10)
$btnExit.Location = New-Object System.Drawing.Point(340, 430)
$btnExit.Size = New-Object System.Drawing.Size(80, 35)
$form.Controls.Add($btnExit)

# 事件处理
$rbStatic.Add_CheckedChanged({
    $grpStatic.Enabled = $rbStatic.Checked
})

$rbDHCP.Add_CheckedChanged({
    $grpStatic.Enabled = $rbStatic.Checked
})

# IP地址验证函数
function Test-IPAddress {
    param([string]$IP)
    return [System.Net.IPAddress]::TryParse($IP, [ref]$null)
}

# 应用配置按钮事件
$btnApply.Add_Click({
    if ($cmbAdapter.SelectedIndex -eq -1) {
        [System.Windows.Forms.MessageBox]::Show("请选择网络适配器！", "提示", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $adapterName = $cmbAdapter.SelectedItem.ToString().Split('-')[0].Trim()
    
    try {
        if ($rbDHCP.Checked) {
            # 设置DHCP
            Remove-NetIPAddress -InterfaceAlias $adapterName -Confirm:$false -ErrorAction SilentlyContinue
            Remove-NetRoute -InterfaceAlias $adapterName -Confirm:$false -ErrorAction SilentlyContinue
            Set-NetIPInterface -InterfaceAlias $adapterName -Dhcp Enabled
            Set-DnsClientServerAddress -InterfaceAlias $adapterName -ResetServerAddresses
            
            [System.Windows.Forms.MessageBox]::Show("DHCP配置已成功应用！", "成功", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        } else {
            # 验证输入
            if (-not (Test-IPAddress $txtIP.Text)) {
                [System.Windows.Forms.MessageBox]::Show("IP地址格式不正确！", "错误", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                return
            }
            
            if (-not (Test-IPAddress $txtMask.Text)) {
                [System.Windows.Forms.MessageBox]::Show("子网掩码格式不正确！", "错误", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                return
            }
            
            if (-not (Test-IPAddress $txtGateway.Text)) {
                [System.Windows.Forms.MessageBox]::Show("网关地址格式不正确！", "错误", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                return
            }
            
            # 计算前缀长度
            $prefixLength = ([convert]::ToString(([System.Net.IPAddress]$txtMask.Text).Address, 2) -replace '0').Length
            
            # 设置静态IP
            Remove-NetIPAddress -InterfaceAlias $adapterName -Confirm:$false -ErrorAction SilentlyContinue
            Remove-NetRoute -InterfaceAlias $adapterName -Confirm:$false -ErrorAction SilentlyContinue
            New-NetIPAddress -InterfaceAlias $adapterName -IPAddress $txtIP.Text -PrefixLength $prefixLength -DefaultGateway $txtGateway.Text
            
            # 设置DNS
            $dnsServers = @()
            if ($txtDNS1.Text -and (Test-IPAddress $txtDNS1.Text)) {
                $dnsServers += $txtDNS1.Text
            }
            if ($txtDNS2.Text -and (Test-IPAddress $txtDNS2.Text)) {
                $dnsServers += $txtDNS2.Text
            }
            
            if ($dnsServers.Count -gt 0) {
                Set-DnsClientServerAddress -InterfaceAlias $adapterName -ServerAddresses $dnsServers
            }
            
            [System.Windows.Forms.MessageBox]::Show("静态IP配置已成功应用！", "成功", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("配置失败：$($_.Exception.Message)", "错误", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

# 显示当前配置按钮事件
$btnCurrent.Add_Click({
    if ($cmbAdapter.SelectedIndex -eq -1) {
        [System.Windows.Forms.MessageBox]::Show("请选择网络适配器！", "提示", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $adapterName = $cmbAdapter.SelectedItem.ToString().Split('-')[0].Trim()
    $adapter = Get-NetAdapter -Name $adapterName
    $ipConfig = Get-NetIPConfiguration -InterfaceAlias $adapterName
    $ipAddress = Get-NetIPAddress -InterfaceAlias $adapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue
    $dnsServers = Get-DnsClientServerAddress -InterfaceAlias $adapterName -AddressFamily IPv4
    
    $configInfo = "=== 当前网络配置 ===`n`n"
    $configInfo += "适配器名称: $($adapter.Name)`n"
    $configInfo += "物理地址: $($adapter.MacAddress)`n"
    $configInfo += "连接状态: $($adapter.Status)`n`n"
    
    if ($ipAddress) {
        $configInfo += "IP地址: $($ipAddress.IPAddress)`n"
        $configInfo += "子网前缀: $($ipAddress.PrefixLength)`n"
        $configInfo += "DHCP启用: $($ipAddress.PrefixOrigin -eq 'Dhcp')`n"
        
        if ($ipConfig.IPv4DefaultGateway) {
            $configInfo += "默认网关: $($ipConfig.IPv4DefaultGateway.NextHop)`n"
        }
    } else {
        $configInfo += "未分配IP地址`n"
    }
    
    if ($dnsServers.ServerAddresses) {
        $configInfo += "DNS服务器: $($dnsServers.ServerAddresses -join ', ')`n"
    }
    
    [System.Windows.Forms.MessageBox]::Show($configInfo, "当前网络配置", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

# 退出按钮事件
$btnExit.Add_Click({
    $form.Close()
})

# 显示窗体
$form.ShowDialog()
