# Загрузка модуля ActiveDirectory
try {
    Import-Module ActiveDirectory -ErrorAction Stop
} catch {
    [System.Windows.Forms.MessageBox]::Show("ActiveDirectory module not found. Install RSAT.", "Error", "OK", "Error")
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Глобальные переменные
$sortColumn = -1
$sortOrder = "Ascending"

# Создание формы
$form = New-Object System.Windows.Forms.Form
$form.Text = "AD User Checker — История паролей"
$form.Size = New-Object System.Drawing.Size(1200, 600)
$form.StartPosition = "CenterScreen"
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# Элементы интерфейса
$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(20, 20)
$label.Size = New-Object System.Drawing.Size(220, 20)
$label.Text = "Логин или ФИО:"
$form.Controls.Add($label)

$textbox = New-Object System.Windows.Forms.TextBox
$textbox.Location = New-Object System.Drawing.Point(240, 18)
$textbox.Size = New-Object System.Drawing.Size(280, 24)
$form.Controls.Add($textbox)

$btnSearch = New-Object System.Windows.Forms.Button
$btnSearch.Location = New-Object System.Drawing.Point(530, 16)
$btnSearch.Size = New-Object System.Drawing.Size(90, 28)
$btnSearch.Text = "Найти"
$form.Controls.Add($btnSearch)

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Location = New-Object System.Drawing.Point(630, 16)
$btnClear.Size = New-Object System.Drawing.Size(90, 28)
$btnClear.Text = "Очистить"
$form.Controls.Add($btnClear)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(20, 525)
$statusLabel.Size = New-Object System.Drawing.Size(800, 20)
$statusLabel.Anchor = "Bottom, Left"
$statusLabel.ForeColor = "Blue"
$form.Controls.Add($statusLabel)

# ListView
$listView = New-Object System.Windows.Forms.ListView
$listView.Location = New-Object System.Drawing.Point(20, 60)
$listView.Size = New-Object System.Drawing.Size(1150, 450)
$listView.View = "Details"
$listView.FullRowSelect = $true
$listView.GridLines = $true
$listView.MultiSelect = $true
$listView.Anchor = "Top,Bottom,Left,Right"

# Колонки
$listView.Columns.Add("Логин", 100) | Out-Null
$listView.Columns.Add("ФИО", 200) | Out-Null
$listView.Columns.Add("Статус", 80) | Out-Null
$listView.Columns.Add("Заблокирован", 100) | Out-Null
$listView.Columns.Add("Текущий пароль от", 130) | Out-Null
$listView.Columns.Add("История (Security Log)", 400) | Out-Null

$form.Controls.Add($listView)

# === ОПТИМИЗИРОВАННАЯ ФУНКЦИЯ ПОЛУЧЕНИЯ ИСТОРИИ ===
function Get-PasswordChangeEvents {
    param(
        [string]$SamAccountName,
        [string]$UserSID
    )
    
    $eventsFound = @()
    
    # Автоматическое получение списка DC (можно заменить на жесткий список, если нужно)
    try {
        $DCs = Get-ADDomainController -Filter * | Select-Object -ExpandProperty HostName
    } catch {
        # Fallback если не удалось получить список
        $DCs = @("spbhdqsrv001", "spbhdqsrv008", "spbhdqsrv038")
    }

    foreach ($dc in $DCs) {
        # Быстрая проверка доступности порта (быстрее чем Ping)
        $socket = New-Object System.Net.Sockets.TcpClient
        $connect = $socket.BeginConnect($dc, 389, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne(200, $false)
        
        if (-not $wait) {
             # DC недоступен, пропускаем
             continue 
        }
        $socket.Close()

        # XPath фильтр - работает в 100 раз быстрее, чем Where-Object
        # Ищем события 4723 (сброс админом) и 4724 (смена юзером)
        # Фильтруем СРАЗУ по SID пользователя (TargetSid), это надежнее чем TargetUserName
        $xpath = "*[System[(EventID=4723 or EventID=4724) and TimeCreated[timediff(@SystemTime) <= 31536000000]]] and *[EventData[Data[@Name='TargetSid']='$UserSID']]"
        
        try {
            $logEvents = Get-WinEvent -ComputerName $dc -LogName Security -FilterXPath $xpath -ErrorAction SilentlyContinue | Select-Object TimeCreated, Id
            if ($logEvents) {
                foreach ($ev in $logEvents) {
                    $type = if ($ev.Id -eq 4723) { "(Сброс админом)" } else { "(Смена юзером)" }
                    $eventsFound += "$($ev.TimeCreated.ToString('dd.MM.yyyy HH:mm')) $type"
                }
            }
        } catch {
            # Игнорируем ошибки доступа к журналам конкретного DC
        }
    }

    # Сортируем, удаляем дубликаты и берем последние 3
    $result = $eventsFound | Sort-Object -Descending | Select-Object -Unique | Select-Object -First 3
    return ($result -join "; ")
}

# === ФУНКЦИЯ СОРТИРОВКИ (Исправленная) ===
$listView.Add_ColumnClick({
    # Переименовали $sender в $thisListView
    param($thisListView, $e) 
    
    # Определение направления сортировки
    if ($script:sortColumn -eq $e.Column) {
        $script:sortOrder = if ($script:sortOrder -eq "Ascending") { "Descending" } else { "Ascending" }
    } else {
        $script:sortColumn = $e.Column
        $script:sortOrder = "Ascending"
    }

    # Визуализация стрелочек в заголовке
    # Используем $thisListView вместо $sender
    foreach ($col in $thisListView.Columns) {
        $col.Text = $col.Text -replace " ▲| ▼", ""
    }
    $arrow = if ($script:sortOrder -eq "Ascending") { " ▲" } else { " ▼" }
    $thisListView.Columns[$e.Column].Text += $arrow

    # Логика сортировки
    $items = @($thisListView.Items)
    $thisListView.BeginUpdate()
    $thisListView.Items.Clear()

    $sortedItems = $items | Sort-Object -Property @{
        Expression = { 
            $val = $_.SubItems[$e.Column].Text
            # Если сортируем по дате (колонки 4 и 5), преобразуем в дату
            if ($e.Column -ge 4) { 
                try { [DateTime]::ParseExact($val, "dd.MM.yyyy HH:mm", $null) } catch { [DateTime]::MinValue }
            } else {
                $val
            }
        }
        Descending = ($script:sortOrder -eq "Descending")
    }

    $thisListView.Items.AddRange(($sortedItems))
    $thisListView.EndUpdate()
})




# Функция поиска
function Invoke-ADUserSearch {
    param([string]$SearchTerm)

    if (-not $SearchTerm) { return }

    $listView.Items.Clear()
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    $statusLabel.Text = "Поиск пользователей..."
    $form.Update()

    try {
        $users = Get-ADUser -Filter "Surname -like '*$SearchTerm*' -or GivenName -like '*$SearchTerm*' -or SamAccountName -like '*$SearchTerm*'" `
                             -Properties Surname, GivenName, DisplayName, LockedOut, PasswordLastSet, Enabled, SID

        if (-not $users) {
            $statusLabel.Text = "Пользователи не найдены."
            return
        }
        
        # Превращаем в массив, если найден 1 пользователь
        if ($users -isnot [System.Array]) { $users = @($users) }

        foreach ($user in $users) {
            $statusLabel.Text = "Сканирование логов для: $($user.SamAccountName)..."
            $form.Update() # Обновляем UI, чтобы не зависало визуально

            $fullName = if ($user.DisplayName) { $user.DisplayName } else { "$($user.GivenName) $($user.Surname)".Trim() }
            $status = if ($user.Enabled) { "Активен" } else { "Отключен" }
            $locked = if ($user.LockedOut) { "Да" } else { "Нет" }
            
            # Текущая дата смены (из атрибута объекта)
            $pwdLastSet = if ($user.PasswordLastSet) { $user.PasswordLastSet.ToString("dd.MM.yyyy HH:mm") } else { "Никогда" }
            
            # Поиск в журналах (история)
            # $historyString = Get-PasswordChangeEvents -SamAccountName $user.SamAccountName -UserSID $user.SID.Value

            $historyString = "Отключено (быстрый режим)" 

            # Создание строки
            $item = New-Object System.Windows.Forms.ListViewItem($user.SamAccountName)
            $item.SubItems.Add($fullName) | Out-Null
            $item.SubItems.Add($status) | Out-Null
            $item.SubItems.Add($locked) | Out-Null
            $item.SubItems.Add($pwdLastSet) | Out-Null
            $item.SubItems.Add($historyString) | Out-Null

            if (-not $user.Enabled) { $item.ForeColor = [System.Drawing.Color]::Gray }
            if ($user.LockedOut) { $item.ForeColor = [System.Drawing.Color]::Red }

            $listView.Items.Add($item) | Out-Null
        }
        $statusLabel.Text = "Готово. Найдено: $($users.Count)"
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Ошибка: $($_.Exception.Message)", "Error")
    }
    finally {
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
}

# Обработчики
$btnSearch.Add_Click({ Invoke-ADUserSearch -SearchTerm $textbox.Text.Trim() })
$textbox.Add_KeyDown({ if ($_.KeyCode -eq "Enter") { Invoke-ADUserSearch -SearchTerm $textbox.Text.Trim() } })
$btnClear.Add_Click({ $listView.Items.Clear(); $textbox.Clear(); $statusLabel.Text = "" })

# Запуск
[void]$form.ShowDialog()
