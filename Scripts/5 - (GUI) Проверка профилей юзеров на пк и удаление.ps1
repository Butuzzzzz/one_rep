# Скрипт с GUI для проверки статуса профилей пользователей в AD
# Требует: PowerShell 5.0+, модуль ActiveDirectory

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Data

# Основная форма
$form = New-Object System.Windows.Forms.Form
$form.Text = "Сканер профилей пользователей"
$form.StartPosition = "CenterScreen"
$form.MaximizeBox = $true
$form.FormBorderStyle = "Sizable"
$form.MinimumSize = New-Object System.Drawing.Size(800, 500)

# Установим размер формы в процентах от экрана
$screen = [System.Windows.Forms.Screen]::PrimaryScreen
$screenWidth = $screen.Bounds.Width
$screenHeight = $screen.Bounds.Height

# Увеличим общую высоту формы
$formWidth = [math]::Min([math]::Round($screenWidth * 0.8), 1200)
$formHeight = [math]::Min([math]::Round($screenHeight * 0.8), 900)  # Увеличили с 0.7 до 0.8
$form.Size = New-Object System.Drawing.Size($formWidth, $formHeight)

# Современные цвета
$primaryColor = [System.Drawing.Color]::FromArgb(0, 123, 255)
$successColor = [System.Drawing.Color]::FromArgb(40, 167, 69)
$warningColor = [System.Drawing.Color]::FromArgb(255, 193, 7)
$dangerColor = [System.Drawing.Color]::FromArgb(220, 53, 69)
$secondaryColor = [System.Drawing.Color]::FromArgb(108, 117, 125)
$lightColor = [System.Drawing.Color]::FromArgb(248, 249, 250)
$darkColor = [System.Drawing.Color]::FromArgb(52, 58, 64)

# Функция для расчета размеров в процентах
function Get-PercentSize {
    param([int]$Percent, [string]$Dimension = "Width", [int]$BaseSize = 0)
    
    if ($BaseSize -eq 0) {
        $BaseSize = if ($Dimension -eq "Width") { $form.Width } else { $form.Height }
    }
    
    return [math]::Round($BaseSize * $Percent / 100)
}

# Заголовок
$labelTitle = New-Object System.Windows.Forms.Label
$labelTitle.Location = New-Object System.Drawing.Point((Get-PercentSize -Percent 2), (Get-PercentSize -Percent 2 -Dimension "Height"))
$labelTitle.Size = New-Object System.Drawing.Size((Get-PercentSize -Percent 96), (Get-PercentSize -Percent 4 -Dimension "Height"))
$labelTitle.Text = "Сканер профилей пользователей и проверка статуса в Active Directory"
$labelTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$labelTitle.ForeColor = $primaryColor
$form.Controls.Add($labelTitle)

# Панель управления
$panelControls = New-Object System.Windows.Forms.Panel
$panelControls.Location = New-Object System.Drawing.Point((Get-PercentSize -Percent 2), (Get-PercentSize -Percent 8 -Dimension "Height"))
$panelControls.Size = New-Object System.Drawing.Size((Get-PercentSize -Percent 96), (Get-PercentSize -Percent 12 -Dimension "Height"))
$panelControls.BackColor = $lightColor
$panelControls.BorderStyle = "FixedSingle"
$form.Controls.Add($panelControls)

# Поле для имени компьютера
$labelComputer = New-Object System.Windows.Forms.Label
$labelComputer.Location = New-Object System.Drawing.Point((Get-PercentSize -Percent 1 -BaseSize $panelControls.Width), (Get-PercentSize -Percent 15 -Dimension "Height" -BaseSize $panelControls.Height))
$labelComputer.Size = New-Object System.Drawing.Size((Get-PercentSize -Percent 15 -BaseSize $panelControls.Width), (Get-PercentSize -Percent 20 -Dimension "Height" -BaseSize $panelControls.Height))
$labelComputer.Text = "Имя компьютера:"
$labelComputer.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
$panelControls.Controls.Add($labelComputer)

$textBoxComputer = New-Object System.Windows.Forms.TextBox
$textBoxComputer.Location = New-Object System.Drawing.Point((Get-PercentSize -Percent 18 -BaseSize $panelControls.Width), (Get-PercentSize -Percent 15 -Dimension "Height" -BaseSize $panelControls.Height))
$textBoxComputer.Size = New-Object System.Drawing.Size((Get-PercentSize -Percent 25 -BaseSize $panelControls.Width), (Get-PercentSize -Percent 20 -Dimension "Height" -BaseSize $panelControls.Height))
$textBoxComputer.Text = $env:COMPUTERNAME
$textBoxComputer.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
$panelControls.Controls.Add($textBoxComputer)

# Стили для кнопок
function Set-ButtonStyle {
    param(
        [System.Windows.Forms.Button]$Button,
        [System.Drawing.Color]$BackColor,
        [System.Drawing.Color]$ForeColor = [System.Drawing.Color]::White,
        [bool]$FlatStyle = $true
    )
    
    $Button.BackColor = $BackColor
    $Button.ForeColor = $ForeColor
    $Button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $Button.FlatAppearance.BorderSize = 0
    $Button.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(
        [Math]::Min($BackColor.R + 20, 255),
        [Math]::Min($BackColor.G + 20, 255),
        [Math]::Min($BackColor.B + 20, 255)
    )
    $Button.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(
        [Math]::Max($BackColor.R - 20, 0),
        [Math]::Max($BackColor.G - 20, 0),
        [Math]::Max($BackColor.B - 20, 0)
    )
    $Button.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $Button.Cursor = [System.Windows.Forms.Cursors]::Hand
}

# Кнопка сканирования
$buttonScan = New-Object System.Windows.Forms.Button
$buttonScan.Location = New-Object System.Drawing.Point((Get-PercentSize -Percent 1 -BaseSize $panelControls.Width), (Get-PercentSize -Percent 50 -Dimension "Height" -BaseSize $panelControls.Height))
$buttonScan.Size = New-Object System.Drawing.Size((Get-PercentSize -Percent 15 -BaseSize $panelControls.Width), (Get-PercentSize -Percent 35 -Dimension "Height" -BaseSize $panelControls.Height))
$buttonScan.Text = "Сканировать"
Set-ButtonStyle -Button $buttonScan -BackColor $primaryColor
$panelControls.Controls.Add($buttonScan)

# Кнопка удаления выбранных
$buttonRemoveSelected = New-Object System.Windows.Forms.Button
$buttonRemoveSelected.Location = New-Object System.Drawing.Point((Get-PercentSize -Percent 18 -BaseSize $panelControls.Width), (Get-PercentSize -Percent 50 -Dimension "Height" -BaseSize $panelControls.Height))
$buttonRemoveSelected.Size = New-Object System.Drawing.Size((Get-PercentSize -Percent 20 -BaseSize $panelControls.Width), (Get-PercentSize -Percent 35 -Dimension "Height" -BaseSize $panelControls.Height))
$buttonRemoveSelected.Text = "Удалить выбранные"
Set-ButtonStyle -Button $buttonRemoveSelected -BackColor $dangerColor
$buttonRemoveSelected.Enabled = $false
$panelControls.Controls.Add($buttonRemoveSelected)

# Кнопка удаления всех заблокированных
$buttonRemoveLocked = New-Object System.Windows.Forms.Button
$buttonRemoveLocked.Location = New-Object System.Drawing.Point((Get-PercentSize -Percent 40 -BaseSize $panelControls.Width), (Get-PercentSize -Percent 50 -Dimension "Height" -BaseSize $panelControls.Height))
$buttonRemoveLocked.Size = New-Object System.Drawing.Size((Get-PercentSize -Percent 20 -BaseSize $panelControls.Width), (Get-PercentSize -Percent 35 -Dimension "Height" -BaseSize $panelControls.Height))
$buttonRemoveLocked.Text = "Удалить заблокир."
Set-ButtonStyle -Button $buttonRemoveLocked -BackColor $warningColor
$buttonRemoveLocked.Enabled = $false
$panelControls.Controls.Add($buttonRemoveLocked)

# Кнопка экспорта в CSV
$buttonExport = New-Object System.Windows.Forms.Button
$buttonExport.Location = New-Object System.Drawing.Point((Get-PercentSize -Percent 62 -BaseSize $panelControls.Width), (Get-PercentSize -Percent 50 -Dimension "Height" -BaseSize $panelControls.Height))
$buttonExport.Size = New-Object System.Drawing.Size((Get-PercentSize -Percent 15 -BaseSize $panelControls.Width), (Get-PercentSize -Percent 35 -Dimension "Height" -BaseSize $panelControls.Height))
$buttonExport.Text = "Экспорт CSV"
Set-ButtonStyle -Button $buttonExport -BackColor $successColor
$buttonExport.Enabled = $false
$panelControls.Controls.Add($buttonExport)

# Прогресс-бар
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point((Get-PercentSize -Percent 2), (Get-PercentSize -Percent 22 -Dimension "Height"))
$progressBar.Size = New-Object System.Drawing.Size((Get-PercentSize -Percent 50), (Get-PercentSize -Percent 2 -Dimension "Height"))
$progressBar.Style = "Continuous"
$progressBar.Visible = $false
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$form.Controls.Add($progressBar)

# Статус лейбл
$labelStatus = New-Object System.Windows.Forms.Label
$labelStatus.Location = New-Object System.Drawing.Point((Get-PercentSize -Percent 2), (Get-PercentSize -Percent 25 -Dimension "Height"))
$labelStatus.Size = New-Object System.Drawing.Size((Get-PercentSize -Percent 96), (Get-PercentSize -Percent 3 -Dimension "Height"))
$labelStatus.Text = "Готов к работе"
$labelStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
$labelStatus.ForeColor = $secondaryColor
$form.Controls.Add($labelStatus)

# Таблица для отображения профилей
$dataGridView = New-Object System.Windows.Forms.DataGridView
$dataGridView.Location = New-Object System.Drawing.Point((Get-PercentSize -Percent 2), (Get-PercentSize -Percent 29 -Dimension "Height"))
$dataGridView.Size = New-Object System.Drawing.Size((Get-PercentSize -Percent 96), (Get-PercentSize -Percent 60 -Dimension "Height"))
$dataGridView.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

# Настройки таблицы
$dataGridView.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::None
$dataGridView.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
$dataGridView.MultiSelect = $true
$dataGridView.ReadOnly = $true
$dataGridView.AllowUserToAddRows = $false
$dataGridView.AllowUserToDeleteRows = $false
$dataGridView.AllowUserToOrderColumns = $false
$dataGridView.AllowUserToResizeRows = $false
$dataGridView.AllowUserToResizeColumns = $true
$dataGridView.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::DisableResizing
$dataGridView.RowHeadersWidthSizeMode = [System.Windows.Forms.DataGridViewRowHeadersWidthSizeMode]::DisableResizing
$dataGridView.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
$dataGridView.BackgroundColor = [System.Drawing.Color]::White
$dataGridView.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$dataGridView.GridColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
$dataGridView.RowHeadersVisible = $false
$dataGridView.ColumnHeadersDefaultCellStyle = New-Object System.Windows.Forms.DataGridViewCellStyle
$dataGridView.ColumnHeadersDefaultCellStyle.BackColor = $darkColor
$dataGridView.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::White
$dataGridView.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$dataGridView.ColumnHeadersDefaultCellStyle.Alignment = [System.Windows.Forms.DataGridViewContentAlignment]::MiddleLeft
$dataGridView.EnableHeadersVisualStyles = $false
$dataGridView.ColumnHeadersDefaultCellStyle.SelectionBackColor = $darkColor
$dataGridView.ColumnHeadersDefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::White
$dataGridView.Cursor = [System.Windows.Forms.Cursors]::Default
$form.Controls.Add($dataGridView)

# Панель статистики
$panelStats = New-Object System.Windows.Forms.Panel
$panelStats.Location = New-Object System.Drawing.Point((Get-PercentSize -Percent 2), (Get-PercentSize -Percent 88 -Dimension "Height"))
$panelStats.Size = New-Object System.Drawing.Size((Get-PercentSize -Percent 96), (Get-PercentSize -Percent 6 -Dimension "Height"))
$panelStats.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$panelStats.BackColor = $lightColor
$panelStats.BorderStyle = "FixedSingle"
$form.Controls.Add($panelStats)

# Статистика
$labelStats = New-Object System.Windows.Forms.Label
$labelStats.Location = New-Object System.Drawing.Point((Get-PercentSize -Percent 2 -BaseSize $panelStats.Width), (Get-PercentSize -Percent 10 -Dimension "Height" -BaseSize $panelStats.Height))
$labelStats.Size = New-Object System.Drawing.Size((Get-PercentSize -Percent 96 -BaseSize $panelStats.Width), (Get-PercentSize -Percent 80 -Dimension "Height" -BaseSize $panelStats.Height))
$labelStats.Text = "Статус:"
$labelStats.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$labelStats.ForeColor = $darkColor
$panelStats.Controls.Add($labelStats)

# Глобальная переменная для хранения данных
$Global:ProfileData = $null

# Функция для проверки доступности хоста
function Test-ComputerConnection {
    param([string]$ComputerName, [int]$TimeoutMs = 1000)
    
    # Для localhost всегда возвращаем true
    if ($ComputerName -eq $env:COMPUTERNAME -or $ComputerName -eq "localhost" -or $ComputerName -eq ".") {
        return $true
    }
    
    try {
        $ping = New-Object System.Net.NetworkInformation.Ping
        $reply = $ping.Send($ComputerName, $TimeoutMs)
        return $reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success
    }
    catch {
        return $false
    }
}

# Функция для обновления статуса
function Update-Status {
    param([string]$Message, [bool]$ShowProgress = $false, [int]$ProgressValue = 0)
    
    $labelStatus.Text = $Message
    $progressBar.Visible = $ShowProgress
    
    if ($ShowProgress) {
        if ($ProgressValue -gt 0) {
            $progressBar.Value = $ProgressValue
            $progressBar.Style = "Continuous"
        } else {
            $progressBar.Style = "Marquee"
        }
    } else {
        $progressBar.Style = "Continuous"
        $progressBar.Value = 0
    }
    
    # Принудительное обновление интерфейса
    [System.Windows.Forms.Application]::DoEvents()
}

# Функция для получения профилей пользователей с улучшенной обработкой ошибок
function Get-UserProfiles {
    param([string]$ComputerName = $env:COMPUTERNAME)
    
    try {
        # Нормализуем имя компьютера
        if ($ComputerName -eq "." -or [string]::IsNullOrEmpty($ComputerName)) {
            $ComputerName = $env:COMPUTERNAME
        }
        
        Update-Status "Подключение к компьютеру $ComputerName..." $true
        
        # Для удаленных компьютеров проверяем доступность
        if ($ComputerName -ne $env:COMPUTERNAME -and $ComputerName -ne "localhost") {
            $isReachable = Test-ComputerConnection -ComputerName $ComputerName -TimeoutMs 2000
            if (-not $isReachable) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Компьютер '$ComputerName' недоступен по сети. Проверьте сетевое подключение, имя компьютера и настройки брандмауэра.", 
                    "Ошибка подключения", 
                    [System.Windows.Forms.MessageBoxButtons]::OK, 
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
                return $null
            }
            
            # Проверяем WMI доступность
            try {
                $null = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ComputerName -ErrorAction Stop
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show(
                    "Нет доступа к WMI на компьютере '$ComputerName'. Возможные причины:`n- Недостаточно прав (требуются права администратора)`n- Включена защита UAC`n- Брандмауэр блокирует WMI`n- Удаленный WMI отключен", 
                    "Ошибка доступа к WMI", 
                    [System.Windows.Forms.MessageBoxButtons]::OK, 
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
                return $null
            }
        }
        
        Update-Status "Получение профилей с компьютера $ComputerName..." $true
        
        # Получаем профили
        $wmiParams = @{
            Class = 'Win32_UserProfile'
            ErrorAction = 'Stop'
        }
        
        if ($ComputerName -ne $env:COMPUTERNAME -and $ComputerName -ne "localhost") {
            $wmiParams.ComputerName = $ComputerName
        }
        
        $profiles = Get-WmiObject @wmiParams
        
        # Фильтруем системные профили и возвращаем только пользовательские с проверкой LocalPath
        $userProfiles = $profiles | Where-Object { 
            $_.Special -eq $false -and 
            $null -ne $_.LocalPath -and 
            $_.LocalPath -ne "" -and
            $_.LocalPath -notlike "*Windows*" -and 
            $_.LocalPath -notlike "*system32*"
        }
        
        return $userProfiles
    }
    catch [System.Management.ManagementException] {
        $errorMsg = switch ($_.Exception.ErrorCode) {
            "InvalidNamespace" { "Неверное пространство имен WMI на компьютере $ComputerName" }
            "AccessDenied" { 
                "Доступ запрещен к компьютеру $ComputerName.`n`nВозможные причины:`n- Отсутствуют права администратора`n- UAC включен на удаленном компьютере`n- Брандмауэр блокирует подключение`n- Компьютер в другой доменной зоне" 
            }
            "InvalidParameter" { "Неверное имя компьютера: $ComputerName" }
            "Timedout" { "Таймаут подключения к компьютеру $ComputerName. Проверьте сетевое подключение." }
            "NotFound" { "Компьютер $ComputerName не найден в сети." }
            default { "Ошибка WMI при подключении к $ComputerName : $($_.Exception.Message)" }
        }
        
        [System.Windows.Forms.MessageBox]::Show(
            $errorMsg, 
            "Ошибка подключения", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return $null
    }
    catch [System.Runtime.InteropServices.COMException] {
        [System.Windows.Forms.MessageBox]::Show(
            "Ошибка COM при подключении к $ComputerName : $($_.Exception.Message)`n`nПроверьте:`n- Доступность компьютера`n- Сетевые настройки`n- Брандмауэр", 
            "Ошибка сети", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return $null
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Неожиданная ошибка при подключении к $ComputerName : $($_.Exception.Message)", 
            "Ошибка", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return $null
    }
}

# Функция для получения информации о пользователе AD с обработкой ошибок
function Get-ADUserInfo {
    param([string]$SID, [string]$LocalPath)
    
    try {
        # Быстрая проверка доступности AD
        if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
            return @{
                SamAccountName = "Модуль AD отсутствует"
                DisplayName = "Модуль AD отсутствует"
                Enabled = $false
                LastLogonDate = $null
                FoundInAD = $false
            }
        }
        
        Import-Module ActiveDirectory -ErrorAction Stop | Out-Null
        
        # Пытаемся найти пользователя по SID
        $adUser = Get-ADUser -Filter {SID -eq $SID} -Properties Enabled, LastLogonDate, DisplayName, SamAccountName -ErrorAction SilentlyContinue
        
        if ($adUser) {
            return @{
                SamAccountName = $adUser.SamAccountName
                DisplayName = $adUser.DisplayName
                Enabled = $adUser.Enabled
                LastLogonDate = $adUser.LastLogonDate
                FoundInAD = $true
            }
        }
        else {
            # Пытаемся найти по имени профиля
            $profileName = if ($LocalPath) { Split-Path $LocalPath -Leaf } else { "Unknown" }
            $adUser = Get-ADUser -Filter {SamAccountName -eq $profileName} -Properties Enabled, LastLogonDate, DisplayName, SamAccountName -ErrorAction SilentlyContinue
            
            if ($adUser) {
                return @{
                    SamAccountName = $adUser.SamAccountName
                    DisplayName = $adUser.DisplayName
                    Enabled = $adUser.Enabled
                    LastLogonDate = $adUser.LastLogonDate
                    FoundInAD = $true
                }
            }
        }
        
        return @{
            SamAccountName = "Не найден в AD"
            DisplayName = "Не найден в AD"
            Enabled = $false
            LastLogonDate = $null
            FoundInAD = $false
        }
    }
    catch {
        return @{
            SamAccountName = "Ошибка AD"
            DisplayName = "Ошибка AD"
            Enabled = $false
            LastLogonDate = $null
            FoundInAD = $false
        }
    }
}

# Функция для обновления статистики
function Update-Statistics {
    param($ProfileData)
    
    if (-not $ProfileData -or $ProfileData.Count -eq 0) {
        $total = 0
        $active = 0
        $locked = 0
        $notFound = 0
    } else {
        $total = $ProfileData.Count
        $active = ($ProfileData | Where-Object { $_.Status -eq "Активен" }).Count
        $locked = ($ProfileData | Where-Object { $_.Status -eq "Заблокирован" }).Count
        $notFound = $total - $active - $locked  # Все остальные = не найденные
    }
    
    $statsText = "Статус: Всего: $total | Активные: $active | Заблокированные: $locked | Не найдены в AD: $notFound"
    $labelStats.Text = $statsText
    
    # Активируем кнопки
    $buttonRemoveLocked.Enabled = ($locked -gt 0)
    $buttonExport.Enabled = ($total -gt 0)
}

# Функция для настройки DataGridView
function Initialize-DataGridView {
    # Очищаем существующие колонки
    $dataGridView.Columns.Clear()
    
    # Создаем колонки с фиксированными ширинами
    $columns = @(
        @{Name = "UserName"; HeaderText = "Имя пользователя"; Width = 150},
        @{Name = "Status"; HeaderText = "Статус в AD"; Width = 120},
        @{Name = "ADUserName"; HeaderText = "Имя в AD"; Width = 120},
        @{Name = "DisplayName"; HeaderText = "Отображаемое имя"; Width = 180},
        @{Name = "LastLogon"; HeaderText = "Последний вход"; Width = 140},
        @{Name = "Loaded"; HeaderText = "Загружен"; Width = 70},  # Узкая колонка
        @{Name = "ProfilePath"; HeaderText = "Путь к профилю"; Width = 250}
    )
    
    foreach ($column in $columns) {
        $newColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $newColumn.Name = $column.Name
        $newColumn.HeaderText = $column.HeaderText
        $newColumn.SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::Automatic
        $newColumn.Width = $column.Width
        
        # Разрешаем изменение размера колонок
        $newColumn.Resizable = [System.Windows.Forms.DataGridViewTriState]::True
        
        $dataGridView.Columns.Add($newColumn) | Out-Null
    }
     # Настраиваем формат даты для колонки LastLogon
    $dataGridView.Columns["LastLogon"].DefaultCellStyle.Format = "yyyy-MM-dd HH:mm"
    
    # Настраиваем выравнивание для колонки "Загружен" - по центру
    $dataGridView.Columns["Loaded"].DefaultCellStyle.Alignment = [System.Windows.Forms.DataGridViewContentAlignment]::MiddleCenter
} 

# Функция для заполнения DataGridView данными с подсветкой
# Функция для заполнения DataGridView данными с подсветкой
function Set-DataGridViewContent {
    param($ProfileData)
    
    # Очищаем строки
    $dataGridView.Rows.Clear()
    
    if ($null -eq $ProfileData) { return }
    
    foreach ($item in $ProfileData) {
        $rowIndex = $dataGridView.Rows.Add()
        $row = $dataGridView.Rows[$rowIndex]
        
        $row.Cells["UserName"].Value = $item.UserName
        $row.Cells["ProfilePath"].Value = $item.ProfilePath
        $row.Cells["Status"].Value = $item.Status
        $row.Cells["ADUserName"].Value = $item.ADUserName
        $row.Cells["DisplayName"].Value = $item.DisplayName
        $row.Cells["LastLogon"].Value = if ($item.LastLogon -eq [datetime]::MinValue) { $null } else { $item.LastLogon }
        $row.Cells["Loaded"].Value = $item.Loaded
        
        # Сохраняем SID в Tag строки для последующего использования
        $row.Tag = $item.SID
        
        # Прямая подсветка строки по статусу
        switch ($item.Status) {
            "Заблокирован" { 
                $row.DefaultCellStyle.ForeColor = $dangerColor
                $row.DefaultCellStyle.SelectionForeColor = $dangerColor
                $row.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(186, 214, 240)  # Windows синий
            }
            "Не найден в AD" { 
                $row.DefaultCellStyle.ForeColor = $warningColor
                $row.DefaultCellStyle.SelectionForeColor = $warningColor
                $row.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(186, 214, 240)  # Windows синий
            }
            "Активен" { 
                $row.DefaultCellStyle.ForeColor = $successColor
                $row.DefaultCellStyle.SelectionForeColor = $successColor
                $row.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(186, 214, 240)  # Windows синий
            }
            default { 
                $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Black
                $row.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::Black
                $row.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(186, 214, 240)  # Windows синий
            }
        }
    }
    
    # Обновляем отображение
    $dataGridView.Refresh()
}

# Функция сканирования профилей
function Start-ScanProcess {
    Write-Host "=== ЗАПУСК СКАНИРОВАНИЯ ===" -ForegroundColor Magenta
    
    $computerName = $textBoxComputer.Text.Trim()
    if ([string]::IsNullOrEmpty($computerName)) {
        $computerName = $env:COMPUTERNAME
    }
    
    # Блокируем кнопки
    $buttonScan.Enabled = $false
    $buttonRemoveSelected.Enabled = $false
    $buttonRemoveLocked.Enabled = $false
    $buttonExport.Enabled = $false
    
    try {
        # Инициализация таблицы
        Initialize-DataGridView
        
        # Получение профилей
        $profiles = Get-UserProfiles -ComputerName $computerName
        
        if ($null -eq $profiles) {
            Update-Status "Сканирование отменено или произошла ошибка" $false
            return
        }
        
        Write-Host "Найдено профилей для обработки: $($profiles.Count)" -ForegroundColor Green
        
        # Создаем коллекцию для данных
        $profileDataCollection = New-Object System.Collections.ArrayList
        
        $totalProfiles = $profiles.Count
        $currentProfile = 0
        
        foreach ($userProfile in $profiles) {
            $currentProfile++
            
            if ($null -eq $userProfile.LocalPath) {
                continue
            }
            
            $userName = Split-Path $userProfile.LocalPath -Leaf
            
            # Обновляем прогресс-бар
            $progressPercent = [math]::Round(($currentProfile / $totalProfiles) * 100)
            Update-Status "Обработка профиля $userName ($currentProfile из $totalProfiles)..." $true $progressPercent
            
            # Получаем информацию из AD
            $adInfo = Get-ADUserInfo -SID $userProfile.SID -LocalPath $userProfile.LocalPath
            
            # Определение статуса
            $status = if ($adInfo.FoundInAD) {
                if ($adInfo.Enabled) { "Активен" } else { "Заблокирован" }
            } else {
                switch ($adInfo.SamAccountName) {
                    "Модуль AD отсутствует" { "Модуль AD отсутствует" }
                    "Ошибка AD" { "Ошибка AD" }
                    default { "Не найден в AD" }
                }
            }
            
            # Добавляем данные в коллекцию
            $row = New-Object PSObject -Property @{
                'UserName' = $userName
                'ProfilePath' = $userProfile.LocalPath
                'Status' = $status
                'ADUserName' = $adInfo.SamAccountName
                'DisplayName' = $adInfo.DisplayName
                'LastLogon' = if ($adInfo.LastLogonDate) { $adInfo.LastLogonDate } else { [datetime]::MinValue }
                'Loaded' = if ($userProfile.Loaded) { "Да" } else { "Нет" }
                'SID' = $userProfile.SID
            }
            
            $profileDataCollection.Add($row) | Out-Null
        }
        
        # Сохраняем и отображаем данные
        $Global:ProfileData = $profileDataCollection
        Set-DataGridViewContent -ProfileData $profileDataCollection
        
        # Обновляем статистику
        Update-Statistics -ProfileData $profileDataCollection
        
        Update-Status "Сканирование завершено. Найдено профилей: $($profileDataCollection.Count)" $false
        
    }
    catch {
        Write-Host "Ошибка: $($_.Exception.Message)" -ForegroundColor Red
        Update-Status "Ошибка при сканировании: $($_.Exception.Message)" $false
    }
    finally {
        # Разблокируем кнопки
        $buttonScan.Enabled = $true
    }
}

# Функция для удаления выбранных профилей
$buttonRemoveSelected.Add_Click({
    if ($dataGridView.SelectedRows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Выберите профили для удаления в таблице!", 
            "Внимание", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    
    $selectedProfiles = @()
    foreach ($row in $dataGridView.SelectedRows) {
        $userName = $row.Cells["UserName"].Value
        $status = $row.Cells["Status"].Value
        $loaded = $row.Cells["Loaded"].Value
        $sid = $row.Tag  # SID сохраняется в Tag строки
        
        # Проверяем, что профиль не загружен
        if ($loaded -eq "Да") {
            [System.Windows.Forms.MessageBox]::Show(
                "Нельзя удалить загруженный профиль '$userName'! Профиль должен быть разгружен перед удалением.", 
                "Ошибка", 
                [System.Windows.Forms.MessageBoxButtons]::OK, 
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            continue
        }
        
        $selectedProfiles += [PSCustomObject]@{
            UserName = $userName
            Status = $status
            SID = $sid
            Loaded = $loaded
        }
    }
    
    if ($selectedProfiles.Count -eq 0) {
        return  # Нет подходящих профилей для удаления
    }
    
    # Подтверждение удаления
    $userList = ($selectedProfiles.UserName -join "`n")
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Вы действительно хотите удалить ВЫБРАННЫЕ профили?`n`nСписок профилей:`n$userList`n`nЭто действие нельзя отменить!", 
        "Подтверждение удаления выбранных", 
        [System.Windows.Forms.MessageBoxButtons]::YesNo, 
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        $computerName = $textBoxComputer.Text.Trim()
        if ([string]::IsNullOrEmpty($computerName)) {
            $computerName = $env:COMPUTERNAME
        }
        
        # Проверяем доступность удаленного компьютера перед удалением
        if ($computerName -ne $env:COMPUTERNAME -and $computerName -ne "localhost") {
            $isReachable = Test-ComputerConnection -ComputerName $computerName -TimeoutMs 2000
            if (-not $isReachable) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Компьютер '$computerName' недоступен для удаления профилей.", 
                    "Ошибка подключения", 
                    [System.Windows.Forms.MessageBoxButtons]::OK, 
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
                return
            }
        }
        
        $successCount = 0
        $errorCount = 0
        
        foreach ($profileItem in $selectedProfiles) {
            Update-Status "Удаление профиля $($profileItem.UserName)..." $true
            
            try {
                if ($computerName -eq $env:COMPUTERNAME -or $computerName -eq "localhost") {
                    $wmiProfile = Get-WmiObject -Class Win32_UserProfile | Where-Object { $_.SID -eq $profileItem.SID }
                }
                else {
                    $wmiProfile = Get-WmiObject -Class Win32_UserProfile -ComputerName $computerName | Where-Object { $_.SID -eq $profileItem.SID }
                }
                
                if ($wmiProfile) {
                    # Дополнная проверка, что профиль не загружен
                    if ($wmiProfile.Loaded) {
                        Write-Host "Профиль $($profileItem.UserName) сейчас загружен, удаление невозможно"
                        $errorCount++
                        continue
                    }
                    
                    $wmiProfile.Delete()
                    $successCount++
                    Write-Host "Удален профиль: $($profileItem.UserName)"
                }
            }
            catch {
                $errorCount++
                Write-Warning "Ошибка при удалении профиля $($profileItem.UserName): $($_.Exception.Message)"
            }
        }
        
        Update-Status "Удаление завершено. Успешно: $successCount, Ошибок: $errorCount" $false
        
        [System.Windows.Forms.MessageBox]::Show(
            "Удаление выбранных профилей завершено!`nУспешно удалено: $successCount`nОшибок: $errorCount", 
            "Результат", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        
        # Обновляем список профилей
        Start-ScanProcess
    }
})

# Функция для удаления всех заблокированных профилей
$buttonRemoveLocked.Add_Click({
    if ($Global:ProfileData -eq $null) {
        [System.Windows.Forms.MessageBox]::Show(
            "Сначала выполните сканирование профилей!", 
            "Внимание", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    
    $lockedProfiles = $Global:ProfileData | Where-Object { $_.Status -eq "Заблокирован" }
    
    if ($lockedProfiles.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Заблокированные профили не найдены!", 
            "Информация", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        return
    }
    
    $userList = ($lockedProfiles.UserName -join "`n")
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Вы действительно хотите удалить ВСЕ ЗАБЛОКИРОВАННЫЕ профили?`n`nСписок профилей:`n$userList`n`nЭто действие нельзя отменить!", 
        "Подтверждение удаления заблокированных", 
        [System.Windows.Forms.MessageBoxButtons]::YesNo, 
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        $computerName = $textBoxComputer.Text.Trim()
        if ([string]::IsNullOrEmpty($computerName)) {
            $computerName = $env:COMPUTERNAME
        }
        
        # Проверяем доступность удаленного компьютера перед удалением
        if ($computerName -ne $env:COMPUTERNAME -and $computerName -ne "localhost") {
            $isReachable = Test-ComputerConnection -ComputerName $computerName -TimeoutMs 2000
            if (-not $isReachable) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Компьютер '$computerName' недоступен для удаления профилей.", 
                    "Ошибка подключения", 
                    [System.Windows.Forms.MessageBoxButtons]::OK, 
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
                return
            }
        }
        
        $successCount = 0
        $errorCount = 0
        
        foreach ($lockedProfile in $lockedProfiles) {
            # Пропускаем загруженные профили
            if ($lockedProfile.Loaded -eq "Да") {
                Write-Host "Профиль $($lockedProfile.UserName) загружен, пропускаем"
                $errorCount++
                continue
            }
            
            Update-Status "Удаление заблокированного профиля $($lockedProfile.UserName)..." $true
            
            try {
                if ($computerName -eq $env:COMPUTERNAME -or $computerName -eq "localhost") {
                    $wmiProfile = Get-WmiObject -Class Win32_UserProfile | Where-Object { $_.SID -eq $lockedProfile.SID }
                }
                else {
                    $wmiProfile = Get-WmiObject -Class Win32_UserProfile -ComputerName $computerName | Where-Object { $_.SID -eq $lockedProfile.SID }
                }
                
                if ($wmiProfile) {
                    # Дополнная проверка, что профиль не загружен
                    if ($wmiProfile.Loaded) {
                        Write-Host "Профиль $($lockedProfile.UserName) сейчас загружен, удаление невозможно"
                        $errorCount++
                        continue
                    }
                    
                    $wmiProfile.Delete()
                    $successCount++
                    Write-Host "Удален заблокированный профиль: $($lockedProfile.UserName)"
                }
            }
            catch {
                $errorCount++
                Write-Warning "Ошибка при удалении профиля $($lockedProfile.UserName): $($_.Exception.Message)"
            }
        }
        
        Update-Status "Удаление завершено. Успешно: $successCount, Ошибок: $errorCount" $false
        
        [System.Windows.Forms.MessageBox]::Show(
            "Удаление заблокированных профилей завершено!`nУспешно удалено: $successCount`nОшибок: $errorCount", 
            "Результат", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        
        # Обновляем список профилей
        Start-ScanProcess
    }
})

# Обработчик выбора строк в таблице
$dataGridView.Add_SelectionChanged({
    $buttonRemoveSelected.Enabled = ($dataGridView.SelectedRows.Count -gt 0)
})

# Обработчик для кнопки экспорта
$buttonExport.Add_Click({
    if ($Global:ProfileData -eq $null) {
        [System.Windows.Forms.MessageBox]::Show("Нет данных для экспорта!", "Внимание", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.Filter = "CSV files (*.csv)|*.csv"
    $saveFileDialog.Title = "Экспорт данных в CSV"
    $saveFileDialog.FileName = "user_profiles_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    
    if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        try {
            $Global:ProfileData | Export-Csv -Path $saveFileDialog.FileName -NoTypeInformation -Encoding UTF8
            [System.Windows.Forms.MessageBox]::Show("Данные успешно экспортированы в: $($saveFileDialog.FileName)", "Успех", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Ошибка при экспорте: $($_.Exception.Message)", "Ошибка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    }
})

# Обработчик нажатия Enter в поле имени компьютера
$textBoxComputer.Add_KeyDown({
    param($s, $e)
    
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        $e.SuppressKeyPress = $true
        Start-ScanProcess
    }
})

# Обработчик нажатия кнопки сканирования
$buttonScan.Add_Click({
    Start-ScanProcess
})

# Обработчик изменения размера формы
$form.Add_Resize({
    # Обновляем все элементы при изменении размера формы
    Update-FormLayout
})

function Update-FormLayout {
    # Заголовок
    $labelTitle.Location = New-Object System.Drawing.Point((Get-PercentSize -Percent 2), (Get-PercentSize -Percent 2 -Dimension "Height"))
    $labelTitle.Size = New-Object System.Drawing.Size((Get-PercentSize -Percent 96), (Get-PercentSize -Percent 4 -Dimension "Height"))
    
    # Панель управления
    $panelControls.Location = New-Object System.Drawing.Point((Get-PercentSize -Percent 2), (Get-PercentSize -Percent 8 -Dimension "Height"))
    $panelControls.Size = New-Object System.Drawing.Size((Get-PercentSize -Percent 96), (Get-PercentSize -Percent 12 -Dimension "Height"))
    
    # Прогресс-бар и статус
    $progressBar.Location = New-Object System.Drawing.Point((Get-PercentSize -Percent 2), (Get-PercentSize -Percent 22 -Dimension "Height"))
    $progressBar.Size = New-Object System.Drawing.Size((Get-PercentSize -Percent 50), (Get-PercentSize -Percent 2 -Dimension "Height"))
    $labelStatus.Location = New-Object System.Drawing.Point((Get-PercentSize -Percent 2), (Get-PercentSize -Percent 25 -Dimension "Height"))
    $labelStatus.Size = New-Object System.Drawing.Size((Get-PercentSize -Percent 96), (Get-PercentSize -Percent 3 -Dimension "Height"))
    
    # Таблица - увеличенная высота
    $dataGridView.Location = New-Object System.Drawing.Point((Get-PercentSize -Percent 2), (Get-PercentSize -Percent 29 -Dimension "Height"))
    $dataGridView.Size = New-Object System.Drawing.Size((Get-PercentSize -Percent 96), (Get-PercentSize -Percent 58 -Dimension "Height"))  # Увеличили с 60% до 58% чтобы поднять статистику
    
    # Панель статистики - уменьшенная высота и поднята выше
    $panelStats.Location = New-Object System.Drawing.Point((Get-PercentSize -Percent 2), (Get-PercentSize -Percent 88 -Dimension "Height"))
    $panelStats.Size = New-Object System.Drawing.Size((Get-PercentSize -Percent 96), (Get-PercentSize -Percent 6 -Dimension "Height"))
    
    # Обновляем элементы внутри панели управления
    Update-PanelControlsLayout
}

function Update-PanelControlsLayout {
    $panelWidth = $panelControls.Width
    $panelHeight = $panelControls.Height
    
    # Поле компьютера
    $labelComputer.Location = New-Object System.Drawing.Point((Get-PercentSize -Percent 1 -BaseSize $panelWidth), (Get-PercentSize -Percent 15 -Dimension "Height" -BaseSize $panelHeight))
    $labelComputer.Size = New-Object System.Drawing.Size((Get-PercentSize -Percent 15 -BaseSize $panelWidth), (Get-PercentSize -Percent 20 -Dimension "Height" -BaseSize $panelHeight))
    
    $textBoxComputer.Location = New-Object System.Drawing.Point((Get-PercentSize -Percent 18 -BaseSize $panelWidth), (Get-PercentSize -Percent 15 -Dimension "Height" -BaseSize $panelHeight))
    $textBoxComputer.Size = New-Object System.Drawing.Size((Get-PercentSize -Percent 25 -BaseSize $panelWidth), (Get-PercentSize -Percent 20 -Dimension "Height" -BaseSize $panelHeight))
    
    # Кнопки
    $buttonScan.Location = New-Object System.Drawing.Point((Get-PercentSize -Percent 1 -BaseSize $panelWidth), (Get-PercentSize -Percent 50 -Dimension "Height" -BaseSize $panelHeight))
    $buttonScan.Size = New-Object System.Drawing.Size((Get-PercentSize -Percent 15 -BaseSize $panelWidth), (Get-PercentSize -Percent 35 -Dimension "Height" -BaseSize $panelHeight))
    
    $buttonRemoveSelected.Location = New-Object System.Drawing.Point((Get-PercentSize -Percent 18 -BaseSize $panelWidth), (Get-PercentSize -Percent 50 -Dimension "Height" -BaseSize $panelHeight))
    $buttonRemoveSelected.Size = New-Object System.Drawing.Size((Get-PercentSize -Percent 20 -BaseSize $panelWidth), (Get-PercentSize -Percent 35 -Dimension "Height" -BaseSize $panelHeight))
    
    $buttonRemoveLocked.Location = New-Object System.Drawing.Point((Get-PercentSize -Percent 40 -BaseSize $panelWidth), (Get-PercentSize -Percent 50 -Dimension "Height" -BaseSize $panelHeight))
    $buttonRemoveLocked.Size = New-Object System.Drawing.Size((Get-PercentSize -Percent 20 -BaseSize $panelWidth), (Get-PercentSize -Percent 35 -Dimension "Height" -BaseSize $panelHeight))
    
    $buttonExport.Location = New-Object System.Drawing.Point((Get-PercentSize -Percent 62 -BaseSize $panelWidth), (Get-PercentSize -Percent 50 -Dimension "Height" -BaseSize $panelHeight))
    $buttonExport.Size = New-Object System.Drawing.Size((Get-PercentSize -Percent 15 -BaseSize $panelWidth), (Get-PercentSize -Percent 35 -Dimension "Height" -BaseSize $panelHeight))
    
    # Обновляем статистику внутри панели статистики
    $statsWidth = $panelStats.Width
    $statsHeight = $panelStats.Height
    $labelStats.Location = New-Object System.Drawing.Point((Get-PercentSize -Percent 2 -BaseSize $statsWidth), (Get-PercentSize -Percent 10 -Dimension "Height" -BaseSize $statsHeight))
    $labelStats.Size = New-Object System.Drawing.Size((Get-PercentSize -Percent 96 -BaseSize $statsWidth), (Get-PercentSize -Percent 80 -Dimension "Height" -BaseSize $statsHeight))
}

# Вызываем первоначальную настройку layout
Update-FormLayout

# Показываем форму
$form.Add_Shown({$form.Activate()})
[void]$form.ShowDialog()