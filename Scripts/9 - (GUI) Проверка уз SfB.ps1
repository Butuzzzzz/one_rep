# SfB_User_Search_GUI.ps1
# GUI для поиска и управления пользователями Skype for Business

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Основные переменные
$Script:SfBSession = $null
$Script:Server = "spbhdqsrv023.stepcon.ru"
$Script:UserData = @()  # Храним исходные данные пользователей SfB
$Script:ADUserData = @()  # Храним данные пользователей AD

# Функция логирования
function Write-Log {
  param([string]$Message, [string]$Type = "INFO")
    
  $timestamp = Get-Date -Format "HH:mm:ss"
  $logEntry = "[$timestamp] $Message"
    
  switch ($Type) {
    "ERROR" { $color = "Red" }
    "WARNING" { $color = "Orange" }
    "SUCCESS" { $color = "Green" }
    default { $color = "Black" }
  }
    
  if ($null -ne $script:LogTextBox) {
    $script:LogTextBox.SelectionColor = $color
    $script:LogTextBox.AppendText("$logEntry`r`n")
    $script:LogTextBox.ScrollToCaret()
  }
}

# Функция тестирования всех методов доступа к AD
function Test-AllADMethods {
  Write-Log "=== ТЕСТИРОВАНИЕ ПОДКЛЮЧЕНИЯ К AD ===" "INFO"
    
  # Тест 1: Модуль ActiveDirectory
  try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Log "✓ Модуль ActiveDirectory доступен" "SUCCESS"
        
    # Пробуем простой запрос
    $null = Get-ADUser -Filter "SamAccountName -like '*'" -ResultSetSize 1 -ErrorAction Stop
    Write-Log "✓ Запрос через Get-ADUser работает" "SUCCESS"
    return "ActiveDirectory"
  }
  catch {
    Write-Log "✗ Модуль ActiveDirectory не работает: $($_.Exception.Message)" "ERROR"
  }
    
  # Тест 2: DirectorySearcher
  try {
    $searcher = New-Object System.DirectoryServices.DirectorySearcher
    $searcher.Filter = "(objectClass=user)"
    $searcher.SizeLimit = 1
    $null = $searcher.FindOne()
    Write-Log "✓ DirectorySearcher работает" "SUCCESS"
    return "DirectorySearcher"
  }
  catch {
    Write-Log "✗ DirectorySearcher не работает: $($_.Exception.Message)" "ERROR"
  }
    
  # Тест 3: [ADSI]
  try {
    $root = [ADSI]"LDAP://rootDSE"
    $defaultNamingContext = $root.defaultNamingContext
    Write-Log "✓ [ADSI] работает. Домен: $defaultNamingContext" "SUCCESS"
    return "ADSI"
  }
  catch {
    Write-Log "✗ [ADSI] не работает: $($_.Exception.Message)" "ERROR"
  }
    
  Write-Log "✗ Все методы подключения к AD не работают" "ERROR"
  return $null
}

# Альтернативный метод поиска через DirectorySearcher
function Find-ADUsersWithDirectorySearcher {
  param([string]$SearchText)
    
  try {
    Write-Log "Используем DirectorySearcher для поиска в AD" "INFO"
        
    # Создаем поисковик
    $searcher = New-Object System.DirectoryServices.DirectorySearcher
        
    # Базовый фильтр для включенных пользователей
    $filter = "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))"
        
    if (-not [string]::IsNullOrWhiteSpace($SearchText)) {
      $filter = "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(|(displayName=*$SearchText*)(sAMAccountName=*$SearchText*)(userPrincipalName=*$SearchText*)(name=*$SearchText*)))"
    }
        
    $searcher.Filter = $filter
    $searcher.PageSize = 1000
        
    # Указываем какие свойства получать
    $searcher.PropertiesToLoad.Add("displayName") | Out-Null
    $searcher.PropertiesToLoad.Add("sAMAccountName") | Out-Null
    $searcher.PropertiesToLoad.Add("userPrincipalName") | Out-Null
    $searcher.PropertiesToLoad.Add("distinguishedName") | Out-Null
    $searcher.PropertiesToLoad.Add("name") | Out-Null
        
    Write-Log "Выполняем поиск с фильтром: $filter" "INFO"
        
    $results = $searcher.FindAll()
    Write-Log "Найдено объектов в AD: $($results.Count)" "INFO"
        
    # Получаем пользователей SfB для исключения
    $sfbUsers = @()
    try {
      $sfbUsers = Get-CsUser -ErrorAction SilentlyContinue
    }
    catch {
      Write-Log "Не удалось получить пользователей SfB для фильтрации" "WARNING"
    }
        
    $sfbUserUPNs = @($sfbUsers | ForEach-Object { 
        if ($_.UserPrincipalName) { $_.UserPrincipalName.ToLower() } 
      })
        
    # Преобразуем результаты
    $adUsers = @()
    foreach ($result in $results) {
      try {
        $userProps = $result.Properties
                
        $user = New-Object PSObject -Property @{
          DisplayName       = if ($userProps["displayName"]) { $userProps["displayName"][0] } else { $null }
          SamAccountName    = if ($userProps["sAMAccountName"]) { $userProps["sAMAccountName"][0] } else { $null }
          UserPrincipalName = if ($userProps["userPrincipalName"]) { $userProps["userPrincipalName"][0] } else { $null }
          DistinguishedName = if ($userProps["distinguishedName"]) { $userProps["distinguishedName"][0] } else { $null }
          Name              = if ($userProps["name"]) { $userProps["name"][0] } else { $null }
          Enabled           = $true  # Так как мы фильтровали по !(userAccountControl:1.2.840.113556.1.4.803:=2)
        }
                
        # Проверяем, нет ли пользователя в SfB
        $userUPN = if ($user.UserPrincipalName) { $user.UserPrincipalName.ToLower() } else { $null }
        if (-not $userUPN -or $userUPN -notin $sfbUserUPNs) {
          $adUsers += $user
        }
                
      }
      catch {
        Write-Log "Ошибка обработки пользователя AD: $($_.Exception.Message)" "WARNING"
      }
    }
        
    Write-Log "Обработано пользователей AD: $($adUsers.Count)" "SUCCESS"
    return $adUsers
        
  }
  catch {
    Write-Log "Ошибка в DirectorySearcher: $($_.Exception.Message)" "ERROR"
    return @()
  }
}

# Простой метод поиска через ADSI (самый базовый)
function Find-ADUsersWithADSI {
  param([string]$SearchText)
    
  try {
    Write-Log "Используем ADSI для поиска в AD" "INFO"
        
    $searcher = [ADSISearcher]""
    $searcher.Filter = "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))"
        
    if (-not [string]::IsNullOrWhiteSpace($SearchText)) {
      $searcher.Filter = "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(|(displayName=*$SearchText*)(sAMAccountName=*$SearchText*)(userPrincipalName=*$SearchText*)))"
    }
        
    $results = $searcher.FindAll()
    Write-Log "Найдено через ADSI: $($results.Count)" "INFO"
        
    # Получаем пользователей SfB для исключения
    $sfbUsers = @()
    try {
      $sfbUsers = Get-CsUser -ErrorAction SilentlyContinue
    }
    catch {
      Write-Log "Не удалось получить пользователей SfB для фильтрации" "WARNING"
    }
        
    $sfbUserUPNs = @($sfbUsers | ForEach-Object { 
        if ($_.UserPrincipalName) { $_.UserPrincipalName.ToLower() } 
      })
        
    $adUsers = @()
    foreach ($result in $results) {
      try {
        $user = $result.GetDirectoryEntry()
        $adUser = New-Object PSObject -Property @{
          DisplayName       = $user.DisplayName
          SamAccountName    = $user.sAMAccountName
          UserPrincipalName = $user.userPrincipalName
          DistinguishedName = $user.distinguishedName
          Enabled           = $true
        }
                
        # Проверяем, нет ли пользователя в SfB
        $userUPN = if ($adUser.UserPrincipalName) { $adUser.UserPrincipalName.ToLower() } else { $null }
        if (-not $userUPN -or $userUPN -notin $sfbUserUPNs) {
          $adUsers += $adUser
        }
      }
      catch {
        Write-Log "Ошибка обработки пользователя ADSI: $($_.Exception.Message)" "WARNING"
      }
    }
        
    return $adUsers
  }
  catch {
    Write-Log "Ошибка ADSI: $($_.Exception.Message)" "ERROR"
    return @()
  }
}

# Функция поиска пользователей в AD, которых нет в SfB
function Find-ADUsersNotInSfB {
  param([string]$SearchText)
    
  try {
    Write-Log "Поиск пользователей в AD: '$SearchText'" "INFO"
        
    # Пробуем разные методы подключения к AD
    $adModuleLoaded = $false
    try {
      Import-Module ActiveDirectory -ErrorAction Stop
      $adModuleLoaded = $true
      Write-Log "Модуль ActiveDirectory загружен" "SUCCESS"
    }
    catch {
      Write-Log "Не удалось загрузить модуль ActiveDirectory: $($_.Exception.Message)" "WARNING"
    }
        
    # Метод 1: Через модуль ActiveDirectory
    if ($adModuleLoaded) {
      Write-Log "Используем метод поиска через модуль ActiveDirectory" "INFO"
            
      # Получаем всех пользователей SfB
      $sfbUsers = @()
      try {
        $sfbUsers = Get-CsUser -ErrorAction SilentlyContinue
        Write-Log "Получено пользователей SfB: $($sfbUsers.Count)" "INFO"
      }
      catch {
        Write-Log "Не удалось получить пользователей SfB: $($_.Exception.Message)" "WARNING"
      }
            
      $sfbUserUPNs = @($sfbUsers | ForEach-Object { 
          if ($_.UserPrincipalName) { $_.UserPrincipalName.ToLower() } 
        })
            
      # Ищем в AD
      $adFilter = "Enabled -eq 'True'"
      if (-not [string]::IsNullOrWhiteSpace($SearchText)) {
        $adFilter = "(&(Enabled=TRUE)(|(DisplayName=*$SearchText*)(SamAccountName=*$SearchText*)(UserPrincipalName=*$SearchText*)(Name=*$SearchText*)))"
      }
            
      Write-Log "Фильтр AD: $adFilter" "INFO"
            
      $adUsers = Get-ADUser -Filter $adFilter -Properties DisplayName, UserPrincipalName, SamAccountName, Enabled, DistinguishedName -ErrorAction Stop
      Write-Log "Найдено пользователей в AD: $($adUsers.Count)" "INFO"
            
      # Фильтруем тех, кого нет в SfB
      $result = @()
      foreach ($user in $adUsers) {
        $userUPN = if ($user.UserPrincipalName) { $user.UserPrincipalName.ToLower() } else { $null }
                
        if (-not $userUPN -or $userUPN -notin $sfbUserUPNs) {
          $result += $user
        }
      }
            
      Write-Log "Пользователей доступных для добавления: $($result.Count)" "SUCCESS"
      return $result
    }
        
    # Метод 2: Через System.DirectoryServices.DirectorySearcher (если модуль не загрузился)
    Write-Log "Пробуем метод поиска через DirectorySearcher" "INFO"
    $result = Find-ADUsersWithDirectorySearcher -SearchText $SearchText
        
    # Если все методы не сработали, пробуем ADSI
    if ($result.Count -eq 0) {
      Write-Log "Все методы не дали результатов, пробуем ADSI" "WARNING"
      $result = Find-ADUsersWithADSI -SearchText $SearchText
    }
        
    return $result
        
  }
  catch {
    Write-Log "Ошибка при поиске в AD: $($_.Exception.Message)" "ERROR"
        
    # Пробуем альтернативный метод
    Write-Log "Пробуем альтернативный метод поиска" "INFO"
    return Find-ADUsersWithDirectorySearcher -SearchText $SearchText
  }
}

# Функция подключения к Skype for Business
function Connect-SfBServer {
  try {
    Write-Log "Подключение к серверу $($Script:Server)..." "INFO"
        
    # Закрываем все предыдущие сессии
    Write-Log "Закрытие предыдущих сессий..." "INFO"
    Get-PSSession | Where-Object { $_.ComputerName -like "*$($Script:Server)*" -or $_.ConnectionUri -like "*$($Script:Server)*" } | Remove-PSSession -ErrorAction SilentlyContinue
        
    # Создаем опции сессии
    $sessionOption = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
        
    # Создаем сессию
    $session = New-PSSession -ConnectionUri "https://$($Script:Server)/OcsPowershell" -SessionOption $sessionOption -Authentication Negotiate
    Write-Log "PSSession создана успешно (ID: $($session.Id))" "SUCCESS"
        
    # Импортируем команды
    $importedCommands = Import-PSSession $session -AllowClobber
    Write-Log "Импортировано команд: $($importedCommands.Count)" "SUCCESS"
        
    # Проверяем команды
    if (Get-Command Get-CsUser -ErrorAction SilentlyContinue) {
      Write-Log "Команды Skype for Business доступны" "SUCCESS"
      $Script:SfBSession = $session
      return $true
    }
    else {
      Write-Log "Команды Skype for Business недоступны" "ERROR"
      return $false
    }
  }
  catch {
    Write-Log "Ошибка подключения: $($_.Exception.Message)" "ERROR"
    return $false
  }
}

# Функция поиска пользователей (ИЩЕМ ВСЕХ, не только включенных)
function Find-SfBUsers {
  param([string]$SearchText)
    
  try {
    Write-Log "Поиск пользователей SfB: '$SearchText'" "INFO"
        
    if ($null -eq $Script:SfBSession) {
      Write-Log "Ошибка: нет подключения к SfB" "ERROR"
      return @()
    }
        
    # Ищем ВСЕХ пользователей, не только включенных
    $allUsers = Get-CsUser -ErrorAction Stop
    Write-Log "Всего пользователей в SfB: $($allUsers.Count)" "INFO"
        
    if ([string]::IsNullOrWhiteSpace($SearchText)) {
      Write-Log "Возвращаем всех пользователей: $($allUsers.Count)" "INFO"
      return $allUsers
    }
    else {
      $results = $allUsers | Where-Object { 
        $_.DisplayName -like "*$SearchText*" -or
        $_.SipAddress -like "*$SearchText*" -or
        $_.UserPrincipalName -like "*$SearchText*" -or
        $_.SamAccountName -like "*$SearchText*"
      }
      Write-Log "Найдено пользователей по фильтру '$SearchText': $($results.Count)" "SUCCESS"
      return $results
    }
  }
  catch {
    Write-Log "Ошибка поиска: $($_.Exception.Message)" "ERROR"
    return @()
  }
}

function Get-ADStatusMapBulk {
  param([array]$SfBUsers)

  $map = @{}

  Import-Module ActiveDirectory -ErrorAction Stop

  $upns = @(
    $SfBUsers | ForEach-Object {
      if ($_.UserPrincipalName) { $_.UserPrincipalName }
      elseif ($_.SipAddress) { ($_.SipAddress -replace '^sip:') }
    } | Where-Object { $_ -like '*@*' } | Select-Object -Unique
  )

  for ($i = 0; $i -lt $upns.Count; $i += 50) {
    $end = [Math]::Min($i + 49, $upns.Count - 1)
    $batch = $upns[$i..$end]

    $orPart = ($batch | ForEach-Object { "(userPrincipalName=$($_))" }) -join ''
    $ldap = "(&(objectCategory=person)(objectClass=user)(|$orPart))"

    $adUsers = Get-ADUser -LDAPFilter $ldap -Properties Enabled, LockedOut, LastLogonDate, SamAccountName, UserPrincipalName

    foreach ($u in $adUsers) {
      if ($u.UserPrincipalName) {
        $key = $u.UserPrincipalName.ToLower()
        $map[$key] = [pscustomobject]@{
          EnabledInAD    = [bool]$u.Enabled
          ExistsInAD     = $true
          LockedOut      = [bool]$u.LockedOut
          LastLogonDate  = $u.LastLogonDate
          SamAccountName = $u.SamAccountName
          ADUser         = $u
        }
      }
    }
  }

  return $map
}



# Функция получения статуса пользователя в AD
function Get-ADUserStatus {
  param($SfBUser)
    
  try {
    # Пробуем разные методы поиска в AD
    $adUser = $null
    $upn = $SfBUser.UserPrincipalName
        
    if ($null -eq $upn -and $SfBUser.SipAddress) {
      $upn = $SfBUser.SipAddress -replace 'sip:'
    }
        
    # Метод 1: Через модуль ActiveDirectory
    try {
      Import-Module ActiveDirectory -ErrorAction Stop
      if ($upn -like "*@*") {
        $adUser = Get-ADUser -Filter "UserPrincipalName -eq '$upn'" -Properties Enabled, LockedOut, LastLogonDate, DisplayName, SamAccountName -ErrorAction SilentlyContinue
      }
            
      if ($null -eq $adUser -and $SfBUser.DisplayName) {
        $adUsers = Get-ADUser -Filter "DisplayName -eq '$($SfBUser.DisplayName)'" -Properties Enabled, LockedOut, LastLogonDate, DisplayName, SamAccountName -ErrorAction SilentlyContinue
        if ($adUsers) { $adUser = $adUsers[0] }
      }
    }
    catch {
      # Метод 2: Через DirectorySearcher
      try {
        $searcher = New-Object System.DirectoryServices.DirectorySearcher
        if ($upn -like "*@*") {
          $searcher.Filter = "(&(objectClass=user)(userPrincipalName=$upn))"
        }
        elseif ($SfBUser.DisplayName) {
          $searcher.Filter = "(&(objectClass=user)(displayName=$($SfBUser.DisplayName)))"
        }
                
        $result = $searcher.FindOne()
        if ($result) {
          $adUser = $result.GetDirectoryEntry()
        }
      }
      catch {
        Write-Log "Ошибка поиска пользователя в AD: $($_.Exception.Message)" "WARNING"
      }
    }
        
    return @{
      EnabledInAD    = if ($adUser) { 
        if ($null -ne $adUser.Enabled) { $adUser.Enabled } 
        elseif ($null -ne $adUser.AccountDisabled) { -not $adUser.AccountDisabled }
        else { $false }
      }
      else { $false }
      ExistsInAD     = if ($adUser) { $true } else { $false }
      LockedOut      = if ($adUser) { $adUser.LockedOut } else { $false }
      LastLogonDate  = if ($adUser) { $adUser.LastLogonDate } else { $null }
      SamAccountName = if ($adUser) { $adUser.SamAccountName } else { $null }
      ADUser         = $adUser
    }
  }
  catch {
    Write-Log "Ошибка проверки AD: $($_.Exception.Message)" "ERROR"
    return @{
      EnabledInAD    = $false
      ExistsInAD     = $false
      LockedOut      = $false
      LastLogonDate  = $null
      SamAccountName = $null
      ADUser         = $null
    }
  }
}

# Функция получения логина пользователя
function Get-UserLogin {
  param($SfBUser, $ADStatus)
    
  # Сначала пробуем получить логин из AD
  if ($ADStatus.SamAccountName) {
    return $ADStatus.SamAccountName
  }
    
  # Если нет в AD, пробуем из SipAddress
  if ($SfBUser.SipAddress -and $SfBUser.SipAddress -like "sip:*@*") {
    $login = $SfBUser.SipAddress -replace 'sip:' -replace '@.*$'
    return $login
  }
    
  # Если нет, пробуем из UserPrincipalName
  if ($SfBUser.UserPrincipalName -and $SfBUser.UserPrincipalName -like "*@*") {
    $login = $SfBUser.UserPrincipalName -replace '@.*$'
    return $login
  }
    
  # Если ничего не нашли, возвращаем пустую строку
  return ""
}

# Функция определения статуса пользователя
function Get-UserStatus {
  param($SfBUser, $ADStatus)
    
  $status = @()
    
  # Проверяем статус в AD
  if (-not $ADStatus.ExistsInAD) {
    $status += "Не найден в AD"
  }
  elseif (-not $ADStatus.EnabledInAD) {
    $status += "Отключен в AD"
  }
  elseif ($ADStatus.LockedOut) {
    $status += "Заблокирован в AD"
  }
    
  # Проверяем статус в SfB
  if (-not $SfBUser.Enabled) {
    $status += "Отключен в SfB"
  }
    
  # Формируем финальный статус по новым правилам
  if ($ADStatus.ExistsInAD -and $ADStatus.EnabledInAD -and -not $ADStatus.LockedOut -and $SfBUser.Enabled) {
    return "Активен"
  }
  elseif ($ADStatus.ExistsInAD -and (-not $ADStatus.EnabledInAD -or $ADStatus.LockedOut) -and -not $SfBUser.Enabled) {
    return "Отключен"
  }
  elseif ($ADStatus.ExistsInAD -and (-not $ADStatus.EnabledInAD -or $ADStatus.LockedOut) -and $SfBUser.Enabled) {
    return "Отклонение: Отключен в AD, Включен в SfB"
  }
  elseif ($ADStatus.ExistsInAD -and $ADStatus.EnabledInAD -and -not $ADStatus.LockedOut -and -not $SfBUser.Enabled) {
    return "Отклонение: Включен в AD, Отключен в SfB"
  }
  else {
    return ($status -join "; ")
  }
}

# Функция снятия/установки галочки "Разрешено для Skype для бизнеса Server"
function Set-SfBUserEnabled {
  param($UserIdentity, [bool]$Enabled)
    
  try {
    $action = if ($Enabled) { "Включение" } else { "Отключение" }
    Write-Log "$action пользователя: $($UserIdentity)" "INFO"
        
    if ($null -eq $Script:SfBSession) {
      Write-Log "Ошибка: нет подключения к SfB" "ERROR"
      return $false
    }
        
    # Получаем текущие настройки пользователя
    Write-Log "Получение текущих настроек пользователя..." "INFO"
    $user = Get-CsUser -Identity $UserIdentity -ErrorAction SilentlyContinue
    if ($null -eq $user) {
      Write-Log "Пользователь $($UserIdentity) не найден в SfB" "ERROR"
      return $false
    }
        
    Write-Log "Текущий статус Enabled: $($user.Enabled)" "INFO"
        
    if ($Enabled) {
      Write-Log "Выполнение Set-CsUser с Enabled=true..." "INFO"
      $setParams = @{
        Identity = $UserIdentity
        Enabled  = $true
        Confirm  = $false
      }
      Set-CsUser @setParams
      Write-Log "Галочка установлена" "SUCCESS"
    }
    else {
      Write-Log "Выполнение Set-CsUser с Enabled=false..." "INFO"
      $setParams = @{
        Identity = $UserIdentity
        Enabled  = $false
        Confirm  = $false
      }
      Set-CsUser @setParams
      Write-Log "Галочка снята" "SUCCESS"
    }
        
    return $true
  }
  catch {
    Write-Log "Ошибка при изменении статуса пользователя $($UserIdentity): $($_.Exception.Message)" "ERROR"
    return $false
  }
}

# Функция добавления пользователя в SfB
function Add-UserToSfB {
  param($UserIdentity, $RegistrarPool)
    
  try {
    Write-Log "Добавление пользователя в SfB: $($UserIdentity)" "INFO"
        
    if ($null -eq $Script:SfBSession) {
      Write-Log "Ошибка: нет подключения к SfB" "ERROR"
      return $false
    }
        
    # Проверяем, не добавлен ли уже пользователь
    $existingUser = Get-CsUser -Identity $UserIdentity -ErrorAction SilentlyContinue
    if ($existingUser) {
      Write-Log "Пользователь $($UserIdentity) уже существует в SfB" "WARNING"
      return $false
    }
        
    # Добавляем пользователя в SfB
    Write-Log "Выполнение Enable-CsUser..." "INFO"
        
    # Пробуем разные варианты SipAddressType
        
    # Вариант 1: UserPrincipalName (использует UPN как SIP адрес)
    try {
      Write-Log "Пробуем добавить с параметром -SipAddressType UserPrincipalName..." "INFO"
      Enable-CsUser -Identity $UserIdentity -RegistrarPool $RegistrarPool -SipAddressType "UserPrincipalName" -ErrorAction Stop
      Write-Log "Пользователь $($UserIdentity) успешно добавлен в SfB с SipAddressType UserPrincipalName" "SUCCESS"
      return $true
    }
    catch {
      Write-Log "Не удалось добавить с UserPrincipalName: $($_.Exception.Message)" "WARNING"
            
      # Вариант 2: SAMAccountName (использует логин AD)
      try {
        Write-Log "Пробуем добавить с параметром -SipAddressType SAMAccountName..." "INFO"
        Enable-CsUser -Identity $UserIdentity -RegistrarPool $RegistrarPool -SipAddressType "SAMAccountName" -ErrorAction Stop
        Write-Log "Пользователь $($UserIdentity) успешно добавлен в SfB с SipAddressType SAMAccountName" "SUCCESS"
        return $true
      }
      catch {
        Write-Log "Не удалось добавить с SAMAccountName: $($_.Exception.Message)" "WARNING"
                
        # Вариант 3: EmailAddress
        try {
          Write-Log "Пробуем добавить с параметром -SipAddressType EmailAddress..." "INFO"
          Enable-CsUser -Identity $UserIdentity -RegistrarPool $RegistrarPool -SipAddressType "EmailAddress" -ErrorAction Stop
          Write-Log "Пользователь $($UserIdentity) успешно добавлен в SfB с SipAddressType EmailAddress" "SUCCESS"
          return $true
        }
        catch {
          Write-Log "Не удалось добавить с EmailAddress: $($_.Exception.Message)" "WARNING"
                    
          # Вариант 4: FirstLastName
          try {
            Write-Log "Пробуем добавить с параметром -SipAddressType FirstLastName..." "INFO"
            Enable-CsUser -Identity $UserIdentity -RegistrarPool $RegistrarPool -SipAddressType "FirstLastName" -ErrorAction Stop
            Write-Log "Пользователь $($UserIdentity) успешно добавлен в SfB с SipAddressType FirstLastName" "SUCCESS"
            return $true
          }
          catch {
            Write-Log "Не удалось добавить с FirstLastName: $($_.Exception.Message)" "WARNING"
                        
            # Вариант 5: None (система сама выберет)
            try {
              Write-Log "Пробуем добавить с параметром -SipAddressType None..." "INFO"
              Enable-CsUser -Identity $UserIdentity -RegistrarPool $RegistrarPool -SipAddressType "None" -ErrorAction Stop
              Write-Log "Пользователь $($UserIdentity) успешно добавлен в SfB с SipAddressType None" "SUCCESS"
              return $true
            }
            catch {
              Write-Log "Не удалось добавить с None: $($_.Exception.Message)" "WARNING"
                            
              # Вариант 6: Без указания SipAddressType (по умолчанию)
              try {
                Write-Log "Пробуем добавить без указания SipAddressType..." "INFO"
                Enable-CsUser -Identity $UserIdentity -RegistrarPool $RegistrarPool -ErrorAction Stop
                Write-Log "Пользователь $($UserIdentity) успешно добавлен в SfB" "SUCCESS"
                return $true
              }
              catch {
                Write-Log "Все методы добавления не сработали: $($_.Exception.Message)" "ERROR"
                return $false
              }
            }
          }
        }
      }
    }
  }
  catch {
    Write-Log "Критическая ошибка при добавлении пользователя $($UserIdentity): $($_.Exception.Message)" "ERROR"
    return $false
  }
}

# Функция обновления строки состояния
function Update-StatusBar {
  param($Users)
    
  if ($null -eq $Users -or $Users.Count -eq 0) {
    $script:statusBarLabel.Text = "Пользователи не найдены"
    return
  }
    
  $total = $Users.Count
  $activeCount = 0
  $deviationCount = 0
  $warningCount = 0
  $disabledCount = 0
  $disabledInSfBCount = 0
  $notFoundInADCount = 0
    
  foreach ($user in $Users) {
    $status = Get-UserStatus -SfBUser $user -ADStatus (Get-ADUserStatus -SfBUser $user)
        
    if ($status -eq "Активен") {
      $activeCount++
    }
    elseif ($status -like "*Отклонение:*") {
      $deviationCount++
    }
    elseif ($status -like "*Отключен*" -and $status -notlike "*Отклонение:*") {
      $disabledCount++
    }
    elseif ($status -like "*Отключен в SfB*") {
      $disabledInSfBCount++
    }
    elseif ($status -like "*Не найден в AD*") {
      $notFoundInADCount++
    }
    else {
      $warningCount++
    }
  }
    
  $statusText = "Всего: $total"
  if ($activeCount -gt 0) { $statusText += " | Активны: $activeCount" }
  if ($deviationCount -gt 0) { $statusText += " | Отклонения: $deviationCount" }
  if ($warningCount -gt 0) { $statusText += " | Предупреждения: $warningCount" }
  if ($disabledCount -gt 0) { $statusText += " | Отключены: $disabledCount" }
  if ($disabledInSfBCount -gt 0) { $statusText += " | Отключены в SfB: $disabledInSfBCount" }
  if ($notFoundInADCount -gt 0) { $statusText += " | Не найдены в AD: $notFoundInADCount" }
    
  $script:statusBarLabel.Text = $statusText
}

# Создание главной формы с вкладками

function Show-MainForm {
  $form = New-Object System.Windows.Forms.Form
  $form.Text = "Skype for Business - Управление пользователями"
  $form.Size = New-Object System.Drawing.Size(1200, 800)
  $form.StartPosition = "CenterScreen"
  $form.MinimumSize = New-Object System.Drawing.Size(1000, 600)
  $form.BackColor = [System.Drawing.Color]::White
  $form.WindowState = 'Maximized'

  # Создаем TabControl
  $tabControl = New-Object System.Windows.Forms.TabControl
  $tabControl.Dock = [System.Windows.Forms.DockStyle]::Fill
  $form.Controls.Add($tabControl)

  # Вкладка 1: Пользователи SfB
  $sfbTab = New-Object System.Windows.Forms.TabPage
  $sfbTab.Text = "Пользователи Skype for Business"
  $sfbTab.BackColor = [System.Drawing.Color]::White

  # Вкладка 2: Пользователи AD (новые)
  $adTab = New-Object System.Windows.Forms.TabPage
  $adTab.Text = "Добавить из Active Directory"
  $adTab.BackColor = [System.Drawing.Color]::White

  # Вкладка 3: Логи
  $logTab = New-Object System.Windows.Forms.TabPage
  $logTab.Text = "Логи"
  $logTab.BackColor = [System.Drawing.Color]::White

  # Добавляем вкладки
  $tabControl.Controls.Add($sfbTab)
  $tabControl.Controls.Add($adTab)
  $tabControl.Controls.Add($logTab)

  # Создаем элементы для вкладки SfB
  New-SfBTab -TabPage $sfbTab

  # Создаем элементы для вкладки AD
  New-ADTab -TabPage $adTab

  # Создаем элементы для вкладки Логи
  New-LogTab -TabPage $logTab

  return $form
}


# Создание элементов для вкладки SfB

# Создание элементов для вкладки SfB
function New-SfBTab {
  param($TabPage)

  $topPanel = New-Object System.Windows.Forms.Panel
  $topPanel.Dock = [System.Windows.Forms.DockStyle]::Top
  $topPanel.Height = 110
  $TabPage.Controls.Add($topPanel)

  $bottomPanel = New-Object System.Windows.Forms.Panel
  $bottomPanel.Dock = [System.Windows.Forms.DockStyle]::Bottom
  $bottomPanel.Height = 30
  $TabPage.Controls.Add($bottomPanel)

  $headerLabel = New-Object System.Windows.Forms.Label
  $searchLabel = New-Object System.Windows.Forms.Label
  $script:searchTextBox = New-Object System.Windows.Forms.TextBox
  $script:searchButton = New-Object System.Windows.Forms.Button
  $script:showAllButton = New-Object System.Windows.Forms.Button
  $script:disableButton = New-Object System.Windows.Forms.Button
  $script:enableButton = New-Object System.Windows.Forms.Button
  $script:statusLabel = New-Object System.Windows.Forms.Label
  $script:resultsGrid = New-Object System.Windows.Forms.DataGridView
  $script:statusBarLabel = New-Object System.Windows.Forms.Label

  $headerLabel.Location = New-Object System.Drawing.Point(20, 15)
  $headerLabel.Size = New-Object System.Drawing.Size(500, 25)
  $headerLabel.Text = "Управление пользователями Skype for Business"
  $headerLabel.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
  $topPanel.Controls.Add($headerLabel)

  $searchLabel.Location = New-Object System.Drawing.Point(20, 52)
  $searchLabel.Size = New-Object System.Drawing.Size(100, 20)
  $searchLabel.Text = "ФИО или логин:"
  $topPanel.Controls.Add($searchLabel)

  $script:searchTextBox.Location = New-Object System.Drawing.Point(120, 50)
  $script:searchTextBox.Size = New-Object System.Drawing.Size(200, 20)
  $script:searchTextBox.Text = "Иванов"
  $script:searchTextBox.Add_KeyDown({
      if ($_.KeyCode -eq "Enter") { Start-UserSearch }
    })
  $topPanel.Controls.Add($script:searchTextBox)

  $script:searchButton.Location = New-Object System.Drawing.Point(330, 48)
  $script:searchButton.Size = New-Object System.Drawing.Size(100, 25)
  $script:searchButton.Text = "Найти"
  $script:searchButton.Enabled = $false
  $script:searchButton.FlatStyle = [System.Windows.Forms.FlatStyle]::System
  $script:searchButton.Add_Click({ Start-UserSearch })
  $topPanel.Controls.Add($script:searchButton)

  $script:showAllButton.Location = New-Object System.Drawing.Point(440, 48)
  $script:showAllButton.Size = New-Object System.Drawing.Size(100, 25)
  $script:showAllButton.Text = "Показать всех"
  $script:showAllButton.Enabled = $false
  $script:showAllButton.FlatStyle = [System.Windows.Forms.FlatStyle]::System
  $script:showAllButton.Add_Click({ $script:searchTextBox.Text = ""; Start-UserSearch })
  $topPanel.Controls.Add($script:showAllButton)

  $script:disableButton.Location = New-Object System.Drawing.Point(550, 48)
  $script:disableButton.Size = New-Object System.Drawing.Size(120, 25)
  $script:disableButton.Text = "Отключить в SfB"
  $script:disableButton.Enabled = $false
  $script:disableButton.FlatStyle = [System.Windows.Forms.FlatStyle]::System
  $script:disableButton.Add_Click({ Disable-SelectedUser })
  $topPanel.Controls.Add($script:disableButton)

  $script:enableButton.Location = New-Object System.Drawing.Point(680, 48)
  $script:enableButton.Size = New-Object System.Drawing.Size(120, 25)
  $script:enableButton.Text = "Включить в SfB"
  $script:enableButton.Enabled = $false
  $script:enableButton.FlatStyle = [System.Windows.Forms.FlatStyle]::System
  $script:enableButton.Add_Click({ Enable-SelectedUser })
  $topPanel.Controls.Add($script:enableButton)

  $script:statusLabel.Location = New-Object System.Drawing.Point(20, 80)
  $script:statusLabel.Size = New-Object System.Drawing.Size(1000, 20)
  $script:statusLabel.Text = "Подключение к серверу..."
  $topPanel.Controls.Add($script:statusLabel)

  $script:statusBarLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
  $script:statusBarLabel.Text = "Готово"
  $script:statusBarLabel.BorderStyle = "FixedSingle"
  $script:statusBarLabel.BackColor = [System.Drawing.Color]::LightGray
  $script:statusBarLabel.TextAlign = "MiddleLeft"
  $bottomPanel.Controls.Add($script:statusBarLabel)

  # ТАБЛИЦА
  $script:resultsGrid.Dock = [System.Windows.Forms.DockStyle]::Fill
  $script:resultsGrid.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::None
  $script:resultsGrid.AllowUserToResizeColumns = $true
  $script:resultsGrid.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::DisableResizing
  $script:resultsGrid.ColumnHeadersHeight = 25
  $script:resultsGrid.SelectionMode = "FullRowSelect"
  $script:resultsGrid.ReadOnly = $true
  $script:resultsGrid.AllowUserToAddRows = $false
  $script:resultsGrid.RowHeadersVisible = $false
  $script:resultsGrid.AllowUserToResizeRows = $false
  $script:resultsGrid.AutoSizeRowsMode = [System.Windows.Forms.DataGridViewAutoSizeRowsMode]::None
  $script:resultsGrid.ScrollBars = [System.Windows.Forms.ScrollBars]::Both

  $script:resultsGrid.BackgroundColor = [System.Drawing.Color]::White
  $script:resultsGrid.DefaultCellStyle.BackColor = [System.Drawing.Color]::White
  $script:resultsGrid.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Black
  $script:resultsGrid.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(220, 230, 255)
  $script:resultsGrid.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::Black

  $script:resultsGrid.Add_SelectionChanged({
      $anyEnabled = $false; $anyDisabled = $false
      foreach ($row in $script:resultsGrid.SelectedRows) {
        if ($row.Cells["EnabledInSfB"].Value -eq "Да") { $anyEnabled = $true } else { $anyDisabled = $true }
      }
      $script:disableButton.Enabled = $anyEnabled
      $script:enableButton.Enabled = $anyDisabled
    })

  $TabPage.Controls.Add($script:resultsGrid)
  $script:resultsGrid.BringToFront()
}


# Создание элементов для вкладки AD

# Создание элементов для вкладки AD
function New-ADTab {
  param($TabPage)

  $topPanel = New-Object System.Windows.Forms.Panel
  $topPanel.Dock = [System.Windows.Forms.DockStyle]::Top
  $topPanel.Height = 110
  $TabPage.Controls.Add($topPanel)

  $bottomPanel = New-Object System.Windows.Forms.Panel
  $bottomPanel.Dock = [System.Windows.Forms.DockStyle]::Bottom
  $bottomPanel.Height = 30
  $TabPage.Controls.Add($bottomPanel)

  $adHeaderLabel = New-Object System.Windows.Forms.Label
  $adSearchLabel = New-Object System.Windows.Forms.Label
  $script:adSearchTextBox = New-Object System.Windows.Forms.TextBox
  $script:adSearchButton = New-Object System.Windows.Forms.Button
  $script:addToSfBButton = New-Object System.Windows.Forms.Button
  $script:adStatusLabel = New-Object System.Windows.Forms.Label
  $script:adResultsGrid = New-Object System.Windows.Forms.DataGridView
  $adInfoLabel = New-Object System.Windows.Forms.Label
  $testADButton = New-Object System.Windows.Forms.Button

  $adHeaderLabel.Location = New-Object System.Drawing.Point(20, 15)
  $adHeaderLabel.Size = New-Object System.Drawing.Size(500, 25)
  $adHeaderLabel.Text = "Добавление пользователей из Active Directory"
  $adHeaderLabel.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
  $topPanel.Controls.Add($adHeaderLabel)

  $adSearchLabel.Location = New-Object System.Drawing.Point(20, 52)
  $adSearchLabel.Size = New-Object System.Drawing.Size(100, 20)
  $adSearchLabel.Text = "ФИО или логин:"
  $topPanel.Controls.Add($adSearchLabel)

  $script:adSearchTextBox.Location = New-Object System.Drawing.Point(120, 50)
  $script:adSearchTextBox.Size = New-Object System.Drawing.Size(200, 20)
  $script:adSearchTextBox.Add_KeyDown({
      if ($_.KeyCode -eq "Enter") { Search-ADUsers }
    })
  $topPanel.Controls.Add($script:adSearchTextBox)

  $script:adSearchButton.Location = New-Object System.Drawing.Point(330, 48)
  $script:adSearchButton.Size = New-Object System.Drawing.Size(100, 25)
  $script:adSearchButton.Text = "Найти в AD"
  $script:adSearchButton.Enabled = $false
  $script:adSearchButton.FlatStyle = [System.Windows.Forms.FlatStyle]::System
  $script:adSearchButton.Add_Click({ Search-ADUsers })
  $topPanel.Controls.Add($script:adSearchButton)

  $script:addToSfBButton.Location = New-Object System.Drawing.Point(440, 48)
  $script:addToSfBButton.Size = New-Object System.Drawing.Size(150, 25)
  $script:addToSfBButton.Text = "Добавить в SfB"
  $script:addToSfBButton.Enabled = $false
  $script:addToSfBButton.FlatStyle = [System.Windows.Forms.FlatStyle]::System
  $script:addToSfBButton.Add_Click({ Add-SelectedUsersToSfB })
  $topPanel.Controls.Add($script:addToSfBButton)

  $testADButton.Location = New-Object System.Drawing.Point(600, 48)
  $testADButton.Size = New-Object System.Drawing.Size(150, 25)
  $testADButton.Text = "Тест подключения к AD"
  $testADButton.FlatStyle = [System.Windows.Forms.FlatStyle]::System
  $testADButton.Add_Click({ Test-AllADMethods | Out-Null })
  $topPanel.Controls.Add($testADButton)

  $script:adStatusLabel.Location = New-Object System.Drawing.Point(20, 80)
  $script:adStatusLabel.Size = New-Object System.Drawing.Size(800, 20)
  $script:adStatusLabel.Text = "Подключение к серверу..."
  $topPanel.Controls.Add($script:adStatusLabel)

  $adInfoLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
  $adInfoLabel.Text = "Готово"
  $adInfoLabel.BorderStyle = "FixedSingle"
  $adInfoLabel.BackColor = [System.Drawing.Color]::LightGray
  $adInfoLabel.TextAlign = "MiddleLeft"
  $bottomPanel.Controls.Add($adInfoLabel)

  # ТАБЛИЦА
  $script:adResultsGrid.Dock = [System.Windows.Forms.DockStyle]::Fill
  $script:adResultsGrid.SelectionMode = "FullRowSelect"
  $script:adResultsGrid.ReadOnly = $true
  $script:adResultsGrid.AllowUserToAddRows = $false
  $script:adResultsGrid.RowHeadersVisible = $false
  $script:adResultsGrid.AllowUserToResizeRows = $false
  $script:adResultsGrid.AutoSizeRowsMode = [System.Windows.Forms.DataGridViewAutoSizeRowsMode]::None
  $script:adResultsGrid.ScrollBars = [System.Windows.Forms.ScrollBars]::Both

  $script:adResultsGrid.BackgroundColor = [System.Drawing.Color]::White
  $script:adResultsGrid.DefaultCellStyle.BackColor = [System.Drawing.Color]::White
  $script:adResultsGrid.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Black
  $script:adResultsGrid.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(220, 230, 255)
  $script:adResultsGrid.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::Black

  $script:adResultsGrid.Add_SelectionChanged({
      $script:addToSfBButton.Enabled = ($script:adResultsGrid.SelectedRows.Count -gt 0)
    })

  $TabPage.Controls.Add($script:adResultsGrid)
  $script:adResultsGrid.BringToFront()
}


# Создание элементов для вкладки Логи
function New-LogTab {
  param($TabPage)

  $topPanel = New-Object System.Windows.Forms.Panel
  $topPanel.Dock = [System.Windows.Forms.DockStyle]::Top
  $topPanel.Height = 50
  $TabPage.Controls.Add($topPanel)

  $bottomPanel = New-Object System.Windows.Forms.Panel
  $bottomPanel.Dock = [System.Windows.Forms.DockStyle]::Bottom
  $bottomPanel.Height = 40
  $TabPage.Controls.Add($bottomPanel)

  $headerLabel = New-Object System.Windows.Forms.Label
  $headerLabel.Location = New-Object System.Drawing.Point(20, 15)
  $headerLabel.Size = New-Object System.Drawing.Size(500, 25)
  $headerLabel.Text = "Логи выполнения"
  $headerLabel.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
  $topPanel.Controls.Add($headerLabel)

  # Поле логов
  $script:LogTextBox = New-Object System.Windows.Forms.RichTextBox
  $script:LogTextBox.Dock = [System.Windows.Forms.DockStyle]::Fill
  $script:LogTextBox.Multiline = $true
  $script:LogTextBox.ScrollBars = "Vertical"
  $script:LogTextBox.ReadOnly = $true
  $TabPage.Controls.Add($script:LogTextBox)
  $script:LogTextBox.BringToFront()

  # Кнопка закрытия
  $closeButton = New-Object System.Windows.Forms.Button
  $closeButton.Location = New-Object System.Drawing.Point(1000, 5)
  $closeButton.Size = New-Object System.Drawing.Size(120, 25)
  $closeButton.Text = "Закрыть"
  $closeButton.Anchor = "Bottom, Right"
  $closeButton.FlatStyle = [System.Windows.Forms.FlatStyle]::System
  $closeButton.Add_Click({
      Write-Log "Закрытие всех сессий..." "INFO"
      try {
        if ($Script:SfBSession) { Remove-PSSession $Script:SfBSession -ErrorAction SilentlyContinue }
        Get-PSSession | Where-Object {
          $_.ComputerName -like "*$($Script:Server)*" -or $_.ConnectionUri -like "*$($Script:Server)*"
        } | Remove-PSSession -ErrorAction SilentlyContinue
      }
      catch {}

      try { $TabPage.FindForm().Close() } catch {}
    })
  $bottomPanel.Controls.Add($closeButton)
}


# Функция поиска и проверки пользователей SfB
function Start-UserSearch {
  $searchText = $script:searchTextBox.Text.Trim()
    
  $script:searchButton.Enabled = $false
  $script:showAllButton.Enabled = $false
  $script:disableButton.Enabled = $false
  $script:enableButton.Enabled = $false
    
  if ([string]::IsNullOrWhiteSpace($searchText)) {
    $script:statusLabel.Text = "Поиск всех пользователей..."
    Write-Log "Запуск поиска всех пользователей SfB..." "INFO"
  }
  else {
    $script:statusLabel.Text = "Поиск пользователей SfB: $searchText..."
  }
    
  try {
    $sfbUsers = Find-SfBUsers -SearchText $searchText
        
    if ($null -eq $sfbUsers -or $sfbUsers.Count -eq 0) {
      $script:statusLabel.Text = "Пользователи не найдены"
      $script:resultsGrid.Rows.Clear()
      Update-StatusBar -Users @()
      Write-Log "Пользователи SfB не найдены" "WARNING"
      return
    }
        
    $Script:UserData = @()
    $counter = 0
    foreach ($user in $sfbUsers) {
      $counter++
      $Script:UserData += @{ Number = $counter; User = $user }
    }
        
    # Настройка колонок
    $script:resultsGrid.Columns.Clear()
    $script:resultsGrid.Columns.Add("DisplayName", "ФИО") | Out-Null
    $script:resultsGrid.Columns.Add("Login", "Логин") | Out-Null
    $script:resultsGrid.Columns.Add("Identity", "Identity") | Out-Null
    $script:resultsGrid.Columns.Add("EnabledInSfB", "Включен в SfB") | Out-Null
    $script:resultsGrid.Columns.Add("EnabledInAD", "Включен в AD") | Out-Null
    $script:resultsGrid.Columns.Add("Status", "Статус") | Out-Null
    $script:resultsGrid.Columns["Identity"].Visible = $false
        
    # Устанавливаем начальные ширины колонок
    $script:resultsGrid.Columns["DisplayName"].Width = 200
    $script:resultsGrid.Columns["Login"].Width = 120
    $script:resultsGrid.Columns["EnabledInSfB"].Width = 100
    $script:resultsGrid.Columns["EnabledInAD"].Width = 100
    $script:resultsGrid.Columns["Status"].AutoSizeMode = [System.Windows.Forms.DataGridViewAutoSizeColumnMode]::Fill
        
    $script:resultsGrid.Rows.Clear()
    $userStatuses = @()
    $adMap = @{}
    try {
      $adMap = Get-ADStatusMapBulk -SfBUsers $sfbUsers
    }
    catch {
      Write-Log "Bulk-поиск AD не сработал, будет медленнее: $($_.Exception.Message)" "WARNING"
    }
    foreach ($userData in $Script:UserData) {
      $user = $userData.User
      $userNumber = $userData.Number
            
      if ([string]::IsNullOrWhiteSpace($searchText)) {
        $script:statusLabel.Text = "Проверка $userNumber из $($sfbUsers.Count): $($user.DisplayName)"
      }
      else {
        $script:statusLabel.Text = "Проверка $userNumber из $($sfbUsers.Count)"
      }
            
      $upn = $user.UserPrincipalName
      if (-not $upn -and $user.SipAddress) { $upn = ($user.SipAddress -replace '^sip:') }

      $adStatus = $null
      if ($upn) { $adStatus = $adMap[$upn.ToLower()] }

      if (-not $adStatus) {
        $adStatus = [pscustomobject]@{
          EnabledInAD    = $false
          ExistsInAD     = $false
          LockedOut      = $false
          LastLogonDate  = $null
          SamAccountName = $null
          ADUser         = $null
        }
      }
      $userStatus = Get-UserStatus -SfBUser $user -ADStatus $adStatus
      $userLogin = Get-UserLogin -SfBUser $user -ADStatus $adStatus
      $userStatuses += @{ User = $user; Status = $userStatus; ADStatus = $adStatus }
            
      $row = New-Object System.Windows.Forms.DataGridViewRow
      $row.CreateCells($script:resultsGrid)
      $row.Cells[0].Value = $user.DisplayName
      $row.Cells[1].Value = $userLogin
      $row.Cells[2].Value = $user.Identity
      $row.Cells[3].Value = if ($user.Enabled) { "Да" } else { "Нет" }
      $row.Cells[4].Value = if ($adStatus.EnabledInAD) { "Да" } else { "Нет" }
      $row.Cells[5].Value = $userStatus
            
      if ($userStatus -eq "Активен") {
        $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Green
      }
      elseif ($userStatus -like "*Отклонение:*") {
        $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Red
      }
      elseif ($userStatus -like "*Заблокирован*" -or $userStatus -like "*Отключен*") {
        $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Orange
      }
      else {
        $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Black
      }
            
      $row.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(220, 230, 255)
      $row.DefaultCellStyle.SelectionForeColor = $row.DefaultCellStyle.ForeColor
            
      $script:resultsGrid.Rows.Add($row)
            
      if ($userNumber % 50 -eq 0) { [System.Windows.Forms.Application]::DoEvents() }
    }
        
    Update-StatusBarFast -UserStatuses $userStatuses
        
    if ([string]::IsNullOrWhiteSpace($searchText)) {
      $script:statusLabel.Text = "Все пользователи загружены. Найдено: $($sfbUsers.Count) пользователей"
      Write-Log "Загрузка всех пользователей SfB завершена. Всего: $($sfbUsers.Count)" "SUCCESS"
    }
    else {
      $script:statusLabel.Text = "Поиск завершен. Найдено: $($sfbUsers.Count) пользователей"
      Write-Log "Поиск пользователей SfB завершен. Найдено: $($sfbUsers.Count)" "SUCCESS"
    }
  }
  catch {
    Write-Log "Ошибка при поиске пользователей SfB: $($_.Exception.Message)" "ERROR"
    $script:statusLabel.Text = "Ошибка при поиске"
    Update-StatusBar -Users @()
  }
  finally {
    $script:searchButton.Enabled = $true
    $script:showAllButton.Enabled = $true
  }
}

# Функция поиска пользователей в AD
function Search-ADUsers {
  $searchText = $script:adSearchTextBox.Text.Trim()
  $script:adSearchButton.Enabled = $false
  $script:addToSfBButton.Enabled = $false
    
  try {
    $script:adStatusLabel.Text = "Поиск пользователей в AD..."
    [System.Windows.Forms.Application]::DoEvents()
        
    Write-Log "Начало поиска в AD: '$searchText'" "INFO"
        
    $adUsers = Find-ADUsersNotInSfB -SearchText $searchText
        
    if ($adUsers.Count -eq 0) {
      Write-Log "Пользователи в AD не найдены или все уже добавлены в SfB" "WARNING"
      $script:adStatusLabel.Text = "Пользователи не найдены или все уже добавлены в SfB"
    }
    else {
      Write-Log "Найдено пользователей для отображения: $($adUsers.Count)" "INFO"
      $script:adStatusLabel.Text = "Найдено пользователей в AD: $($adUsers.Count)"
    }
        
    Show-ADUsers -ADUsers $adUsers
  }
  catch {
    Write-Log "Ошибка при поиске в AD: $($_.Exception.Message)" "ERROR"
    $script:adStatusLabel.Text = "Ошибка при поиске в AD"
  }
  finally {
    $script:adSearchButton.Enabled = $true
  }
}

# Отображение пользователей AD
function Show-ADUsers {
  param($ADUsers)
    
  $script:adResultsGrid.Columns.Clear()
  $script:adResultsGrid.Rows.Clear()
    
  # Настройка колонок
  $script:adResultsGrid.Columns.Add("DisplayName", "ФИО") | Out-Null
  $script:adResultsGrid.Columns.Add("SamAccountName", "Логин") | Out-Null
  $script:adResultsGrid.Columns.Add("UserPrincipalName", "UPN") | Out-Null
  $script:adResultsGrid.Columns.Add("DistinguishedName", "DN") | Out-Null
  $script:adResultsGrid.Columns["DistinguishedName"].Visible = $false
    
  # Устанавливаем ширины колонок
  $script:adResultsGrid.Columns["DisplayName"].Width = 250
  $script:adResultsGrid.Columns["SamAccountName"].Width = 120
  $script:adResultsGrid.Columns["UserPrincipalName"].AutoSizeMode = [System.Windows.Forms.DataGridViewAutoSizeColumnMode]::Fill
    
  $Script:ADUserData = @()
  $counter = 0
    
  foreach ($user in $ADUsers) {
    $counter++
    $Script:ADUserData += @{ Number = $counter; User = $user }
        
    $row = New-Object System.Windows.Forms.DataGridViewRow
    $row.CreateCells($script:adResultsGrid)
    $row.Cells[0].Value = $user.DisplayName
    $row.Cells[1].Value = $user.SamAccountName
    $row.Cells[2].Value = $user.UserPrincipalName
    $row.Cells[3].Value = $user.DistinguishedName
        
    $script:adResultsGrid.Rows.Add($row)
        
    if ($counter % 50 -eq 0) { [System.Windows.Forms.Application]::DoEvents() }
  }
}

# Добавление выбранных пользователей в SfB
function Add-SelectedUsersToSfB {
  $selectedRows = $script:adResultsGrid.SelectedRows
    
  if ($selectedRows.Count -eq 0) {
    [System.Windows.Forms.MessageBox]::Show("Выберите пользователей для добавления в SfB!", "Ошибка", "OK", "Error")
    return
  }
    
  $userNames = @()
  foreach ($row in $selectedRows) { 
    $userNames += "$($row.Cells['DisplayName'].Value) ($($row.Cells['SamAccountName'].Value))"
  }
    
  $result = [System.Windows.Forms.MessageBox]::Show(
    "Добавить выбранных пользователей ($($selectedRows.Count)) в Skype for Business?`n`n$($userNames -join "`n")", 
    "Подтверждение добавления", "YesNo", "Question"
  )
    
  if ($result -eq "Yes") {
    $script:adSearchButton.Enabled = $false
    $script:addToSfBButton.Enabled = $false
        
    $successCount = 0
    $failedCount = 0
    $processedCount = 0
        
    foreach ($selectedRow in $selectedRows) {
      $processedCount++
      $userPrincipalName = $selectedRow.Cells["UserPrincipalName"].Value
      $displayName = $selectedRow.Cells["DisplayName"].Value
            
      # В функции Add-SelectedUsersToSfB обновим отображение имени пользователя:
      $script:adStatusLabel.Text = "Добавление $processedCount из $($selectedRows.Count): $displayName ($login)"
      [System.Windows.Forms.Application]::DoEvents()
            
      if (Add-UserToSfB -UserIdentity $userPrincipalName -RegistrarPool $Script:Server) {
        $successCount++
        # Помечаем строку как успешно добавленную
        $selectedRow.DefaultCellStyle.BackColor = [System.Drawing.Color]::LightGreen
      }
      else {
        $failedCount++
        # Помечаем строку как ошибку
        $selectedRow.DefaultCellStyle.BackColor = [System.Drawing.Color]::LightCoral
      }
    }
        
    if ($successCount -gt 0) {
      Write-Log "Успешно добавлено пользователей в SfB: $successCount" "SUCCESS"
    }
    if ($failedCount -gt 0) {
      Write-Log "Не удалось добавить пользователей в SfB: $failedCount" "WARNING"
    }
        
    $script:adStatusLabel.Text = "Добавление завершено. Успешно: $successCount, Ошибок: $failedCount"
    $script:adSearchButton.Enabled = $true
  }
}

# Быстрая функция обновления строки состояния
function Update-StatusBarFast {
  param($UserStatuses)
    
  if ($null -eq $UserStatuses -or $UserStatuses.Count -eq 0) {
    $script:statusBarLabel.Text = "Пользователи не найдены"
    return
  }
    
  $total = $UserStatuses.Count
  $activeCount = 0
  $deviationCount = 0
  $warningCount = 0
  $disabledCount = 0
  $disabledInSfBCount = 0
  $notFoundInADCount = 0
    
  foreach ($userStatus in $UserStatuses) {
    $status = $userStatus.Status
    if ($status -eq "Активен") { $activeCount++ }
    elseif ($status -like "*Отклонение:*") { $deviationCount++ }
    elseif ($status -like "*Отключен*" -and $status -notlike "*Отклонение:*") { $disabledCount++ }
    elseif ($status -like "*Отключен в SfB*") { $disabledInSfBCount++ }
    elseif ($status -like "*Не найден в AD*") { $notFoundInADCount++ }
    else { $warningCount++ }
  }
    
  $statusText = "Всего: $total"
  if ($activeCount -gt 0) { $statusText += " | Активны: $activeCount" }
  if ($deviationCount -gt 0) { $statusText += " | Отклонения: $deviationCount" }
  if ($warningCount -gt 0) { $statusText += " | Предупреждения: $warningCount" }
  if ($disabledCount -gt 0) { $statusText += " | Отключены: $disabledCount" }
  if ($disabledInSfBCount -gt 0) { $statusText += " | Отключены в SfB: $disabledInSfBCount" }
  if ($notFoundInADCount -gt 0) { $statusText += " | Не найдены в AD: $notFoundInADCount" }
    
  $script:statusBarLabel.Text = $statusText
}

# Функции отключения/включения пользователей SfB
function Disable-SelectedUser {
  $selectedRows = $script:resultsGrid.SelectedRows
    
  if ($selectedRows.Count -eq 0) {
    [System.Windows.Forms.MessageBox]::Show("Выберите пользователей для отключения!", "Ошибка", "OK", "Error")
    return
  }
    
  $userNames = @()
  foreach ($row in $selectedRows) { $userNames += $row.Cells["DisplayName"].Value }
    
  $result = [System.Windows.Forms.MessageBox]::Show(
    "Вы уверены, что хотите отключить в Skype for Business выбранных пользователей ($($selectedRows.Count))?`n`n$($userNames -join "`n")", 
    "Подтверждение отключения", "YesNo", "Question"
  )
    
  if ($result -eq "Yes") {
    $script:disableButton.Enabled = $false
    $script:enableButton.Enabled = $false
    $script:searchButton.Enabled = $false
    $script:showAllButton.Enabled = $false
        
    $successCount = 0; $failedCount = 0
        
    foreach ($selectedRow in $selectedRows) {
      $identity = $selectedRow.Cells["Identity"].Value
      $currentEnabledInAD = $selectedRow.Cells["EnabledInAD"].Value
            
      if (Set-SfBUserEnabled -UserIdentity $identity -Enabled $false) {
        $selectedRow.Cells["EnabledInSfB"].Value = "Нет"
                
        # ОБНОВЛЯЕМ СТАТУС НА ОСНОВЕ ДАННЫХ ИЗ ТАБЛИЦЫ
        $newStatus = ""
        $newColor = [System.Drawing.Color]::Orange
                
        if ($currentEnabledInAD -eq "Да") {
          $newStatus = "Отклонение: Включен в AD, Отключен в SfB"
          $newColor = [System.Drawing.Color]::Red
        }
        else {
          $newStatus = "Отключен"
          $newColor = [System.Drawing.Color]::Orange
        }
                
        $selectedRow.Cells["Status"].Value = $newStatus
                
        # ОБНОВЛЯЕМ ЦВЕТ ВСЕХ ЯЧЕЕК В СТРОКЕ И СТИЛЬ ВЫДЕЛЕНИЯ
        foreach ($cell in $selectedRow.Cells) {
          $cell.Style.ForeColor = $newColor
          $cell.Style.SelectionForeColor = $newColor
        }
                
        $successCount++
      }
      else {
        $failedCount++
      }
            
      $script:statusLabel.Text = "Отключено: $successCount из $($selectedRows.Count)"
      [System.Windows.Forms.Application]::DoEvents()
      Start-Sleep -Milliseconds 10
    }
        
    if ($failedCount -gt 0) { Write-Log "Не удалось отключить $failedCount пользователей" "WARNING" }
        
    # ОБНОВЛЯЕМ СТРОКУ СОСТОЯНИЯ
    Update-StatusBarAfterChange
    $script:statusLabel.Text = "Отключено пользователей: $successCount из $($selectedRows.Count)"
        
    $script:searchButton.Enabled = $true
    $script:showAllButton.Enabled = $true
  }
}

function Enable-SelectedUser {
  $selectedRows = $script:resultsGrid.SelectedRows
    
  if ($selectedRows.Count -eq 0) {
    [System.Windows.Forms.MessageBox]::Show("Выберите пользователей для включения!", "Ошибка", "OK", "Error")
    return
  }
    
  $userNames = @()
  foreach ($row in $selectedRows) { $userNames += $row.Cells["DisplayName"].Value }
    
  $result = [System.Windows.Forms.MessageBox]::Show(
    "Вы уверены, что хотите включить в Skype for Business выбранных пользователей ($($selectedRows.Count))?`n`n$($userNames -join "`n")", 
    "Подтверждение включения", "YesNo", "Question"
  )
    
  if ($result -eq "Yes") {
    $script:disableButton.Enabled = $false
    $script:enableButton.Enabled = $false
    $script:searchButton.Enabled = $false
    $script:showAllButton.Enabled = $false
        
    $successCount = 0; $failedCount = 0
        
    foreach ($selectedRow in $selectedRows) {
      $identity = $selectedRow.Cells["Identity"].Value
      $currentEnabledInAD = $selectedRow.Cells["EnabledInAD"].Value
            
      if (Set-SfBUserEnabled -UserIdentity $identity -Enabled $true) {
        $selectedRow.Cells["EnabledInSfB"].Value = "Да"
                
        # ОБНОВЛЯЕМ СТАТУС НА ОСНОВЕ ДАННЫХ ИЗ ТАБЛИЦЫ
        $newStatus = ""
        $newColor = [System.Drawing.Color]::Green
                
        if ($currentEnabledInAD -eq "Да") {
          $newStatus = "Активен"
          $newColor = [System.Drawing.Color]::Green
        }
        else {
          $newStatus = "Отклонение: Отключен в AD, Включен в SfB"
          $newColor = [System.Drawing.Color]::Red
        }
                
        $selectedRow.Cells["Status"].Value = $newStatus
                
        # ОБНОВЛЯЕМ ЦВЕТ ВСЕХ ЯЧЕЕК В СТРОКЕ И СТИЛЬ ВЫДЕЛЕНИЯ
        foreach ($cell in $selectedRow.Cells) {
          $cell.Style.ForeColor = $newColor
          $cell.Style.SelectionForeColor = $newColor
        }
                
        $successCount++
      }
      else {
        $failedCount++
      }
            
      $script:statusLabel.Text = "Включено: $successCount из $($selectedRows.Count)"
      [System.Windows.Forms.Application]::DoEvents()
      Start-Sleep -Milliseconds 10
    }
        
    if ($failedCount -gt 0) { Write-Log "Не удалось включить $failedCount пользователей" "WARNING" }
        
    # ОБНОВЛЯЕМ СТРОКУ СОСТОЯНИЯ
    Update-StatusBarAfterChange
    $script:statusLabel.Text = "Включено пользователей: $successCount из $($selectedRows.Count)"
        
    $script:searchButton.Enabled = $true
    $script:showAllButton.Enabled = $true
  }
}

# Функция обновления строки состояния после изменений
function Update-StatusBarAfterChange {
  # Быстрый подсчет по ВСЕЙ таблице, но без создания объектов пользователей
  $total = 0
  $activeCount = 0
  $disabledCount = 0
  $deviationCount = 0
  $otherCount = 0
    
  # Быстро проходим по всем строкам и считаем статусы
  foreach ($row in $script:resultsGrid.Rows) {
    if ($null -ne $row.Cells["Status"].Value -and $null -ne $row.Cells["DisplayName"].Value) {
      $total++
      $status = $row.Cells["Status"].Value
      switch -Wildcard ($status) {
        "Активен" { $activeCount++ }
        "Отключен" { $disabledCount++ }
        "Отклонение:*" { $deviationCount++ }
        default { $otherCount++ }
      }
    }
  }
    
  # Формируем полный текст статуса
  $statusText = "Всего: $total"
  if ($activeCount -gt 0) { $statusText += " | Активны: $activeCount" }
  if ($disabledCount -gt 0) { $statusText += " | Отключены: $disabledCount" }
  if ($deviationCount -gt 0) { $statusText += " | Отклонения: $deviationCount" }
  if ($otherCount -gt 0) { $statusText += " | Прочие: $otherCount" }
    
  $script:statusBarLabel.Text = $statusText
  Write-Log "Статистика обновлена: Всего $total, Активны: $activeCount, Отключены: $disabledCount, Отклонения: $deviationCount" "INFO"
}

# Запуск приложения
Write-Host "Запуск GUI для управления пользователями SfB..."
Write-Host "Автоматическое подключение к серверу $($Script:Server)..."

# Запускаем тест AD
$adMethod = Test-AllADMethods
if ($adMethod) {
  Write-Log "Для работы с AD будет использован метод: $adMethod" "SUCCESS"
}
else {
  Write-Log "Внимание: не удалось подключиться к AD. Функциональность поиска пользователей будет ограничена." "WARNING"
}

$mainForm = Show-MainForm

# Подключаемся к серверу
if (Connect-SfBServer) {
  $script:searchButton.Enabled = $true
  $script:showAllButton.Enabled = $true
  $script:adSearchButton.Enabled = $true
  $script:statusLabel.Text = "Подключено к $($Script:Server). Введите ФИО для поиска или нажмите 'Показать всех'."
  $script:adStatusLabel.Text = "Готово к поиску пользователей в AD"
  Write-Log "Приложение готово к работе" "SUCCESS"
}
else {
  $script:statusLabel.Text = "Ошибка подключения к серверу"
  $script:adStatusLabel.Text = "Ошибка подключения к серверу"
}

$mainForm.ShowDialog()