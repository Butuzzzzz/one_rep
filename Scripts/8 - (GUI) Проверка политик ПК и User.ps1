Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Полностью скрыть консоль PowerShell
if ($Host.Name -eq 'ConsoleHost') {
    Add-Type -Name Window -Namespace Console -MemberDefinition '
    [DllImport("Kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
    '
    $consolePtr = [Console.Window]::GetConsoleWindow()
    [Console.Window]::ShowWindow($consolePtr, 0)
}

# Основная форма
$form = New-Object System.Windows.Forms.Form
$form.Text = "Анализатор групповых политик"
$form.Size = New-Object System.Drawing.Size(1000, 700)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(800, 600)
$form.KeyPreview = $true

# Стиль шрифта
$font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)

# Заголовок
$labelTitle = New-Object System.Windows.Forms.Label
$labelTitle.Text = "Проверка применяемых групповых политик"
$labelTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$labelTitle.Size = New-Object System.Drawing.Size(800, 30)
$labelTitle.Location = New-Object System.Drawing.Point(50, 20)
$labelTitle.TextAlign = "MiddleCenter"
$form.Controls.Add($labelTitle)

# Группа выбора типа
$groupType = New-Object System.Windows.Forms.GroupBox
$groupType.Text = "Тип объекта"
$groupType.Size = New-Object System.Drawing.Size(800, 80)
$groupType.Location = New-Object System.Drawing.Point(50, 60)
$form.Controls.Add($groupType)

# Радио-кнопки
$radioComputer = New-Object System.Windows.Forms.RadioButton
$radioComputer.Text = "Компьютер"
$radioComputer.Size = New-Object System.Drawing.Size(120, 24)
$radioComputer.Location = New-Object System.Drawing.Point(20, 30)
$radioComputer.Checked = $true
$groupType.Controls.Add($radioComputer)

$radioUser = New-Object System.Windows.Forms.RadioButton
$radioUser.Text = "Пользователь"
$radioUser.Size = New-Object System.Drawing.Size(120, 24)
$radioUser.Location = New-Object System.Drawing.Point(160, 30)
$groupType.Controls.Add($radioUser)

# Поле ввода имени
$labelName = New-Object System.Windows.Forms.Label
$labelName.Text = "Имя компьютера:"
$labelName.Size = New-Object System.Drawing.Size(300, 20)
$labelName.Location = New-Object System.Drawing.Point(50, 160)
$labelName.Font = $font
$form.Controls.Add($labelName)

$textBoxName = New-Object System.Windows.Forms.TextBox
$textBoxName.Size = New-Object System.Drawing.Size(500, 30)
$textBoxName.Location = New-Object System.Drawing.Point(50, 185)
$textBoxName.Font = $font
$textBoxName.Text = $env:COMPUTERNAME
$form.Controls.Add($textBoxName)

# Кнопка проверки
$buttonCheck = New-Object System.Windows.Forms.Button
$buttonCheck.Text = "Проверить политики"
$buttonCheck.Size = New-Object System.Drawing.Size(150, 35)
$buttonCheck.Location = New-Object System.Drawing.Point(565, 180)
$buttonCheck.Font = $font
$buttonCheck.BackColor = "#0078D4"
$buttonCheck.ForeColor = "White"
$buttonCheck.FlatStyle = "Flat"
$form.Controls.Add($buttonCheck)

# Группа результатов
$groupResults = New-Object System.Windows.Forms.GroupBox
$groupResults.Text = "Результаты проверки"
$groupResults.Location = New-Object System.Drawing.Point(50, 240)
$groupResults.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($groupResults)

# Текстовое поле для результатов
$textBoxResults = New-Object System.Windows.Forms.RichTextBox
$textBoxResults.Location = New-Object System.Drawing.Point(10, 20)
$textBoxResults.Font = $font
$textBoxResults.ReadOnly = $true
$textBoxResults.BackColor = "White"
$textBoxResults.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$groupResults.Controls.Add($textBoxResults)

# Прогресс-бар
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Height = 20
$progressBar.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$progressBar.Style = "Marquee"
$progressBar.Visible = $false
$form.Controls.Add($progressBar)

# Функция для обновления размеров контролов
function Update-ControlSizes {
    $formWidth = $form.ClientSize.Width
    $formHeight = $form.ClientSize.Height
    
    $groupType.Width = $formWidth - 100
    $groupResults.Width = $formWidth - 100
    $groupResults.Height = $formHeight - 300
    
    $textBoxName.Width = $formWidth - 250
    $buttonCheck.Location = New-Object System.Drawing.Point(($formWidth - 185), 180)
    
    $progressBar.Width = $formWidth - 100
    $progressBar.Location = New-Object System.Drawing.Point(50, ($formHeight - 40))
    
    $textBoxResults.Width = $groupResults.Width - 20
    $textBoxResults.Height = $groupResults.Height - 40
}

# Функция для добавления текста в результаты
function Add-Result {
    param([string]$Message, [string]$Color = "Black")
    
    $textBoxResults.SelectionStart = $textBoxResults.TextLength
    $textBoxResults.SelectionLength = 0
    
    switch ($Color) {
        "Green" { $textBoxResults.SelectionColor = "DarkGreen" }
        "Red" { $textBoxResults.SelectionColor = "DarkRed" }
        "Blue" { $textBoxResults.SelectionColor = "DarkBlue" }
        "Orange" { $textBoxResults.SelectionColor = "DarkOrange" }
        "DarkGray" { $textBoxResults.SelectionColor = "Gray" }
        "DarkBlue" { $textBoxResults.SelectionColor = "Navy" }
        "Purple" { $textBoxResults.SelectionColor = "Purple" }
        default { $textBoxResults.SelectionColor = "Black" }
    }
    
    $textBoxResults.AppendText("$Message`r`n")
    $textBoxResults.ScrollToCaret()
}

# Функция проверки прав администратора
function Test-AdminRights {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Функция проверки доступности компьютера
function Test-ComputerAvailability {
    param([string]$ComputerName)
    
    try {
        if ($ComputerName -eq "." -or $ComputerName -eq "localhost" -or $ComputerName -eq $env:COMPUTERNAME) {
            return $true
        }
        
        $result = Test-Connection -ComputerName $ComputerName -Count 1 -Quiet -ErrorAction Stop
        return $result
    }
    catch {
        return $false
    }
}

# Функция поиска пользователя по ФИО
function Find-UserByDisplayName {
    param([string]$DisplayName)
    
    try {
        Add-Result "Поиск пользователя по ФИО: $DisplayName" "Blue"
        
        # Ищем пользователей по ФИО
        $users = Get-ADUser -Filter "DisplayName -like '*$DisplayName*'" -Properties DisplayName, SamAccountName, UserPrincipalName, Enabled, DistinguishedName
        
        if ($users.Count -eq 0) {
            Add-Result "Пользователи с ФИО '$DisplayName' не найдены" "Orange"
            return $null
        }
        elseif ($users.Count -eq 1) {
            $user = $users[0]
            Add-Result "✓ Найден пользователь: $($user.DisplayName)" "Green"
            Add-Result "  Логин: $($user.SamAccountName)" "Black"
            Add-Result "  UPN: $($user.UserPrincipalName)" "Black"
            Add-Result "  Статус: $(if($user.Enabled){'Включен'}else{'Отключен'})" "Black"
            return $user
        }
        else {
            Add-Result "Найдено несколько пользователей ($($users.Count)):" "Blue"
            
            # Форма для выбора пользователя
            $selectionForm = New-Object System.Windows.Forms.Form
            $selectionForm.Text = "Выберите пользователя"
            $selectionForm.Size = New-Object System.Drawing.Size(600, 400)
            $selectionForm.StartPosition = "CenterScreen"
            $selectionForm.TopMost = $true
            
            $label = New-Object System.Windows.Forms.Label
            $label.Text = "Найдено несколько пользователей. Выберите нужного:"
            $label.Location = New-Object System.Drawing.Point(10, 10)
            $label.Size = New-Object System.Drawing.Size(560, 20)
            $selectionForm.Controls.Add($label)
            
            $listBox = New-Object System.Windows.Forms.ListBox
            $listBox.Location = New-Object System.Drawing.Point(10, 40)
            $listBox.Size = New-Object System.Drawing.Size(560, 280)
            $listBox.Font = New-Object System.Drawing.Font("Consolas", 9)
            
            foreach ($user in $users) {
                $status = if($user.Enabled) { "Вкл" } else { "Откл" }
                $listBox.Items.Add("$($user.DisplayName.PadRight(40)) | $($user.SamAccountName.PadRight(15)) | $($user.UserPrincipalName.PadRight(30)) | $status") | Out-Null
            }
            
            $listBox.SelectedIndex = 0
            $selectionForm.Controls.Add($listBox)
            
            $okButton = New-Object System.Windows.Forms.Button
            $okButton.Text = "OK"
            $okButton.Location = New-Object System.Drawing.Point(250, 330)
            $okButton.Size = New-Object System.Drawing.Size(80, 25)
            $okButton.DialogResult = "OK"
            $selectionForm.AcceptButton = $okButton
            $selectionForm.Controls.Add($okButton)
            
            $result = $selectionForm.ShowDialog($form)
            
            if ($result -eq "OK" -and $listBox.SelectedIndex -ge 0) {
                $selectedUser = $users[$listBox.SelectedIndex]
                Add-Result "✓ Выбран пользователь: $($selectedUser.DisplayName)" "Green"
                Add-Result "  Логин: $($selectedUser.SamAccountName)" "Black"
                Add-Result "  UPN: $($selectedUser.UserPrincipalName)" "Black"
                return $selectedUser
            }
            else {
                Add-Result "Выбор пользователя отменен" "Orange"
                return $null
            }
        }
    }
    catch {
        Add-Result "Ошибка при поиске пользователя в Active Directory: $($_.Exception.Message)" "Red"
        return $null
    }
}

# Функция для получения информации о пользователе
function Get-UserADInfo {
    param([string]$UserName)
    
    try {
        $user = Get-ADUser -Identity $UserName -Properties DisplayName, DistinguishedName, LastLogonDate, Enabled, MemberOf, EmailAddress -ErrorAction Stop
        return $user
    }
    catch {
        return $null
    }
}

# Функция для получения политик с улучшенным парсингом
function Get-GPOsWithDetailedAnalysis {
    param([string]$Target, [bool]$IsComputer)
    
    $gpos = @()
    $filteredGpos = @()
    $rawOutput = @()
    
    try {
        # Создаем временный файл с правильной кодировкой
        $tempFile = [System.IO.Path]::GetTempFileName()
        
        if ($IsComputer) {
            Add-Result "Выполнение: gpresult /S $Target /R /Scope Computer" "DarkGray"
            $process = Start-Process -FilePath "gpresult" -ArgumentList "/S", $Target, "/R", "/Scope", "Computer" -Wait -PassThru -NoNewWindow -RedirectStandardOutput $tempFile
        }
        else {
            Add-Result "Выполнение: gpresult /USER $Target /R /Scope User" "DarkGray"
            $process = Start-Process -FilePath "gpresult" -ArgumentList "/USER", $Target, "/R", "/Scope", "User" -Wait -PassThru -NoNewWindow -RedirectStandardOutput $tempFile
        }
        
        # Читаем файл с правильной кодировкой
        $rawOutput = Get-Content $tempFile -Encoding Unicode
        Remove-Item $tempFile -ErrorAction SilentlyContinue
        
        # Если не получилось, пробуем другие кодировки
        if ($rawOutput.Count -eq 0 -or $rawOutput[0] -match "€") {
            $rawOutput = Get-Content $tempFile -Encoding UTF8
        }
        if ($rawOutput.Count -eq 0 -or $rawOutput[0] -match "€") {
            $rawOutput = Get-Content $tempFile -Encoding Default
        }
        
        # Если все еще проблемы, используем прямой вызов
        if ($rawOutput.Count -eq 0 -or $rawOutput[0] -match "€") {
            Add-Result "Проблемы с кодировкой, используем альтернативный метод..." "Orange"
            if ($IsComputer) {
                $rawOutput = & cmd /c "chcp 65001 >nul && gpresult /S $Target /R /Scope Computer"
            }
            else {
                $rawOutput = & cmd /c "chcp 65001 >nul && gpresult /USER $Target /R /Scope User"
            }
        }
        
        # Диагностика: покажем информативные строки
        Add-Result "Поиск информативных строк в выводе..." "DarkGray"
        $infoLines = $rawOutput | Where-Object { 
            $_ -match "Applied Group Policy Objects" -or 
            $_ -match "Применяемые объекты групповой политики" -or
            $_ -match "USER|Пользователь" -or
            $_ -match "COMPUTER|Компьютер" -or
            $_ -match "Last time|Последний раз" -or
            $_ -match "Group Policy was applied|Групповая политика применялась"
        }
        
        foreach ($line in $infoLines) {
            Add-Result "  $($line.Trim())" "DarkGray"
        }
        
        # Анализ вывода
        $inAppliedSection = $false
        $inFilteredSection = $false
        
        foreach ($line in $rawOutput) {
            $trimmedLine = $line.Trim()
            
            # Пропускаем строки с мусором из-за кодировки
            if ($trimmedLine -match "^[�€¤]+$" -or $trimmedLine -eq "") {
                continue
            }
            
            # Определяем начало секции с применяемыми политиками
            if ($trimmedLine -match "Applied Group Policy Objects" -or $trimmedLine -match "Применяемые объекты групповой политики") {
                $inAppliedSection = $true
                $inFilteredSection = $false
                Add-Result "✓ Найдена секция применяемых политик" "Green"
                continue
            }
            
            # Определяем начало секции с отфильтрованными политиками
            if ($trimmedLine -match "Следующие политики GPO не были применены" -or $trimmedLine -match "The following GPOs were not applied") {
                $inAppliedSection = $false
                $inFilteredSection = $true
                Add-Result "✓ Найдена секция отфильтрованных политик" "Orange"
                continue
            }
            
            # Обрабатываем применяемые политики
            if ($inAppliedSection) {
                if ($trimmedLine -eq "" -or 
                    $trimmedLine -match "Security Groups" -or 
                    $trimmedLine -match "Группы безопасности" -or
                    $trimmedLine -match "Resultant Set Of Policies" -or
                    $trimmedLine -match "Результирующий набор политик" -or
                    $trimmedLine -match "^-+$") {
                    $inAppliedSection = $false
                    continue
                }
                
                if ($trimmedLine -notmatch "Local Group Policy" -and 
                    $trimmedLine -notmatch "Локальная групповая политика" -and
                    $trimmedLine -ne "") {
                    $gpos += $trimmedLine
                    Add-Result "  ✓ Политика: $trimmedLine" "DarkGreen"
                }
            }
            
            # Обрабатываем отфильтрованные политики
            if ($inFilteredSection) {
                if ($trimmedLine -eq "" -or 
                    $trimmedLine -match "Компьютер является членом" -or 
                    $trimmedLine -match "Computer is a part of" -or
                    $trimmedLine -match "^-+$") {
                    $inFilteredSection = $false
                    continue
                }
                
                if ($trimmedLine -match "Local Group Policy" -or $trimmedLine -match "Локальная групповая политика") {
                    $filteredGpos += $trimmedLine
                    Add-Result "  ⚠ Отфильтровано: $trimmedLine" "DarkOrange"
                }
            }
        }
        
        Add-Result "Итог: применяемых политик - $($gpos.Count), отфильтрованных - $($filteredGpos.Count)" "Blue"
        
        return @{
            GPOs = $gpos
            FilteredGPOs = $filteredGpos
            RawOutput = $rawOutput
            Success = $true
        }
    }
    catch {
        Add-Result "Ошибка выполнения gpresult: $($_.Exception.Message)" "Red"
        return @{
            GPOs = @()
            FilteredGPOs = @()
            RawOutput = @("Ошибка выполнения: $($_.Exception.Message)")
            Success = $false
        }
    }
}

# Функция для проверки через RSOP.MSC (если доступно)
function Test-RSOPMethod {
    param([string]$UserName)
    
    try {
        Add-Result "Попытка использования RSOP данных..." "Blue"
        
        # Пробуем найти существующие файлы RSOP
        $rsopPaths = @(
            "$env:WINDIR\System32\GroupPolicy\DataStore",
            "$env:WINDIR\System32\GroupPolicy\User",
            "$env:WINDIR\System32\GroupPolicy\Machine"
        )
        
        foreach ($path in $rsopPaths) {
            if (Test-Path $path) {
                $files = Get-ChildItem $path -Recurse -ErrorAction SilentlyContinue
                if ($files.Count -gt 0) {
                    Add-Result "Найдены файлы RSOP в: $path" "Green"
                    return $true
                }
            }
        }
        
        # Пробуем создать временный RSOP
        Add-Result "Создание временного RSOP отчета..." "DarkGray"
        $tempFile = [System.IO.Path]::GetTempFileName() + ".html"
        $process = Start-Process -FilePath "gpresult" -ArgumentList "/USER", $UserName, "/H", $tempFile -Wait -PassThru
        
        if (Test-Path $tempFile -and (Get-Item $tempFile).Length -gt 0) {
            Add-Result "✓ RSOP отчет создан: $tempFile" "Green"
            
            # Читаем HTML и ищем GPO
            $htmlContent = Get-Content $tempFile -Raw -ErrorAction SilentlyContinue
            if ($htmlContent -match "GPO") {
                $gpoMatches = [regex]::Matches($htmlContent, ">([^<]+GPO[^<]+)<")
                if ($gpoMatches.Count -gt 0) {
                    Add-Result "Найдены упоминания GPO в отчете:" "Green"
                    foreach ($match in $gpoMatches[0..4]) { # Показываем первые 5
                        Add-Result "  • $($match.Groups[1].Value)" "Black"
                    }
                    return $true
                }
            }
            
            Remove-Item $tempFile -ErrorAction SilentlyContinue
        }
        
        return $false
    }
    catch {
        Add-Result "RSOP метод не сработал: $($_.Exception.Message)" "Orange"
        return $false
    }
}

# Функция для ручной проверки через net commands
function Test-NetCommands {
    param([string]$UserName)
    
    try {
        Add-Result "Проверка через сетевые команды..." "Blue"
        
        # Проверяем членство в группах
        Add-Result "Членство пользователя в группах:" "DarkGray"
        $groups = & cmd /c "net user $UserName /domain 2>&1" | Where-Object { $_ -match "Локальные члены группы" -or $_ -match "Local Group Memberships" -or $_ -match "Глобальные члены группы" -or $_ -match "Global Group Memberships" }
        
        foreach ($group in $groups) {
            Add-Result "  $($group.Trim())" "Black"
        }
        
        # Проверяем информацию о пользователе
        Add-Result "Информация о пользователе из домена:" "DarkGray"
        $userInfo = & cmd /c "net user $UserName /domain 2>&1" | Select-Object -First 20
        foreach ($line in $userInfo) {
            if ($line.Trim() -ne "" -and $line -notmatch "Команда выполнена" -and $line -notmatch "The command completed") {
                Add-Result "  $($line.Trim())" "Black"
            }
        }
        
        return $true
    }
    catch {
        Add-Result "Сетевые команды не сработали: $($_.Exception.Message)" "Orange"
        return $false
    }
}

# Улучшенная функция для получения GPO через LDAP запросы
function Get-GPOsViaLDAP {
    param([string]$UserName, [string]$UserDN)
    
    try {
        Add-Result "Поиск GPO через LDAP запросы..." "Blue"
        
        # Разбираем DN пользователя чтобы получить всю иерархию OU
        $dnParts = $UserDN -split ","
        $ouHierarchy = @()
        
        foreach ($part in $dnParts) {
            if ($part -match "^OU=") {
                $ouName = $part -replace "^OU=", ""
                $ouHierarchy += $ouName
            }
        }
        
        Add-Result "Иерархия OU пользователя: $($ouHierarchy -join ' -> ')" "Green"
        
        # Пробуем подключиться к контроллеру домена
        $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
        $dc = $domain.DomainControllers[0].Name
        Add-Result "Используем контроллер домена: $dc" "DarkGray"
        
        # Получаем информацию о пользователе
        $searcher = New-Object System.DirectoryServices.DirectorySearcher
        $searcher.SearchRoot = "LDAP://$dc/$UserDN"
        $searcher.Filter = "(objectClass=*)"
        
        $userResult = $searcher.FindOne()
        if ($userResult) {
            $userEntry = $userResult.GetDirectoryEntry()
            Add-Result "✓ Получены данные пользователя из AD" "Green"
        }
        
        # Ищем GPO во всей иерархии OU
        $allGPOs = @()
        $currentPath = $UserDN -replace "^CN=[^,]+,", ""
        
        Add-Result "Поиск GPO в иерархии OU..." "Blue"
        
        # Проверяем каждый уровень OU снизу вверх
        for ($i = 0; $i -lt $ouHierarchy.Count; $i++) {
            $currentOUs = $ouHierarchy[$i..($ouHierarchy.Count-1)]
            $currentOUPath = "OU=" + ($currentOUs -join ",OU=") + "," + ($UserDN -replace "^CN=[^,]+,", "" -replace "^OU=[^,]+,", "")
            
            # Убираем лишние части чтобы получить правильный путь
            $searchPath = $currentOUPath -replace "OU=[^,]+,CN=Users,", ""
            
            try {
                $ouSearcher = New-Object System.DirectoryServices.DirectorySearcher
                $ouSearcher.SearchRoot = "LDAP://$dc/$searchPath"
                $ouSearcher.Filter = "(objectClass=organizationalUnit)"
                
                $ouResult = $ouSearcher.FindOne()
                if ($ouResult) {
                    $ouEntry = $ouResult.GetDirectoryEntry()
                    
                    if ($ouEntry.Properties.Contains("gPLink")) {
                        $gplink = $ouEntry.Properties["gPLink"][0]
                        Add-Result "✓ Найдены GPO в OU: $($currentOUs[0])" "Green"
                        
                        # Парсим gPLink для извлечения имен GPO
                        $gpoMatches = [regex]::Matches($gplink, "\[LDAP://CN=([^,]+),CN=Policies,CN=System")
                        foreach ($match in $gpoMatches) {
                            if ($match.Success) {
                                $gpoName = $match.Groups[1].Value
                                if ($gpoName -notin $allGPOs) {
                                    $allGPOs += $gpoName
                                    Add-Result "  • $gpoName" "Black"
                                }
                            }
                        }
                    } else {
                        Add-Result "  ℹ Нет GPO ссылок в OU: $($currentOUs[0])" "Gray"
                    }
                }
            }
            catch {
                Add-Result "  ⚠ Ошибка поиска в OU $($currentOUs[0]): $($_.Exception.Message)" "Orange"
            }
        }
        
        # Также проверяем GPO примененные непосредственно к пользователю
        Add-Result "Проверка GPO примененных к пользователю..." "Blue"
        try {
            $userSearcher = New-Object System.DirectoryServices.DirectorySearcher
            $userSearcher.SearchRoot = "LDAP://$dc/CN=$UserName,CN=Users,$($domain.Name)"
            $userSearcher.Filter = "(objectClass=*)"
            
            $directUserResult = $userSearcher.FindOne()
            if ($directUserResult) {
                $directUserEntry = $directUserResult.GetDirectoryEntry()
                if ($directUserEntry.Properties.Contains("gPLink")) {
                    $userGplink = $directUserEntry.Properties["gPLink"][0]
                    Add-Result "✓ Найдены GPO примененные к пользователю" "Green"
                    
                    $userGpoMatches = [regex]::Matches($userGplink, "\[LDAP://CN=([^,]+),CN=Policies,CN=System")
                    foreach ($match in $userGpoMatches) {
                        if ($match.Success) {
                            $gpoName = $match.Groups[1].Value
                            if ($gpoName -notin $allGPOs) {
                                $allGPOs += $gpoName
                                Add-Result "  • $gpoName" "Black"
                            }
                        }
                    }
                }
            }
        }
        catch {
            Add-Result "  ℹ Нет прямых GPO примененных к пользователю" "Gray"
        }
        
        # Проверяем членство в группах которые могут иметь GPO
        Add-Result "Анализ членства в группах..." "Blue"
        try {
            $groupSearcher = New-Object System.DirectoryServices.DirectorySearcher
            $groupSearcher.SearchRoot = "LDAP://$dc/$UserDN"
            $groupSearcher.Filter = "(objectClass=*)"
            $groupSearcher.PropertiesToLoad.Add("memberOf")
            
            $groupResult = $groupSearcher.FindOne()
            if ($groupResult -and $groupResult.Properties["memberOf"].Count -gt 0) {
                Add-Result "Пользователь состоит в группах:" "Green"
                foreach ($groupDN in $groupResult.Properties["memberOf"]) {
                    $groupName = ($groupDN -split ",")[0] -replace "^CN=", ""
                    Add-Result "  • $groupName" "Black"
                    
                    # Проверяем есть ли GPO примененные к этой группе
                    try {
                        $groupGpoSearcher = New-Object System.DirectoryServices.DirectorySearcher
                        $groupGpoSearcher.SearchRoot = "LDAP://$dc/$groupDN"
                        $groupGpoSearcher.Filter = "(objectClass=*)"
                        
                        $groupGpoResult = $groupGpoSearcher.FindOne()
                        if ($groupGpoResult) {
                            $groupEntry = $groupGpoResult.GetDirectoryEntry()
                            if ($groupEntry.Properties.Contains("gPLink")) {
                                $groupGplink = $groupEntry.Properties["gPLink"][0]
                                Add-Result "    ✓ Группа имеет GPO:" "DarkGreen"
                                
                                $groupGpoMatches = [regex]::Matches($groupGplink, "\[LDAP://CN=([^,]+),CN=Policies,CN=System")
                                foreach ($match in $groupGpoMatches) {
                                    if ($match.Success) {
                                        $gpoName = $match.Groups[1].Value
                                        if ($gpoName -notin $allGPOs) {
                                            $allGPOs += $gpoName
                                            Add-Result "      • $gpoName" "Black"
                                        }
                                    }
                                }
                            }
                        }
                    }
                    catch {
                        # Игнорируем ошибки при проверке групп
                    }
                }
            }
        }
        catch {
            Add-Result "Ошибка анализа групп: $($_.Exception.Message)" "Orange"
        }
        
        if ($allGPOs.Count -gt 0) {
            Add-Result "✓ Всего найдено GPO через LDAP: $($allGPOs.Count)" "Green"
            return @{
                Success = $true
                GPOs = $allGPOs
            }
        }
        else {
            Add-Result "ℹ GPO не найдены в иерархии OU пользователя" "Orange"
            Add-Result "Это означает, что:" "Gray"
            Add-Result "  • Нет GPO примененных к OU пользователя" "Gray"
            Add-Result "  • Нет GPO примененных непосредственно к пользователю" "Gray"
            Add-Result "  • Нет GPO примененных к группам пользователя" "Gray"
            return @{
                Success = $false
                GPOs = @()
            }
        }
    }
    catch {
        Add-Result "Ошибка LDAP метода: $($_.Exception.Message)" "Orange"
        return @{
            Success = $false
            GPOs = @()
        }
    }
}

# Функция для выполнения проверки политик
function Start-PolicyCheck {
    $name = $textBoxName.Text.Trim()

    if ([string]::IsNullOrEmpty($name)) {
        [System.Windows.Forms.MessageBox]::Show("Введите имя компьютера или пользователя", "Ошибка", "OK", "Error")
        return
    }

    $textBoxResults.Clear()
    $progressBar.Visible = $true
    $buttonCheck.Enabled = $false
    $textBoxName.Enabled = $false
    [System.Windows.Forms.Application]::DoEvents()

    try {
        # Проверка прав администратора
        $isAdmin = Test-AdminRights
        if (-not $isAdmin) {
            Add-Result "⚠ ВНИМАНИЕ: Скрипт запущен без прав администратора" "Orange"
            Add-Result "Для получения полной информации о политиках рекомендуется запустить скрипт от имени администратора" "Orange"
            Add-Result "" "Black"
        }

        # Проверка доступных методов
        Add-Result "Доступные методы проверки:" "DarkGray"
        if (Get-Command "Get-ADUser" -ErrorAction SilentlyContinue) {
            Add-Result "  ✓ Active Directory модуль доступен" "Green"
        } else {
            Add-Result "  ✗ Active Directory модуль недоступен" "Orange"
        }

        if (Get-Command "Get-GPO" -ErrorAction SilentlyContinue) {
            Add-Result "  ✓ Group Policy модуль доступен" "Green"
        } else {
            Add-Result "  ✗ Group Policy модуль недоступен" "Orange"
        }
        Add-Result "" "Black"

        if ($radioComputer.Checked) {
            # Проверка компьютера
            Add-Result "=== ПРОВЕРКА ПОЛИТИК ДЛЯ КОМПЬЮТЕРА: $name ===" "Green"
            
            # Проверка доступности компьютера
            if ($name -ne "." -and $name -ne "localhost" -and $name -ne $env:COMPUTERNAME) {
                Add-Result "Проверка доступности компьютера..." "Blue"
                $isAvailable = Test-ComputerAvailability -ComputerName $name
                if (-not $isAvailable) {
                    Add-Result "✗ Компьютер '$name' недоступен по сети" "Red"
                    Add-Result "Проверьте:" "Orange"
                    Add-Result "  - Включен ли компьютер" "Orange"
                    Add-Result "  - Сетевое подключение" "Orange"
                    Add-Result "  - Правильность имени компьютера" "Orange"
                    return
                }
                Add-Result "✓ Компьютер доступен" "Green"
            }
            else {
                Add-Result "✓ Проверка локального компьютера" "Green"
            }
            
            Add-Result "" "Black"
            
            # Получение политик
            $result = Get-GPOsWithDetailedAnalysis -Target $name -IsComputer $true
            
            # Вывод результатов
            Add-Result "=== АНАЛИЗ РЕЗУЛЬТАТОВ ===" "Blue"
            
            if ($result.Success -and $result.GPOs.Count -gt 0) {
                Add-Result "✓ Найдено применяемых компьютерных политик: $($result.GPOs.Count)" "Green"
                Add-Result "" "Black"
                
                foreach ($gpo in $result.GPOs) {
                    Add-Result "  • $gpo" "Black"
                }
                
                # Показываем отфильтрованные политики
                if ($result.FilteredGPOs.Count -gt 0) {
                    Add-Result "" "Black"
                    Add-Result "Отфильтрованные политики (не применяются):" "Orange"
                    foreach ($gpo in $result.FilteredGPOs) {
                        Add-Result "  • $gpo" "DarkGray"
                    }
                }
            }
            else {
                Add-Result "ℹ Применяемые компьютерные политики не найдены" "Orange"
                Add-Result "" "Black"
                Add-Result "ВОЗМОЖНЫЕ ПРИЧИНЫ:" "DarkBlue"
                Add-Result "• Компьютер не в домене Active Directory" "Black"
                Add-Result "• Отсутствуют примененные групповые политики" "Black"
                Add-Result "• Компьютер в рабочей группе (не в домене)" "Black"
                Add-Result "• Политики не применялись или были удалены" "Black"
                Add-Result "• Недостаточно прав для запроса информации" "Black"
            }
        }
        else {
            # Проверка пользователя
            $actualUserName = $name
            $userObject = $null
            
            # Пытаемся найти пользователя по ФИО
            if ($name -notmatch "^[a-zA-Z0-9\._-]+$" -or $name.Contains(" ")) {
                $userObject = Find-UserByDisplayName -DisplayName $name
                if ($userObject) {
                    $actualUserName = $userObject.SamAccountName
                    Add-Result "✓ Используется логин: $actualUserName" "Green"
                    Add-Result "" "Black"
                }
            }
            
            if (-not $userObject) {
                # Если не нашли по ФИО, используем как логин
                if ($name -eq $env:USERNAME) {
                    Add-Result "✓ Проверка текущего пользователя" "Green"
                }
                else {
                    Add-Result "Проверка пользователя: $name" "Blue"
                    Add-Result "ℹ Для удаленных пользователей требуется, чтобы пользователь был залогинен в системе" "Orange"
                }
                
                # Пытаемся получить информацию из AD
                $userInfo = Get-UserADInfo -UserName $name
                if ($userInfo) {
                    Add-Result "✓ Пользователь найден в Active Directory" "Green"
                    Add-Result "  ФИО: $($userInfo.DisplayName)" "Black"
                    Add-Result "  Логин: $($userInfo.SamAccountName)" "Black"
                    Add-Result "  Статус: $(if($userInfo.Enabled){'Включен'}else{'Отключен'})" "Black"
                    Add-Result "  Последний вход: $(if($userInfo.LastLogonDate){$userInfo.LastLogonDate}else{'Никогда'})" "Black"
                }
                else {
                    Add-Result "✗ Пользователь не найден в Active Directory" "Red"
                }
            }
            
            Add-Result "" "Black"
            
            # Основной метод через gpresult
            Add-Result "Выполнение проверки для пользователя: $actualUserName" "Blue"
            $result = Get-GPOsWithDetailedAnalysis -Target $actualUserName -IsComputer $false
            
            # Если основной метод не сработал, пробуем альтернативные
            if ($result.GPOs.Count -eq 0) {
                Add-Result "" "Black"
                Add-Result "=== АЛЬТЕРНАТИВНЫЕ МЕТОДЫ ПРОВЕРКИ ===" "Blue"
                
                # Метод 1: Сетевые команды
                Test-NetCommands -UserName $actualUserName
                
                # Метод 2: RSOP
                $rsopSuccess = Test-RSOPMethod -UserName $actualUserName
                
                # Метод 3: LDAP (если есть информация о пользователе)
                if ($userObject) {
                    $ldapResult = Get-GPOsViaLDAP -UserName $actualUserName -UserDN $userObject.DistinguishedName
                    if ($ldapResult.Success -and $ldapResult.GPOs.Count -gt 0) {
                        Add-Result "✓ LDAP метод нашел политики:" "Green"
                        foreach ($gpo in $ldapResult.GPOs) {
                            Add-Result "  • $gpo" "Black"
                        }
                    }
                }
                
                # Метод 4: Проверка локальных политик для текущего пользователя
                if ($actualUserName -eq $env:USERNAME) {
                    Add-Result "Проверка локальных политик текущего пользователя..." "Blue"
                    try {
                        $localGPO = & cmd /c "gpresult /R /Scope User 2>&1"
                        $localGpos = $localGPO | Where-Object { $_ -match "Applied Group Policy Objects" -or $_ -match "Применяемые объекты групповой политики" -or ($_ -match "GPO" -and $_ -notmatch "Local Group Policy") }
                        if ($localGpos.Count -gt 0) {
                            Add-Result "Локальные политики текущего пользователя:" "Green"
                            foreach ($line in $localGpos) {
                                Add-Result "  $($line.Trim())" "Black"
                            }
                        }
                    }
                    catch {
                        Add-Result "Локальная проверка не сработала" "Orange"
                    }
                }
            }
            
            # Вывод результатов основного метода
            Add-Result "" "Black"
            Add-Result "=== РЕЗУЛЬТАТЫ ОСНОВНОГО МЕТОДА ===" "Blue"
            
            if ($result.Success -and $result.GPOs.Count -gt 0) {
                Add-Result "✓ Найдено применяемых пользовательских политик: $($result.GPOs.Count)" "Green"
                Add-Result "" "Black"
                
                foreach ($gpo in $result.GPOs) {
                    Add-Result "  • $gpo" "Black"
                }
                
                # Показываем отфильтрованные политики
                if ($result.FilteredGPOs.Count -gt 0) {
                    Add-Result "" "Black"
                    Add-Result "Отфильтрованные политики (не применяются):" "Orange"
                    foreach ($gpo in $result.FilteredGPOs) {
                        Add-Result "  • $gpo" "DarkGray"
                    }
                }
            }
            else {
                Add-Result "ℹ Основной метод не нашел применяемых политик" "Orange"
                Add-Result "" "Black"
                Add-Result "ВОЗМОЖНЫЕ ПРИЧИНЫ:" "DarkBlue"
                Add-Result "• Пользователь в данный момент не залогинен на компьютере" "Black"
                Add-Result "• Отсутствуют примененные групповые политики для этого пользователя" "Black"
                Add-Result "• gpresult не может получить данные для удаленного пользователя" "Black"
                Add-Result "• Пользователь находится в исключениях политик" "Black"
            }
        }
        
        # Общие рекомендации
        Add-Result "" "Black"
        Add-Result "=== РЕКОМЕНДАЦИИ ===" "Green"
        if (-not $isAdmin) {
            Add-Result "• Запустите скрипт от имени администратора для получения полной информации" "Blue"
        }
        Add-Result "• Для компьютера в домене должны отображаться доменные политики" "Blue"
        Add-Result "• Локальная групповая политика не отображается в применяемых политиках" "Blue"
        Add-Result "• Убедитесь, что целевой объект находится в домене Active Directory" "Blue"
        Add-Result "• Для проверки пользователя требуется его активный вход в систему" "Blue"
        
        Add-Result "" "Black"
        Add-Result "=== ПРОВЕРКА ЗАВЕРШЕНА ===" "Green"
    }
    catch {
        Add-Result "КРИТИЧЕСКАЯ ОШИБКА: $($_.Exception.Message)" "Red"
        Add-Result "Стек вызовов: $($_.ScriptStackTrace)" "DarkGray"
    }
    finally {
        $progressBar.Visible = $false
        $buttonCheck.Enabled = $true
        $textBoxName.Enabled = $true
        $textBoxName.Focus()
    }
}

# Обработчики событий
$buttonCheck.Add_Click({
    Start-PolicyCheck
})

$textBoxName.Add_KeyDown({
    if ($_.KeyCode -eq "Enter") {
        $_.SuppressKeyPress = $true
        Start-PolicyCheck
    }
})

$form.Add_KeyDown({
    if ($_.KeyCode -eq "Enter" -and $buttonCheck.Enabled) {
        $_.SuppressKeyPress = $true
        Start-PolicyCheck
    }
})

$radioComputer.Add_CheckedChanged({
    if ($radioComputer.Checked) {
        $labelName.Text = "Имя компьютера:"
        $textBoxName.Text = $env:COMPUTERNAME
        $textBoxName.Focus()
    }
})

$radioUser.Add_CheckedChanged({
    if ($radioUser.Checked) {
        $labelName.Text = "Имя пользователя (логин или ФИО):"
        $textBoxName.Text = $env:USERNAME
        $textBoxName.Focus()
    }
})

$form.Add_Resize({
    if ($form.WindowState -ne [System.Windows.Forms.FormWindowState]::Minimized) {
        Update-ControlSizes
    }
})

$form.Add_Load({
    $textBoxName.Focus()
    Update-ControlSizes
})

# Показываем форму
[void]$form.ShowDialog()