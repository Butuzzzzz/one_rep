# 1. Создаем папку для модулей
$ModulePath = "C:\temp\PSModules"
if (!(Test-Path $ModulePath)) { New-Item -ItemType Directory -Path $ModulePath }

# ==========================================
# ЭКСПОРТ EXCHANGE (Server: spbhdqsrv073)
# ==========================================
Write-Host "Подключение к Exchange..." -ForegroundColor Cyan
$exchSession = New-PSSession -ConfigurationName Microsoft.Exchange `
    -ConnectionUri "http://spbhdqsrv073.stepcon.ru/PowerShell/" `
    -Authentication Kerberos `
    -ErrorAction Stop

Write-Host "Экспорт команд Exchange в файл..." -ForegroundColor Cyan
# Сохраняем модуль с именем 'RemoteExchange'
Export-PSSession -Session $exchSession `
    -OutputModule "$ModulePath\RemoteExchange" `
    -AllowClobber -Force

Remove-PSSession $exchSession

# ==========================================
# ЭКСПОРТ SFB (Server: spbhdqsrv023)
# ==========================================
Write-Host "Подключение к Skype for Business..." -ForegroundColor Cyan
$sfbOptions = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
$sfbSession = New-PSSession -ConnectionUri "https://spbhdqsrv023.stepcon.ru/OcsPowershell" `
    -SessionOption $sfbOptions `
    -Authentication Negotiate `
    -ErrorAction Stop

Write-Host "Экспорт команд SfB в файл..." -ForegroundColor Cyan
# Сохраняем модуль с именем 'RemoteSfB'
Export-PSSession -Session $sfbSession `
    -OutputModule "$ModulePath\RemoteSfB" `
    -AllowClobber -Force

Remove-PSSession $sfbSession

Write-Host "Готово! Модули лежат в $ModulePath" -ForegroundColor Green
