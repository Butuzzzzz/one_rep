# Скрипт с GUI для поиска и удаления неактивных компьютеров и пользователей из AD
# Требуется: PowerShell 5.0+, модуль ActiveDirectory

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Импортируем модуль Active Directory
try {
    Import-Module ActiveDirectory -ErrorAction Stop
}
catch {
    [System.Windows.Forms.MessageBox]::Show(
        "Модуль Active Directory не найден. Установите RSAT Tools.", 
        "Ошибка", 
        [System.Windows.Forms.MessageBoxButtons]::OK, 
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit
}

# Создаем главную форму
$form = New-Object System.Windows.Forms.Form
$form.Text = "Поиск неактивных объектов в AD"
$form.Size = New-Object System.Drawing.Size(1200, 750)
$form.StartPosition = "CenterScreen"
$form.MaximizeBox = $true
$form.FormBorderStyle = "Sizable"
$form.MinimumSize = New-Object System.Drawing.Size(1200, 750)

# Создаем TabControl для вкладок
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(10, 10)
$tabControl.Size = New-Object System.Drawing.Size(1160, 690)  
$tabControl.Anchor = 'Top, Bottom, Left, Right'
$form.Controls.Add($tabControl)

# Вкладка "Компьютеры"
$tabComputers = New-Object System.Windows.Forms.TabPage
$tabComputers.Text = "Компьютеры"
$tabControl.Controls.Add($tabComputers)

# Вкладка "Пользователи"
$tabUsers = New-Object System.Windows.Forms.TabPage
$tabUsers.Text = "Пользователи"
$tabControl.Controls.Add($tabUsers)

# Вкладка "Лог"
$tabLog = New-Object System.Windows.Forms.TabPage
$tabLog.Text = "Лог операций"
$tabControl.Controls.Add($tabLog)

# === ЭЛЕМЕНТЫ ДЛЯ ВКЛАДКИ "КОМПЬЮТЕРЫ" ===

# Метка для ввода месяцев (компьютеры)
$labelMonthsComputers = New-Object System.Windows.Forms.Label
$labelMonthsComputers.Location = New-Object System.Drawing.Point(20, 20)
$labelMonthsComputers.Size = New-Object System.Drawing.Size(200, 20)
$labelMonthsComputers.Text = "Количество месяцев неактивности:"
$tabComputers.Controls.Add($labelMonthsComputers)

# Поле ввода для месяцев (компьютеры)
$textBoxMonthsComputers = New-Object System.Windows.Forms.NumericUpDown
$textBoxMonthsComputers.Location = New-Object System.Drawing.Point(220, 18)
$textBoxMonthsComputers.Size = New-Object System.Drawing.Size(45, 20)
$textBoxMonthsComputers.Minimum = 0
$textBoxMonthsComputers.Maximum = 120
$textBoxMonthsComputers.Value = 24
$textBoxMonthsComputers.Increment = 1
$tabComputers.Controls.Add($textBoxMonthsComputers)

# Кнопка поиска (компьютеры)
$buttonSearchComputers = New-Object System.Windows.Forms.Button
$buttonSearchComputers.Location = New-Object System.Drawing.Point(320, 16)
$buttonSearchComputers.Size = New-Object System.Drawing.Size(100, 25)
$buttonSearchComputers.Text = "Найти"
$tabComputers.Controls.Add($buttonSearchComputers)

# Метка для фильтра типа (компьютеры)
$labelFilterType = New-Object System.Windows.Forms.Label
$labelFilterType.Location = New-Object System.Drawing.Point(440, 21)
$labelFilterType.Size = New-Object System.Drawing.Size(90, 20)
$labelFilterType.Text = "Фильтр по типу:"
$tabComputers.Controls.Add($labelFilterType)

# Выпадающий список для фильтрации типа (компьютеры)
$comboBoxFilterComputers = New-Object System.Windows.Forms.ComboBox
$comboBoxFilterComputers.Location = New-Object System.Drawing.Point(530, 18)
$comboBoxFilterComputers.Size = New-Object System.Drawing.Size(150, 20)
$comboBoxFilterComputers.DropDownStyle = "DropDownList"
$comboBoxFilterComputers.Items.AddRange(@("Все", "Только серверы", "Только ноутбуки", "Только рабочие станции"))
$comboBoxFilterComputers.SelectedIndex = 0
$tabComputers.Controls.Add($comboBoxFilterComputers)

# Метка для фильтра статуса (компьютеры)
$labelFilterStatusComputers = New-Object System.Windows.Forms.Label
$labelFilterStatusComputers.Location = New-Object System.Drawing.Point(700, 21)
$labelFilterStatusComputers.Size = New-Object System.Drawing.Size(45, 20)
$labelFilterStatusComputers.Text = "Статус:"
$tabComputers.Controls.Add($labelFilterStatusComputers)

# Выпадающий список для фильтрации статуса (компьютеры)
$comboBoxStatusComputers = New-Object System.Windows.Forms.ComboBox
$comboBoxStatusComputers.Location = New-Object System.Drawing.Point(750, 18)
$comboBoxStatusComputers.Size = New-Object System.Drawing.Size(120, 20)
$comboBoxStatusComputers.DropDownStyle = "DropDownList"
$comboBoxStatusComputers.Items.AddRange(@("Все", "Активные", "Отключенные"))
$comboBoxStatusComputers.SelectedIndex = 0
$tabComputers.Controls.Add($comboBoxStatusComputers)

# Статусная строка (компьютеры)
$statusLabelComputers = New-Object System.Windows.Forms.Label
$statusLabelComputers.Location = New-Object System.Drawing.Point(20, 50)
$statusLabelComputers.Size = New-Object System.Drawing.Size(1120, 20)
$statusLabelComputers.Text = "Готов к работе..."
$tabComputers.Controls.Add($statusLabelComputers)

# DataGridView для отображения результатов (компьютеры)
$dataGridViewComputers = New-Object System.Windows.Forms.DataGridView
$dataGridViewComputers.Location = New-Object System.Drawing.Point(20, 70)
$dataGridViewComputers.Size = New-Object System.Drawing.Size(1120, 540)
$dataGridViewComputers.AutoSizeColumnsMode = "Fill"
$dataGridViewComputers.SelectionMode = "FullRowSelect"
$dataGridViewComputers.MultiSelect = $true
$dataGridViewComputers.AllowUserToAddRows = $false
$dataGridViewComputers.ReadOnly = $true
$tabComputers.Controls.Add($dataGridViewComputers)

# Кнопка экспорта (компьютеры)
$buttonExportComputers = New-Object System.Windows.Forms.Button
$buttonExportComputers.Location = New-Object System.Drawing.Point(20, 625)
$buttonExportComputers.Size = New-Object System.Drawing.Size(120, 30)
$buttonExportComputers.Text = "Экспорт в CSV"
$buttonExportComputers.Enabled = $false
$tabComputers.Controls.Add($buttonExportComputers)

# Кнопка блокировки (компьютеры)
$buttonDisableComputers = New-Object System.Windows.Forms.Button
$buttonDisableComputers.Location = New-Object System.Drawing.Point(870, 625)
$buttonDisableComputers.Size = New-Object System.Drawing.Size(120, 30)
$buttonDisableComputers.Text = "Заблокировать"
$buttonDisableComputers.Enabled = $false
$tabComputers.Controls.Add($buttonDisableComputers)

# Кнопка удаления (компьютеры)
$buttonDeleteComputers = New-Object System.Windows.Forms.Button
$buttonDeleteComputers.Location = New-Object System.Drawing.Point(1020, 625)
$buttonDeleteComputers.Size = New-Object System.Drawing.Size(120, 30)
$buttonDeleteComputers.Text = "Удалить"
$buttonDeleteComputers.Enabled = $false
$tabComputers.Controls.Add($buttonDeleteComputers)

# === ЭЛЕМЕНТЫ ДЛЯ ВКЛАДКИ "ПОЛЬЗОВАТЕЛИ" ===

# Метка для ввода месяцев (пользователи)
$labelMonthsUsers = New-Object System.Windows.Forms.Label
$labelMonthsUsers.Location = New-Object System.Drawing.Point(20, 20)
$labelMonthsUsers.Size = New-Object System.Drawing.Size(200, 20)
$labelMonthsUsers.Text = "Количество месяцев неактивности:"
$tabUsers.Controls.Add($labelMonthsUsers)

# Поле ввода для месяцев (пользователи)
$textBoxMonthsUsers = New-Object System.Windows.Forms.NumericUpDown
$textBoxMonthsUsers.Location = New-Object System.Drawing.Point(220, 18)
$textBoxMonthsUsers.Size = New-Object System.Drawing.Size(45, 20)
$textBoxMonthsUsers.Minimum = 0
$textBoxMonthsUsers.Maximum = 120
$textBoxMonthsUsers.Value = 24
$textBoxMonthsUsers.Increment = 1
$tabUsers.Controls.Add($textBoxMonthsUsers)

# Кнопка поиска (пользователи)
$buttonSearchUsers = New-Object System.Windows.Forms.Button
$buttonSearchUsers.Location = New-Object System.Drawing.Point(320, 16)
$buttonSearchUsers.Size = New-Object System.Drawing.Size(100, 25)
$buttonSearchUsers.Text = "Найти"
$tabUsers.Controls.Add($buttonSearchUsers)

# Метка для фильтра статуса (пользователи)
$labelFilterStatusUsers = New-Object System.Windows.Forms.Label
$labelFilterStatusUsers.Location = New-Object System.Drawing.Point(440, 21)
$labelFilterStatusUsers.Size = New-Object System.Drawing.Size(45, 20)
$labelFilterStatusUsers.Text = "Статус:"
$tabUsers.Controls.Add($labelFilterStatusUsers)

# Выпадающий список для фильтрации статуса (пользователи)
$comboBoxStatusUsers = New-Object System.Windows.Forms.ComboBox
$comboBoxStatusUsers.Location = New-Object System.Drawing.Point(490, 18)
$comboBoxStatusUsers.Size = New-Object System.Drawing.Size(120, 20)
$comboBoxStatusUsers.DropDownStyle = "DropDownList"
$comboBoxStatusUsers.Items.AddRange(@("Все", "Активные", "Отключенные"))
$comboBoxStatusUsers.SelectedIndex = 0
$tabUsers.Controls.Add($comboBoxStatusUsers)

# Статусная строка (пользователи)
$statusLabelUsers = New-Object System.Windows.Forms.Label
$statusLabelUsers.Location = New-Object System.Drawing.Point(20, 50)
$statusLabelUsers.Size = New-Object System.Drawing.Size(1120, 20)
$statusLabelUsers.Text = "Готов к работе..."
$tabUsers.Controls.Add($statusLabelUsers)

# DataGridView для отображения результатов (пользователи)
$dataGridViewUsers = New-Object System.Windows.Forms.DataGridView
$dataGridViewUsers.Location = New-Object System.Drawing.Point(20, 70)
$dataGridViewUsers.Size = New-Object System.Drawing.Size(1120, 540)
$dataGridViewUsers.AutoSizeColumnsMode = "Fill"
$dataGridViewUsers.SelectionMode = "FullRowSelect"
$dataGridViewUsers.MultiSelect = $true
$dataGridViewUsers.AllowUserToAddRows = $false
$dataGridViewUsers.ReadOnly = $true
$tabUsers.Controls.Add($dataGridViewUsers)

# Кнопка экспорта (пользователи)
$buttonExportUsers = New-Object System.Windows.Forms.Button
$buttonExportUsers.Location = New-Object System.Drawing.Point(20, 625)
$buttonExportUsers.Size = New-Object System.Drawing.Size(120, 30)
$buttonExportUsers.Text = "Экспорт в CSV"
$buttonExportUsers.Enabled = $false
$tabUsers.Controls.Add($buttonExportUsers)

# Кнопка блокировки (пользователи)
$buttonDisableUsers = New-Object System.Windows.Forms.Button
$buttonDisableUsers.Location = New-Object System.Drawing.Point(1020, 625)
$buttonDisableUsers.Size = New-Object System.Drawing.Size(120, 30)
$buttonDisableUsers.Text = "Заблокировать"
$buttonDisableUsers.Enabled = $false
$tabUsers.Controls.Add($buttonDisableUsers)

# === ЭЛЕМЕНТЫ ДЛЯ ВКЛАДКИ "ЛОГ" ===

# Текстовое поле лога
$textBoxLog = New-Object System.Windows.Forms.TextBox
$textBoxLog.Location = New-Object System.Drawing.Point(20, 10)
$textBoxLog.Size = New-Object System.Drawing.Size(1120, 600)
$textBoxLog.Multiline = $true
$textBoxLog.ScrollBars = "Both"
$textBoxLog.ReadOnly = $true
$textBoxLog.Font = New-Object System.Drawing.Font("Consolas", 9)
$tabLog.Controls.Add($textBoxLog)

# Кнопка очистки лога
$buttonClearLog = New-Object System.Windows.Forms.Button
$buttonClearLog.Location = New-Object System.Drawing.Point(20, 620)
$buttonClearLog.Size = New-Object System.Drawing.Size(100, 25)
$buttonClearLog.Text = "Очистить лог"
$tabLog.Controls.Add($buttonClearLog)

# Кнопка открытия файла лога
$buttonOpenLogFile = New-Object System.Windows.Forms.Button
$buttonOpenLogFile.Location = New-Object System.Drawing.Point(130, 620)
$buttonOpenLogFile.Size = New-Object System.Drawing.Size(150, 25)
$buttonOpenLogFile.Text = "Открыть файл лога"
$tabLog.Controls.Add($buttonOpenLogFile)

# Кнопка "Сохранить как"
$buttonSaveLogAs = New-Object System.Windows.Forms.Button
$buttonSaveLogAs.Location = New-Object System.Drawing.Point(290, 620)
$buttonSaveLogAs.Size = New-Object System.Drawing.Size(120, 25)
$buttonSaveLogAs.Text = "Сохранить как"
$tabLog.Controls.Add($buttonSaveLogAs)

# Метка с путем к файлу лога
$labelLogPath = New-Object System.Windows.Forms.Label
$labelLogPath.Location = New-Object System.Drawing.Point(420, 625)
$labelLogPath.Size = New-Object System.Drawing.Size(850, 20)
$labelLogPath.Text = "Файл лога: $((Get-Location).Path)\$Script:LogFileName"
$tabLog.Controls.Add($labelLogPath)

# Глобальные переменные для хранения результатов
$Script:InactiveComputers = @()
$Script:AllInactiveComputers = @()
$Script:InactiveUsers = @()
$Script:AllInactiveUsers = @()
$Script:LogFileName = "AD_Cleanup_Log.txt"

# Функция логирования
function Write-Log {
    param(
        [string]$Message,
        [string]$Type = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Type] $Message"
    
    $logEntry | Out-File -FilePath $Script:LogFileName -Append -Encoding UTF8
    
    $textBoxLog.AppendText("$logEntry`r`n")
    $textBoxLog.SelectionStart = $textBoxLog.Text.Length
    $textBoxLog.ScrollToCaret()
    
    Write-Host $logEntry
}

# Функция сохранения лога в указанное место
function Save-LogAs {
    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.Filter = "Текстовые файлы (*.txt)|*.txt|Все файлы (*.*)|*.*"
    $saveFileDialog.FileName = "AD_Cleanup_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $saveFileDialog.Title = "Сохранить лог как..."
    $saveFileDialog.InitialDirectory = [Environment]::GetFolderPath('Desktop')
    
    if ($saveFileDialog.ShowDialog() -eq "OK") {
        try {
            $textBoxLog.Text | Out-File -FilePath $saveFileDialog.FileName -Encoding UTF8
            Write-Log "Лог сохранен как: $($saveFileDialog.FileName)" "INFO"
            [System.Windows.Forms.MessageBox]::Show(
                "Лог успешно сохранен в:`n$($saveFileDialog.FileName)", 
                "Сохранение завершено", 
                [System.Windows.Forms.MessageBoxButtons]::OK, 
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
        catch {
            $errorMsg = "Ошибка при сохранении лога: $($_.Exception.Message)"
            Write-Log $errorMsg "ERROR"
            [System.Windows.Forms.MessageBox]::Show(
                $errorMsg, 
                "Ошибка сохранения", 
                [System.Windows.Forms.MessageBoxButtons]::OK, 
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    }
}

# === ФУНКЦИИ ДЛЯ КОМПЬЮТЕРОВ ===

# Функция обновления статуса (компьютеры)
function Update-StatusComputers {
    param([string]$Message, [string]$Color = "Black")
    $statusLabelComputers.Text = $Message
    $statusLabelComputers.ForeColor = $Color
    [System.Windows.Forms.Application]::DoEvents()
}

# Функция для определения типа компьютера
function Get-ComputerType {
    param([string]$ComputerName)
    
    $computerNameUpper = $ComputerName.ToUpper()
    
    if ($computerNameUpper -like "*SRV*" -or $computerNameUpper -like "*-S*") {
        return "Сервер"
    }
    elseif ($computerNameUpper -like "N*" -and $computerNameUpper -match '^N\d{3,}$' -or 
            $computerNameUpper -like "*NTB*") {
        return "Ноутбук"
    }
    elseif ($computerNameUpper -like "W*" -and $computerNameUpper -match '^W\d{3,}$' -or 
            $computerNameUpper -like "*WKS*") {
        return "Рабочая станция"
    }
    else {
        return "Другое"
    }
}

# Функция применения фильтров (компьютеры)
function Invoke-FilterApplicationComputers {
    if ($Script:AllInactiveComputers.Count -eq 0) {
        return
    }
    
    $filteredComputers = $Script:AllInactiveComputers
    
    switch ($comboBoxFilterComputers.SelectedItem) {
        "Только серверы" {
            $filteredComputers = $filteredComputers | Where-Object {
                (Get-ComputerType -ComputerName $_.Name) -eq "Сервер"
            }
        }
        "Только ноутбуки" {
            $filteredComputers = $filteredComputers | Where-Object {
                (Get-ComputerType -ComputerName $_.Name) -eq "Ноутбук"
            }
        }
        "Только рабочие станции" {
            $filteredComputers = $filteredComputers | Where-Object {
                (Get-ComputerType -ComputerName $_.Name) -eq "Рабочая станция"
            }
        }
    }
    
    switch ($comboBoxStatusComputers.SelectedItem) {
        "Активные" {
            $filteredComputers = $filteredComputers | Where-Object {
                $_.Enabled -eq $true
            }
        }
        "Отключенные" {
            $filteredComputers = $filteredComputers | Where-Object {
                $_.Enabled -eq $false
            }
        }
    }
    
    $Script:InactiveComputers = $filteredComputers
    Update-DataGridViewComputers -Computers $Script:InactiveComputers
    $buttonDeleteComputers.Enabled = ($Script:InactiveComputers.Count -gt 0)
    $buttonDisableComputers.Enabled = ($Script:InactiveComputers.Count -gt 0)
    $buttonExportComputers.Enabled = ($Script:InactiveComputers.Count -gt 0)
    
    $typeFilter = $comboBoxFilterComputers.SelectedItem
    $statusFilter = $comboBoxStatusComputers.SelectedItem
    
    if ($typeFilter -eq "Все" -and $statusFilter -eq "Все") {
        Update-StatusComputers "Отфильтровано: $($Script:InactiveComputers.Count) компьютеров" "Green"
    } else {
        Update-StatusComputers "${typeFilter} (${statusFilter}): $($Script:InactiveComputers.Count) из $($Script:AllInactiveComputers.Count)" "Green"
    }
}

# Функция поиска неактивных компьютеров
function Find-InactiveComputers {
    param([int]$Months)
    
    $buttonSearchComputers.Enabled = $false
    $buttonDeleteComputers.Enabled = $false
    $buttonDisableComputers.Enabled = $false
    $buttonExportComputers.Enabled = $false
    
    Update-StatusComputers "Поиск неактивных компьютеров..." "Blue"
    
    try {
        $CutoffDate = (Get-Date).AddMonths(-$Months)
        
        $ComputerProperties = @(
            'Name',
            'LastLogonDate',
            'OperatingSystem', 
            'Enabled',
            'DistinguishedName',
            'Created',
            'whenChanged',
            'Description'
            'CanonicalName' 
        )
        
        Write-Log "Начало поиска неактивных компьютеров (более $Months месяцев)"
        Write-Log "Дата отсечения: $($CutoffDate.ToString('yyyy-MM-dd'))"
        
        Update-StatusComputers "Получение списка компьютеров из AD..." "Blue"
        
        $AllComputers = Get-ADComputer -Filter * -Properties $ComputerProperties | 
                       Select-Object $ComputerProperties
        
        Write-Log "Всего компьютеров в AD: $($AllComputers.Count)"
        
        Update-StatusComputers "Фильтрация неактивных компьютеров..." "Blue"
        
        $Script:AllInactiveComputers = $AllComputers | Where-Object {
            ($null -eq $_.LastLogonDate -or $_.LastLogonDate -lt $CutoffDate)
        } | Sort-Object LastLogonDate
        
        Write-Log "Найдено неактивных компьютеров: $($Script:AllInactiveComputers.Count)"
        
        Update-StatusComputers "Применение фильтров..." "Blue"
        
        Invoke-FilterApplicationComputers
        
        $typeFilter = $comboBoxFilterComputers.SelectedItem
        $statusFilter = $comboBoxStatusComputers.SelectedItem
        
        if ($typeFilter -eq "Все" -and $statusFilter -eq "Все") {
            Update-StatusComputers "Готово! Найдено неактивных компьютеров: $($Script:AllInactiveComputers.Count)" "Green"
        } else {
            Update-StatusComputers "Готово! ${typeFilter} (${statusFilter}): $($Script:InactiveComputers.Count) из $($Script:AllInactiveComputers.Count)" "Green"
        }
        
    }
    catch {
        $errorMsg = "Ошибка при поиске компьютеров: $($_.Exception.Message)"
        Write-Log $errorMsg "ERROR"
        Update-StatusComputers $errorMsg "Red"
    }
    finally {
        $buttonSearchComputers.Enabled = $true
        $buttonDeleteComputers.Enabled = ($Script:InactiveComputers.Count -gt 0)
        $buttonDisableComputers.Enabled = ($Script:InactiveComputers.Count -gt 0)
        $buttonExportComputers.Enabled = ($Script:InactiveComputers.Count -gt 0)
    }
}

# Функция обновления DataGridView (компьютеры)
function Update-DataGridViewComputers {
    param($Computers)
    
    $dataGridViewComputers.Rows.Clear()
    $dataGridViewComputers.Columns.Clear()
    
    $columns = @(
        @{Name="ComputerName"; Header="Имя компьютера"},
        @{Name="Type"; Header="Тип"},
        @{Name="LastLogonDate"; Header="Дата последнего входа"},
        @{Name="LastModified"; Header="Дата последнего изменения"},
        @{Name="Status"; Header="Статус"},
        @{Name="Description"; Header="Описание"},
        @{Name="FullPath"; Header="Полный путь в AD"},
        @{Name="Created"; Header="Дата создания"},
        @{Name="OS"; Header="Операционная система"}
    )
    
    foreach ($column in $columns) {
        $dataGridViewComputers.Columns.Add($column.Name, $column.Header) | Out-Null
    }
    
    foreach ($computer in $Computers) {
        $computerType = Get-ComputerType -ComputerName $computer.Name
        $fullPath = $computer.CanonicalName
        $status = if ($computer.Enabled) { "Активен" } else { "Отключен" }
        
        $row = New-Object System.Windows.Forms.DataGridViewRow
        $row.CreateCells($dataGridViewComputers)
        $row.Cells[0].Value = $computer.Name
        $row.Cells[1].Value = $computerType
        $row.Cells[2].Value = if ($computer.LastLogonDate) { $computer.LastLogonDate.ToString("yyyy-MM-dd HH:mm") } else { "Never" }
        $row.Cells[3].Value = $computer.whenChanged.ToString("yyyy-MM-dd HH:mm")
        $row.Cells[4].Value = $status
        $row.Cells[5].Value = $computer.Description
        $row.Cells[6].Value = $fullPath
        $row.Cells[7].Value = $computer.Created.ToString("yyyy-MM-dd HH:mm")
        $row.Cells[8].Value = $computer.OperatingSystem
        
        if ($computer.Enabled -eq $false) {
            $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Gray
        }
        
        $dataGridViewComputers.Rows.Add($row)
    }
    
    $dataGridViewComputers.AutoResizeColumns()
}

# Функция блокировки выбранных компьютеров
function Disable-SelectedComputers {
    $selectedRows = $dataGridViewComputers.SelectedRows
    
    if ($selectedRows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Выберите компьютеры для блокировки!", 
            "Внимание", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    
    $computerNames = $selectedRows | ForEach-Object { $_.Cells[0].Value }
    $targetOU = "stepcon.ru/STEP/Computers/Unused"
    
    if ($computerNames.Count -le 30) {
        $computerList = $computerNames -join "`n"
        $message = "Вы уверены, что хотите заблокировать следующие компьютеры?`n`n" +
                   "Компьютеров: $($computerNames.Count)`n" +
                   "Будут выполнены действия:`n" +
                   "1. Отключение учетной записи в AD`n" +
                   "2. Перемещение в: $targetOU`n`n" +
                   "Список компьютеров:`n$computerList"
    } else {
        $message = "Вы уверены, что хотите заблокировать $($computerNames.Count) компьютеров?`n`n" +
                   "Будут выполнены действия:`n" +
                   "1. Отключение учетной записи в AD`n" +
                   "2. Перемещение в: $targetOU`n`n" +
                   "Слишком много компьютеров для отображения списка."
    }
    
    $result = [System.Windows.Forms.MessageBox]::Show(
        $message, 
        "Подтверждение блокировки", 
        [System.Windows.Forms.MessageBoxButtons]::YesNo, 
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    
    if ($result -eq "Yes") {
        $successDisableCount = 0
        $successMoveCount = 0
        $errorCount = 0
        
        Write-Log "НАЧАЛО ПРОЦЕДУРЫ БЛОКИРОВКИ КОМПЬЮТЕРОВ"
        Write-Log "Выбрано для блокировки: $($computerNames.Count) компьютеров"
        Write-Log "Целевое подразделение: $targetOU"
        
        foreach ($computerName in $computerNames) {
            try {
                $computer = $Script:AllInactiveComputers | Where-Object { $_.Name -eq $computerName }
                if (-not $computer) {
                    Write-Log "ОШИБКА: Не удалось найти компьютер $computerName в кэше" "ERROR"
                    $errorCount++
                    continue
                }
                
                Write-Log "БЛОКИРОВКА: $computerName"
                $currentPath = $computer.CanonicalName
                Write-Log "  Текущий путь: $currentPath"
                
                Disable-ADAccount -Identity $computer.DistinguishedName
                Write-Log "  УСПЕХ: Учетная запись отключена" "SUCCESS"
                $successDisableCount++
                
                try {
                    Move-ADObject -Identity $computer.DistinguishedName -TargetPath "OU=Unused,OU=Computers,OU=STEP,DC=stepcon,DC=ru"
                    Write-Log "  УСПЕХ: Компьютер перемещен в $targetOU" "SUCCESS"
                    $successMoveCount++
                }
                catch {
                    Write-Log "  ПРЕДУПРЕЖДЕНИЕ: Не удалось переместить компьютер: $($_.Exception.Message)" "WARNING"
                }
                
            }
            catch {
                $errorMsg = "ОШИБКА: Не удалось заблокировать $computerName - $($_.Exception.Message)"
                Write-Log $errorMsg "ERROR"
                $errorCount++
            }
        }
        
        Write-Log "ЗАВЕРШЕНИЕ ПРОЦЕДУРЫ БЛОКИРОВКИ"
        Write-Log "Успешно отключено: $successDisableCount, Успешно перемещено: $successMoveCount, Ошибок: $errorCount"
        
        [System.Windows.Forms.MessageBox]::Show(
            "Блокировка завершена!`n" +
            "Успешно отключено: $successDisableCount`n" +
            "Успешно перемещено: $successMoveCount`n" +
            "Ошибок: $errorCount", 
            "Результат блокировки", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        
        Find-InactiveComputers -Months $textBoxMonthsComputers.Value
    }
}

# Функция удаления выбранных компьютеров
function Remove-SelectedComputers {
    $selectedRows = $dataGridViewComputers.SelectedRows
    
    if ($selectedRows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Выберите компьютеры для удаления!", 
            "Внимание", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    
    $computerNames = $selectedRows | ForEach-Object { $_.Cells[0].Value }
    
    if ($computerNames.Count -le 30) {
        $computerList = $computerNames -join "`n"
        $message = "Вы уверены, что хотите удалить следующие компьютеры из AD?`n`n$computerList`n`nЭта операция необратима!"
    } else {
        $message = "Вы уверены, что хотите удалить $($computerNames.Count) компьютеров из AD?`n`nЭта операция необратима!"
    }
    
    $result = [System.Windows.Forms.MessageBox]::Show(
        $message, 
        "Подтверждение удаления", 
        [System.Windows.Forms.MessageBoxButtons]::YesNo, 
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    
    if ($result -eq "Yes") {
        $successCount = 0
        $errorCount = 0
        $notFoundCount = 0
        
        Write-Log "НАЧАЛО ПРОЦЕДУРЫ УДАЛЕНИЯ КОМПЬЮТЕРОВ"
        Write-Log "Выбрано для удаления: $($computerNames.Count) компьютеров"
        
        foreach ($computerName in $computerNames) {
            try {
                $computerInAD = $null
                try {
                    $computerInAD = Get-ADComputer -Identity $computerName -ErrorAction Stop
                }
                catch {
                    Write-Log "ПРЕДУПРЕЖДЕНИЕ: Компьютер $computerName не найден в Active Directory" "WARNING"
                    $notFoundCount++
                    continue
                }
                
                $computer = $Script:AllInactiveComputers | Where-Object { $_.Name -eq $computerName }
                if ($computer) {
                    Write-Log "УДАЛЕНИЕ: $computerName"
                    Write-Log "  Тип: $(Get-ComputerType -ComputerName $computerName)"
                    Write-Log "  Дата последнего входа: $(if($computer.LastLogonDate){$computer.LastLogonDate.ToString('yyyy-MM-dd HH:mm')}else{'Never'})"
                    Write-Log "  ОС: $($computer.OperatingSystem)"
                    Write-Log "  Активен: $($computer.Enabled)"
                    Write-Log "  Полный путь: $($computer.CanonicalName)"
                    Write-Log "  Дата создания: $($computer.Created.ToString('yyyy-MM-dd HH:mm'))"
                    Write-Log "  Дата изменения: $($computer.whenChanged.ToString('yyyy-MM-dd HH:mm'))"
                    Write-Log "  Описание: $($computer.Description)"
                } else {
                    Write-Log "УДАЛЕНИЕ: $computerName (информация из кэша недоступна)"
                }
                
                Remove-ADComputer -Identity $computerInAD.DistinguishedName -Confirm:$false
                Write-Log "УСПЕХ: Компьютер $computerName удален из AD" "SUCCESS"
                $successCount++
                
            }
            catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
                Write-Log "ПРЕДУПРЕЖДЕНИЕ: Компьютер $computerName уже удален из AD" "WARNING"
                $notFoundCount++
            }
            catch [Microsoft.ActiveDirectory.Management.ADInvalidOperationException] {
                $errorMsg = "ОШИБКА: Не удалось удалить $computerName - объект не является оконечным листовым объектом"
                Write-Log $errorMsg "ERROR"
                $errorCount++
            }
            catch {
                $errorMsg = "ОШИБКА: Не удалось удалить $computerName - $($_.Exception.Message)"
                Write-Log $errorMsg "ERROR"
                $errorCount++
            }
        }
        
        Write-Log "ЗАВЕРШЕНИЕ ПРОЦЕДУРЫ УДАЛЕНИЯ"
        Write-Log "Успешно удалено: $successCount, Не найдено в AD: $notFoundCount, Ошибок: $errorCount"
        
        $resultMessage = "Удаление завершено!`nУспешно: $successCount`nНе найдено в AD: $notFoundCount`nОшибок: $errorCount"
        
        [System.Windows.Forms.MessageBox]::Show(
            $resultMessage, 
            "Результат", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        
        Find-InactiveComputers -Months $textBoxMonthsComputers.Value
    }
}

# Функция экспорта компьютеров в CSV
function Export-ComputersToCSV {
    if ($Script:InactiveComputers.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Нет данных для экспорта!", 
            "Внимание", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    
    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.Filter = "CSV files (*.csv)|*.csv"
    $saveFileDialog.FileName = "InactiveComputers_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $saveFileDialog.Title = "Экспорт в CSV"
    
    if ($saveFileDialog.ShowDialog() -eq "OK") {
        try {
            $exportData = $Script:InactiveComputers | Select-Object @(
                @{Name="ComputerName"; Expression={$_.Name}},
                @{Name="Type"; Expression={Get-ComputerType -ComputerName $_.Name}},
                @{Name="LastLogonDate"; Expression={if($_.LastLogonDate){$_.LastLogonDate.ToString("yyyy-MM-dd HH:mm")}else{"Never"}}},
                @{Name="LastModified"; Expression={$_.whenChanged.ToString("yyyy-MM-dd HH:mm")}},
                @{Name="Status"; Expression={if($_.Enabled){"Активен"}else{"Отключен"}}},
                @{Name="Description"; Expression={$_.Description}},
                @{Name="FullPath"; Expression={$_.CanonicalName}},
                @{Name="Created"; Expression={$_.Created.ToString("yyyy-MM-dd HH:mm")}},
                @{Name="OperatingSystem"; Expression={$_.OperatingSystem}}
            )
            
            $exportData | Export-Csv -Path $saveFileDialog.FileName -NoTypeInformation -Encoding UTF8
            Write-Log "Экспорт данных компьютеров в CSV: $($saveFileDialog.FileName)"
            Update-StatusComputers "Данные экспортированы в: $($saveFileDialog.FileName)" "Green"
            
            [System.Windows.Forms.MessageBox]::Show(
                "Данные успешно экспортированы в: $($saveFileDialog.FileName)", 
                "Экспорт завершен", 
                [System.Windows.Forms.MessageBoxButtons]::OK, 
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
        catch {
            $errorMsg = "Ошибка при экспорте компьютеров: $($_.Exception.Message)"
            Write-Log $errorMsg "ERROR"
            Update-StatusComputers $errorMsg "Red"
        }
    }
}

# === ФУНКЦИИ ДЛЯ ПОЛЬЗОВАТЕЛЕЙ ===

# Функция обновления статуса (пользователи)
function Update-StatusUsers {
    param([string]$Message, [string]$Color = "Black")
    $statusLabelUsers.Text = $Message
    $statusLabelUsers.ForeColor = $Color
    [System.Windows.Forms.Application]::DoEvents()
}

# Функция применения фильтров (пользователи)
function Invoke-FilterApplicationUsers {
    if ($Script:AllInactiveUsers.Count -eq 0) {
        return
    }
    
    $filteredUsers = $Script:AllInactiveUsers
    
    switch ($comboBoxStatusUsers.SelectedItem) {
        "Активные" {
            $filteredUsers = $filteredUsers | Where-Object {
                $_.Enabled -eq $true
            }
        }
        "Отключенные" {
            $filteredUsers = $filteredUsers | Where-Object {
                $_.Enabled -eq $false
            }
        }
    }
    
    $Script:InactiveUsers = $filteredUsers
    Update-DataGridViewUsers -Users $Script:InactiveUsers
    $buttonDisableUsers.Enabled = ($Script:InactiveUsers.Count -gt 0)
    $buttonExportUsers.Enabled = ($Script:InactiveUsers.Count -gt 0)
    
    $statusFilter = $comboBoxStatusUsers.SelectedItem
    
    if ($statusFilter -eq "Все") {
        Update-StatusUsers "Отфильтровано: $($Script:InactiveUsers.Count) пользователей" "Green"
    } else {
        Update-StatusUsers "${statusFilter}: $($Script:InactiveUsers.Count) из $($Script:AllInactiveUsers.Count)" "Green"
    }
}

# Функция поиска неактивных пользователей
function Find-InactiveUsers {
    param([int]$Months)
    
    $buttonSearchUsers.Enabled = $false
    $buttonDisableUsers.Enabled = $false
    $buttonExportUsers.Enabled = $false
    
    Update-StatusUsers "Поиск неактивных пользователей..." "Blue"
    
    try {
        $CutoffDate = (Get-Date).AddMonths(-$Months)
        
        $UserProperties = @(
            'Name',
            'DisplayName',
            'SamAccountName',
            'LastLogonDate',
            'Enabled',
            'DistinguishedName',
            'Created',
            'whenChanged',
            'Description',
            'CanonicalName'
        )
        
        Write-Log "Начало поиска неактивных пользователей (более $Months месяцев)"
        Write-Log "Дата отсечения: $($CutoffDate.ToString('yyyy-MM-dd'))"
        
        Update-StatusUsers "Получение списка пользователей из AD..." "Blue"
        
        $AllUsers = Get-ADUser -Filter * -Properties $UserProperties | 
                   Select-Object $UserProperties
        
        Write-Log "Всего пользователей в AD: $($AllUsers.Count)"
        
        Update-StatusUsers "Фильтрация неактивных пользователей..." "Blue"
        
        $Script:AllInactiveUsers = $AllUsers | Where-Object {
            ($null -eq $_.LastLogonDate -or $_.LastLogonDate -lt $CutoffDate)
        } | Sort-Object LastLogonDate
        
        Write-Log "Найдено неактивных пользователей: $($Script:AllInactiveUsers.Count)"
        
        Update-StatusUsers "Применение фильтров..." "Blue"
        
        Invoke-FilterApplicationUsers
        
        $statusFilter = $comboBoxStatusUsers.SelectedItem
        
        if ($statusFilter -eq "Все") {
            Update-StatusUsers "Готово! Найдено неактивных пользователей: $($Script:AllInactiveUsers.Count)" "Green"
        } else {
            Update-StatusUsers "Готово! ${statusFilter}: $($Script:InactiveUsers.Count) из $($Script:AllInactiveUsers.Count)" "Green"
        }
        
    }
    catch {
        $errorMsg = "Ошибка при поиске пользователей: $($_.Exception.Message)"
        Write-Log $errorMsg "ERROR"
        Update-StatusUsers $errorMsg "Red"
    }
    finally {
        $buttonSearchUsers.Enabled = $true
        $buttonDisableUsers.Enabled = ($Script:InactiveUsers.Count -gt 0)
        $buttonExportUsers.Enabled = ($Script:InactiveUsers.Count -gt 0)
    }
}

# Функция обновления DataGridView (пользователи)
function Update-DataGridViewUsers {
    param($Users)
    
    $dataGridViewUsers.Rows.Clear()
    $dataGridViewUsers.Columns.Clear()
    
    $columns = @(
        @{Name="DisplayName"; Header="ФИО"},
        @{Name="SamAccountName"; Header="Логин"},
        @{Name="LastLogonDate"; Header="Дата последнего входа"},
        @{Name="LastModified"; Header="Дата последнего изменения"},
        @{Name="Status"; Header="Статус"},
        @{Name="Description"; Header="Описание"},
        @{Name="FullPath"; Header="Полный путь в AD"},
        @{Name="Created"; Header="Дата создания"}
    )
    
    foreach ($column in $columns) {
        $dataGridViewUsers.Columns.Add($column.Name, $column.Header) | Out-Null
    }
    
    foreach ($user in $Users) {
        $status = if ($user.Enabled) { "Активен" } else { "Отключен" }
        
        $row = New-Object System.Windows.Forms.DataGridViewRow
        $row.CreateCells($dataGridViewUsers)
        $row.Cells[0].Value = $user.DisplayName
        $row.Cells[1].Value = $user.SamAccountName
        $row.Cells[2].Value = if ($user.LastLogonDate) { $user.LastLogonDate.ToString("yyyy-MM-dd HH:mm") } else { "Never" }
        $row.Cells[3].Value = $user.whenChanged.ToString("yyyy-MM-dd HH:mm")
        $row.Cells[4].Value = $status
        $row.Cells[5].Value = $user.Description
        $row.Cells[6].Value = $user.CanonicalName
        $row.Cells[7].Value = $user.Created.ToString("yyyy-MM-dd HH:mm")
        
        if ($user.Enabled -eq $false) {
            $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Gray
        }
        
        $dataGridViewUsers.Rows.Add($row)
    }
    
    $dataGridViewUsers.AutoResizeColumns()
}

# Функция блокировки выбранных пользователей
function Disable-SelectedUsers {
    $selectedRows = $dataGridViewUsers.SelectedRows
    
    if ($selectedRows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Выберите пользователей для блокировки!", 
            "Внимание", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    
    $userNames = $selectedRows | ForEach-Object { $_.Cells[1].Value } # Берем логин из колонки SamAccountName
    $targetOU = "stepcon.ru/STEP/Users/Disabled"
    
    if ($userNames.Count -le 30) {
        $userList = $selectedRows | ForEach-Object { $_.Cells[0].Value + " (" + $_.Cells[1].Value + ")" }
        $userList = $userList -join "`n"
        $message = "Вы уверены, что хотите заблокировать следующих пользователей?`n`n" +
                   "Пользователей: $($userNames.Count)`n" +
                   "Будут выполнены действия:`n" +
                   "1. Отключение учетной записи в AD`n" +
                   "2. Перемещение в: $targetOU`n`n" +
                   "Список пользователей:`n$userList"
    } else {
        $message = "Вы уверены, что хотите заблокировать $($userNames.Count) пользователей?`n`n" +
                   "Будут выполнены действия:`n" +
                   "1. Отключение учетной записи в AD`n" +
                   "2. Перемещение в: $targetOU`n`n" +
                   "Слишком много пользователей для отображения списка."
    }
    
    $result = [System.Windows.Forms.MessageBox]::Show(
        $message, 
        "Подтверждение блокировки", 
        [System.Windows.Forms.MessageBoxButtons]::YesNo, 
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    
    if ($result -eq "Yes") {
        $successDisableCount = 0
        $successMoveCount = 0
        $errorCount = 0
        
        Write-Log "НАЧАЛО ПРОЦЕДУРЫ БЛОКИРОВКИ ПОЛЬЗОВАТЕЛЕЙ"
        Write-Log "Выбрано для блокировки: $($userNames.Count) пользователей"
        Write-Log "Целевое подразделение: $targetOU"
        
        foreach ($userName in $userNames) {
            try {
                $user = $Script:AllInactiveUsers | Where-Object { $_.SamAccountName -eq $userName }
                if (-not $user) {
                    Write-Log "ОШИБКА: Не удалось найти пользователя $userName в кэше" "ERROR"
                    $errorCount++
                    continue
                }
                
                Write-Log "БЛОКИРОВКА: $($user.DisplayName) ($userName)"
                $currentPath = $user.CanonicalName
                Write-Log "  Текущий путь: $currentPath"
                
                Disable-ADAccount -Identity $user.DistinguishedName
                Write-Log "  УСПЕХ: Учетная запись отключена" "SUCCESS"
                $successDisableCount++
                
                try {
                    Move-ADObject -Identity $user.DistinguishedName -TargetPath "OU=Disabled,OU=Users,OU=STEP,DC=stepcon,DC=ru"
                    Write-Log "  УСПЕХ: Пользователь перемещен в $targetOU" "SUCCESS"
                    $successMoveCount++
                }
                catch {
                    Write-Log "  ПРЕДУПРЕЖДЕНИЕ: Не удалось переместить пользователя: $($_.Exception.Message)" "WARNING"
                }
                
            }
            catch {
                $errorMsg = "ОШИБКА: Не удалось заблокировать $userName - $($_.Exception.Message)"
                Write-Log $errorMsg "ERROR"
                $errorCount++
            }
        }
        
        Write-Log "ЗАВЕРШЕНИЕ ПРОЦЕДУРЫ БЛОКИРОВКИ ПОЛЬЗОВАТЕЛЕЙ"
        Write-Log "Успешно отключено: $successDisableCount, Успешно перемещено: $successMoveCount, Ошибок: $errorCount"
        
        [System.Windows.Forms.MessageBox]::Show(
            "Блокировка завершена!`n" +
            "Успешно отключено: $successDisableCount`n" +
            "Успешно перемещено: $successMoveCount`n" +
            "Ошибок: $errorCount", 
            "Результат блокировки", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        
        Find-InactiveUsers -Months $textBoxMonthsUsers.Value
    }
}

# Функция экспорта пользователей в CSV
function Export-UsersToCSV {
    if ($Script:InactiveUsers.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Нет данных для экспорта!", 
            "Внимание", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    
    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.Filter = "CSV files (*.csv)|*.csv"
    $saveFileDialog.FileName = "InactiveUsers_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $saveFileDialog.Title = "Экспорт в CSV"
    
    if ($saveFileDialog.ShowDialog() -eq "OK") {
        try {
            $exportData = $Script:InactiveUsers | Select-Object @(
                @{Name="DisplayName"; Expression={$_.DisplayName}},
                @{Name="SamAccountName"; Expression={$_.SamAccountName}},
                @{Name="LastLogonDate"; Expression={if($_.LastLogonDate){$_.LastLogonDate.ToString("yyyy-MM-dd HH:mm")}else{"Never"}}},
                @{Name="LastModified"; Expression={$_.whenChanged.ToString("yyyy-MM-dd HH:mm")}},
                @{Name="Status"; Expression={if($_.Enabled){"Активен"}else{"Отключен"}}},
                @{Name="Description"; Expression={$_.Description}},
                @{Name="FullPath"; Expression={$_.CanonicalName}},
                @{Name="Created"; Expression={$_.Created.ToString("yyyy-MM-dd HH:mm")}}
            )
            
            $exportData | Export-Csv -Path $saveFileDialog.FileName -NoTypeInformation -Encoding UTF8
            Write-Log "Экспорт данных пользователей в CSV: $($saveFileDialog.FileName)"
            Update-StatusUsers "Данные экспортированы в: $($saveFileDialog.FileName)" "Green"
            
            [System.Windows.Forms.MessageBox]::Show(
                "Данные успешно экспортированы в: $($saveFileDialog.FileName)", 
                "Экспорт завершен", 
                [System.Windows.Forms.MessageBoxButtons]::OK, 
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
        catch {
            $errorMsg = "Ошибка при экспорте пользователей: $($_.Exception.Message)"
            Write-Log $errorMsg "ERROR"
            Update-StatusUsers $errorMsg "Red"
        }
    }
}

# === ОБРАБОТЧИКИ СОБЫТИЙ ===

# Обработчики для компьютеров
$buttonSearchComputers.Add_Click({
    Find-InactiveComputers -Months $textBoxMonthsComputers.Value
})

$buttonDeleteComputers.Add_Click({
    Remove-SelectedComputers
})

$buttonDisableComputers.Add_Click({
    Disable-SelectedComputers
})

$buttonExportComputers.Add_Click({
    Export-ComputersToCSV
})

$comboBoxFilterComputers.Add_SelectedIndexChanged({
    Invoke-FilterApplicationComputers
})

$comboBoxStatusComputers.Add_SelectedIndexChanged({
    Invoke-FilterApplicationComputers
})

# Обработчики для пользователей
$buttonSearchUsers.Add_Click({
    Find-InactiveUsers -Months $textBoxMonthsUsers.Value
})

$buttonDisableUsers.Add_Click({
    Disable-SelectedUsers
})

$buttonExportUsers.Add_Click({
    Export-UsersToCSV
})

$comboBoxStatusUsers.Add_SelectedIndexChanged({
    Invoke-FilterApplicationUsers
})

# Обработчики для лога
$buttonClearLog.Add_Click({
    $textBoxLog.Clear()
})

$buttonOpenLogFile.Add_Click({
    if (Test-Path $Script:LogFileName) {
        Invoke-Item $Script:LogFileName
    }
})

$buttonSaveLogAs.Add_Click({
    Save-LogAs
})

# Контекстные меню для DataGridView
$contextMenuComputers = New-Object System.Windows.Forms.ContextMenuStrip
$copyMenuItemComputers = $contextMenuComputers.Items.Add("Копировать выделенное")
$copyMenuItemComputers.Add_Click({
    $selectedCells = $dataGridViewComputers.GetClipboardContent()
    if ($selectedCells -ne $null) {
        [System.Windows.Forms.Clipboard]::SetDataObject($selectedCells)
    }
})

$selectAllMenuItemComputers = $contextMenuComputers.Items.Add("Выделить все")
$selectAllMenuItemComputers.Add_Click({
    $dataGridViewComputers.SelectAll()
})

$dataGridViewComputers.ContextMenuStrip = $contextMenuComputers

$contextMenuUsers = New-Object System.Windows.Forms.ContextMenuStrip
$copyMenuItemUsers = $contextMenuUsers.Items.Add("Копировать выделенное")
$copyMenuItemUsers.Add_Click({
    $selectedCells = $dataGridViewUsers.GetClipboardContent()
    if ($selectedCells -ne $null) {
        [System.Windows.Forms.Clipboard]::SetDataObject($selectedCells)
    }
})

$selectAllMenuItemUsers = $contextMenuUsers.Items.Add("Выделить все")
$selectAllMenuItemUsers.Add_Click({
    $dataGridViewUsers.SelectAll()
})

$dataGridViewUsers.ContextMenuStrip = $contextMenuUsers

# Обработчик изменения размера формы
$form.Add_Resize({
    try {
        $formWidth = $form.Width
        $formHeight = $form.Height
        
        # Обновляем размер TabControl
        $tabControl.Width = $formWidth - 30
        $tabControl.Height = $formHeight - 30
        
        # Обновляем размер DataGridView для компьютеров
        $dataGridViewComputers.Width = $tabControl.Width - 50
        $dataGridViewComputers.Height = $tabControl.Height - 160
        
        # Обновляем размер и положение статусной строки (компьютеры)
        $statusLabelComputers.Width = $tabControl.Width - 50
        $statusLabelComputers.Location = New-Object System.Drawing.Point(20, 50)
        
        # Обновляем положение кнопок (компьютеры)
        $buttonExportComputers.Location = New-Object System.Drawing.Point(20, ($tabControl.Height - 80))
        $buttonDeleteComputers.Location = New-Object System.Drawing.Point(($tabControl.Width - 150), ($tabControl.Height - 80))
        $buttonDisableComputers.Location = New-Object System.Drawing.Point(($tabControl.Width - 290), ($tabControl.Height - 80))
        
        # Обновляем положение элементов фильтра (компьютеры)
        $comboBoxFilterComputers.Location = New-Object System.Drawing.Point(530, 18)
        $comboBoxStatusComputers.Location = New-Object System.Drawing.Point(745, 18)
        
        # Обновляем размер DataGridView для пользователей
        $dataGridViewUsers.Width = $tabControl.Width - 50
        $dataGridViewUsers.Height = $tabControl.Height - 160
        
        # Обновляем размер и положение статусной строки (пользователи)
        $statusLabelUsers.Width = $tabControl.Width - 50
        $statusLabelUsers.Location = New-Object System.Drawing.Point(20, 50)
        
        # Обновляем положение кнопок (пользователи)
        $buttonExportUsers.Location = New-Object System.Drawing.Point(20, ($tabControl.Height - 80))
        $buttonDisableUsers.Location = New-Object System.Drawing.Point(($tabControl.Width - 150), ($tabControl.Height - 80))
        
        # Обновляем положение элементов фильтра (пользователи)
        $comboBoxStatusUsers.Location = New-Object System.Drawing.Point(490, 18)
        
        # Обновляем размеры для вкладки лога
        if ($tabControl.SelectedTab -eq $tabLog) {
            $textBoxLog.Width = $tabControl.Width - 30
            $textBoxLog.Height = $tabControl.Height - 100
            
            $buttonClearLog.Location = New-Object System.Drawing.Point(20, ($tabControl.Height - 80))
            $buttonOpenLogFile.Location = New-Object System.Drawing.Point(130, ($tabControl.Height - 80))
            $buttonSaveLogAs.Location = New-Object System.Drawing.Point(290, ($tabControl.Height - 80))
            $labelLogPath.Location = New-Object System.Drawing.Point(420, ($tabControl.Height - 75))
            $labelLogPath.Width = $tabControl.Width - 440
        }
        
    }
    catch {
        # Игнорируем ошибки при изменении размера
    }
})

# Запускаем форму
$form.Add_Shown({$form.Activate()})
[void]$form.ShowDialog()