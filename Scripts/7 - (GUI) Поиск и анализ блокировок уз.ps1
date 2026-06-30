# Анализатор блокировок AD + Exchange (Версия 2.2 Table Selection)
# Запускается с любого ПК в домене с правами администратора

# Проверяем наличие модуля AD
if (-not (Get-Module -ListAvailable -Name "ActiveDirectory")) {
    Write-Host "❌ Модуль 'ActiveDirectory' не установлен." -ForegroundColor Red
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- КОНФИГУРАЦИЯ ---
$Config = @{
    PrimaryDC       = "spbhdqsrv001.stepcon.ru"
    AdditionalDCs   = @("spbhdqsrv008.stepcon.ru", "spbhdqsrv038.stepcon.ru")
    ExchangeServers = @("SPBHDQSRV073.stepcon.ru")
    SearchHours     = 24
    TimeWindowBefore = 10
    TimeWindowAfter  = 2
}

# Словарь кодов ошибок 4625
$FailureCodes = @{
    "0xC000006A" = "НЕВЕРНЫЙ ПАРОЛЬ (Пользователь ошибся или старый пароль в кэше)"
    "0xC0000234" = "УЧЕТНАЯ ЗАПИСЬ УЖЕ ЗАБЛОКИРОВАНА (Попытка входа после лока)"
    "0xC0000072" = "УЧЕТНАЯ ЗАПИСЬ ОТКЛЮЧЕНА"
    "0xC0000193" = "СРОК ДЕЙСТВИЯ УЧЕТНОЙ ЗАПИСИ ИСТЕК"
    "0xC0000064" = "ПОЛЬЗОВАТЕЛЬ НЕ СУЩЕСТВУЕТ"
}

# --- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (без зависимости от GUI) ---

function Test-ServerConnection {
    param([string]$ServerName)
    try { return Test-Connection $ServerName -Count 1 -Quiet -ErrorAction SilentlyContinue } catch { return $false }
}

function Get-PrimaryDC {
    try {
        $pdc = (Get-ADDomain).PDCEmulator
        if (Test-ServerConnection $pdc) { return $pdc }
    } catch {}
    if (Test-ServerConnection $Config.PrimaryDC) { return $Config.PrimaryDC }
    return $Config.AdditionalDCs | Where-Object { Test-ServerConnection $_ } | Select-Object -First 1
}

function Get-RemoteExchangeLogs {
    param(
        [string]$ComputerName,
        [string]$Username,
        [datetime]$StartTime,
        [datetime]$EndTime
    )
    
    $results = @()
    $logPaths = @(
        "C$\inetpub\logs\LogFiles\W3SVC1", 
        "C$\inetpub\logs\LogFiles\W3SVC2"
    )
    
    foreach ($logPath in $logPaths) {
        $fullPath = "\\$ComputerName\$logPath"
        if (-not (Test-Path $fullPath)) { continue }
        
        try {
            $logFiles = Get-ChildItem -Path "$fullPath\u_ex*.log" -ErrorAction SilentlyContinue | 
                        Where-Object { $_.LastWriteTime -ge $StartTime.AddHours(-1) } | 
                        Sort-Object LastWriteTime -Descending | Select-Object -First 2
            
            foreach ($file in $logFiles) {
                $stream = [System.IO.File]::Open($file.FullName, 'Open', 'Read', 'ReadWrite')
                $reader = New-Object System.IO.StreamReader($stream)
                
                while ($null -ne ($line = $reader.ReadLine())) {
                    if ($line.StartsWith("#")) { continue }
                    if ($line.IndexOf($Username, [StringComparison]::OrdinalIgnoreCase) -eq -1) { continue }
                    
                    $fields = $line -split " "
                    if ($fields.Count -lt 10) { continue }

                    try {
                        $logTime = [DateTime]::ParseExact("$($fields[0]) $($fields[1])", "yyyy-MM-dd HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture)
                        
                        if ($logTime -lt $StartTime -or $logTime -gt $EndTime) { continue }
                        
                        $csUri = $fields[4]
                        $csUsername = $fields[7]
                        $cIp = $fields[9]
                        $userAgent = $fields[10].Replace("+", " ")
                        $scStatus = $fields[11] 
                        
                        $protocol = "Unknown"
                        if ($csUri -match "Microsoft-Server-ActiveSync") { $protocol = "ActiveSync (Mobile)" }
                        elseif ($csUri -match "/owa") { $protocol = "OWA (Browser)" }
                        elseif ($csUri -match "/ews") { $protocol = "EWS (Mac/Outlook)" }
                        elseif ($csUri -match "/rpc") { $protocol = "RPC (Outlook)" }
                        elseif ($csUri -match "/mapi") { $protocol = "MAPI (Outlook)" }
                        elseif ($csUri -match "/autodiscover") { $protocol = "AutoDiscover" }

                        $results += [PSCustomObject]@{
                            Time = $logTime
                            Protocol = $protocol
                            ClientIP = $cIp
                            User = $csUsername
                            UserAgent = $userAgent
                            Status = $scStatus
                            SourceServer = $ComputerName
                        }
                    } catch { continue }
                }
                $reader.Close()
                $stream.Close()
            }
        } catch { }
    }
    return $results
}

function Search-4625 {
    param($TargetDC, $User, $Time)
    $startTime = $Time.AddMinutes(-5)
    $endTime = $Time.AddMinutes(5)
    
    try {
        $events = Get-WinEvent -ComputerName $TargetDC -FilterHashtable @{
            LogName = 'Security'
            ID = 4625
            StartTime = $startTime
            EndTime = $endTime
        } -ErrorAction SilentlyContinue 
        
        $targetEvent = $events | Where-Object { $_.Properties[5].Value -eq $User } | Sort-Object TimeCreated -Descending | Select-Object -First 1
        
        if ($targetEvent) {
            $subStatusHex = "0x{0:X}" -f $targetEvent.Properties[21].Value
            $reason = if ($FailureCodes[$subStatusHex]) { $FailureCodes[$subStatusHex] } else { "Код ошибки: $subStatusHex" }
            return "🛑 ПРИЧИНА ОТКАЗА (Event 4625): $reason"
        }
    } catch {}
    return $null
}

function Get-LogonFailureDetails {
    param($DC, $User, $Time)
    
    $failure = Search-4625 -TargetDC $DC -User $User -Time $Time
    if ($failure) { return $failure }

    $otherDCs = $Config.AdditionalDCs
    foreach ($odc in $otherDCs) {
        if ($odc -ne $DC) {
            $failure = Search-4625 -TargetDC $odc -User $User -Time $Time
            if ($failure) { return $failure + " (найдено на $odc)" }
        }
    }

    return "⚠️ Событие 4625 (причина отказа) не найдено ни на одном DC."
}

function Get-RemoteLockoutProcess {
    param(
        [string]$ComputerName,
        [string]$UserName
    )

    $resultBox.SelectionColor = [System.Drawing.Color]::DarkBlue
    $resultBox.AppendText("🕵️ ГЛУБОКИЙ АНАЛИЗ ИСТОЧНИКА ($ComputerName):`n")
    $form.Refresh()

    if (-not (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet)) {
        $resultBox.SelectionColor = [System.Drawing.Color]::Red
        $resultBox.AppendText("❌ Компьютер недоступен (Ping).`n")
        return
    }

    $resultBox.AppendText("✅ Компьютер в сети. Запускаю PsExec (CMD-режим)...`n")
    $form.Refresh()

    # Путь к PsExec
    $psexec = "$PSScriptRoot\PSTools\PsExec.exe"
    if (-not (Test-Path $psexec)) { $psexec = "$PSScriptRoot\PsExec.exe" }
    if (-not (Test-Path $psexec)) { $psexec = "PsExec.exe" }

    # Сама команда PowerShell, которую надо выполнить ТАМ.
    # Обратите внимание: всё в одну строку, минимум кавычек.
    $remoteCommand = "Get-WinEvent -FilterHashtable @{LogName='Security';ID=4625} -MaxEvents 5 -ErrorAction SilentlyContinue | Select-Object @{N='Time';E={$_.TimeCreated.ToString('HH:mm:ss')}}, @{N='Proc';E={$_.Properties[10].Value}} | Format-Table -HideTableHeaders -AutoSize | Out-String -Width 300"
    
    # Заворачиваем в Base64, чтобы CMD не подавился спецсимволами
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($remoteCommand)
    $encoded = [Convert]::ToBase64String($bytes)

    # Запускаем через CMD /C, чтобы PsExec чувствовал себя как дома
    # 2>&1 объединяет поток ошибок и вывода
    $cmdArgs = "/c `"$psexec`" \\$ComputerName -s -accepteula -nobanner powershell -NoProfile -EncodedCommand $encoded 2>&1"
    
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "cmd.exe"
    $processInfo.Arguments = $cmdArgs
    $processInfo.RedirectStandardOutput = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true

    $p = [System.Diagnostics.Process]::Start($processInfo)
    
    # Читаем вывод в реальном времени (ну почти)
    $output = $p.StandardOutput.ReadToEnd()
    $p.WaitForExit()

    # Парсим и выводим
    if ($output) {
        $lines = $output -split "`n"
        $foundEvents = $false

        foreach ($line in $lines) {
            # Пропускаем служебные сообщения PsExec
            if ($line -match "^PsExec|^Copyright|^Connect|^Start|^Exited") { continue }
            if ($line -match "^\s*$") { continue }

            $foundEvents = $true
            $resultBox.SelectionColor = [System.Drawing.Color]::Black
            $resultBox.AppendText("   $line`n")

            if ($line -match "svchost") {
                $resultBox.SelectionColor = [System.Drawing.Color]::Gray
                $resultBox.AppendText("      ↳ Системная служба / Credential Manager`n")
            }
            if ($line -match "OUTLOOK") {
                $resultBox.SelectionColor = [System.Drawing.Color]::Gray
                $resultBox.AppendText("      ↳ Outlook (старый пароль)`n")
            }
        }
        
        if (-not $foundEvents) {
             $resultBox.SelectionColor = [System.Drawing.Color]::DarkOrange
             $resultBox.AppendText("⚠️ Вывод получен, но событий 4625 не найдено.`n")
        }
    } else {
        $resultBox.SelectionColor = [System.Drawing.Color]::Red
        $resultBox.AppendText("❌ Нет ответа от PsExec. Порт 445 закрыт или доступ запрещен.`n")
    }
}






# --- GUI СОЗДАНИЕ (СНАЧАЛА СОЗДАЕМ ФОРМУ И ВСЕ КОНТРОЛЫ) ---

$form = New-Object System.Windows.Forms.Form
$form.Text = "Active Directory Lockout Investigator v2.2"
$form.Size = New-Object System.Drawing.Size(900, 700)
$form.StartPosition = "CenterScreen"

$lbl = New-Object System.Windows.Forms.Label
$lbl.Location = "10,15"; $lbl.Size = "200,20"; $lbl.Text = "Пользователь (Login/FIO):"
$form.Controls.Add($lbl)

$txt = New-Object System.Windows.Forms.TextBox
$txt.Location = "210,12"; $txt.Size = "200,20"
$form.Controls.Add($txt)

$btnFind = New-Object System.Windows.Forms.Button
$btnFind.Location = "420,10"; $btnFind.Text = "🔍 Найти источник"; $btnFind.Size = "120,25"
$form.Controls.Add($btnFind)

$btnExchange = New-Object System.Windows.Forms.Button
$btnExchange.Location = "550,10"; $btnExchange.Text = "📧 Логи Exchange"; $btnExchange.Size = "120,25"; $btnExchange.Enabled = $false
$form.Controls.Add($btnExchange)

$resultBox = New-Object System.Windows.Forms.RichTextBox
$resultBox.Location = "10,50"; $resultBox.Size = "860,570"; $resultBox.Font = "Consolas, 9"; $resultBox.ReadOnly = $true
$form.Controls.Add($resultBox)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20, 630)
$progressBar.Size = New-Object System.Drawing.Size(400, 20)
$progressBar.Style = "Continuous"
$form.Controls.Add($progressBar)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(430, 630)
$statusLabel.Size = New-Object System.Drawing.Size(480, 20)
$statusLabel.Text = "Готов к работе"
$statusLabel.ForeColor = [System.Drawing.Color]::DimGray
$form.Controls.Add($statusLabel)

# --- ТЕПЕРЬ ФУНКЦИЯ Set-Progress (ПОСЛЕ СОЗДАНИЯ GUI) ---

function Set-Progress {
    param(
        [string]$Text,
        [int]$Percent = -1,
        [string]$Color = "Black"
    )
    
    $statusLabel.Text = $Text
    
    if ($Color -eq "Red") { $statusLabel.ForeColor = [System.Drawing.Color]::Red }
    elseif ($Color -eq "Green") { $statusLabel.ForeColor = [System.Drawing.Color]::Green }
    else { $statusLabel.ForeColor = [System.Drawing.Color]::Black }

    if ($Percent -ge 0 -and $Percent -le 100) {
        $progressBar.Value = $Percent
    } elseif ($Percent -ne -1) {
        $progressBar.Value = 0
    }

    $form.Refresh()
    [System.Windows.Forms.Application]::DoEvents()
}

# --- ФУНКЦИИ С ЗАВИСИМОСТЬЮ ОТ GUI (ПОСЛЕ Set-Progress) ---

function Find-LastLockoutSource {
    param([string]$SearchTerm)
    
    $resultBox.Clear()
    Set-Progress "Поиск пользователя в Active Directory..." 10
    
    if (-not $SearchTerm) { 
        $resultBox.Text = "Введите ФИО или логин."
        Set-Progress "Ошибка ввода" 0 "Red"
        return 
    }
    
    try {
        # --- БЛОК ПОИСКА ПОЛЬЗОВАТЕЛЯ ---
        $usersFound = Get-ADUser -Filter "SamAccountName -eq '$SearchTerm' -or Name -like '*$SearchTerm*'" -Properties DisplayName, SamAccountName, Enabled, UserPrincipalName
        
        $targetUser = $null

        if (-not $usersFound) { 
            $resultBox.Text = "Пользователь не найден."
            Set-Progress "Пользователь не найден" 0 "Red"
            return 
        }
        elseif ($usersFound.Count -gt 1) {
            Set-Progress "Найдено несколько пользователей. Ожидание выбора..." 15
            $selected = $usersFound | Select-Object Name, SamAccountName, Enabled, UserPrincipalName | 
                        Out-GridView -Title "Найдено $($usersFound.Count) совпадений. Выберите нужного пользователя и нажмите OK" -OutputMode Single
            
            if (-not $selected) {
                $resultBox.Text = "Выбор отменен."
                Set-Progress "Отмена выбора" 0 "Red"
                return
            }
            $targetUser = $usersFound | Where-Object { $_.SamAccountName -eq $selected.SamAccountName } | Select-Object -First 1
        }
        else {
            $targetUser = $usersFound[0] 
            if (-not $targetUser) { $targetUser = $usersFound }
        }

        # --- НАЧАЛО ПОИСКА БЛОКИРОВКИ ---
        Set-Progress "Пользователь выбран. Начинаем поиск по всем DC..." 20
        $sam = $targetUser.SamAccountName
        $script:currentSam = $sam
        $resultBox.Text = "✅ Выбран пользователь: $($targetUser.DisplayName) ($sam)`n"
        $resultBox.Text += "--------------------------------------------------`n"
        
        # Собираем список всех контроллеров (PDC первый, потом остальные)
        $allDCs = @()
        if ($Config.PrimaryDC) { $allDCs += $Config.PrimaryDC }
        if ($Config.AdditionalDCs) { $allDCs += $Config.AdditionalDCs }
        # Убираем дубликаты, если вдруг PDC попал и туда и сюда
        $allDCs = $allDCs | Select-Object -Unique

        $event4740 = $null
        $foundOnDC = $null

        $timeWindow = (Get-Date).AddHours(-$Config.SearchHours)
        
        $counter = 0
        foreach ($dc in $allDCs) {
            $counter++
            # Расчет прогресса от 30 до 60%
            $prog = 30 + [int](($counter / $allDCs.Count) * 30)
            Set-Progress "Сканирование DC: $dc..." $prog

            if (-not (Test-ServerConnection $dc)) {
                $resultBox.Text += "⚠️ $dc недоступен, пропускаем...`n"
                continue
            }

            try {
                # Ищем 4740 на конкретном DC
                $ev = Get-WinEvent -ComputerName $dc -FilterHashtable @{LogName='Security';ID=4740;StartTime=$timeWindow} -ErrorAction SilentlyContinue | 
                      Where-Object { $_.Properties[0].Value -eq $sam } | Sort-Object TimeCreated -Descending | Select-Object -First 1
                
                # Если нашли событие, и оно новее, чем то, что у нас уже есть (или если у нас еще ничего нет)
                if ($ev) {
                    if ($null -eq $event4740 -or $ev.TimeCreated -gt $event4740.TimeCreated) {
                        $event4740 = $ev
                        $foundOnDC = $dc
                        # Можно прервать цикл, если считаем, что нашли самое свежее (обычно достаточно первого найденного)
                        # Но для точности лучше проверить все или хотя бы PDC первым.
                        # Если нашли на PDC - прерываем точно.
                        if ($dc -eq $Config.PrimaryDC) { break }
                    }
                }
            } catch {
                $resultBox.Text += "⚠️ Ошибка чтения логов на $dc.`n"
            }
        }

        # --- ОБРАБОТКА РЕЗУЛЬТАТА ---

        if ($event4740) {
            Set-Progress "Блокировка найдена! Анализ источника..." 65
            
            $lockoutTime = $event4740.TimeCreated
            $sourceMachine = $event4740.Properties[1].Value
            
            $script:lockoutStartTime = $lockoutTime.AddMinutes(-$Config.TimeWindowBefore)
            $script:lockoutEndTime = $lockoutTime.AddMinutes($Config.TimeWindowAfter)
            
            $resultBox.SelectionColor = [System.Drawing.Color]::Red
            $resultBox.AppendText("ЗАБЛОКИРОВАН: $($lockoutTime.ToString('dd.MM.yyyy HH:mm:ss'))`n")
            $resultBox.SelectionColor = [System.Drawing.Color]::Black
            $resultBox.AppendText("Обнаружено на контроллере: $foundOnDC`n")
            $resultBox.AppendText("💻 ИСТОЧНИК БЛОКИРОВКИ: $sourceMachine`n")
            
            # 2. Анализ причины (4625)
            # Тут мы передаем $foundOnDC, так как логичнее искать причину там, где зафиксирована блокировка, 
            # но функция Get-LogonFailureDetails и так умеет искать везде.
            Set-Progress "Поиск причины (Event 4625)..." 70
            $failureReason = Get-LogonFailureDetails -DC $foundOnDC -User $sam -Time $lockoutTime
            $resultBox.AppendText("$failureReason`n")
            
             # 3. Анализ источника
Set-Progress "Инспекция источника ($sourceMachine)..." 80

if ($sourceMachine -and $sourceMachine -ne "") {
    if ($Config.ExchangeServers -contains $sourceMachine) {
        $resultBox.SelectionColor = [System.Drawing.Color]::Blue
        $resultBox.AppendText("Источник - Exchange. Проверьте логи Exchange.`n")
    } else {
        $resultBox.SelectionColor = [System.Drawing.Color]::DarkBlue
        $resultBox.AppendText("Глубокий анализ источника ($sourceMachine):`n")
        $form.Refresh()

        # Проверка ping
        if (-not (Test-Connection -ComputerName $sourceMachine -Count 1 -Quiet)) {
            $resultBox.SelectionColor = [System.Drawing.Color]::Red
            $resultBox.AppendText("Компьютер недоступен (Ping).`n")
            return
        }

        $resultBox.AppendText("Компьютер в сети. Запускаю PsExec (как в CMD)...`n")
        $form.Refresh()

        # Путь к PsExec.exe
        $psexec = Join-Path $PSScriptRoot "PsExec.exe"
        if (-not (Test-Path $psexec)) {
            $psexec = Join-Path (Join-Path $PSScriptRoot "PSTools") "PsExec.exe"
        }
        if (-not (Test-Path $psexec)) {
            $resultBox.SelectionColor = [System.Drawing.Color]::Red
            $resultBox.AppendText("PsExec.exe не найден рядом со скриптом.`n")
            return
        }

        # Ровно та же команда, что работает у тебя в CMD.
        # Важно: `$_ экранирован, чтобы интерпретировался на удаленной машине.
        $remoteCmd = "Get-WinEvent -FilterHashtable @{LogName='Security';ID=4625} -MaxEvents 5 | " +
                     "Select-Object TimeCreated, @{N='Process';E={`$_.Properties[10].Value}}, @{N='LogonType';E={`$_.Properties[18].Value}}"

        try {
            # Запуск PsExec напрямую из PowerShell
            $output = & $psexec "\\$sourceMachine" -s -accepteula -nobanner `
                       powershell -NoProfile -Command $remoteCmd 2>&1

            if (-not $output) {
                $resultBox.SelectionColor = [System.Drawing.Color]::DarkOrange
                $resultBox.AppendText("PsExec не вернул данных (нет событий 4625 или доступ запрещен).`n")
                return
            }

            # Превращаем вывод в строки
            $lines = ($output | Out-String) -split "`r?`n"

            # Фильтруем служебный мусор PsExec/PowerShell
            $useful = $lines | Where-Object {
                $_.Trim() -ne "" -and
                $_ -notmatch '^PsExec' -and
                $_ -notmatch '^Copyright' -and
                $_ -notmatch '^Connecting to ' -and
                $_ -notmatch '^Starting PSEXESVC' -and
                $_ -notmatch '^Copying authentication key' -and
                $_ -notmatch '^Connecting with PsExec service' -and
                $_ -notmatch '^Starting powershell on' -and
                $_ -notmatch '^powershell exited' -and
                $_ -notmatch '^TimeCreated' -and
                $_ -notmatch '^-----------'
            }

            if (-not $useful) {
                $resultBox.SelectionColor = [System.Drawing.Color]::DarkOrange
                $resultBox.AppendText("События 4625 найдены, но пригодных строк нет.`n")
                return
            }

            foreach ($line in $useful) {
                # Пример строки: "19.02.2026 9:20:58       2 C:\Windows\System32\svchost.exe"
                $resultBox.SelectionColor = [System.Drawing.Color]::Black
                $resultBox.AppendText("    $line`n")

                if ($line -match "svchost.exe") {
                    $resultBox.SelectionColor = [System.Drawing.Color]::Gray
                    $resultBox.AppendText("        Подсказка: системная служба (часто Credential Manager или задача в планировщике).`n")
                }
                if ($line -match "OUTLOOK.EXE") {
                    $resultBox.SelectionColor = [System.Drawing.Color]::Gray
                    $resultBox.AppendText("        Подсказка: Outlook с сохраненным старым паролем.`n")
                }
            }
        } catch {
            $resultBox.SelectionColor = [System.Drawing.Color]::Red
            $resultBox.AppendText("Ошибка при запуске PsExec: $($_.Exception.Message)`n")
        }
    }
}






            
            $btnExchange.Enabled = $true
            Set-Progress "Готово. Источник найден." 100 "Green"
            
        } else {
            Set-Progress "Блокировок не найдено" 100
            $resultBox.Text += "✅ Событий блокировки (4740) не найдено на проверенных DC.`n"
        }

    } catch {
        Set-Progress "Ошибка выполнения" 0 "Red"
        $resultBox.Text += "❌ Ошибка: $($_.Exception.Message)"
    }
}


function Search-ExchangeLogs {
    param([string]$Username)
    
    $resultBox.Clear()
    Set-Progress "Инициализация поиска Exchange..." 0
    
    $resultBox.SelectionFont = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $resultBox.AppendText("🔍 АНАЛИЗ ПОЧТОВЫХ ЛОГОВ ДЛЯ: $Username`n")
    $resultBox.AppendText("-" * 60 + "`n")
    
    $allLogs = @()
    $serverCount = $Config.ExchangeServers.Count
    $currentServer = 0
    
    foreach ($server in $Config.ExchangeServers) {
        $currentServer++
        $pct = [math]::Round(($currentServer / $serverCount) * 100)
        
        Set-Progress "Сканирование логов на сервере $server ($currentServer из $serverCount)..." $pct
        $resultBox.AppendText("📡 Чтение логов с $server... ")
        $form.Refresh() 
        
        $logs = Get-RemoteExchangeLogs -ComputerName $server -Username $Username -StartTime $script:lockoutStartTime -EndTime $script:lockoutEndTime
        
        if ($logs) {
            $resultBox.AppendText("найдено $($logs.Count) записей.`n")
            $allLogs += $logs
        } else {
            $resultBox.AppendText("пусто.`n")
        }
    }

    Set-Progress "Анализ полученных данных..." 100
    
    if ($allLogs.Count -gt 0) {
        $resultBox.AppendText("`n📋 ДЕТАЛИЗАЦИЯ ЗАПРОСОВ (401/Ошибки):`n")
        
        $grouped = $allLogs | Group-Object ClientIP, Protocol
        
        foreach ($g in $grouped) {
            $ip = $g.Values[0]
            $proto = $g.Values[1]
            $count = $g.Count
            $userAgentEx = $g.Group[0].UserAgent
            
            $resultBox.SelectionColor = [System.Drawing.Color]::Blue
            $resultBox.AppendText(" • $proto с IP: $ip ($count попыток)`n")
            $resultBox.SelectionColor = [System.Drawing.Color]::Black
            $resultBox.AppendText("   Agent: $userAgentEx`n")
        }
    } else {
        $resultBox.AppendText("`n✅ Подозрительных записей в логах IIS/Exchange не найдено.`n")
    }

    Set-Progress "Анализ Exchange завершен" 100 "Green"
}

# --- ПОДКЛЮЧЕНИЕ ОБРАБОТЧИКОВ СОБЫТИЙ (В САМОМ КОНЦЕ) ---

$btnFind.Add_Click({ Find-LastLockoutSource $txt.Text })
$btnExchange.Add_Click({ Search-ExchangeLogs $script:currentSam })

$txt.Add_KeyDown({
    if ($_.KeyCode -eq "Enter") {
        $_.SuppressKeyPress = $true 
        $btnFind.PerformClick() 
    }
})

# --- ЗАПУСК ФОРМЫ ---
$form.ShowDialog()
