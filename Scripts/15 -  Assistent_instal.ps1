# 1. Где лежит PsExec на сервере
$psexecSource = "\\stepcon.ru\distr\!SOFT\Ассистент\PsExec64.exe"

# 2. Куда временно положить на вашем ПК (в папку Temp)
$psexecLocal  = "$env:TEMP\PsExec64.exe"

# 3. Копируем его к себе (если его там нет или он устарел)
Copy-Item $psexecSource $psexecLocal -Force

# 4. В скрипте используем уже локальный путь
$psexec = $psexecLocal 

# Запрашиваем имя или IP
$inputComputer = Read-Host "Введите имя или IP удаленного ПК"  # одно значение

# Формируем массив (на будущее удобно расширять)
$computers = @($inputComputer)

# Пути на шаре
$msiSource    = "\\stepcon.ru\distr\!SOFT\Ассистент\assistant_6.5-1_step_.msi"
$cfgSource    = "\\stepcon.ru\distr\!SOFT\Ассистент\assistant.acfg" # ВАШ ГОТОВЫЙ КОНФИГ

foreach ($c in $computers) {
    Write-Host "----------------------------------------"
    Write-Host "[$c] Проверка доступности..." -ForegroundColor Cyan
    
    if (Test-Connection -ComputerName $c -Count 1 -Quiet) {
        
        # --- ПРОВЕРКА НАЛИЧИЯ УСТАНОВЛЕННОЙ ВЕРСИИ ---
        $possiblePaths = @(
            "\\$c\C$\Program Files (x86)\Ассистент",
            "\\$c\C$\Program Files (x86)\Assistent",
            "\\$c\C$\Program Files (x86)\Assistant",
            "\\$c\C$\Program Files\Ассистент",
            "\\$c\C$\Program Files\Assistent",
            "\\$c\C$\Program Files\Assistant"
        )
        
        $isInstalled = $false
        foreach ($path in $possiblePaths) {
            if (Test-Path $path) {
                $isInstalled = $true
                break
            }
        }

        $doUninstall = $false
        $skipPC = $false

        if ($isInstalled) {
            Write-Host "[$c] ВНИМАНИЕ: На ПК уже обнаружена папка Ассистента!" -ForegroundColor Magenta
            $validInput = $false
            
            while (-not $validInput) {
                $ans = Read-Host "[$c] Выполнить деинсталляцию старой версии перед установкой? (Y - Да / N - Нет, ставить поверх / S - Пропустить ПК)"
                
                if ($ans -match '^[YyДд]') {
                    $doUninstall = $true
                    $validInput = $true
                } elseif ($ans -match '^[NnНн]') {
                    $doUninstall = $false
                    $validInput = $true
                    Write-Host "[$c] Деинсталляция отменена, установка будет выполнена поверх." -ForegroundColor Yellow
                } elseif ($ans -match '^[SsПп]') {
                    Write-Host "[$c] Установка на этот ПК отменена пользователем." -ForegroundColor Yellow
                    $skipPC = $true
                    $validInput = $true
                }
            }
        }

        if ($skipPC) { continue }

        Write-Host "[$c] Подготовка..." -ForegroundColor Yellow
        $remoteTempPath = "\\$c\C$\Temp"
        if (-not (Test-Path $remoteTempPath)) {
            try { New-Item -ItemType Directory -Path $remoteTempPath -Force | Out-Null }
            catch { Write-Host "[$c] ОШИБКА создания папки C:\Temp" -ForegroundColor Red; continue }
        }
        
        Write-Host "[$c] Копирование файлов..." -ForegroundColor Yellow
        try {
            Copy-Item $msiSource "$remoteTempPath\assistant.msi" -Force -ErrorAction Stop
            Copy-Item $cfgSource "$remoteTempPath\assistant.acfg" -Force -ErrorAction Stop
        }
        catch { Write-Host "[$c] ОШИБКА копирования: $($_.Exception.Message)" -ForegroundColor Red; continue }

        # --- ДИНАМИЧЕСКАЯ ГЕНЕРАЦИЯ PS1 СКРИПТА ---
        $remoteScriptContent = @"
`$ErrorActionPreference = 'Continue'

Write-Output '[1/7] Настройка приоритета сети (Wi-Fi > Ethernet)...'
# Находим активные Wi-Fi адаптеры и ставим им низкую метрику (высокий приоритет)
Get-NetIPInterface -AddressFamily IPv4 | Where-Object { `$_.InterfaceAlias -match 'Беспроводн|Wi-Fi|Wireless' } | Set-NetIPInterface -InterfaceMetric 10 -ErrorAction SilentlyContinue
# Находим проводные подключения и ставим им метрику ниже
Get-NetIPInterface -AddressFamily IPv4 | Where-Object { `$_.InterfaceAlias -match 'Ethernet|Подключение по локальной сети' } | Set-NetIPInterface -InterfaceMetric 50 -ErrorAction SilentlyContinue

Write-Output '[1.5] Проверка связи с серверами Ассистента...'
# Пингуем один из серверов авторизации из вашего лога
if (Test-Connection -ComputerName "195.239.29.61" -Count 2 -Quiet) {
    Write-Output 'УСПЕХ: Интернет есть, сервер Ассистента доступен!'
} else {
    Write-Output 'ВНИМАНИЕ: Сервер Ассистента НЕ пингуется! Программа установится, но может не подключиться к организации.'
}


Write-Output '[2/7] Остановка служб и зависших процессов...'
Get-Process -Name 'ast_service','assistant','msiexec' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Stop-Service -Name AstService -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

"@

        if ($doUninstall) {
            $remoteScriptContent += @"
Write-Output '[3/7] Деинсталляция старых версий...'
`$uninstallPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
`$apps = Get-ItemProperty -Path `$uninstallPaths -ErrorAction SilentlyContinue | Where-Object { 
    `$_.DisplayName -match 'Ассистент|Assistent|Assistant' 
}

foreach (`$app in `$apps) {
    if (`$app.UninstallString -match 'msiexec') {
        `$productCode = `$app.PSChildName
        Write-Output `"Удаление версии `$(`$app.DisplayName) (`$productCode)...`"
        cmd.exe /c `"start /wait msiexec.exe /x `$productCode /qn /norestart`"
    }
}
Start-Sleep -Seconds 3

Write-Output '[4/7] Глубокая зачистка системы...'
sc.exe delete AstService >nul 2>&1
# Удаляем хвосты из реестра, чтобы не было ошибки "Нельзя установить старую версию поверх новой"
reg delete `"HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{D6D988BF-9272-4F81-ABD5-ACE63F4EBE3E}`" /f >nul 2>&1
reg delete `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{D6D988BF-9272-4F81-ABD5-ACE63F4EBE3E}`" /f >nul 2>&1
reg delete `"HKCR\Installer\Products\FB889D6D272918F4BA5DCA6EF3E4EBE3`" /f >nul 2>&1

# Удаляем папки установки
`$candidateDirs = @(
  'C:\Program Files (x86)\Ассистент', 'C:\Program Files (x86)\Assistent', 'C:\Program Files (x86)\Assistant',
  'C:\Program Files\Ассистент', 'C:\Program Files\Assistent', 'C:\Program Files\Assistant'
)
foreach (`$d in `$candidateDirs) {
  if (Test-Path -LiteralPath `$d) {
    Remove-Item -LiteralPath `$d -Recurse -Force -ErrorAction SilentlyContinue
  }
}
"@
        } else {
            $remoteScriptContent += "Write-Output '[3/7] Деинсталляция пропущена пользователем...'\n"
            $remoteScriptContent += "Write-Output '[4/7] Зачистка системы пропущена...'\n"
        }

        $remoteScriptContent += @"

Write-Output '[5/7] Установка MSI...'
cmd.exe /c `"start /wait msiexec.exe /i C:\Temp\assistant.msi /qn /norestart /l*v C:\Temp\assistant_install.log`"

Write-Output '[6/7] Копирование конфигурации...'
`$folderWait = 0
`$installDirs = @(
  'C:\Program Files (x86)\Ассистент', 'C:\Program Files (x86)\Assistent', 'C:\Program Files (x86)\Assistant',
  'C:\Program Files\Ассистент', 'C:\Program Files\Assistent', 'C:\Program Files\Assistant'
)

while (`$folderWait -lt 30 -and -not (`$installDirs | Where-Object { Test-Path -LiteralPath `$_ })) {
  Start-Sleep -Seconds 2
  `$folderWait += 2
}

`$targetDir = `$installDirs | Where-Object { Test-Path -LiteralPath `$_ } | Select-Object -First 1
if (`$null -eq `$targetDir) {
  Write-Output 'ОШИБКА: Папка установки не найдена! Установка прервалась.'
} else {
  Copy-Item -Path 'C:\Temp\assistant.acfg' -Destination (Join-Path `$targetDir 'assistant.acfg') -Force
  Write-Output `"Конфиг успешно скопирован в `$targetDir`"
}

Write-Output '[7/7] Перезапуск службы...'
sc.exe stop AstService >nul 2>&1
Start-Sleep -Seconds 3
if (Get-Service -Name AstService -ErrorAction SilentlyContinue) {
  Restart-Service -Name AstService -Force
  Write-Output 'Служба успешно перезапущена. Ассистент готов к работе.'
} else {
  Write-Output 'ОШИБКА: Служба AstService не найдена!'
}
"@

        # Записываем PS1-скрипт на удаленный диск (Используем UTF8 с BOM для поддержки кириллицы)
        $remoteScriptContent | Out-File -FilePath "$remoteTempPath\deploy_assistant.ps1" -Encoding UTF8 -Force

        Write-Host "[$c] Запуск удаленного скрипта от имени SYSTEM..." -ForegroundColor Yellow
        
        # Запускаем PS1 через PsExec (ключ -s обязателен для обхода UAC и тихой установки)
        $cmd = "`"$psexec`" \\$c -s -accepteula cmd.exe /c `"echo . | powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Temp\deploy_assistant.ps1`""
        
        # Выводим логи выполнения
        $result = cmd.exe /c $cmd 2>&1 | ForEach-Object { "$_" }
        $result | ForEach-Object { Write-Host "    [PsExec] $_" -ForegroundColor Gray }

        Write-Host "[$c] ГОТОВО." -ForegroundColor Green
    } else {
        Write-Host "[$c] Недоступен." -ForegroundColor Red
    }
}
