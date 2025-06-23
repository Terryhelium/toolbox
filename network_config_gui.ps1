# ���ر�Ҫ�ĳ���
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ������ԱȨ��
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    [System.Windows.Forms.MessageBox]::Show("�˳�����Ҫ����ԱȨ�����У�`n���Ҽ�ѡ��'�Թ���Ա�������'", "Ȩ�޲���", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    exit
}

# ����������
$form = New-Object System.Windows.Forms.Form
$form.Text = "����IP���ù���"
$form.Size = New-Object System.Drawing.Size(480, 520)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# �����ǩ
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "�������ù���"
$lblTitle.Font = New-Object System.Drawing.Font("Microsoft YaHei", 16, [System.Drawing.FontStyle]::Bold)
$lblTitle.Location = New-Object System.Drawing.Point(150, 20)
$lblTitle.Size = New-Object System.Drawing.Size(180, 30)
$lblTitle.TextAlign = "MiddleCenter"
$form.Controls.Add($lblTitle)

# ����������ѡ��
$lblAdapter = New-Object System.Windows.Forms.Label
$lblAdapter.Text = "ѡ������������:"
$lblAdapter.Font = New-Object System.Drawing.Font("Microsoft YaHei", 10)
$lblAdapter.Location = New-Object System.Drawing.Point(30, 70)
$lblAdapter.Size = New-Object System.Drawing.Size(120, 20)
$form.Controls.Add($lblAdapter)

$cmbAdapter = New-Object System.Windows.Forms.ComboBox
$cmbAdapter.Location = New-Object System.Drawing.Point(30, 95)
$cmbAdapter.Size = New-Object System.Drawing.Size(400, 25)
$cmbAdapter.DropDownStyle = "DropDownList"
$form.Controls.Add($cmbAdapter)

# ��������������
$adapters = Get-NetAdapter -Physical | Where-Object {$_.Status -eq "Up"}
foreach ($adapter in $adapters) {
    $cmbAdapter.Items.Add("$($adapter.Name) - $($adapter.InterfaceDescription)")
}
if ($cmbAdapter.Items.Count -gt 0) {
    $cmbAdapter.SelectedIndex = 0
}

# ���÷�ʽѡ��
$grpConfig = New-Object System.Windows.Forms.GroupBox
$grpConfig.Text = "���÷�ʽ"
$grpConfig.Font = New-Object System.Drawing.Font("Microsoft YaHei", 10)
$grpConfig.Location = New-Object System.Drawing.Point(30, 140)
$grpConfig.Size = New-Object System.Drawing.Size(400, 60)
$form.Controls.Add($grpConfig)

$rbDHCP = New-Object System.Windows.Forms.RadioButton
$rbDHCP.Text = "�Զ���ȡIP��ַ(DHCP)"
$rbDHCP.Font = New-Object System.Drawing.Font("Microsoft YaHei", 9)
$rbDHCP.Location = New-Object System.Drawing.Point(20, 25)
$rbDHCP.Size = New-Object System.Drawing.Size(160, 20)
$rbDHCP.Checked = $true
$grpConfig.Controls.Add($rbDHCP)

$rbStatic = New-Object System.Windows.Forms.RadioButton
$rbStatic.Text = "ʹ�������IP��ַ"
$rbStatic.Font = New-Object System.Drawing.Font("Microsoft YaHei", 9)
$rbStatic.Location = New-Object System.Drawing.Point(200, 25)
$rbStatic.Size = New-Object System.Drawing.Size(140, 20)
$grpConfig.Controls.Add($rbStatic)

# ��̬IP�������
$grpStatic = New-Object System.Windows.Forms.GroupBox
$grpStatic.Text = "��̬IP����"
$grpStatic.Font = New-Object System.Drawing.Font("Microsoft YaHei", 10)
$grpStatic.Location = New-Object System.Drawing.Point(30, 220)
$grpStatic.Size = New-Object System.Drawing.Size(400, 180)
$grpStatic.Enabled = $false
$form.Controls.Add($grpStatic)

# IP��ַ
$lblIP = New-Object System.Windows.Forms.Label
$lblIP.Text = "IP��ַ:"
$lblIP.Font = New-Object System.Drawing.Font("Microsoft YaHei", 9)
$lblIP.Location = New-Object System.Drawing.Point(20, 30)
$lblIP.Size = New-Object System.Drawing.Size(80, 20)
$grpStatic.Controls.Add($lblIP)

$txtIP = New-Object System.Windows.Forms.TextBox
$txtIP.Location = New-Object System.Drawing.Point(100, 28)
$txtIP.Size = New-Object System.Drawing.Size(130, 22)
$txtIP.Font = New-Object System.Drawing.Font("Consolas", 9)
$grpStatic.Controls.Add($txtIP)

# ��������
$lblMask = New-Object System.Windows.Forms.Label
$lblMask.Text = "��������:"
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

# Ĭ������
$lblGateway = New-Object System.Windows.Forms.Label
$lblGateway.Text = "Ĭ������:"
$lblGateway.Font = New-Object System.Drawing.Font("Microsoft YaHei", 9)
$lblGateway.Location = New-Object System.Drawing.Point(20, 70)
$lblGateway.Size = New-Object System.Drawing.Size(80, 20)
$grpStatic.Controls.Add($lblGateway)

$txtGateway = New-Object System.Windows.Forms.TextBox
$txtGateway.Location = New-Object System.Drawing.Point(100, 68)
$txtGateway.Size = New-Object System.Drawing.Size(130, 22)
$txtGateway.Font = New-Object System.Drawing.Font("Consolas", 9)
$grpStatic.Controls.Add($txtGateway)

# DNS������
$lblDNS1 = New-Object System.Windows.Forms.Label
$lblDNS1.Text = "��ѡDNS:"
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
$lblDNS2.Text = "����DNS:"
$lblDNS2.Font = New-Object System.Drawing.Font("Microsoft YaHei", 9)
$lblDNS2.Location = New-Object System.Drawing.Point(250, 110)
$lblDNS2.Size = New-Object System.Drawing.Size(80, 20)
$grpStatic.Controls.Add($lblDNS2)

$txtDNS2 = New-Object System.Windows.Forms.TextBox
$txtDNS2.Location = New-Object System.Drawing.Point(250, 108)
$txtDNS2.Size = New-Object System.Drawing.Size(130, 22)
$txtDNS2.Font = New-Object System.Drawing.Font("Consolas", 9)
$grpStatic.Controls.Add($txtDNS2)

# ��ť
$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Text = "Ӧ������"
$btnApply.Font = New-Object System.Drawing.Font("Microsoft YaHei", 10, [System.Drawing.FontStyle]::Bold)
$btnApply.Location = New-Object System.Drawing.Point(100, 430)
$btnApply.Size = New-Object System.Drawing.Size(100, 35)
$btnApply.BackColor = [System.Drawing.Color]::LightBlue
$form.Controls.Add($btnApply)

$btnCurrent = New-Object System.Windows.Forms.Button
$btnCurrent.Text = "��ǰ����"
$btnCurrent.Font = New-Object System.Drawing.Font("Microsoft YaHei", 10)
$btnCurrent.Location = New-Object System.Drawing.Point(220, 430)
$btnCurrent.Size = New-Object System.Drawing.Size(100, 35)
$form.Controls.Add($btnCurrent)

$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = "�˳�"
$btnExit.Font = New-Object System.Drawing.Font("Microsoft YaHei", 10)
$btnExit.Location = New-Object System.Drawing.Point(340, 430)
$btnExit.Size = New-Object System.Drawing.Size(80, 35)
$form.Controls.Add($btnExit)

# �¼�����
$rbStatic.Add_CheckedChanged({
    $grpStatic.Enabled = $rbStatic.Checked
})

$rbDHCP.Add_CheckedChanged({
    $grpStatic.Enabled = $rbStatic.Checked
})

# IP��ַ��֤����
function Test-IPAddress {
    param([string]$IP)
    return [System.Net.IPAddress]::TryParse($IP, [ref]$null)
}

# Ӧ�����ð�ť�¼�
$btnApply.Add_Click({
    if ($cmbAdapter.SelectedIndex -eq -1) {
        [System.Windows.Forms.MessageBox]::Show("��ѡ��������������", "��ʾ", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $adapterName = $cmbAdapter.SelectedItem.ToString().Split('-')[0].Trim()
    
    try {
        if ($rbDHCP.Checked) {
            # ����DHCP
            Remove-NetIPAddress -InterfaceAlias $adapterName -Confirm:$false -ErrorAction SilentlyContinue
            Remove-NetRoute -InterfaceAlias $adapterName -Confirm:$false -ErrorAction SilentlyContinue
            Set-NetIPInterface -InterfaceAlias $adapterName -Dhcp Enabled
            Set-DnsClientServerAddress -InterfaceAlias $adapterName -ResetServerAddresses
            
            [System.Windows.Forms.MessageBox]::Show("DHCP�����ѳɹ�Ӧ�ã�", "�ɹ�", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        } else {
            # ��֤����
            if (-not (Test-IPAddress $txtIP.Text)) {
                [System.Windows.Forms.MessageBox]::Show("IP��ַ��ʽ����ȷ��", "����", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                return
            }
            
            if (-not (Test-IPAddress $txtMask.Text)) {
                [System.Windows.Forms.MessageBox]::Show("���������ʽ����ȷ��", "����", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                return
            }
            
            if (-not (Test-IPAddress $txtGateway.Text)) {
                [System.Windows.Forms.MessageBox]::Show("���ص�ַ��ʽ����ȷ��", "����", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                return
            }
            
            # ����ǰ׺����
            $prefixLength = ([convert]::ToString(([System.Net.IPAddress]$txtMask.Text).Address, 2) -replace '0').Length
            
            # ���þ�̬IP
            Remove-NetIPAddress -InterfaceAlias $adapterName -Confirm:$false -ErrorAction SilentlyContinue
            Remove-NetRoute -InterfaceAlias $adapterName -Confirm:$false -ErrorAction SilentlyContinue
            New-NetIPAddress -InterfaceAlias $adapterName -IPAddress $txtIP.Text -PrefixLength $prefixLength -DefaultGateway $txtGateway.Text
            
            # ����DNS
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
            
            [System.Windows.Forms.MessageBox]::Show("��̬IP�����ѳɹ�Ӧ�ã�", "�ɹ�", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("����ʧ�ܣ�$($_.Exception.Message)", "����", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

# ��ʾ��ǰ���ð�ť�¼�
$btnCurrent.Add_Click({
    if ($cmbAdapter.SelectedIndex -eq -1) {
        [System.Windows.Forms.MessageBox]::Show("��ѡ��������������", "��ʾ", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $adapterName = $cmbAdapter.SelectedItem.ToString().Split('-')[0].Trim()
    $adapter = Get-NetAdapter -Name $adapterName
    $ipConfig = Get-NetIPConfiguration -InterfaceAlias $adapterName
    $ipAddress = Get-NetIPAddress -InterfaceAlias $adapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue
    $dnsServers = Get-DnsClientServerAddress -InterfaceAlias $adapterName -AddressFamily IPv4
    
    $configInfo = "=== ��ǰ�������� ===`n`n"
    $configInfo += "����������: $($adapter.Name)`n"
    $configInfo += "�����ַ: $($adapter.MacAddress)`n"
    $configInfo += "����״̬: $($adapter.Status)`n`n"
    
    if ($ipAddress) {
        $configInfo += "IP��ַ: $($ipAddress.IPAddress)`n"
        $configInfo += "����ǰ׺: $($ipAddress.PrefixLength)`n"
        $configInfo += "DHCP����: $($ipAddress.PrefixOrigin -eq 'Dhcp')`n"
        
        if ($ipConfig.IPv4DefaultGateway) {
            $configInfo += "Ĭ������: $($ipConfig.IPv4DefaultGateway.NextHop)`n"
        }
    } else {
        $configInfo += "δ����IP��ַ`n"
    }
    
    if ($dnsServers.ServerAddresses) {
        $configInfo += "DNS������: $($dnsServers.ServerAddresses -join ', ')`n"
    }
    
    [System.Windows.Forms.MessageBox]::Show($configInfo, "��ǰ��������", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

# �˳���ť�¼�
$btnExit.Add_Click({
    $form.Close()
})

# ��ʾ����
$form.ShowDialog()
