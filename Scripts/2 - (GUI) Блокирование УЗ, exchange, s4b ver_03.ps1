Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# === Глобальные переменные ===
$exchangeConnected = $false
$sfbConnected = $false
$sortColumn = -1
$sortOrder = "Ascending"
$script:SfBConnected = $false
$script:SfBSession = $null
$script:exchangeConnected = $false
$script:exchangeInitialized = $false
$script:SfBConnected = $false
$script:SfBInitialized = $false



# Определяем папку скрипта
$script:ScriptRoot = if ($PSScriptRoot) {
  $PSScriptRoot
}
elseif ($MyInvocation.MyCommand.Path) {
  Split-Path -Parent $MyInvocation.MyCommand.Path
}
else {
  (Get-Location).Path
}

# Папка для кеша модулей (рядом со скриптом)
$script:ModulePath = Join-Path $script:ScriptRoot "PSModules"

# Автоматически определяем, использовать ли кеш
# Кеш используется, если существуют манифесты обоих модулей
$exchManifest = Join-Path $script:ModulePath "RemoteExchange\RemoteExchange.psd1"
$sfbManifest = Join-Path $script:ModulePath "RemoteSfB\RemoteSfB.psd1"

$script:useModuleCache = (Test-Path $exchManifest) -and (Test-Path $sfbManifest)

if ($script:useModuleCache) {
  Write-Host "📦 Обнаружен кеш модулей. Будет использован локальный импорт." -ForegroundColor Cyan
}
else {
  Write-Host "🌐 Кеш модулей не найден. Будет использоваться прямое подключение." -ForegroundColor Yellow
}

# Создаем папку для модулей, если её нет
if (!(Test-Path $script:ModulePath)) {
  New-Item -ItemType Directory -Path $script:ModulePath -Force | Out-Null
}

# === Настройки ===
$logFolder = "\\stepcon.ru\office\ИТ\13\Fired"

# Создаем папку для логов
if (-not (Test-Path $logFolder)) {
  New-Item -ItemType Directory -Path $logFolder -Force
}

# ==========================================
# ФУНКЦИЯ ЭКСПОРТА МОДУЛЕЙ
# ==========================================
function Export-RemoteModules {
  try {
    Write-Log "📦 Начало экспорта модулей..."
    Write-Host "📦 Экспорт модулей Exchange и SfB..." -ForegroundColor Cyan
        
    # Создаем папку для модулей
    if (!(Test-Path $script:ModulePath)) { 
      New-Item -ItemType Directory -Path $script:ModulePath | Out-Null
      Write-Log "📁 Создана папка: $script:ModulePath"
    }
        
    # ==========================================
    # ЭКСПОРТ EXCHANGE (Server: spbhdqsrv073)
    # ==========================================
    Write-Log "🔗 Подключение к Exchange для экспорта..."
    Write-Host "  → Exchange (spbhdqsrv073)..." -ForegroundColor Yellow
        
    $exchSession = New-PSSession -ConfigurationName Microsoft.Exchange `
      -ConnectionUri "http://spbhdqsrv073.stepcon.ru/PowerShell/" `
      -Authentication Kerberos `
      -ErrorAction Stop
        
    Write-Log "💾 Экспорт команд Exchange в файл..."
    Export-PSSession -Session $exchSession `
      -OutputModule "$script:ModulePath\RemoteExchange" `
      -AllowClobber -Force | Out-Null
        
    Remove-PSSession $exchSession
    Write-Log "✅ Exchange модуль экспортирован"
    Write-Host "  ✅ Exchange готов" -ForegroundColor Green
        
    # ==========================================
    # ЭКСПОРТ SFB (Server: spbhdqsrv023)
    # ==========================================
    Write-Log "🔗 Подключение к Skype for Business для экспорта..."
    Write-Host "  → SfB (spbhdqsrv023)..." -ForegroundColor Yellow
        
    $sfbOptions = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
    $sfbSession = New-PSSession -ConnectionUri "https://spbhdqsrv023.stepcon.ru/OcsPowershell" `
      -SessionOption $sfbOptions `
      -Authentication Negotiate `
      -ErrorAction Stop
        
    Write-Log "💾 Экспорт команд SfB в файл..."
    Export-PSSession -Session $sfbSession `
      -OutputModule "$script:ModulePath\RemoteSfB" `
      -AllowClobber -Force | Out-Null
        
    Remove-PSSession $sfbSession
    Write-Log "✅ SfB модуль экспортирован"
    Write-Host "  ✅ SfB готов" -ForegroundColor Green
        
    Write-Log "✅ Все модули успешно экспортированы в $script:ModulePath"
    Write-Host "✅ Готово! Модули сохранены в $script:ModulePath" -ForegroundColor Green
        
    # ==========================================
    # ВКЛЮЧАЕМ КЕШ И ЗАГРУЖАЕМ МОДУЛИ
    # ==========================================
    $script:useModuleCache = $true
    Write-Log "🔄 Автоматическая загрузка из кеша..."
        
    # Загружаем Exchange
    if (Connect-ExchangeServer) {
      Write-Log "✅ Exchange загружен из кеша"
    }
        
    # Загружаем SfB
    if (Connect-SfBServer) {
      Write-Log "✅ SfB загружен из кеша"
    }
        
    [System.Windows.Forms.MessageBox]::Show(
      "Модули успешно экспортированы:`n`n• RemoteExchange`n• RemoteSfB`n`nПуть: $script:ModulePath`n`nМодули загружены и готовы к работе!",
      "Экспорт завершен",
      "OK",
      "Information"
    )
        
    return $true
  }
  catch {
    $errorMsg = $_.Exception.Message
    Write-Log "❌ Ошибка экспорта модулей: $errorMsg" "ERROR"
    Write-Host "❌ Ошибка: $errorMsg" -ForegroundColor Red
        
    [System.Windows.Forms.MessageBox]::Show(
      "Ошибка при экспорте модулей:`n`n$errorMsg",
      "Ошибка экспорта",
      "OK",
      "Error"
    )
        
    return $false
  }
}




# === Элементы прогресса (под строкой поиска) ===
$progressLabel = $null
$progressDetails = $null

# === Функция для показа прогресса ===
function Show-Progress {
  param(
    [string]$Status = "Подготовка...",
    [string]$Details = ""
  )
    
  if ($null -ne $script:progressLabel) {
    $script:progressLabel.Text = $Status
    $script:progressLabel.Visible = $true
    $script:progressLabel.ForeColor = [System.Drawing.Color]::DarkBlue
  }
    
  if ($null -ne $script:progressDetails) {
    $script:progressDetails.Text = $Details
    $script:progressDetails.Visible = $true
  }
    
  [System.Windows.Forms.Application]::DoEvents()
}

# === Функция для обновления прогресса ===
function Update-Progress {
  param(
    [string]$Status,
    [string]$Details = ""
  )
    
  if ($null -ne $script:progressLabel) {
    $script:progressLabel.Text = $Status
  }
    
  if ($null -ne $script:progressDetails) {
    $script:progressDetails.Text = $Details
  }
    
  [System.Windows.Forms.Application]::DoEvents()
  Start-Sleep -Milliseconds 50  # Даем время для обновления UI
}

# === Функция для скрытия прогресса ===
# function Hide-Progress {
#   if ($null -ne $script:progressLabel) {
#     $script:progressLabel.Text = ""
#     $script:progressLabel.Visible = $false
#   }
    
#   if ($null -ne $script:progressDetails) {
#     $script:progressDetails.Text = ""
#     $script:progressDetails.Visible = $false
#   }
    
#   [System.Windows.Forms.Application]::DoEvents()
# }

# === Функция для создания индивидуального лог-файла ===
function New-UserLogFile {
  param([string]$SamAccountName, [string]$DisplayName)
    
  $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
  $logFileName = "$timestamp`_$SamAccountName.log"
  $logFilePath = Join-Path $logFolder $logFileName
    
  # Получаем дату увольнения (может быть пустой)
  $terminationDateText = if ($terminationDatePicker.CustomFormat -ne " ") { 
    $terminationDatePicker.Value.ToString("dd.MM.yyyy") 
  }
  else { 
    "" 
  }
    
  $logHeader = @"
==============================================
ЛОГ УВОЛЬНЕНИЯ/БЛОКИРОВКИ ПОЛЬЗОВАТЕЛЯ
==============================================
Дата/время: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Пользователь: $DisplayName
Логин: $SamAccountName
$(if ($terminationDateText) { "Дата увольнения: $terminationDateText" } else { "Тип операции: Блокировка (без даты увольнения)" })
Лог-файл: $logFileName
==============================================

"@
    
  try {
    $logHeader | Out-File -FilePath $logFilePath -Encoding UTF8
    Write-Log "📄 Создан лог-файл: $logFileName"
    return $logFilePath
  }
  catch {
    Write-Log "⚠️ Ошибка создания лог-файл: $($_.Exception.Message)"
    return $null
  }
}

# === Функция для записи в индивидуальный лог-файл ===
function Write-UserLog {
  param([string]$LogFilePath, [string]$Message)
    
  if ($null -ne $LogFilePath -and (Test-Path $LogFilePath)) {
    try {
      $Message | Out-File -FilePath $LogFilePath -Append -Encoding UTF8
    }
    catch {
      # Если не удалось записать в файл, просто продолжаем
    }
  }
}

# === Функция для записи в основной лог ===
function Write-Log {
  param([string]$Message)
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $logBox.AppendText("[$timestamp] $Message`r`n")
  $logBox.ScrollToCaret()
  [System.Windows.Forms.Application]::DoEvents()  # Обновляем UI лога
}

# === Функция для проверки подчиненных ===
function Get-UserSubordinates {
  param([string]$SamAccountName)
    
  try {
    # Сначала получаем пользователя с DisplayName!
    $user = Get-ADUser -Identity $SamAccountName -Properties DisplayName, DistinguishedName -ErrorAction Stop
    
    if ($null -eq $user) {
      Write-Log "⚠️ Пользователь не найден: $SamAccountName"
      return @()
    }
    
    Write-Log "🔍 Поиск подчиненных для: $($user.DisplayName) (DN: $($user.DistinguishedName))"
    
    # Ищем подчиненных
    $subordinates = Get-ADUser -Filter "Manager -eq '$($user.DistinguishedName)'" -Properties DisplayName, SamAccountName, Title, Department -ErrorAction Stop
    
    Write-Log "✅ Найдено подчиненных: $($subordinates.Count)"
    
    return $subordinates
  }
  catch {
    Write-Log "⚠️ Ошибка при поиске подчиненных: $($_.Exception.Message)"
    return @()
  }
}



# === ФУНКЦИЯ ДЛЯ ОЧИСТКИ ПОЛЯ РУКОВОДИТЕЛЯ ===
# Удаляет ссылку на руководителя у блокируемого пользователя
# Логирует имя руководителя в понятном формате (Фамилия Имя)

function Clear-UserManager {
  param([object]$User, [string]$LogFilePath)
  
  try {
    Write-Log "🔍 Проверка поля 'Руководитель' для пользователя: $($User.DisplayName)"
    
    # Получаем текущего руководителя
    $currentUser = Get-ADUser -Identity $User.SamAccountName -Properties Manager -ErrorAction Stop
    
    if ($null -ne $currentUser.Manager) {
      # Получаем полное имя руководителя для красивого логирования
      try {
        $managerUser = Get-ADUser -Identity $currentUser.Manager -Properties DisplayName -ErrorAction SilentlyContinue
        $managerDisplayName = if ($managerUser) { $managerUser.DisplayName } else { "Неизвестный пользователь" }
      }
      catch {
        $managerDisplayName = "Неизвестный пользователь"
      }
      
      Write-Log "📝 Текущий руководитель: $managerDisplayName"
      Write-UserLog -LogFilePath $LogFilePath -Message "ОЧИСТКА ПОЛЯ РУКОВОДИТЕЛЯ"
      Write-UserLog -LogFilePath $LogFilePath -Message "Текущий руководитель: $managerDisplayName"
      
      # Очищаем поле Manager
      Set-ADUser -Identity $User.SamAccountName -Manager $null -ErrorAction Stop
      Write-Log "✅ Поле 'Руководитель' очищено для: $($User.DisplayName)"
      Write-UserLog -LogFilePath $LogFilePath -Message "Поле 'Руководитель' очищено"
      
      return $true
    }
    else {
      Write-Log "ℹ️ Поле 'Руководитель' уже пусто: $($User.DisplayName)"
      Write-UserLog -LogFilePath $LogFilePath -Message "ОЧИСТКА ПОЛЯ РУКОВОДИТЕЛЯ"
      Write-UserLog -LogFilePath $LogFilePath -Message "Поле 'Руководитель' уже пусто"
      return $true
    }
  }
  catch {
    Write-Log "⚠️ Ошибка при очистке 'Руководителя': $($_.Exception.Message)"
    Write-UserLog -LogFilePath $LogFilePath -Message "ОШИБКА при очистке 'Руководителя': $($_.Exception.Message)"
    return $false
  }
}



# === Функция для очистки подчиненных ===
function Clear-UserSubordinates {
  param([object]$User, [string]$LogFilePath)
    
  Write-UserLog -LogFilePath $LogFilePath -Message "ПРОВЕРКА ПОДЧИНЕННЫХ"
    
  $subordinates = @(Get-UserSubordinates -SamAccountName $User.SamAccountName)  # ← обернули в @()
    
  if ($subordinates.Count -gt 0) {
    Write-UserLog -LogFilePath $LogFilePath -Message "НАЙДЕНО ПОДЧИНЕННЫХ: $($subordinates.Count)"
    Write-Log "ℹ️ У пользователя $($User.DisplayName) ($($User.SamAccountName)) найдено подчиненных: $($subordinates.Count)"
        
    foreach ($subordinate in $subordinates) {
      Write-UserLog -LogFilePath $LogFilePath -Message "Подчиненный: $($subordinate.DisplayName) ($($subordinate.SamAccountName)) - $($subordinate.Title) - $($subordinate.Department)"
      Write-Log "   👤 $($subordinate.DisplayName) ($($subordinate.SamAccountName)) - $($subordinate.Department)"
    }
        
    # Очищаем руководителя у всех подчиненных
    Write-UserLog -LogFilePath $LogFilePath -Message "ОЧИСТКА РУКОВОДИТЕЛЯ У ПОДЧИНЕННЫХ"
    $clearedCount = 0
        
    foreach ($subordinate in $subordinates) {
      try {
        Set-ADUser -Identity $subordinate.SamAccountName -Manager $null -ErrorAction Stop
        Write-UserLog -LogFilePath $LogFilePath -Message "Очищен руководитель $($User.DisplayName) у сотрудника: $($subordinate.SamAccountName)"
        Write-Log "✅ Очищен руководитель у: $($subordinate.DisplayName)"
        $clearedCount++
      }
      catch {
        Write-UserLog -LogFilePath $LogFilePath -Message "ОШИБКА очистки руководителя $($User.DisplayName) у $($subordinate.SamAccountName): $($_.Exception.Message)"
        Write-Log "⚠️ Ошибка очистки руководителя $($User.DisplayName) у $($subordinate.SamAccountName): $($_.Exception.Message)"
      }
    }
        
    Write-UserLog -LogFilePath $LogFilePath -Message "УСПЕШНО ОЧИЩЕНО ПОДЧИНЕННЫХ: $clearedCount из $($subordinates.Count)"
    Write-Log "✅ Очищены руководители $($User.DisplayName) у $clearedCount подчиненных"
        
    return $subordinates.Count
  }
  else {
    Write-UserLog -LogFilePath $LogFilePath -Message "ПОДЧИНЕННЫЕ НЕ НАЙДЕНЫ"
    Write-Log "ℹ️ У пользователя $($User.DisplayName) ($($User.SamAccountName)) нет подчиненных"
    return 0
  }
}


# === Функция для формирования сообщения подтверждения ===
function Get-ConfirmationMessage {
  param(
    [array]$Users,
    [string]$OperationType,
    [string]$OperationDetails,
    [string]$SubordinatesInfo,
    [int]$TotalSubordinates,
    [string]$LogFolder
  )
    
  $userList = ""
  $counter = 0
  foreach ($user in $Users) {
    $counter++
    if ($Users.Count -eq 1) {
      $userList = "• $($user.DisplayName) ($($user.SamAccountName))`n"
    }
    else {
      $userList += "$counter. $($user.DisplayName) ($($user.SamAccountName))`n"
      if ($counter -ge 15) {
        $userList += "... и еще $($Users.Count - 15) пользователей`n"
        break
      }
    }
  }
    
  $additionalOperations = "• Удаление групп доступа пользователя (RO/RW)`n• Удаление папки из !OBMEN`n• Создание в AD группы доступа Fired`n• Перенос личной папки в FIRED`n• Настройка разрешений для папок в FIRED`n"
    
  if ($Users.Count -eq 1) {
    return "Вы уверены, что хотите $operationType пользователя?`n`n$operationDetails`n`nПользователь:`n$userList$subordinatesInfo`n`nОперации:`n• Проверка и очистка подчиненных ($totalSubordinates всего)`n• Блокировка учетной записи`n• Очистка групп и руководителей`n• Перенос в AD УЗ в FIRED (кроме Guest)`n• Скрытие почты в адресной книге`n• Отключение в S4B`n$additionalOperations• Лог-файлы в: $logFolder"
  }
  else {
    return "Вы уверены, что хотите $operationType $($Users.Count) пользователей?`n`n$operationDetails`n`nСписок пользователей:`n$userList$subordinatesInfo`n`nОперации:`n• Проверка и очистка подчиненных ($totalSubordinates всего)`n• Блокировка учетной записи`n• Очистка групп и руководителей`n• Перенос в AD УЗ в FIRED (кроме Guest)`n• Скрытие почты в адресной книге`n• Отключение в S4B`n$additionalOperations• Лог-файлы в: $logFolder"
  }
}



# ==========================================
# ИСПРАВЛЕННАЯ ФУНКЦИЯ Connect-SfBServer
# ==========================================
function Connect-SfBServer {
  try {
    Write-Log "Подключение к Skype for Business Server..." "INFO"
    Write-Host "ℹ️  Подключение к Skype for Business Server..." -ForegroundColor Yellow
        
    # Закрываем предыдущие сессии
    Get-PSSession | Where-Object { 
      $_.ComputerName -like "*spbhdqsrv023*" -or 
      $_.ConnectionUri -like "*spbhdqsrv023*" 
    } | Remove-PSSession -ErrorAction SilentlyContinue
        
    # Путь к манифесту модуля SfB
    $sfbManifest = Join-Path $script:ModulePath "RemoteSfB\RemoteSfB.psd1"

    # Проверяем режим кеша
    if ($script:useModuleCache -and (Test-Path $sfbManifest)) {
      Write-Log "📦 Загрузка SfB из кеша..." "INFO"
      Write-Host "📦 Загрузка из кеша..." -ForegroundColor Cyan
            
      # Загружаем модуль
      Import-Module (Join-Path $script:ModulePath "RemoteSfB") -DisableNameChecking -Force -ErrorAction Stop
      Write-Log "✅ SfB модуль загружен из кеша" "INFO"
    }
    else {
      Write-Log "🌐 Прямое подключение к SfB серверу..." "INFO"
      $sessionOption = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
            
      $session = New-PSSession -ConnectionUri "https://spbhdqsrv023.stepcon.ru/OcsPowershell" `
        -SessionOption $sessionOption `
        -Authentication Negotiate -ErrorAction Stop
            
      Import-PSSession $session -AllowClobber | Out-Null
      $Script:SfBSession = $session
      Write-Log "✅ Подключение к SfB установлено (прямое подключение)" "INFO"
    }
        
    Write-Host "✅ Done" -ForegroundColor Green
        
    # Проверяем команды
    if (Get-Command Get-CsUser -ErrorAction SilentlyContinue) {
      $script:sfbConnected = $true
      Update-SfBStatus -Connected $true
      return $true
    }
    else {
      Write-Log "❌ Команды Skype for Business недоступны" "ERROR"
      $script:sfbConnected = $false
      Update-SfBStatus -Connected $false
      return $false
    }
  }
  catch {
    Write-Log "❌ Ошибка подключения к Skype for Business: $($_.Exception.Message)" "ERROR"
    $script:sfbConnected = $false
    Update-SfBStatus -Connected $false
    return $false
  }
}


# Функция для обновления статуса подключения SfB
function Update-SfBStatus {
  param([bool]$Connected)
    
  if ($Connected) { 
    $sfbStatusLabel.Text = "✓ SfB"
    $sfbStatusLabel.ForeColor = [System.Drawing.Color]::DarkGreen
    $sfbStatusLabel.BackColor = [System.Drawing.Color]::FromArgb(240, 255, 240)
  }
  else { 
    $sfbStatusLabel.Text = "✗ SfB" 
    $sfbStatusLabel.ForeColor = [System.Drawing.Color]::DarkRed
    $sfbStatusLabel.BackColor = [System.Drawing.Color]::FromArgb(255, 240, 240)
  }
}

function Connect-SfBSession {
  # Если уже подключены через кеш - ничего не делаем
  if ($script:useModuleCache -and (Get-Command Get-CsUser -ErrorAction SilentlyContinue)) {
    return
  }
  
  # Если есть живая сессия - используем её
  if ($script:SfBConnected -and $script:SfBSession -and $script:SfBSession.State -eq 'Opened') {
    return
  }

  # Только если НЕ используется кеш - создаем новую сессию
  if (-not $script:useModuleCache) {
    Write-Log "🔄 Подключение к серверу SfB..."
    $SfBServer = "spbhdqsrv023.stepcon.ru"
    $sessionOption = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck

    $session = New-PSSession `
      -ConnectionUri "https://$SfBServer/OcsPowershell" `
      -SessionOption $sessionOption `
      -Authentication Negotiate `
      -ErrorAction Stop

    Import-PSSession $session -AllowClobber -ErrorAction Stop | Out-Null

    $script:SfBSession = $session
    $script:SfBConnected = $true

    Write-Log "✅ Подключение к SfB установлено"
  }
}



# Функция отключения пользователя в Skype for Business
function Disable-SfBUser {
    param(
        [string]$UserDN,
        [string]$LogFilePath
    )

    Write-UserLog -LogFilePath $LogFilePath -Message "SKYPE FOR BUSINESS (remote SfB session)"
    Write-UserLog -LogFilePath $LogFilePath -Message "DN: $UserDN"

    try {
        Connect-SfBSession

        # Проверяем, есть ли пользователь в SfB
        $sfbUser = Get-CsUser -Identity $UserDN -ErrorAction SilentlyContinue
        if (-not $sfbUser) {
            Write-Log    "SfB: пользователь с DN '$UserDN' не найден"
            Write-UserLog -LogFilePath $LogFilePath -Message "Пользователь не найден в Skype for Business"
            return $true
        }

        if (-not $sfbUser.Enabled) {
            Write-Log    "SfB: пользователь уже отключен (Enabled=False)"
            Write-UserLog -LogFilePath $LogFilePath -Message "Пользователь уже отключен в Skype for Business"
            return $true
        }

        # Отключаем пользователя
        Write-UserLog -LogFilePath $LogFilePath -Message "Выполняется Set-CsUser Enabled = False"
        Set-CsUser -Identity $UserDN -Enabled $false -ErrorAction Stop
        
        Write-Log    "SfB: команда отключения выполнена успешно"
        Write-UserLog -LogFilePath $LogFilePath -Message "Команда отключения выполнена"
        return $true
    }
    catch {
        $msg = $_.Exception.Message
        Write-Log    "SfB: ошибка отключения пользователя (DN=$UserDN): $msg"
        Write-UserLog -LogFilePath $LogFilePath -Message "Ошибка отключения SfB: $msg"
        return $false
    }
}






# Функция проверки подключения к SfB
function Test-SfBConnection {
  try {
    if ($null -eq $Script:SfBSession -or $Script:SfBSession.State -ne "Opened") {
      Write-Log "🔄 Сессия SfB неактивна, переподключаемся..." "INFO"
      return Connect-SfBServer
    }
        
    # Простая проверка команд
    $testCmd = Get-Command Get-CsUser -ErrorAction SilentlyContinue
    if (-not $testCmd) {
      Write-Log "🔄 Команды SfB недоступны, переподключаемся..." "INFO"
      return Connect-SfBServer
    }
        
    return $true
  }
  catch {
    Write-Log "❌ Ошибка проверки подключения SfB: $($_.Exception.Message)" "ERROR"
    return $false
  }
}

# === ФУНКЦИЯ ДЛЯ ПЕРЕНОСА DESCRIPTION В NOTES (ЗАМЕТКИ) ===
# Добавлена для скрипта блокировки пользователя
# Переносит содержимое Description в Notes со сдвигом истории вверх

function Update-UserNotes {
  param(
    [string]$Login,
    [string]$NewDateDescription
  )
  
  try {
    Write-Log "🔍 Обновление заметок пользователя: $Login"
    
    # Получаем текущие значения Description и Notes из AD
    $existingUser = Get-ADUser -Identity $Login -Properties Info, Description -ErrorAction SilentlyContinue
    
    if (-not $existingUser) {
      Write-Log "❌ Пользователь не найден: $Login"
      return $false
    }
    
    $currentNotes = $existingUser.Info
    $currentDescription = $existingUser.Description
    
    Write-Log "📝 Текущее Description: '$currentDescription'"
    Write-Log "📝 Текущие Notes: '$currentNotes'"
    
    # Если Description содержит текст, переносим его в Notes
    if (-not [string]::IsNullOrWhiteSpace($currentDescription)) {
      Write-Log "🔄 Перенос Description в Notes..."
      
      # Новое содержимое Notes - переносим Description в начало
      $newNotes = $currentDescription
      
      # Если Notes уже содержат текст, добавляем старые заметки на новую строку ниже
      if (-not [string]::IsNullOrWhiteSpace($currentNotes)) {
        Write-Log "✅ Заметки уже содержат текст, добавляем новую строку с разделением"
        $newNotes = "$currentDescription`r`n$currentNotes"
      }
      
      # Обновляем поле Notes (Info в AD)
      Set-ADUser -Identity $Login -Replace @{info = $newNotes } -ErrorAction Stop
      Write-Log "✅ Заметки обновлены: переношено Description '$currentDescription'"
    }
    else {
      Write-Log "ℹ️  Description пусто, заметки не обновляются"
    }
    
    # Обновляем Description новой датой
    if (-not [string]::IsNullOrWhiteSpace($NewDateDescription)) {
      Set-ADUser -Identity $Login -Description $NewDateDescription -ErrorAction Stop
      Write-Log "✅ Description обновлено на: $NewDateDescription"
    }
    
    return $true
    
  }
  catch {
    Write-Log "❌ Ошибка при обновлении Notes: $($_.Exception.Message)"
    return $false
  }
}


# === Функция для увольнения/блокировки пользователя ===
function Disable-UserAccount {
  param(
    [object]$User, 
    [bool]$ShowDetailsWindow = $true,
    [bool]$ShowProgress = $true
  )
    
  Write-Log "🔧 Вызов Disable-UserAccount: ShowDetailsWindow=$ShowDetailsWindow"

  # ПОКАЗЫВАЕМ ПРОГРЕСС-БАР
  Show-Progress -Status "Начало процедуры блокировки..." -Details "Пользователь: $($User.DisplayName)"
    
  $userLogPath = New-UserLogFile -SamAccountName $User.SamAccountName -DisplayName $User.DisplayName
    
  try {
    $isGuestUser = $User.DistinguishedName -like "*OU=Guest,*DC=stepcon,DC=ru"
        
    Write-UserLog -LogFilePath $userLogPath -Message "НАЧАЛО ПРОЦЕДУРЫ УВОЛЬНЕНИЯ/БЛОКИРОВКИ"
    Write-UserLog -LogFilePath $userLogPath -Message "Пользователь: $($User.DisplayName) ($($User.SamAccountName))"
        
    # Получаем выбранную дату увольнения (может быть пустой)
    $terminationDateText = if ($terminationDatePicker.CustomFormat -ne " ") { 
      $terminationDatePicker.Value.ToString("dd.MM.yyyy") 
    }
    else { 
      "" 
    }
        
    if ($terminationDateText) {
      Write-UserLog -LogFilePath $userLogPath -Message "Дата увольнения: $terminationDateText"
    }
    else {
      Write-UserLog -LogFilePath $userLogPath -Message "Тип операции: Блокировка (без даты увольнения)"
    }
        
    # === ВСЕГДА ВЫПОЛНЯЕМ ПОЛНУЮ ПРОЦЕДУРУ УВОЛЬНЕНИЯ ===
    # ПРАВИЛЬНОЕ получение ФИО пользователя
    $UserDisplayName = $User.DisplayName
    Write-Log "🔍 Получение детальной информации о пользователе..."
        
    # Получаем полную информацию о пользователе с правильными свойствами
    $userDetailed = Get-ADUser -Identity $User.SamAccountName -Properties GivenName, Surname, Name, DisplayName
    Write-Log "✅ Детальная информация получена: DisplayName='$($userDetailed.DisplayName)', Name='$($userDetailed.Name)', GivenName='$($userDetailed.GivenName)', Surname='$($userDetailed.Surname)'"
        
    # Определяем имя и фамилию разными способами
    if ($userDetailed.GivenName -and $userDetailed.Surname) {
      # Способ 1: Из GivenName и Surname
      $UserFirstName = $userDetailed.GivenName
      $UserLastName = $userDetailed.Surname
      Write-Log "✅ ФИО получено из GivenName/Surname: $UserLastName $UserFirstName"
    }
    elseif ($userDetailed.DisplayName) {
      # Способ 2: Разбираем DisplayName
      $nameParts = $userDetailed.DisplayName -split '\s+'
      if ($nameParts.Count -ge 2) {
        $UserLastName = $nameParts[0]
        $UserFirstName = $nameParts[1]
        Write-Log "✅ ФИО получено из DisplayName: $UserLastName $UserFirstName"
      }
      else {
        $UserLastName = $userDetailed.DisplayName
        $UserFirstName = "Unknown"
        Write-Log "⚠️ DisplayName содержит только одну часть: $UserLastName"
      }
    }
    else {
      # Способ 3: Используем Name
      $nameParts = $userDetailed.Name -split '\s+'
      if ($nameParts.Count -ge 2) {
        $UserLastName = $nameParts[0]
        $UserFirstName = $nameParts[1]
        Write-Log "✅ ФИО получено из Name: $UserLastName $UserFirstName"
      }
      else {
        $UserLastName = $userDetailed.Name
        $UserFirstName = "Unknown"
        Write-Log "⚠️ Name содержит только одну часть: $UserLastName"
      }
    }
        
    Write-Log "🎯 Используется ФИО: $UserLastName $UserFirstName"
        
    
    # === ПРОВЕРКА И ОЧИСТКА ПОДЧИНЕННЫХ  ===
    Update-Progress -Status "Проверка подчиненных..." -Details "Пользователь: $($User.DisplayName)"
    Write-UserLog -LogFilePath $userLogPath -Message "ПРОВЕРКА ПОДЧИНЕННЫХ"
    $subordinatesCount = Clear-UserSubordinates -User $User -LogFilePath $userLogPath

    # === ОЧИСТКА ПОЛЯ РУКОВОДИТЕЛЯ ===
    Update-Progress -Status "Очистка поля Руководителя..." -Details "Пользователь: $($User.DisplayName)"
    Clear-UserManager -User $User -LogFilePath $userLogPath




    # УДАЛЕНИЕ ИЗ ГРУПП
    Update-Progress -Status "Удаление из групп..." -Details "Пользователь: $($User.DisplayName)"
    Write-UserLog -LogFilePath $userLogPath -Message "УДАЛЕНИЕ ИЗ ГРУПП:"

    try {
      # Пробуем получить группы пользователя
      $userGroups = Get-ADPrincipalGroupMembership -Identity $User.SamAccountName -ErrorAction Stop
    
      # Фильтруем группы которые нужно удалить
      $groupsToRemove = $userGroups | Where-Object { 
        $_.Name -ne "Domain Users" -and 
        $_.GroupScope -ne "DomainLocal" -and
        $_.Name -notlike "Fired--*"  # Не удаляем Fired группы
      }
    
      Write-Log "🔍 Найдено групп у пользователя: $($userGroups.Count). Удаляем: $($groupsToRemove.Count)"
    
      # Сохраняем список групп для лога
      $removedGroups = @()
    
      if ($groupsToRemove.Count -gt 0) {
        foreach ($group in $groupsToRemove) {
          try {
            # Используем DistinguishedName вместо Name для корректного поиска
            Remove-ADGroupMember -Identity $group.DistinguishedName -Members $User.SamAccountName -Confirm:$false -ErrorAction Stop
            Write-Log "✅ Удален из группы: $($group.Name) - $($User.DisplayName)"
            $removedGroups += $group.Name
          }
          catch {
            Write-Log "⚠️ Ошибка удаления $($User.DisplayName) из группы '$($group.Name)': $($_.Exception.Message)"
          }
        }

      }
      else {
        Write-Log "ℹ️ Нет групп для удаления у пользователя: $($User.DisplayName)"
      }
    
      # Записываем список удаленных групп в лог
      foreach ($group in $removedGroups) {
        Write-UserLog -LogFilePath $userLogPath -Message "$group;"
      }
    
    }
    catch {
      Write-Log "❌ Ошибка при получении списка групп: $($_.Exception.Message)"
      Write-UserLog -LogFilePath $userLogPath -Message "ОШИБКА ПРИ ПОЛУЧЕНИИ ГРУПП: $($_.Exception.Message)"
      # ПРОДОЛЖАЕМ ВЫПОЛНЕНИЕ, даже если не удалось получить группы
    }

    # Удаляем группы доступа RO/RW
    if ($ShowProgress) {
      Update-Progress -Status "Удаление групп доступа..." -Details "Пользователь: $UserDisplayName"
    }
    Write-UserLog -LogFilePath $userLogPath -Message "УДАЛЕНИЕ ГРУПП ДОСТУПА"
        
    $GroupNameRO = "U--$UserLastName $UserFirstName (RO)"
    $GroupNameRW = "U--$UserLastName $UserFirstName (RW)"
        
    Write-Log "🔍 Поиск групп: '$GroupNameRO' и '$GroupNameRW'"
        
    $deletedGroups = @()
        
    if (Get-ADGroup -Filter "Name -eq '$GroupNameRO'" -ErrorAction SilentlyContinue) {
      Remove-ADGroup -Identity $GroupNameRO -Confirm:$false -ErrorAction Stop
      Write-Log "✅ Удалена группа: $GroupNameRO"
      Write-UserLog -LogFilePath $userLogPath -Message "Удалена группа: $GroupNameRO"
      $deletedGroups += $GroupNameRO
    }
    else {
      Write-Log "⚠️ Группа не найдена: $GroupNameRO"
      Write-UserLog -LogFilePath $userLogPath -Message "Группа не найдена: $GroupNameRO"
    }
        
    if (Get-ADGroup -Filter "Name -eq '$GroupNameRW'" -ErrorAction SilentlyContinue) {
      Remove-ADGroup -Identity $GroupNameRW -Confirm:$false -ErrorAction Stop
      Write-Log "✅ Удалена группа: $GroupNameRW"
      Write-UserLog -LogFilePath $userLogPath -Message "Удалена группа: $GroupNameRW"
      $deletedGroups += $GroupNameRW
    }
    else {
      Write-Log "⚠️ Группа не найдена: $GroupNameRW"
      Write-UserLog -LogFilePath $userLogPath -Message "Группа не найдена: $GroupNameRW"
    }
        
    # Удаляем папку из !OBMEN
    if ($ShowProgress) {
      Update-Progress -Status "Удаление папки из !OBMEN..." -Details "Пользователь: $UserDisplayName"
    }
    Write-UserLog -LogFilePath $userLogPath -Message "УДАЛЕНИЕ ПАПКИ ИЗ !OBMEN"
        
    $folderName = "$UserLastName $UserFirstName"
    $obmenFolderPath = "\\stepcon.ru\users\Current\!OBMEN\$folderName"
        
    Write-Log "🔍 Проверка папки: $obmenFolderPath"
        
    if (Test-Path $obmenFolderPath) {
      try {
        Remove-Item -Path $obmenFolderPath -Recurse -Force -ErrorAction Stop
        Write-Log "✅ Удалена папка из !OBMEN: $obmenFolderPath"
        Write-UserLog -LogFilePath $userLogPath -Message "Удалена папка из !OBMEN: $obmenFolderPath"
      }
      catch {
        Write-Log "⚠️ Ошибка при удалении папки !OBMEN: $($_.Exception.Message)"
        Write-UserLog -LogFilePath $userLogPath -Message "Ошибка при удалении папки !OBMEN: $($_.Exception.Message)"
      }
    }
    else {
      Write-Log "⚠️ Папка в !OBMEN не найдена: $obmenFolderPath"
      Write-UserLog -LogFilePath $userLogPath -Message "Папка в !OBMEN не найдена: $obmenFolderPath"
    }
        
    # 3. Создаем новую группу для уволенных
    if ($ShowProgress) {
      Update-Progress -Status "Создание группы для уволенных..." -Details "Пользователь: $UserDisplayName"
    }
    Write-UserLog -LogFilePath $userLogPath -Message "СОЗДАНИЕ ГРУППЫ ДЛЯ УВОЛЕННЫХ"

    $FiredGroupName = "Fired--$UserLastName $UserFirstName (RO)"
    $FiredOUPath = "OU=USERS_Fired,OU=DFS,OU=Access Groups,OU=STEP,DC=stepcon,DC=ru"

    Write-Log "🔍 Проверка существования группы: $FiredGroupName"

    # Проверяем существование группы
    $groupExists = Get-ADGroup -Filter "Name -eq '$FiredGroupName'" -ErrorAction SilentlyContinue

    if (-not $groupExists) {
      New-ADGroup -Name $FiredGroupName `
        -SamAccountName $FiredGroupName `
        -GroupCategory Security `
        -GroupScope Global `
        -DisplayName $FiredGroupName `
        -Path $FiredOUPath `
        -Description "Группа доступа для уволенного сотрудника $UserDisplayName" `
        -ErrorAction Stop
      Write-Log "✅ Создана группа для уволенного: $FiredGroupName"
      Write-UserLog -LogFilePath $userLogPath -Message "Создана группа для уволенного: $FiredGroupName"
      
      # Ждем репликации группы перед настройкой разрешений ТОЛЬКО ЕСЛИ ГРУППА БЫЛА СОЗДАНА
      Write-UserLog -LogFilePath $userLogPath -Message "Ожидание репликации группы в AD перед настройкой разрешений..."
      Write-Log "⏳ Ожидание репликации группы $FiredGroupName в AD..."
      Start-Sleep -Seconds 5
    }
    else {
      Write-Log "⚠️ Группа для уволенного уже существует: $FiredGroupName"
      Write-UserLog -LogFilePath $userLogPath -Message "Группа для уволенного уже существует: $FiredGroupName"
    }
        
    # 4. ПЕРЕМЕЩАЕМ папку пользователя в архив Fired с правильной структурой
    if ($ShowProgress) {
      Update-Progress -Status "Перенос папки в архив Fired..." -Details "Пользователь: $UserDisplayName"
    }
    Write-UserLog -LogFilePath $userLogPath -Message "ПЕРЕМЕЩЕНИЕ ПАПКИ В АРХИВ FIRED"
        
    $sourceFolder = "\\stepcon.ru\users\Current\$folderName"
    $destParentFolder = "\\stepcon.ru\users\Fired\$folderName"  # FIRED\Фамилия Имя
    $destFolder = "$destParentFolder\$folderName"  # FIRED\Фамилия Имя\Фамилия Имя
        
    Write-Log "🔍 Проверка исходной папки: $sourceFolder"
    Write-Log "🔍 Проверка целевой папки: $destFolder"
        
    $folderMoved = $false
    $folderCreated = $false
    $folderExists = $false

    # Проверяем, существует ли уже архивная папка
    if (Test-Path $destFolder) {
      Write-Log "ℹ️ Архивная папка уже существует в FIRED: $destFolder"
      Write-UserLog -LogFilePath $userLogPath -Message "Архивная папка уже существует в FIRED"
      $folderExists = $true
      
      # Проверяем и обновляем разрешения если нужно
      try {
        $archiveAcl = Get-Acl $destFolder
        $needsPermissionUpdate = $true
        
        # Проверяем, есть ли уже разрешения для группы Fired
        foreach ($access in $archiveAcl.Access) {
          if ($access.IdentityReference -like "*Fired--$UserLastName*" -or 
            $access.IdentityReference -like "*$FiredGroupName*") {
            $needsPermissionUpdate = $false
            Write-Log "ℹ️ Разрешения для группы Fired уже настроены для папки"
            Write-UserLog -LogFilePath $userLogPath -Message "Разрешения для группы Fired уже настроены для папки"
            break
          }
        }
      }
      catch {
        Write-Log "⚠️ Не удалось проверить/настроить разрешения существующей папки: $($_.Exception.Message)"
        Write-UserLog -LogFilePath $userLogPath -Message "Ошибка проверки разрешений существующей папки: $($_.Exception.Message)"
      }
    }
    else {
      if (Test-Path $sourceFolder) {
        try {
          # Создаем родительскую папку если не существует (FIRED\Фамилия Имя)
          if (-not (Test-Path $destParentFolder)) {
            New-Item -Path $destParentFolder -ItemType Directory -Force | Out-Null
            Write-Log "✅ Создана родительская папка: $destParentFolder"
            Write-UserLog -LogFilePath $userLogPath -Message "Создана родительская папка: $destParentFolder"
          }
                    
          # Пробуем прямое перемещение
          Write-UserLog -LogFilePath $userLogPath -Message "Попытка прямого перемещения папки..."
                    
          try {
            # Перемещаем папку напрямую в целевую локацию
            Move-Item -Path $sourceFolder -Destination $destFolder -Force -ErrorAction Stop
            Write-Log "✅ Папка успешно перемещена: $sourceFolder -> $destFolder"
            Write-UserLog -LogFilePath $userLogPath -Message "Папка успешно перемещена: $sourceFolder -> $destFolder"
            $folderMoved = $true
                        
          }
          catch {
            Write-Log "⚠️ Прямое перемещение не удалось: $($_.Exception.Message)"
            Write-UserLog -LogFilePath $userLogPath -Message "Прямое перемещение не удалось: $($_.Exception.Message)"
                        
            # Альтернативный метод - копирование и удаление
            Write-UserLog -LogFilePath $userLogPath -Message "Попытка альтернативного метода копирования..."
                        
            try {
              # Создаем целевую папку
              if (-not (Test-Path $destFolder)) {
                New-Item -Path $destFolder -ItemType Directory -Force | Out-Null
              }
                            
              # Копируем содержимое
              Copy-Item -Path "$sourceFolder\*" -Destination $destFolder -Recurse -Force -ErrorAction Stop
              Write-Log "✅ Содержимое папки скопировано в архив: $destFolder"
              Write-UserLog -LogFilePath $userLogPath -Message "Содержимое папки скопировано в архив: $destFolder"
                            
              # Удаляем исходную папку
              Remove-Item -Path $sourceFolder -Recurse -Force -ErrorAction SilentlyContinue
              Write-Log "✅ Исходная папка удалена: $sourceFolder"
              Write-UserLog -LogFilePath $userLogPath -Message "Исходная папка удалена: $sourceFolder"
              $folderMoved = $true
                            
            }
            catch {
              Write-Log "❌ Альтернативный метод также не сработал: $($_.Exception.Message)"
              Write-UserLog -LogFilePath $userLogPath -Message "Альтернативный метод также не сработал: $($_.Exception.Message)"
            }
          }
                    
        }
        catch {
          Write-Log "❌ Ошибка при перемещении папки: $($_.Exception.Message)"
          Write-UserLog -LogFilePath $userLogPath -Message "Ошибка при перемещении папки: $($_.Exception.Message)"
        }
      }
      else {
        Write-Log "⚠️ Исходная папка не найдена: $sourceFolder"
        Write-UserLog -LogFilePath $userLogPath -Message "Исходная папка не найдена: $sourceFolder"
                
        # СОЗДАЕМ СТРУКТУРУ ПАПОК ДАЖЕ ЕСЛИ ИСХОДНОЙ ПАПКИ НЕТ
        try {
          # Создаем родительскую папку если не существует (FIRED\Фамилия Имя)
          if (-not (Test-Path $destParentFolder)) {
            New-Item -Path $destParentFolder -ItemType Directory -Force | Out-Null
            Write-Log "✅ Создана родительская папка: $destParentFolder"
            Write-UserLog -LogFilePath $userLogPath -Message "Создана родительская папка: $destParentFolder"
          }
                    
          # Создаем целевую папку даже если исходной нет
          if (-not (Test-Path $destFolder)) {
            New-Item -Path $destFolder -ItemType Directory -Force | Out-Null
            Write-Log "✅ Создана архивная папка: $destFolder"
            Write-UserLog -LogFilePath $userLogPath -Message "Создана архивная папка: $destFolder"
            $folderCreated = $true
          }
          else {
            Write-Log "ℹ️ Архивная папка уже существует: $destFolder"
            Write-UserLog -LogFilePath $userLogPath -Message "Архивная папка уже существует: $destFolder"
            $folderExists = $true
          }
        }
        catch {
          Write-Log "⚠️ Ошибка при создании Fired структуры папок: $($_.Exception.Message)"
          Write-UserLog -LogFilePath $userLogPath -Message "Ошибка при создании Fired структуры папок: $($_.Exception.Message)"
        }
      }
    }



    # БЛОКИРОВКА УЧЕТНОЙ ЗАПИСИ (если еще не заблокирована)
    try {
      $userStatus = Get-ADUser -Identity $User.SamAccountName -Properties Enabled | Select-Object -ExpandProperty Enabled
      if ($userStatus -eq $true) {
        Update-Progress -Status "Блокировка учетной записи..." -Details "Пользователь: $($User.DisplayName)"
        Write-UserLog -LogFilePath $userLogPath -Message "БЛОКИРОВКА УЧЕТНОЙ ЗАПИСИ"
        Disable-ADAccount -Identity $User.SamAccountName
        Write-Log "✅ Учетная запись заблокирована: $($User.DisplayName) ($($User.SamAccountName))"
        Write-UserLog -LogFilePath $userLogPath -Message "Учетная запись заблокирована: $($User.DisplayName)"
      }
      else {
        Write-Log "ℹ️ Учетная запись уже заблокирована: $($User.DisplayName)"
        Write-UserLog -LogFilePath $userLogPath -Message "Учетная запись уже заблокирована"
      }
    }
    catch {
      Write-Log "⚠️ Не удалось проверить/заблокировать учетную запись: $($_.Exception.Message)"
    }
        
    # Скрытие почты
    if ($ShowProgress) {
      Update-Progress -Status "Скрытие почты из адресной книги..." -Details "Пользователь: $($User.DisplayName)"
    }
    Write-UserLog -LogFilePath $userLogPath -Message "СКРЫТИЕ ПОЧТЫ ИЗ АДРЕСНОЙ КНИГИ"
    
    # Функция для безопасной проверки наличия ящика
    function Test-MailboxExists {
      param($Identity)
      # Get-Recipient с фильтром не выдает ошибку, если не найдено
      $recipient = Get-Recipient -Filter "SamAccountName -eq '$Identity'" -ErrorAction SilentlyContinue
      return ($null -ne $recipient -and $recipient.RecipientTypeDetails -match "Mailbox")
    }

    if (Test-ExchangeCommands) {
      try {
        if (Test-MailboxExists -Identity $User.SamAccountName) {
          Set-Mailbox -Identity $User.SamAccountName -HiddenFromAddressListsEnabled $true -ErrorAction Stop
          Write-Log "✅ Почта скрыта из адресной книги: $($User.DisplayName)"
          Write-UserLog -LogFilePath $userLogPath -Message "Почта скрыта из адресной книги"
        }
        else {
          Write-Log "ℹ️ У пользователя $($User.DisplayName) нет почтового ящика Exchange"
          Write-UserLog -LogFilePath $userLogPath -Message "У пользователя нет почтового ящика Exchange"
        }
      }
      catch {
        Write-Log "⚠️ Ошибка скрытия почты для $($User.DisplayName): $($_.Exception.Message)"
        Write-UserLog -LogFilePath $userLogPath -Message "Ошибка скрытия почты: $($_.Exception.Message)"
      }
    }
    else {
      if (Connect-ExchangeServer) {
        try {
          if (Test-MailboxExists -Identity $User.SamAccountName) {
            Set-Mailbox -Identity $User.SamAccountName -HiddenFromAddressListsEnabled $true -ErrorAction Stop
            Write-Log "✅ Почта скрыта из адресной книги: $($User.DisplayName)"
            Write-UserLog -LogFilePath $userLogPath -Message "Почта скрыта из адресной книги"
          }
          else {
            Write-Log "ℹ️ У пользователя $($User.DisplayName) нет почтового ящика Exchange"
            Write-UserLog -LogFilePath $userLogPath -Message "У пользователя нет почтового ящика Exchange"
          }
        }
        catch {
          Write-Log "⚠️ Ошибка скрытия почты для $($User.DisplayName): $($_.Exception.Message)"
          Write-UserLog -LogFilePath $userLogPath -Message "Ошибка скрытия почты: $($_.Exception.Message)"
        }
      }
    }


        
    # Отключение в Skype for Business
    if ($ShowProgress) {
      Update-Progress -Status "Skype for Business..." -Details $User.DisplayName
    }

    Write-UserLog -LogFilePath $userLogPath -Message "SKYPE FOR BUSINESS"

    # Передаем DistinguishedName, как в Set-SfBUser
    $dn = $User.DistinguishedName

    if (Disable-SfBUser -UserDN $dn -LogFilePath $userLogPath) {
      Write-Log "Skype for Business: пользователь $($User.DisplayName) успешно отключен"
    }
    else {
      Write-Log "Skype for Business: не удалось отключить пользователя $($User.DisplayName)"
    }


        
    # Дата увольнения (только если указана)
    if ($terminationDateText) {
      if ($ShowProgress) {
        Update-Progress -Status "Установка даты увольнения и переноса заметок..." -Details "Пользователь: $($User.DisplayName)"
      }
      Write-UserLog -LogFilePath $userLogPath -Message "УСТАНОВКА ДАТЫ УВОЛЬНЕНИЯ И ПЕРЕНОС ЗАМЕТОК"
      
      # 🔄 Вызываем функцию переноса Description в Notes ДО обновления
      $newDescription = "Увольнение: $terminationDateText"
      Update-UserNotes -Login $User.SamAccountName -NewDateDescription $newDescription
      
      Write-Log "✅ Дата увольнения установлена и заметки обновлены: $terminationDateText для $($User.DisplayName)"
      Write-UserLog -LogFilePath $userLogPath -Message "Дата увольнения установлена и заметки обновлены: $terminationDateText"
    }

    else {
      # Если дата не указана, описание не меняем
      Write-Log "ℹ️ Дата увольнения не указана, описание в AD не изменено"
      Write-UserLog -LogFilePath $userLogPath -Message "Дата увольнения не указана, описание в AD не изменено"
    }
        
    # 5. НАСТРОЙКА РАЗРЕШЕНИЙ ДЛЯ ПАПОК (ПОСЛЕ ВСЕХ ОСНОВНЫХ ОПЕРАЦИЙ)
    if ($ShowProgress) {
      Update-Progress -Status "Настройка разрешений для архивных папок..." -Details "Пользователь: $UserDisplayName"
    }
    Write-UserLog -LogFilePath $userLogPath -Message "НАСТРОЙКА РАЗРЕШЕНИЙ ДЛЯ АРХИВНЫХ ПАПОК"
        
    # Получаем SID новой группы (после репликации)
    $firedGroupSID = $null
    try {
      $firedGroupObj = Get-ADGroup -Identity $FiredGroupName -Properties SID
      $firedGroupSID = $firedGroupObj.SID
      Write-UserLog -LogFilePath $userLogPath -Message "Получен SID для группы уволенных после репликации: $($firedGroupSID.Value)"
      Write-Log "✅ Получен SID группы $FiredGroupName после репликации"
    }
    catch {
      Write-Log "⚠️ Не удалось получить SID группы уволенных после репликации: $FiredGroupName"
      Write-UserLog -LogFilePath $userLogPath -Message "Не удалось получить SID группы уволенных после репликации: $FiredGroupName"
    }
        
    if ($firedGroupSID) {
      # Права "Изменение и запись" для папок
      $modifyRights = [System.Security.AccessControl.FileSystemRights]::ReadAndExecute -bor
      [System.Security.AccessControl.FileSystemRights]::ListDirectory -bor
      [System.Security.AccessControl.FileSystemRights]::Read -bor
      [System.Security.AccessControl.FileSystemRights]::Write -bor
      [System.Security.AccessControl.FileSystemRights]::Modify
            
      $inheritanceFlags = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
      [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
            
      # Настраиваем разрешения для родительской папки (FIRED\Фамилия Имя)
      if (Test-Path $destParentFolder) {
        try {
          $parentAcl = Get-Acl $destParentFolder
                    
          # Добавляем правило для группы уволенных с правами "Изменение и запись"
          $parentRule = [System.Security.AccessControl.FileSystemAccessRule]::new(
            $firedGroupSID,
            $modifyRights,
            $inheritanceFlags,
            [System.Security.AccessControl.PropagationFlags]::None,
            [System.Security.AccessControl.AccessControlType]::Allow
          )
                    
          # Проверяем, нет ли уже такого правила
          $hasParentRule = $parentAcl.Access | Where-Object { 
            $_.IdentityReference -eq $firedGroupSID -or 
            $_.IdentityReference -eq "STEPCON\$FiredGroupName" -or
            $_.IdentityReference -like "*$FiredGroupName*"
          }
                    
          if (-not $hasParentRule) {
            $parentAcl.AddAccessRule($parentRule)
            Set-Acl -Path $destParentFolder -AclObject $parentAcl
            Write-Log "✅ Разрешения 'Изменение и запись' настроены для родительской папки: $destParentFolder"
            Write-UserLog -LogFilePath $userLogPath -Message "Разрешения 'Изменение и запись' настроены для родительской папки: $destParentFolder"
          }
          else {
            Write-Log "ℹ️ Разрешения для родительской папки уже настроены: $destParentFolder"
            Write-UserLog -LogFilePath $userLogPath -Message "Разрешения для родительской папки уже настроены: $destParentFolder"
          }
        }
        catch {
          Write-Log "⚠️ Ошибка при настройке разрешений для родительской папки: $($_.Exception.Message)"
          Write-UserLog -LogFilePath $userLogPath -Message "Ошибка при настройке разрешений для родительской папки: $($_.Exception.Message)"
        }
      }
      else {
        Write-Log "⚠️ Родительская папка не найдена: $destParentFolder"
        Write-UserLog -LogFilePath $userLogPath -Message "Родительская папка не найдена: $destParentFolder"
      }
            
      # Настраиваем разрешения для папки (FIRED\Фамилия Имя\Фамилия Имя) - только если не настроены ранее
      if ($needsPermissionUpdate -and $firedGroupSID -and (Test-Path $destFolder)) {
        try {
          $archiveAcl = Get-Acl $destFolder
                    
          # Добавляем правило для группы уволенных с правами "Изменение и запись"
          $archiveRule = [System.Security.AccessControl.FileSystemAccessRule]::new(
            $firedGroupSID,
            $modifyRights,
            $inheritanceFlags,
            [System.Security.AccessControl.PropagationFlags]::None,
            [System.Security.AccessControl.AccessControlType]::Allow
          )
                    
          $archiveAcl.AddAccessRule($archiveRule)
          Set-Acl -Path $destFolder -AclObject $archiveAcl
          Write-Log "✅ Разрешения 'Изменение и запись' настроены для существующей папки Fired: $destFolder"
          Write-UserLog -LogFilePath $userLogPath -Message "Разрешения 'Изменение и запись' настроены для существующей папки Fired: $destFolder"
        }
        catch {
          Write-Log "⚠️ Ошибка при настройке разрешений для папки Fired: $($_.Exception.Message)"
          Write-UserLog -LogFilePath $userLogPath -Message "Ошибка при настройке разрешений для папки Fired: $($_.Exception.Message)"
        }
      }
    }
        
    # 6. ПЕРЕНОС В FIRED В САМУЮ ПОСЛЕДНЮЮ ОЧЕРЕДЬ (кроме Guest)
    if ($ShowProgress) {
      Update-Progress -Status "Перенос учетной записи в AD в OU FIRED..." -Details "Пользователь: $($User.DisplayName)"
    }
    Write-UserLog -LogFilePath $userLogPath -Message "ПЕРЕМЕЩЕНИЕ УЗ В OU FIRED"

    # ДОБАВЛЯЕМ ОПРЕДЕЛЕНИЕ OU
    $firedOU = "OU=FIRED,OU=Users,OU=STEP,DC=stepcon,DC=ru"

    if ($isGuestUser) {
      Write-Log "ℹ️ Пользователь из подразделения Guest, перенос в FIRED не требуется: $($User.DisplayName)"
      Write-UserLog -LogFilePath $userLogPath -Message "Пользователь из подразделения Guest, перенос в FIRED не требуется"
    }
    else {
      try {
        Move-ADObject -Identity $User.DistinguishedName -TargetPath $firedOU
        Write-Log "✅ Перенесен в OU FIRED: $($User.DisplayName) ($($User.SamAccountName))"
        Write-UserLog -LogFilePath $userLogPath -Message "Перенесен в OU FIRED"
      }
      catch {
        Write-Log "⚠️ Ошибка при перемещении в OU FIRED: $($_.Exception.Message)"
        Write-UserLog -LogFilePath $userLogPath -Message "Ошибка при перемещении в OU FIRED: $($_.Exception.Message)"
      }
    }
        
    # ИТОГИ ПО ПОДЧИНЕННЫМ
    if ($subordinatesCount -gt 0) {
      Write-UserLog -LogFilePath $userLogPath -Message "ИТОГ: Очищены руководители $($User.DisplayName) у $subordinatesCount подчиненных"
    }
        
    if ($ShowProgress) {
      Update-Progress -Status "Завершено!" -Details "Пользователь $($User.DisplayName) успешно обработан"
    }
    Write-UserLog -LogFilePath $userLogPath -Message "ПРОЦЕДУРА УВОЛЬНЕНИЯ/БЛОКИРОВКИ УСПЕШНО ЗАВЕРШЕНА"
        
    # Показываем детальное окно только если указано
    if ($ShowDetailsWindow) {
      # Формируем расширенное сообщение для увольнения
      $message = "Процедура увольнения завершена:`n`n"
      $message += "Удаленные группы доступа:`n"
      if ($deletedGroups.Count -gt 0) {
        $message += $deletedGroups -join "`n"
      }
      else {
        $message += "Группы не найдены для удаления`n"
      }
      $message += "`nСоздана группа в FIRED:`n"
      $message += "$FiredGroupName`n"
      $message += "`nСтатус архивной папки:`n"
            
      if ($folderMoved) {
        $message += "✅ Папка успешно перемещена в FIRED`n"
      }
      elseif ($folderCreated) {
        $message += "✅ Создана архивная структура в FIRED`n"
      }
      elseif ($folderExists) {
        $message += "ℹ️ Архивная папка уже существует в FIRED`n"
      }
      else {
        $message += "⚠️ Архивная папка НЕ создана в FIRED`n"
      }
      $message += "\\stepcon.ru\users\Fired\$folderName\$folderName`n"
      $message += "Настроены разрешения для папок`n"
      $message += "`nУправление подчиненными:`n"
      if ($subordinatesCount -gt 0) {
        $message += "✅ Очищены руководители у $subordinatesCount подчиненных`n"
      }
      else {
        $message += "ℹ️ Подчиненные не найдены`n"
      }
     
      $message += "`nСтандартные операции:`n"
      $message += "• Учетная запись заблокирована`n"
      $message += "• Руководитель очищен`n"
      $message += "• Пользователь удален из групп ($($removedGroups.Count) групп)`n"
      $message += "• Перенесен в OU FIRED`n"
      $message += "• Почта скрыта из адресной книги`n"
      $message += "• Отключен в Skype for Business`n"
      if ($subordinatesCount -gt 0) {
        $message += "• Очищены руководители у $subordinatesCount подчиненных`n"
      }
            
      if ($terminationDateText) {
        $message += "`nДата увольнения: $terminationDateText"
        Write-Log "✅ Пользователь уволен: $UserDisplayName ($($User.SamAccountName)) (подчиненных обработано: $subordinatesCount)"
      }
      else {
        $message += "`nТип операции: Блокировка (без даты увольнения)"
        Write-Log "✅ Пользователь заблокирован: $UserDisplayName ($($User.SamAccountName)) (подчиненных обработано: $subordinatesCount)"
      }
            
      # ОБНОВЛЯЕМ ИНТЕРФЕЙС ПЕРЕД ПОКАЗОМ ОКНА
      [System.Windows.Forms.Application]::DoEvents()
      Start-Sleep -Milliseconds 100
            
      # ПОКАЗЫВАЕМ ОКНО
      [System.Windows.Forms.MessageBox]::Show($form, $message, "Увольнение/блокировка завершена", "OK", "Information")
      Write-Log "✅ Окно показано"
    }
    else {
      # Для массовых операций просто логируем
      if ($terminationDateText) {
        Write-Log "✅ Пользователь уволен: $UserDisplayName ($($User.SamAccountName)) (подчиненных обработано: $subordinatesCount)"
      }
      else {
        Write-Log "✅ Пользователь заблокирован: $UserDisplayName ($($User.SamAccountName)) (подчиненных обработано: $subordinatesCount)"
      }
    }
        
    return $true
  }
  catch {
    $errorMessage = $_.Exception.Message
    Write-UserLog -LogFilePath $userLogPath -Message "ОШИБКА ПРИ УВОЛЬНЕНИИ/БЛОКИРОВКИ: $errorMessage"
    Write-Log "❌ Ошибка при обработке $($User.DisplayName) ($($User.SamAccountName)): $errorMessage"
    return $false
  }
}

# === Функция для массового увольнения ===
function Disable-MultipleUserAccounts {
  param([array]$Users)
    
  $successCount = 0
  $errorCount = 0
  $totalSubordinates = 0
    
  # Получаем выбранную дату увольнения (может быть пустой)
  $terminationDateText = if ($terminationDatePicker.CustomFormat -ne " ") { 
    $terminationDatePicker.Value.ToString("dd.MM.yyyy") 
  }
  else { 
    "" 
  }
    
  # Показываем прогресс для массовой операции
  Show-Progress -Status "Массовая блокировка - подготовка..." -Details "Обработка $($Users.Count) пользователей"
    
  try {
    # Предварительная проверка подчиненных
    Update-Progress -Status "Предварительная проверка подчиненных..." -Details "Обработка $($Users.Count) пользователей"
    Write-Log "🔍 Предварительная проверка подчиненных..."
    $usersWithSubordinates = @()
        
    foreach ($user in $Users) {
      
      $subordinates = @(Get-UserSubordinates -SamAccountName $user.SamAccountName)

      if ($subordinates.Count -gt 0) {
        $usersWithSubordinates += @{
          User              = $user
          SubordinatesCount = $subordinates.Count
        }
        $totalSubordinates += $subordinates.Count
      }
    }
        
    # Определяем тип операции для сообщения
    $operationType = if ($terminationDateText) { "уволить" } else { "заблокировать" }
    $operationDetails = if ($terminationDateText) { "Дата увольнения: $terminationDateText" } else { "Тип операции: Блокировка (без даты увольнения)" }
        
    # Одно окно подтверждения для всех пользователей
    $userList = ""
    $counter = 0
    foreach ($user in $Users) {
      $counter++
      $userList += "$counter. $($user.DisplayName) ($($user.SamAccountName))`n"
      if ($counter -ge 15) {
        $userList += "... и еще $($Users.Count - 15) пользователей`n"
        break
      }
    }
        
    # Добавляем информацию о подчиненных в сообщение подтверждения
    $subordinatesInfo = ""
    if ($usersWithSubordinates.Count -gt 0) {
      $subordinatesInfo = "`nПользователи с подчиненными:`n"
      foreach ($item in $usersWithSubordinates) {
        $subordinatesInfo += "• $($item.User.DisplayName) - $($item.SubordinatesCount) подчиненных`n"
      }
    }
        
    # Определяем дополнительные операции для увольнения
    $confirmationMessage = Get-ConfirmationMessage -Users $Users -OperationType $operationType -OperationDetails $operationDetails -SubordinatesInfo $subordinatesInfo -TotalSubordinates $totalSubordinates -LogFolder $logFolder
        
    $result = [System.Windows.Forms.MessageBox]::Show($confirmationMessage, "Подтверждение операции", "YesNo", "Question")    

    if ($result -ne "Yes") {
      Write-Log "⏸️ Операция отменена пользователем"
      return
    }
        
    # Обрабатываем каждого пользователя БЕЗ показа детальных окон
    $currentUserIndex = 0
    foreach ($user in $Users) {
      $currentUserIndex++
            
      Update-Progress -Status "Обработка пользователя $currentUserIndex из $($Users.Count)" -Details "Пользователь: $($user.DisplayName)"
      Write-Log "🔨 Обработка ($currentUserIndex/$($Users.Count)): $($user.DisplayName) ($($user.SamAccountName))"
            
      # Вызываем без показа детального окна и без прогресса
      if (Disable-UserAccount -User $user -ShowDetailsWindow $false -ShowProgress $false) {
        $successCount++
      }
      else {
        $errorCount++
      }

            
      Update-Progress -Status "Завершено $currentUserIndex из $($Users.Count)" -Details "Обработано: $($user.DisplayName)"
    }
        
    # Формируем итоговое сообщение для массовой операции
    $operationResult = if ($terminationDateText) { "уволено" } else { "заблокировано" }
        
    $additionalResults = "`nДополнительные операции увольнения:`n• Удалены группы доступа пользователя`n• Удалена папка из !OBMEN`n• Создана группа доступа FIRED`n• Личная папка перенесена FIRED`n• Настроены разрешения"
        
    $message = "Обработка завершена!`n`n$operationDetails`n$operationResult`: $successCount`nОшибок: $errorCount`nВсего: $($Users.Count)`nОбработано подчиненных: $totalSubordinates$additionalResults`n`nЛог-файлы в:`n$logFolder"
        
    # ПОКАЗЫВАЕМ ОКНО ТОЛЬКО ДЛЯ МАССОВЫХ ОПЕРАЦИЙ (>1 пользователя)
    [System.Windows.Forms.MessageBox]::Show($form, $message, "Итоги операции", "OK", "Information")
    Write-Log "📊 Итоги: $operationResult - $successCount, Ошибок - $errorCount, Подчиненных - $totalSubordinates"
    $searchButton.PerformClick()
        
  }
  finally {
    # Hide-Progress
  }
}

# === Функция для подключения к Exchange ===
function Connect-ExchangeServer {
  try {
    Write-Log "🔗 Подключение к Exchange..."
    Write-Host "ℹ️  Подключение к Exchange..." -ForegroundColor Yellow

    # Закрываем старые сессии Exchange (на всякий случай)
    $oldSessions = Get-PSSession | Where-Object {
      $_.ConfigurationName -eq "Microsoft.Exchange" -or
      $_.ComputerName -like "*spbhdqsrv073*" -or
      $_.ConnectionUri -like "*spbhdqsrv073*"
    }
    if ($oldSessions) {
      Write-Log "🗑️ Закрываем $($oldSessions.Count) старых сессий Exchange"
      $oldSessions | Remove-PSSession -ErrorAction SilentlyContinue
      Start-Sleep -Seconds 1
    }

    # Проверка кеша
    $exchManifest = Join-Path $script:ModulePath "RemoteExchange\\RemoteExchange.psd1"

    if (Test-Path $exchManifest) {
      Write-Log "📦 Загрузка Exchange из кеша..."
      Write-Host "📦 Загрузка Exchange из кеша..." -ForegroundColor Cyan

      Import-Module (Join-Path $script:ModulePath "RemoteExchange") -DisableNameChecking -Force -ErrorAction Stop
      Write-Log "✅ Exchange модуль загружен из кеша"
    }
    else {
      Write-Log "🌐 Кеш Exchange не найден, подключаемся к серверу..."
      $session = New-PSSession -ConfigurationName Microsoft.Exchange `
        -ConnectionUri "http://spbhdqsrv073.stepcon.ru/PowerShell/" `
        -Authentication Kerberos `
        -ErrorAction Stop

      Import-PSSession $session -DisableNameChecking -AllowClobber -ErrorAction Stop | Out-Null
      Write-Log "✅ Подключено к Exchange серверу (online)"
    }

    # Контрольная проверка: команды реально доступны
    if (Get-Command Set-Mailbox -ErrorAction SilentlyContinue) {
      Write-Host "✅ Done" -ForegroundColor Green
      $script:exchangeConnected = $true
      Update-ConnectionStatus -Connected $true
      return $true
    }
    else {
      throw "Команды Exchange недоступны (Set-Mailbox не найден)."
    }
  }
  catch {
    Write-Log "❌ Ошибка подключения к Exchange: $($_.Exception.Message)"
    $script:exchangeConnected = $false
    Update-ConnectionStatus -Connected $false
    return $false
  }
}



# === Функция для проверки команд Exchange ===
function Test-ExchangeCommands { 
  return ($null -ne (Get-Command Set-Mailbox -ErrorAction SilentlyContinue))
}

function Update-ConnectionStatus {
  param([bool]$Connected)
    
  if ($Connected) { 
    $exchangeStatusLabel.Text = "✓ Exchange"
    $exchangeStatusLabel.ForeColor = [System.Drawing.Color]::DarkGreen
    $exchangeStatusLabel.BackColor = [System.Drawing.Color]::FromArgb(240, 255, 240)
        
    # Автоматически подключаемся к SfB
    if (Test-SfBConnection) {
      $sfbStatusLabel.Text = "✓ SfB"
      $sfbStatusLabel.ForeColor = [System.Drawing.Color]::DarkGreen
      $sfbStatusLabel.BackColor = [System.Drawing.Color]::FromArgb(240, 255, 240)
    }
  }
  else { 
    $exchangeStatusLabel.Text = "✗ Exchange" 
    $exchangeStatusLabel.ForeColor = [System.Drawing.Color]::DarkRed
    $exchangeStatusLabel.BackColor = [System.Drawing.Color]::FromArgb(255, 240, 240)
  }
}

# === Функция для поиска пользователей ===
function Search-ADUsers {
  param([string]$SearchTerm)
    
  try {
    $searchBase = "OU=STEP,DC=stepcon,DC=ru"
    $filter = "*"
    if ($SearchTerm) { 
      $filter = "Name -like '*$SearchTerm*' -or SamAccountName -like '*$SearchTerm*' -or DisplayName -like '*$SearchTerm*'" 
    }
        
    $users = Get-ADUser -Filter $filter -SearchBase $searchBase -SearchScope Subtree -Properties DisplayName, Title, Department, Enabled, Manager, DistinguishedName, Company, Description |
    Select-Object Name, SamAccountName, DisplayName, Title, Department, Enabled, DistinguishedName, Manager, Company, Description
        
    foreach ($user in $users) {
      $distinguishedName = $user.DistinguishedName
      $ou = ""
      if ($distinguishedName) {
        $dnParts = $distinguishedName -split ','
        foreach ($part in $dnParts) {
          if ($part -like "OU=*") {
            $ou = $part.Substring(3)
            break
          }
        }
      }
      $user | Add-Member -NotePropertyName 'Subdivision' -NotePropertyValue $ou -Force
    }
        
    return $users
  }
  catch {
    [System.Windows.Forms.MessageBox]::Show($form, "❌ Ошибка поиска: $($_.Exception.Message)", "Ошибка", "OK", "Error")
    return @()
  }
}

# === Функция для поиска пользователей по подразделению ===
function Search-ADUsersByOU {
  param([string]$OUName)
    
  try {
    $searchBase = "OU=STEP,DC=stepcon,DC=ru"
        
    $allUsers = Get-ADUser -Filter "*" -SearchBase $searchBase -SearchScope Subtree -Properties DisplayName, Title, Department, Enabled, Manager, DistinguishedName, Company, Description |
    Select-Object Name, SamAccountName, DisplayName, Title, Department, Enabled, DistinguishedName, Manager, Company, Description
        
    $filteredUsers = @()
        
    foreach ($user in $allUsers) {
      $distinguishedName = $user.DistinguishedName
      $ou = ""
      if ($distinguishedName) {
        $dnParts = $distinguishedName -split ','
        foreach ($part in $dnParts) {
          if ($part -like "OU=*") {
            $ou = $part.Substring(3)
            if ($ou -like "*$OUName*") {
              $user | Add-Member -NotePropertyName 'Subdivision' -NotePropertyValue $ou -Force
              $filteredUsers += $user
              break
            }
          }
        }
      }
    }
        
    return $filteredUsers
  }
  catch {
    [System.Windows.Forms.MessageBox]::Show($form, "❌ Ошибка поиска по подразделению: $($_.Exception.Message)", "Ошибка", "OK", "Error")
    return @()
  }
}

# === Функция для сортировки ListView ===
function Invoke-ListViewSort {
  param(
    [System.Windows.Forms.ListView]$ListView,
    [int]$ColumnIndex,
    [string]$SortOrder
  )
    
  if ($ListView.Items.Count -eq 0) { return }
    
  # Убираем стрелочки с предыдущей колонки
  for ($i = 0; $i -lt $ListView.Columns.Count; $i++) {
    $currentText = $ListView.Columns[$i].Text
    if ($currentText -like "* ▲*" -or $currentText -like "* ▼*") {
      $ListView.Columns[$i].Text = $currentText -replace " [▲▼]", ""
    }
  }
    
  # Добавляем стрелочку к текущей колонке
  $arrow = if ($SortOrder -eq "Ascending") { " ▲" } else { " ▼" }
  $ListView.Columns[$ColumnIndex].Text = $ListView.Columns[$ColumnIndex].Text + $arrow
    
  # Создаем массив для сортировки
  $itemsArray = New-Object System.Collections.ArrayList
  foreach ($item in $ListView.Items) {
    $itemsArray.Add($item) | Out-Null
  }
    
  # Сортируем массив
  $sortedItems = $itemsArray | Sort-Object @{
    Expression = {
      if ($null -eq $_.SubItems[$ColumnIndex].Text) { "" }
      else { $_.SubItems[$ColumnIndex].Text }
    }
    Descending = ($SortOrder -eq "Descending")
  }
    
  # Очищаем ListView и добавляем отсортированные элементы
  $ListView.BeginUpdate()
  $ListView.Items.Clear()
  $ListView.Items.AddRange($sortedItems)
  $ListView.EndUpdate()
    
  # Сохраняем состояние сортировки
  $script:sortColumn = $ColumnIndex
  $script:sortOrder = $SortOrder
}

# === СОЗДАНИЕ ИНТЕРФЕЙСА ===

# Основная форма
$form = New-Object System.Windows.Forms.Form
$form.Text = "Увольнение/Блокировка сотрудника"
$form.Size = New-Object System.Drawing.Size(1200, 700)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.FormBorderStyle = "Sizable"
$form.MaximizeBox = $true
$form.MinimizeBox = $true

# Создаем контрол для подсказок
$toolTip = New-Object System.Windows.Forms.ToolTip
$toolTip.AutoPopDelay = 5000
$toolTip.InitialDelay = 1000
$toolTip.ReshowDelay = 500
$toolTip.ShowAlways = $true

# TabControl
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(10, 10)
$tabControl.Size = New-Object System.Drawing.Size(1160, 600) 
$tabControl.Anchor = "Top,Bottom,Left"

# Вкладка "Пользователи"
$usersTab = New-Object System.Windows.Forms.TabPage
$usersTab.Text = "Пользователи"
$usersTab.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)

# Вкладка "Лог"
$logTab = New-Object System.Windows.Forms.TabPage
$logTab.Text = "Лог операций"
$logTab.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)

# Панель поиска
$searchPanel = New-Object System.Windows.Forms.Panel
$searchPanel.Location = New-Object System.Drawing.Point(10, 10)
$searchPanel.Size = New-Object System.Drawing.Size(1130, 125)
$searchPanel.BackColor = [System.Drawing.Color]::White
$searchPanel.BorderStyle = "FixedSingle"

# Элементы поиска
$searchLabel = New-Object System.Windows.Forms.Label
$searchLabel.Location = New-Object System.Drawing.Point(10, 17)
$searchLabel.Size = New-Object System.Drawing.Size(100, 20)
$searchLabel.Text = "Поиск:"
$searchLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$searchLabel.Cursor = [System.Windows.Forms.Cursors]::Hand

$searchTextBox = New-Object System.Windows.Forms.TextBox
$searchTextBox.Location = New-Object System.Drawing.Point(110, 15)
$searchTextBox.Size = New-Object System.Drawing.Size(200, 22)
$searchTextBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# === Кнопка "Экспортировать модули" ===
$exportButton = New-Object System.Windows.Forms.Button
$exportButton.Location = New-Object System.Drawing.Point(920, 15)
$exportButton.Size = New-Object System.Drawing.Size(180, 25)
$exportButton.Text = "Экспортировать модули"

$exportButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$exportButton.BackColor = [System.Drawing.Color]::FromArgb(23, 162, 184) # Цвет Info (голубой)
$exportButton.ForeColor = [System.Drawing.Color]::White
$exportButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$exportButton.FlatAppearance.BorderSize = 0
$exportButton.Cursor = [System.Windows.Forms.Cursors]::Hand

$exportButton.Add_Click({
    $exportButton.Enabled = $false
    $exportButton.Text = "Экспорт..."
    
    try {
      if (Export-RemoteModules) {
        # Если экспорт прошел успешно, включаем использование кеша
        $script:useModuleCache = $true
        Write-Log "✅ Режим кеша модулей активирован"
      }
    }
    finally {
      $exportButton.Text = "Экспортировать модули"
      $exportButton.Enabled = $true
    }
  })


# Добавляем на форму (вставьте в нужное место, где создаются другие кнопки)
$searchPanel.Controls.Add($exportButton)



# Чек-бокс "Поиск по подразделению"
$searchByOUCheckbox = New-Object System.Windows.Forms.CheckBox
$searchByOUCheckbox.Location = New-Object System.Drawing.Point(320, 17)
$searchByOUCheckbox.Size = New-Object System.Drawing.Size(170, 20)
$searchByOUCheckbox.Text = "Поиск по подразделению"
$searchByOUCheckbox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$searchByOUCheckbox.Checked = $false
$searchByOUCheckbox.Cursor = [System.Windows.Forms.Cursors]::Hand

$searchButton = New-Object System.Windows.Forms.Button
$searchButton.Location = New-Object System.Drawing.Point(500, 15)
$searchButton.Size = New-Object System.Drawing.Size(80, 25)
$searchButton.Text = "Найти"
$searchButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$searchButton.ForeColor = [System.Drawing.Color]::White
$searchButton.FlatStyle = "Flat"
$searchButton.Cursor = [System.Windows.Forms.Cursors]::Hand

$terminateButton = New-Object System.Windows.Forms.Button
$terminateButton.Location = New-Object System.Drawing.Point(590, 15)
$terminateButton.Size = New-Object System.Drawing.Size(150, 25)
$terminateButton.Text = "Заблокировать"
$terminateButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$terminateButton.BackColor = [System.Drawing.Color]::FromArgb(220, 53, 69)
$terminateButton.ForeColor = [System.Drawing.Color]::White
$terminateButton.FlatStyle = "Flat"
$terminateButton.Cursor = [System.Windows.Forms.Cursors]::Hand

# Поле для даты увольнения
$terminationDateLabel = New-Object System.Windows.Forms.Label
$terminationDateLabel.Location = New-Object System.Drawing.Point(10, 53)
$terminationDateLabel.Size = New-Object System.Drawing.Size(120, 20)
$terminationDateLabel.Text = "Дата увольнения:"
$terminationDateLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

$terminationDatePicker = New-Object System.Windows.Forms.DateTimePicker
$terminationDatePicker.Location = New-Object System.Drawing.Point(130, 50)
$terminationDatePicker.Size = New-Object System.Drawing.Size(120, 22)
$terminationDatePicker.Format = [System.Windows.Forms.DateTimePickerFormat]::Custom
$terminationDatePicker.CustomFormat = "dd.MM.yyyy"
$terminationDatePicker.Value = Get-Date  # Текущая дата по умолчанию
$terminationDatePicker.Cursor = [System.Windows.Forms.Cursors]::Hand


# Кнопка для очистки даты
$clearDateButton = New-Object System.Windows.Forms.Button
$clearDateButton.Location = New-Object System.Drawing.Point(255, 50)
$clearDateButton.Size = New-Object System.Drawing.Size(25, 22)
$clearDateButton.Text = "✕"
$clearDateButton.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$clearDateButton.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
$clearDateButton.ForeColor = [System.Drawing.Color]::DarkRed
$clearDateButton.FlatStyle = "Flat"
$clearDateButton.Cursor = [System.Windows.Forms.Cursors]::Hand
# Устанавливаем подсказку через ToolTip
$toolTip.SetToolTip($clearDateButton, "Очистить дату (простая блокировка)")

$dateHintLabel = New-Object System.Windows.Forms.Label
$dateHintLabel.Location = New-Object System.Drawing.Point(285, 53)
$dateHintLabel.Size = New-Object System.Drawing.Size(300, 20)
$dateHintLabel.Text = "* Очистите поле для блокировки без даты увольнения"
$dateHintLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$dateHintLabel.ForeColor = [System.Drawing.Color]::FromArgb(100, 100, 100)

$infoLabel = New-Object System.Windows.Forms.Label
$infoLabel.Location = New-Object System.Drawing.Point(15, 615)
$infoLabel.Size = New-Object System.Drawing.Size(500, 20)
$infoLabel.Text = "Выделите пользователя(ей) в списке выше и нажмите 'Заблокировать'"
$infoLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$infoLabel.ForeColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
$infoLabel.Anchor = "Bottom,Left"

# === Элементы прогресса (ближе к строке поиска) ===
$progressLabel = New-Object System.Windows.Forms.Label
$progressLabel.Location = New-Object System.Drawing.Point(10, 80)
$progressLabel.Size = New-Object System.Drawing.Size(800, 20)
$progressLabel.Text = ""
$progressLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$progressLabel.ForeColor = [System.Drawing.Color]::DarkBlue
$progressLabel.Visible = $false

$progressDetails = New-Object System.Windows.Forms.Label
$progressDetails.Location = New-Object System.Drawing.Point(10, 100)
$progressDetails.Size = New-Object System.Drawing.Size(800, 15)
$progressDetails.Text = ""
$progressDetails.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$progressDetails.ForeColor = [System.Drawing.Color]::DarkGreen
$progressDetails.Visible = $false

# Список пользователей
$listView = New-Object System.Windows.Forms.ListView
$listView.Location = New-Object System.Drawing.Point(10, 145) 
$listView.Size = New-Object System.Drawing.Size(1130, 430) 
$listView.View = "Details"
$listView.FullRowSelect = $true
$listView.GridLines = $true
$listView.MultiSelect = $true
$listView.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$listView.Anchor = "Top,Left"
$listView.Scrollable = $true

# Строка состояния
$statusStrip = New-Object System.Windows.Forms.StatusStrip
$statusStrip.Location = New-Object System.Drawing.Point(0, 675)
$statusStrip.Size = New-Object System.Drawing.Size(1180, 22)
$statusStrip.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)

# Добавляем элементы в панель поиска
$searchPanel.Controls.Add($searchLabel)
$searchPanel.Controls.Add($searchTextBox)
$searchPanel.Controls.Add($searchByOUCheckbox)
$searchPanel.Controls.Add($searchButton)
$searchPanel.Controls.Add($terminateButton)
$searchPanel.Controls.Add($terminationDateLabel)
$searchPanel.Controls.Add($terminationDatePicker)
$searchPanel.Controls.Add($clearDateButton)
$searchPanel.Controls.Add($progressLabel)
$searchPanel.Controls.Add($progressDetails)
$searchPanel.Controls.Add($dateHintLabel)

# Добавляем элементы на вкладку пользователей
$usersTab.Controls.Add($searchPanel)
$usersTab.Controls.Add($listView)

# Колонки списка
$listView.Columns.Add("ФИО", 150) | Out-Null
$listView.Columns.Add("Логин", 120) | Out-Null
$listView.Columns.Add("Должность", 170) | Out-Null
$listView.Columns.Add("Отдел", 150) | Out-Null
$listView.Columns.Add("Подразделение", 200) | Out-Null
$listView.Columns.Add("Организация", 150) | Out-Null
$listView.Columns.Add("Описание", 200) | Out-Null
$listView.Columns.Add("Статус", 105) | Out-Null

# Лог
$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(10, 10)
$logBox.Size = New-Object System.Drawing.Size(1130, 540)
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.Font = New-Object System.Drawing.Font("Consolas", 8)
$logBox.ReadOnly = $true
$logBox.BackColor = [System.Drawing.Color]::White
$logBox.Anchor = "Top,Left"

# Статус Exchange
$exchangeStatusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$exchangeStatusLabel.Text = "✗ Exchange"
$exchangeStatusLabel.ForeColor = [System.Drawing.Color]::DarkRed
$exchangeStatusLabel.BackColor = [System.Drawing.Color]::FromArgb(255, 240, 240)
$exchangeStatusLabel.BorderSides = "All"
$exchangeStatusLabel.BorderStyle = "Sunken"
$exchangeStatusLabel.Margin = New-Object System.Windows.Forms.Padding(1, 0, 1, 0)
$exchangeStatusLabel.Padding = New-Object System.Windows.Forms.Padding(2, 0, 2, 0)
$exchangeStatusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

# Статус Skype for Business
$sfbStatusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$sfbStatusLabel.Text = "✗ SfB"
$sfbStatusLabel.ForeColor = [System.Drawing.Color]::DarkRed
$sfbStatusLabel.BackColor = [System.Drawing.Color]::FromArgb(255, 240, 240)
$sfbStatusLabel.BorderSides = "All"
$sfbStatusLabel.BorderStyle = "Sunken"
$sfbStatusLabel.Margin = New-Object System.Windows.Forms.Padding(1, 0, 1, 0)
$sfbStatusLabel.Padding = New-Object System.Windows.Forms.Padding(2, 0, 2, 0)
$sfbStatusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

$usersCountLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$usersCountLabel.Text = "Найдено пользователей: 0"

$selectedCountLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$selectedCountLabel.Text = "Выделено: 0"

# Добавление элементов (Exchange и SfB рядом)
$statusStrip.Items.Add($exchangeStatusLabel) | Out-Null
$statusStrip.Items.Add($sfbStatusLabel) | Out-Null
$statusStrip.Items.Add($usersCountLabel) | Out-Null
$statusStrip.Items.Add($selectedCountLabel) | Out-Null

$usersTab.Controls.Add($searchPanel)
$usersTab.Controls.Add($listView)

$logTab.Controls.Add($logBox)

$tabControl.TabPages.Add($usersTab) | Out-Null
$tabControl.TabPages.Add($logTab) | Out-Null

$form.Controls.Add($tabControl)
$form.Controls.Add($infoLabel)
$form.Controls.Add($statusStrip)

$infoLabel.BringToFront()

# === ОБРАБОТЧИКИ СОБЫТИЙ ===

# Обработчик клика по заголовку колонки для сортировки
$listView.Add_ColumnClick({
    param($s, $e)
    
    $columnIndex = $e.Column
    
    # Определяем порядок сортировки
    if ($script:sortColumn -eq $columnIndex) {
      # Если кликнули по той же колонке - меняем порядок
      $script:sortOrder = if ($script:sortOrder -eq "Ascending") { "Descending" } else { "Ascending" }
    }
    else {
      # Если кликнули по новой колонке - сортируем по возрастанию
      $script:sortOrder = "Ascending"
    }
    
    # Выполняем сортировку
    Invoke-ListViewSort -ListView $listView -ColumnIndex $columnIndex -SortOrder $script:sortOrder
  })

# Обработчик для кнопки очистки даты
$clearDateButton.Add_Click({
    if ($terminationDatePicker.CustomFormat -eq " ") {
      # Восстанавливаем отображение даты
      $terminationDatePicker.CustomFormat = "dd.MM.yyyy"
      $terminationDatePicker.Value = Get-Date
      $clearDateButton.Text = "✕"
      $toolTip.SetToolTip($clearDateButton, "Очистить дату (простая блокировка)")
      Write-Log "📅 Дата увольнения установлена: $($terminationDatePicker.Value.ToString('dd.MM.yyyy'))"
    }
    else {
      # Очищаем дату
      $terminationDatePicker.CustomFormat = " "
      $terminationDatePicker.Value = Get-Date
      $clearDateButton.Text = "↺"
      $toolTip.SetToolTip($clearDateButton, "Восстановить дату")
      Write-Log "ℹ️ Дата увольнения очищена (режим простой блокировки)"
    }
  })

# Поиск пользователей
$searchButton.Add_Click({
    $searchTerm = $searchTextBox.Text.Trim()
    $searchByOU = $searchByOUCheckbox.Checked
    
    Show-Progress -Status "Поиск пользователей..." -Details "Идет поиск в Active Directory"
    
    try {
      if ($searchByOU) {
        Write-Log "🔍 Поиск по подразделению: '$searchTerm'"
        $users = Search-ADUsersByOU -OUName $searchTerm
      }
      else {
        Write-Log "🔍 Поиск пользователей: '$searchTerm'"
        $users = Search-ADUsers -SearchTerm $searchTerm
      }
        
      $listView.Items.Clear()
        
      # Показываем прогресс при добавлении пользователей в список
      $totalUsers = $users.Count
      $currentUser = 0
        
      foreach ($user in $users) {
        $currentUser++
        if ($currentUser % 50 -eq 0 -or $currentUser -eq $totalUsers) {
          Update-Progress -Status "Загрузка пользователей..." -Details "Загружено $currentUser из $totalUsers"
        }
            
        if ($null -eq $user) { continue }
            
        $displayName = if ($user.DisplayName) { $user.DisplayName } else { $user.Name }
        $title = if ($user.Title) { $user.Title } else { "" }
        $department = if ($user.Department) { $user.Department } else { "" }
        $subdivision = if ($user.Subdivision) { $user.Subdivision } else { "" }
        $company = if ($user.Company) { $user.Company } else { "" }
        $description = if ($user.Description) { $user.Description } else { "" }
        $status = if ($user.Enabled) { "Активен" } else { "Заблокирован" }
            
        $item = New-Object System.Windows.Forms.ListViewItem($displayName)
        $item.SubItems.Add($user.SamAccountName) | Out-Null
        $item.SubItems.Add($title) | Out-Null
        $item.SubItems.Add($department) | Out-Null
        $item.SubItems.Add($subdivision) | Out-Null
        $item.SubItems.Add($company) | Out-Null
        $item.SubItems.Add($description) | Out-Null
        $item.SubItems.Add($status) | Out-Null

        if (-not $user.Enabled) {
          $item.ForeColor = [System.Drawing.Color]::Gray
        }

        $item.Tag = $user
        $listView.Items.Add($item) | Out-Null
      }
        
      # Применяем текущую сортировку если она была
      if ($script:sortColumn -ne -1) {
        Invoke-ListViewSort -ListView $listView -ColumnIndex $script:sortColumn -SortOrder $script:sortOrder
      }
        
      # ИСПРАВЛЕНИЕ: Правильно обрабатываем количество пользователей
      $userCount = 0
      if ($users -ne $null) {
        if ($users.GetType().Name -eq "Object[]" -or $users.GetType().Name -eq "ArrayList") {
          $userCount = $users.Count
        }
        elseif ($users -is [System.Collections.ICollection]) {
          $userCount = $users.Count
        }
        else {
          # Если это одиночный объект
          $userCount = 1
        }
      }
      $usersCountLabel.Text = "Найдено пользователей: $userCount"
        
      Update-Progress -Status "Завершено" -Details "Загружено $totalUsers пользователей"
      Start-Sleep -Milliseconds 500  # Даем увидеть завершение
        
    }
    catch {
      [System.Windows.Forms.MessageBox]::Show($form, "❌ Ошибка поиска: $($_.Exception.Message)", "Ошибка", "OK", "Error")
      Write-Log "❌ Ошибка поиска: $($_.Exception.Message)"
      
    }
    finally {
      #   Hide-Progress
    }
  })

# Поиск по Enter
$searchTextBox.Add_KeyDown({
    if ($_.KeyCode -eq "Enter") { 
      $searchButton.PerformClick() 
    }
  })


# Блокировка пользователей
$terminateButton.Add_Click({
    if ($listView.SelectedItems.Count -eq 0) {
      [System.Windows.Forms.MessageBox]::Show($form, "❌ Выберите пользователя(ей) для блокировки", "Ошибка", "OK", "Warning")
      return
    }
    
    $selectedUsers = @()
    foreach ($item in $listView.SelectedItems) {
      if ($null -ne $item.Tag) { 
        $selectedUsers += $item.Tag 
      }
    }
    
    if ($selectedUsers.Count -eq 0) {
      [System.Windows.Forms.MessageBox]::Show($form, "❌ Нет доступных пользователей для блокировки", "Ошибка", "OK", "Warning")
      return
    }
    
    Write-Log "🔨 Начало обработки ($($selectedUsers.Count) пользователей)"
    
    if ($selectedUsers.Count -eq 1) {
      # Для одного пользователя - показываем окно подтверждения
      $user = $selectedUsers[0]
        
      # Получаем выбранную дату увольнения
      $terminationDateText = if ($terminationDatePicker.CustomFormat -ne " ") { 
        $terminationDatePicker.Value.ToString("dd.MM.yyyy") 
      }
      else { 
        "" 
      }
        
      # Определяем тип операции
      $operationType = if ($terminationDateText) { "уволить" } else { "заблокировать" }
      $operationDetails = if ($terminationDateText) { "Дата увольнения: $terminationDateText" } else { "Тип операции: Блокировка (без даты увольнения)" }
        
      # Предварительная проверка подчиненных
      $subordinates = @(Get-UserSubordinates -SamAccountName $user.SamAccountName)

      $subordinatesInfo = ""
      if ($subordinates.Count -gt 0) {
        $subordinatesInfo = "`nПользователь имеет подчиненных: $($subordinates.Count) человек`n"
      }
        
      # Формируем сообщение подтверждения
      $confirmationMessage = Get-ConfirmationMessage -Users @($user) -OperationType $operationType -OperationDetails $operationDetails -SubordinatesInfo $subordinatesInfo -TotalSubordinates (@($subordinates).Count) -LogFolder $logFolder
        
      $result = [System.Windows.Forms.MessageBox]::Show($confirmationMessage, "Подтверждение операции", "YesNo", "Question")
        
      if ($result -ne "Yes") {
        Write-Log "⏸️ Операция отменена пользователем"
        return
      }
        
      # Выполняем блокировку
      Disable-UserAccount -User $user -ShowDetailsWindow $true
        
      # ОБНОВЛЯЕМ СПИСОК ПОСЛЕ ОБРАБОТКИ
      [System.Windows.Forms.Application]::DoEvents()
      Start-Sleep -Milliseconds 500
      $searchButton.PerformClick()
        
    }
    else {
      # Для нескольких пользователей - массовая операция с итоговым окном
      Disable-MultipleUserAccounts -Users $selectedUsers
    }
  })

# Обновление счетчика выделенных
$listView.Add_ItemSelectionChanged({
    $selectedCountLabel.Text = "Выделено: $($listView.SelectedItems.Count)"
  })

# === Функция для закрытия всех сессий ===
function Close-AllSessions {
  Write-Log "🔌 Закрытие всех подключений..."
  Write-Host "ℹ️  Закрытие всех подключений..." -ForegroundColor Yellow
    
    
  try {
    # Закрываем сессии Exchange
    $exchangeSessions = Get-PSSession | Where-Object { 
      $_.ConfigurationName -eq "Microsoft.Exchange" -or 
      $_.ComputerName -like "*spbhdqsrv073*" -or
      $_.ConnectionUri -like "*spbhdqsrv073*"
    }
    if ($exchangeSessions) {
      Write-Log "🗑️ Закрываем $($exchangeSessions.Count) сессий Exchange"
      $exchangeSessions | Remove-PSSession -ErrorAction SilentlyContinue
    }
  }
  catch {
    Write-Log "⚠️ Ошибка при закрытии сессий Exchange: $($_.Exception.Message)"
  }
    
  try {
    # Закрываем сессии Skype for Business
    $sfbSessions = Get-PSSession | Where-Object { 
      $_.ComputerName -like "*spbhdqsrv023*" -or 
      $_.ConnectionUri -like "*spbhdqsrv023*" -or
      $_.ConfigurationName -like "*OcsPowershell*"
    }
    if ($sfbSessions) {
      Write-Log "🗑️ Закрываем $($sfbSessions.Count) сессий Skype for Business"
      $sfbSessions | Remove-PSSession -ErrorAction SilentlyContinue
    }
  }
  catch {
    Write-Log "⚠️ Ошибка при закрытии сессий Skype for Business: $($_.Exception.Message)"
  }
    
  try {
    # Закрываем все остальные сессии
    $otherSessions = Get-PSSession | Where-Object { 
      $_.ConfigurationName -ne "Microsoft.PowerShell" -and
      $_.ComputerName -notlike "*spbhdqsrv073*" -and
      $_.ComputerName -notlike "*spbhdqsrv023*"
    }
    if ($otherSessions) {
      Write-Log "🗑️ Закрываем $($otherSessions.Count) других сессий"
      $otherSessions | Remove-PSSession -ErrorAction SilentlyContinue
    }
  }
  catch {
    Write-Log "⚠️ Ошибка при закрытии других сессий: $($_.Exception.Message)"
  }
    
  Write-Log "✅ Все подключения закрыты"
  Write-Host "✅ Все подключения закрыты" -ForegroundColor Green
}

# === Обработчик закрытия формы ===
$form.Add_FormClosing({
    param($s, $e)
    
    # Закрываем все сессии
    Close-AllSessions
    
    Write-Log "👋 Скрипт завершен"
  })

# Загружаем начальных пользователей
$searchButton.PerformClick()


# Авто-подключение при старте, если используется кеш
if ($script:useModuleCache) {
  Write-Log "🚀 Автоматическое подключение (используется кеш)..."
    
  # Запускаем в фоне или просто вызываем, так как это быстро
  if (Connect-ExchangeServer) {
    Write-Log "✅ Exchange модуль загружен"
  }
    
  if (Connect-SfBServer) {
    Write-Log "✅ SfB модуль загружен"
  }
}

# Показываем форму
$form.Add_Load({ 
    $form.Activate()
    $searchTextBox.Focus()
  })
$form.ShowDialog() | Out-Null