Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Глобальные переменные ---
$global:CurrentComputerName = $null
$global:CurrentComputerIP = $null
$global:AdaptersCache = @()
$global:LogEntries = New-Object System.Collections.ArrayList

# --- Форма и UI ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Управление IPv6 на удалённых ПК"
$form.Size = New-Object System.Drawing.Size(950, 730)
$form.StartPosition = "CenterScreen"

$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(10, 10)
$tabControl.Size = New-Object System.Drawing.Size(930, 620)
$form.Controls.Add($tabControl)
$tabMain = New-Object System.Windows.Forms.TabPage
$tabMain.Text = "Основная"
$tabControl.Controls.Add($tabMain)
$tabLog = New-Object System.Windows.Forms.TabPage
$tabLog.Text = "Лог операций"
$tabControl.Controls.Add($tabLog)

# --- Верхняя панель поиска ---
$panelSearch = New-Object System.Windows.Forms.Panel
$panelSearch.Location = New-Object System.Drawing.Point(10, 6)
$panelSearch.Size = New-Object System.Drawing.Size(910, 40)
$tabMain.Controls.Add($panelSearch)

$labelInput = New-Object System.Windows.Forms.Label
$labelInput.Location = New-Object System.Drawing.Point(0, 7)
$labelInput.Size = New-Object System.Drawing.Size(175, 24)
$labelInput.Text = "Имя компьютера или IP:"
$panelSearch.Controls.Add($labelInput)

$textBoxInput = New-Object System.Windows.Forms.TextBox
$textBoxInput.Location = New-Object System.Drawing.Point(180, 5)
$textBoxInput.Size = New-Object System.Drawing.Size(260, 24)
$panelSearch.Controls.Add($textBoxInput)

$buttonSearch = New-Object System.Windows.Forms.Button
$buttonSearch.Location = New-Object System.Drawing.Point(455, 3)
$buttonSearch.Size = New-Object System.Drawing.Size(90, 28)
$buttonSearch.Text = "Поиск"
$panelSearch.Controls.Add($buttonSearch)

$buttonRefresh = New-Object System.Windows.Forms.Button
$buttonRefresh.Location = New-Object System.Drawing.Point(560, 3)
$buttonRefresh.Size = New-Object System.Drawing.Size(110, 28)
$buttonRefresh.Text = "Обновить список"
$buttonRefresh.Enabled = $false
$panelSearch.Controls.Add($buttonRefresh)

# --- Блок информации о компьютере ---
$groupBoxComputer = New-Object System.Windows.Forms.GroupBox
$groupBoxComputer.Location = New-Object System.Drawing.Point(10, 52)
$groupBoxComputer.Size = New-Object System.Drawing.Size(910, 80)
$groupBoxComputer.Text = "Информация о компьютере"
$tabMain.Controls.Add($groupBoxComputer)
$labelComputerName = New-Object System.Windows.Forms.Label
$labelComputerName.Location = New-Object System.Drawing.Point(10, 20)
$labelComputerName.Size = New-Object System.Drawing.Size(800, 20)
$labelComputerName.Text = "Имя компьютера:"
$groupBoxComputer.Controls.Add($labelComputerName)
$labelIPAddress = New-Object System.Windows.Forms.Label
$labelIPAddress.Location = New-Object System.Drawing.Point(10, 40)
$labelIPAddress.Size = New-Object System.Drawing.Size(800, 20)
$labelIPAddress.Text = "IP-адрес:"
$groupBoxComputer.Controls.Add($labelIPAddress)
$labelStatus = New-Object System.Windows.Forms.Label
$labelStatus.Location = New-Object System.Drawing.Point(10, 60)
$labelStatus.Size = New-Object System.Drawing.Size(800, 20)
$labelStatus.Text = "Статус:"
$groupBoxComputer.Controls.Add($labelStatus)

# --- Сетевые адаптеры ---
$groupBoxAdapters = New-Object System.Windows.Forms.GroupBox
$groupBoxAdapters.Location = New-Object System.Drawing.Point(10, 140)
$groupBoxAdapters.Size = New-Object System.Drawing.Size(910, 320)
$groupBoxAdapters.Text = "Сетевые подключения"
$tabMain.Controls.Add($groupBoxAdapters)
$listViewAdapters = New-Object System.Windows.Forms.ListView
$listViewAdapters.Location = New-Object System.Drawing.Point(10, 20)
$listViewAdapters.Size = New-Object System.Drawing.Size(890, 290)
$listViewAdapters.View = "Details"
$listViewAdapters.FullRowSelect = $true
$listViewAdapters.GridLines = $true
$listViewAdapters.MultiSelect = $false
$listViewAdapters.Columns.Add("Имя подключения", 200) | Out-Null
$listViewAdapters.Columns.Add("Тип адаптера", 120) | Out-Null
$listViewAdapters.Columns.Add("Статус", 120) | Out-Null
$listViewAdapters.Columns.Add("IPv4 адрес", 150) | Out-Null
$listViewAdapters.Columns.Add("Описание", 200) | Out-Null
$listViewAdapters.Columns.Add("IPv6", 80) | Out-Null
$groupBoxAdapters.Controls.Add($listViewAdapters)

# --- Панель управления адаптером ---
$panelAdapterButtons = New-Object System.Windows.Forms.Panel
$panelAdapterButtons.Location = New-Object System.Drawing.Point(10, 470)
$panelAdapterButtons.Size = New-Object System.Drawing.Size(910, 46)
$tabMain.Controls.Add($panelAdapterButtons)

$buttonEnableIPv6 = New-Object System.Windows.Forms.Button
$buttonEnableIPv6.Location = New-Object System.Drawing.Point(10, 8)
$buttonEnableIPv6.Size = New-Object System.Drawing.Size(190, 30)
$buttonEnableIPv6.Text = "Включить IPv6 (адаптер)"
$buttonEnableIPv6.Enabled = $false
$panelAdapterButtons.Controls.Add($buttonEnableIPv6)

$buttonDisableIPv6 = New-Object System.Windows.Forms.Button
$buttonDisableIPv6.Location = New-Object System.Drawing.Point(210, 8)
$buttonDisableIPv6.Size = New-Object System.Drawing.Size(190, 30)
$buttonDisableIPv6.Text = "Отключить IPv6 (адаптер)"
$buttonDisableIPv6.Enabled = $false
$panelAdapterButtons.Controls.Add($buttonDisableIPv6)

$buttonEnableIPv6All = New-Object System.Windows.Forms.Button
$buttonEnableIPv6All.Location = New-Object System.Drawing.Point(410, 8)
$buttonEnableIPv6All.Size = New-Object System.Drawing.Size(190, 30)
$buttonEnableIPv6All.Text = "Включить IPv6 (все)"
$buttonEnableIPv6All.Enabled = $false
$panelAdapterButtons.Controls.Add($buttonEnableIPv6All)

$buttonDisableIPv6All = New-Object System.Windows.Forms.Button
$buttonDisableIPv6All.Location = New-Object System.Drawing.Point(610, 8)
$buttonDisableIPv6All.Size = New-Object System.Drawing.Size(190, 30)
$buttonDisableIPv6All.Text = "Отключить IPv6 (все)"
$buttonDisableIPv6All.Enabled = $false
$panelAdapterButtons.Controls.Add($buttonDisableIPv6All)

# --- Статусбар ---
$statusBar = New-Object System.Windows.Forms.StatusBar
$statusBar.Size = New-Object System.Drawing.Size(950, 22)
$statusBar.Text = "Готов к работе"
$form.Controls.Add($statusBar)

# --- Лог ---
$textBoxLog = New-Object System.Windows.Forms.TextBox
$textBoxLog.Location = New-Object System.Drawing.Point(10, 10)
$textBoxLog.Size = New-Object System.Drawing.Size(890, 540)
$textBoxLog.Multiline = $true
$textBoxLog.ScrollBars = "Both"
$textBoxLog.ReadOnly = $true
$textBoxLog.Font = New-Object System.Drawing.Font("Consolas", 9)
$tabLog.Controls.Add($textBoxLog)
$panelLogButtons = New-Object System.Windows.Forms.Panel
$panelLogButtons.Location = New-Object System.Drawing.Point(10, 560)
$panelLogButtons.Size = New-Object System.Drawing.Size(890, 40)
$tabLog.Controls.Add($panelLogButtons)
$buttonClearLog = New-Object System.Windows.Forms.Button
$buttonClearLog.Location = New-Object System.Drawing.Point(10, 5)
$buttonClearLog.Size = New-Object System.Drawing.Size(120, 30)
$buttonClearLog.Text = "Очистить лог"
$panelLogButtons.Controls.Add($buttonClearLog)
$buttonSaveLog = New-Object System.Windows.Forms.Button
$buttonSaveLog.Location = New-Object System.Drawing.Point(140, 5)
$buttonSaveLog.Size = New-Object System.Drawing.Size(120, 30)
$buttonSaveLog.Text = "Сохранить лог"
$panelLogButtons.Controls.Add($buttonSaveLog)

# --- Кнопка выхода ---
$buttonExit = New-Object System.Windows.Forms.Button
$buttonExit.Location = New-Object System.Drawing.Point(770, 640)
$buttonExit.Size = New-Object System.Drawing.Size(160, 38)
$buttonExit.Text = "Выход"
$form.Controls.Add($buttonExit)

# --- Функции ---
function Add-LogEntry {
    param([string]$Message,[string]$Type="INFO",[string]$ComputerName="")
    $timestamp=Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry="[$timestamp] [$Type] $Message"
    if ($ComputerName) { $logEntry="[$timestamp] [$Type] [$ComputerName] $Message" }
    $global:LogEntries.Add($logEntry) | Out-Null
    $textBoxLog.AppendText("$logEntry`r`n"); $textBoxLog.ScrollToCaret(); Write-Host $logEntry
}

function Enable-WinRMRemote {
    param($computerName)
    Add-LogEntry "Активация WinRM на $computerName (автоматически)" "INFO" $computerName
    try {
        Invoke-WmiMethod -Path "Win32_Process" -Name "Create" -ArgumentList "cmd /c winrm quickconfig -quiet" -ComputerName $computerName -ErrorAction Stop | Out-Null
        Invoke-WmiMethod -Path "Win32_Process" -Name "Create" -ArgumentList "cmd /c netsh advfirewall firewall add rule name='WinRM' dir=in action=allow protocol=TCP localport=5985" -ComputerName $computerName -ErrorAction Stop | Out-Null
        Add-LogEntry "WinRM включён, порт открыт" "SUCCESS" $computerName
    }
    catch {Add-LogEntry "Ошибка автоматической активации WinRM: $($_.Exception.Message)" "ERROR" $computerName}
}

function Test-ComputerConnection {
    param($computerNameOrIP)
    Add-LogEntry "Поиск компьютера: $computerNameOrIP" "INFO" $computerNameOrIP
    try {
        if ($computerNameOrIP -match '^\d{1,3}(\.\d{1,3}){3}$') {
            $ipAddress = $computerNameOrIP
            try { $computerInfo = [System.Net.Dns]::GetHostAddresses($computerNameOrIP); if ($computerInfo.Count -gt 0) { $ipAddress = $computerInfo[0].IPAddressToString } } catch {}
            $computerName = $computerNameOrIP
        } else {
            $computerInfo = [System.Net.Dns]::GetHostEntry($computerNameOrIP)
            $computerName = $computerInfo.HostName
            $ipAddress = $computerInfo.AddressList[0].IPAddressToString
        }
        Add-LogEntry "Компьютер найден: $computerName ($ipAddress)" "INFO" $computerName
        $ping=Test-Connection -ComputerName $computerName -Count 1 -Quiet -ErrorAction Stop
        if ($ping) {
            Add-LogEntry "Компьютер доступен по ping" "SUCCESS" $computerName
            return @{Success=$true;ComputerName=$computerName;IPAddress=$ipAddress;Status="Доступен"}
        } else {
            Add-LogEntry "Компьютер не отвечает на ping" "WARNING" $computerName
            return @{Success=$false;ComputerName=$computerName;IPAddress=$ipAddress;Status="Не отвечает на ping"}
        }
    }
    catch {
        Add-LogEntry "Ошибка поиска компьютера: $($_.Exception.Message)" "ERROR" $computerNameOrIP
        return @{Success=$false;ComputerName=$computerNameOrIP;IPAddress="Не определен";Status="Ошибка: $($_.Exception.Message)"}
    }
}

function Get-NetworkConnections {
    param($computerName)
    Add-LogEntry "Получение списка адаптеров с IPv6" "INFO" $computerName
    try {
        Enable-WinRMRemote -computerName $computerName
        Start-Sleep -Seconds 2 # Пауза для WinRM
        $session = New-PSSession -ComputerName $computerName -ErrorAction Stop
        $adapters = Invoke-Command -Session $session -ScriptBlock {
            $adapters = Get-NetAdapter | Where-Object { $_.Status -ne "Disabled" }
            $list = @(); foreach ($adapter in $adapters) {
                $binding = Get-NetAdapterBinding -Name $adapter.Name -ComponentID ms_tcpip6
                $ipv6Enabled=if ($binding.Enabled) {"Включен"} else {"Отключен"}
                $ipv4=(Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
                if (-not $ipv4) { $ipv4 = "Нет адреса" }
                $list += @{
                    Name        = $adapter.Name
                    AdapterType = $adapter.InterfaceDescription
                    Status      = $adapter.Status
                    IPv4Address = $ipv4
                    Description = $adapter.InterfaceDescription
                    IPv6        = $ipv6Enabled
                }
            };return $list
        }
        Remove-PSSession $session
        Add-LogEntry "Адаптеры успешно получены" "SUCCESS" $computerName
        return @{Success=$true;Adapters=$adapters}
    }
    catch {
        Add-LogEntry "Ошибка получения адаптеров: $($_.Exception.Message)" "ERROR" $computerName
        return @{Success=$false;Adapters=@()}
    }
}

function Set-IPv6Adapter {
    param($computerName, $adapterName, $enableIPv6)
    $action = if ($enableIPv6) { "Включение" } else { "Отключение" }
    Add-LogEntry "$action IPv6 на адаптере $adapterName" "INFO" $computerName
    try {
        Enable-WinRMRemote -computerName $computerName
        Start-Sleep -Seconds 1
        $session = New-PSSession -ComputerName $computerName -ErrorAction Stop
        $scriptBlock = if ($enableIPv6) {
            { param($n) Enable-NetAdapterBinding -Name $n -ComponentID ms_tcpip6 -ErrorAction Stop; return "IPv6 включён для адаптера $n" }
        } else {
            { param($n) Disable-NetAdapterBinding -Name $n -ComponentID ms_tcpip6 -ErrorAction Stop; return "IPv6 отключён для адаптера $n" }
        }
        $result = Invoke-Command -Session $session -ScriptBlock $scriptBlock -ArgumentList $adapterName
        Remove-PSSession $session
        Add-LogEntry $result "SUCCESS" $computerName
        return @{Success=$true;Message=$result}
    }
    catch {
        Add-LogEntry "$action ошибки IPv6: $($_.Exception.Message)" "ERROR" $computerName
        return @{Success=$false;Error=$_.Exception.Message}
    }
}

function Set-IPv6All {
    param($computerName, $enableIPv6)
    Add-LogEntry "$(if($enableIPv6){'Включение'}else{'Отключение'}) IPv6 на всех адаптерах" "INFO" $computerName
    try {
        Enable-WinRMRemote -computerName $computerName
        Start-Sleep -Seconds 1
        $session = New-PSSession -ComputerName $computerName -ErrorAction Stop
        $scriptBlock = if ($enableIPv6) {
            { Enable-NetAdapterBinding -Name * -ComponentID ms_tcpip6 -ErrorAction Stop; return "IPv6 включён на всех" }
        } else {
            { Disable-NetAdapterBinding -Name * -ComponentID ms_tcpip6 -ErrorAction Stop; return "IPv6 отключён на всех" }
        }
        $result = Invoke-Command -Session $session -ScriptBlock $scriptBlock
        Remove-PSSession $session
        Add-LogEntry $result "SUCCESS" $computerName
        return @{Success=$true;Message=$result}
    }
    catch {
        Add-LogEntry "Ошибка: $($_.Exception.Message)" "ERROR" $computerName
        return @{Success=$false;Error=$_.Exception.Message}
    }
}

function Save-LogToFile {
    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.Filter = "Текстовые файлы (*.txt)|*.txt|Все файлы (*.*)|*.*"
    $saveFileDialog.FileName = "IPv6_Disable_Log_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"
    if ($saveFileDialog.ShowDialog() -eq "OK") {
        try {
            $logContent = $global:LogEntries -join "`r`n"
            [System.IO.File]::WriteAllText($saveFileDialog.FileName, $logContent)
            Add-LogEntry "Лог сохранён: $($saveFileDialog.FileName)" "SUCCESS"
            [System.Windows.Forms.MessageBox]::Show("Лог успешно сохранён в файл:`n$($saveFileDialog.FileName)", "Сохранение", "OK", "Information")
        }
        catch {
            Add-LogEntry "Ошибка сохранения лога: $($_.Exception.Message)" "ERROR"
            [System.Windows.Forms.MessageBox]::Show("Ошибка: $($_.Exception.Message)", "Ошибка", "OK", "Error")
        }
    }
}

function Update-AdaptersList {
    param($computerName)
    $statusBar.Text = "Обновление списка адаптеров..."
    $form.Refresh()
    $adaptersResult = Get-NetworkConnections -computerName $computerName
    $listViewAdapters.Items.Clear()
    if ($adaptersResult.Success) {
        $global:AdaptersCache = $adaptersResult.Adapters
        foreach ($adapter in $adaptersResult.Adapters) {
            $item = New-Object System.Windows.Forms.ListViewItem($adapter.Name)
            $item.SubItems.Add($adapter.AdapterType) | Out-Null
            $item.SubItems.Add($adapter.Status) | Out-Null
            $item.SubItems.Add($adapter.IPv4Address) | Out-Null
            $item.SubItems.Add($adapter.Description) | Out-Null
            $item.SubItems.Add($adapter.IPv6) | Out-Null
            $listViewAdapters.Items.Add($item) | Out-Null
        }
        $statusBar.Text = "Адаптеров: $($adaptersResult.Adapters.Count)"
        $buttonEnableIPv6.Enabled = $true
        $buttonDisableIPv6.Enabled = $true
        $buttonEnableIPv6All.Enabled = $true
        $buttonDisableIPv6All.Enabled = $true
    } else {
        $statusBar.Text = "Ошибка или нет адаптеров"
        $buttonEnableIPv6.Enabled = $false
        $buttonDisableIPv6.Enabled = $false
        $buttonEnableIPv6All.Enabled = $false
        $buttonDisableIPv6All.Enabled = $false
    }
}

function Start-Search {
    $computerNameOrIP = $textBoxInput.Text.Trim()
    if ([string]::IsNullOrEmpty($computerNameOrIP)) {
        [System.Windows.Forms.MessageBox]::Show("Введите имя или IP", "Ошибка", "OK", "Error")
        return
    }
    $statusBar.Text = "Поиск компьютера..."
    $form.Refresh()
    $connectionResult = Test-ComputerConnection -computerNameOrIP $computerNameOrIP
    $labelComputerName.Text = "Имя компьютера: $($connectionResult.ComputerName)"
    $labelIPAddress.Text = "IP-адрес: $($connectionResult.IPAddress)"
    $labelStatus.Text = "Статус: $($connectionResult.Status)"
    if ($connectionResult.Success) {
        $global:CurrentComputerName = $connectionResult.ComputerName
        $global:CurrentComputerIP = $connectionResult.IPAddress
        Update-AdaptersList -computerName $global:CurrentComputerName
        $buttonRefresh.Enabled = $true
    } else {
        $listViewAdapters.Items.Clear()
        $buttonEnableIPv6.Enabled = $false
        $buttonDisableIPv6.Enabled = $false
        $buttonEnableIPv6All.Enabled = $false
        $buttonDisableIPv6All.Enabled = $false
        $buttonRefresh.Enabled = $false
        $statusBar.Text = "Компьютер недоступен"
    }
}

# --- Обработчики GUI ---
$buttonSearch.Add_Click({ Start-Search })
$textBoxInput.Add_KeyDown({ if ($_.KeyCode -eq "Enter") { Start-Search } })
$buttonRefresh.Add_Click({ if ($global:CurrentComputerName) { Update-AdaptersList -computerName $global:CurrentComputerName } })
$buttonClearLog.Add_Click({ $textBoxLog.Clear(); $global:LogEntries.Clear(); Add-LogEntry "Лог очищен" "INFO" })
$buttonSaveLog.Add_Click({ Save-LogToFile })
$buttonExit.Add_Click({ $form.Close() })

$buttonEnableIPv6.Add_Click({
    if (-not $global:CurrentComputerName) { [System.Windows.Forms.MessageBox]::Show("Найдите ПК!", "Ошибка", "OK", "Error"); return }
    if ($listViewAdapters.SelectedItems.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Выберите адаптер!", "Ошибка", "OK", "Error"); return }
    $adapterName = $listViewAdapters.SelectedItems[0].Text
    $result = [System.Windows.Forms.MessageBox]::Show("Включить IPv6 на адаптере '$adapterName'?", "Подтверждение", "YesNo", "Question")
    if ($result -eq "Yes") {
        $statusBar.Text="Включение IPv6..."; $form.Refresh()
        $execResult = Set-IPv6Adapter -computerName $global:CurrentComputerName -adapterName $adapterName -enableIPv6 $true
        Update-AdaptersList -computerName $global:CurrentComputerName
        if ($execResult.Success) {
            [System.Windows.Forms.MessageBox]::Show("IPv6 включен!\n$($execResult.Message)", "Успех", "OK", "Information")
        } else {
            [System.Windows.Forms.MessageBox]::Show("Ошибка: $($execResult.Error)", "Ошибка", "OK", "Error")
        }
    }
})

$buttonDisableIPv6.Add_Click({
    if (-not $global:CurrentComputerName) { [System.Windows.Forms.MessageBox]::Show("Найдите ПК!", "Ошибка", "OK", "Error"); return }
    if ($listViewAdapters.SelectedItems.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Выберите адаптер!", "Ошибка", "OK", "Error"); return }
    $adapterName = $listViewAdapters.SelectedItems[0].Text
    $result = [System.Windows.Forms.MessageBox]::Show("Отключить IPv6 на адаптере '$adapterName'?", "Подтверждение", "YesNo", "Question")
    if ($result -eq "Yes") {
        $statusBar.Text="Отключение IPv6..."; $form.Refresh()
        $execResult = Set-IPv6Adapter -computerName $global:CurrentComputerName -adapterName $adapterName -enableIPv6 $false
        Update-AdaptersList -computerName $global:CurrentComputerName
        if ($execResult.Success) {
            [System.Windows.Forms.MessageBox]::Show("IPv6 отключен!\n$($execResult.Message)", "Успех", "OK", "Information")
        } else {
            [System.Windows.Forms.MessageBox]::Show("Ошибка: $($execResult.Error)", "Ошибка", "OK", "Error")
        }
    }
})

$buttonEnableIPv6All.Add_Click({
    if (-not $global:CurrentComputerName) { [System.Windows.Forms.MessageBox]::Show("Найдите ПК!", "Ошибка", "OK", "Error"); return }
    $result = [System.Windows.Forms.MessageBox]::Show("Включить IPv6 на ВСЕХ адаптерах?", "Подтверждение", "YesNo", "Question")
    if ($result -eq "Yes") {
        $statusBar.Text="Включение IPv6 на всех..."; $form.Refresh()
        $execResult = Set-IPv6All -computerName $global:CurrentComputerName -enableIPv6 $true
        Update-AdaptersList -computerName $global:CurrentComputerName
        if ($execResult.Success) {
            [System.Windows.Forms.MessageBox]::Show("IPv6 включен на всех!\n$($execResult.Message)", "Успех", "OK", "Information")
        } else {
            [System.Windows.Forms.MessageBox]::Show("Ошибка: $($execResult.Error)", "Ошибка", "OK", "Error")
        }
    }
})

$buttonDisableIPv6All.Add_Click({
    if (-not $global:CurrentComputerName) { [System.Windows.Forms.MessageBox]::Show("Найдите ПК!", "Ошибка", "OK", "Error"); return }
    $result = [System.Windows.Forms.MessageBox]::Show("Отключить IPv6 на ВСЕХ адаптерах?", "Подтверждение", "YesNo", "Question")
    if ($result -eq "Yes") {
        $statusBar.Text="Отключение IPv6 на всех..."; $form.Refresh()
        $execResult = Set-IPv6All -computerName $global:CurrentComputerName -enableIPv6 $false
        Update-AdaptersList -computerName $global:CurrentComputerName
        if ($execResult.Success) {
            [System.Windows.Forms.MessageBox]::Show("IPv6 отключен на всех!\n$($execResult.Message)", "Успех", "OK", "Information")
        } else {
            [System.Windows.Forms.MessageBox]::Show("Ошибка: $($execResult.Error)", "Ошибка", "OK", "Error")
        }
    }
})

Add-LogEntry "Приложение запущено" "INFO"
Add-LogEntry "Готов к работе" "INFO"
$form.Add_Shown({$form.Activate()})
[void]$form.ShowDialog()
