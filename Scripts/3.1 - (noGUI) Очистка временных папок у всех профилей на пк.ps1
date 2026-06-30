#requires -RunAsAdministrator

# === Настройки ===
$LogPath = "C:\Logs\Cleanup-Temp-NoGUI.log"
$TempAgeDays = 1

# === Создание папки логов ===
if (-not (Test-Path (Split-Path $LogPath -Parent))) {
    New-Item -ItemType Directory -Path (Split-Path $LogPath -Parent) -Force | Out-Null
}

# === Функция логирования ===
function Write-Log {
    param([string]$Message, [string]$Level = "Info")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] $Message"
    Add-Content -Path $LogPath -Value $LogEntry
    Write-Host $LogEntry
}

# === Вспомогательная функция для получения активных пользователей ===
function Get-ActiveUsersList {
    $ActiveUsers = @()
    try {
        $QUserOutput = quser 2>&1 | Out-String
        if ($QUserOutput -notmatch "No User exists" -and $QUserOutput -notmatch "Ошибка") {
            $lines = $QUserOutput -split "`r`n" | Where-Object { $_ -match '^\s*\>' -or ($_ -match '\s+\d+\s+' -and $_ -notmatch 'USERNAME') }
            foreach ($line in $lines) {
                $parts = $line -split '\s+'
                if ($parts.Count -gt 1) {
                    $login = $parts[1].Trim()
                    if ($login -and $login -notin @("USERNAME", ">")) {
                        $ActiveUsers += $login
                    }
                }
            }
        }
    } catch {}
    return $ActiveUsers
}

# === Функции очистки ===
function Clear-SystemTemp {
    $SystemTemp = "$env:SystemRoot\Temp"
    if (Test-Path $SystemTemp) {
        Write-Log "Проверка: $SystemTemp"
        $items = Get-ChildItem -Path $SystemTemp -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$TempAgeDays) }
        $count = 0
        foreach ($item in $items) {
            try { Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop; $count++ } catch {}
        }
        if ($count -gt 0) {
            Write-Log "✅ Удалено $count элементов из системной Temp"
        } else {
            Write-Log "ℹ️ Ничего не удалено из системной Temp"
        }
    } else {
        Write-Log "ℹ️ Папка системной Temp не найдена: $SystemTemp"
    }
}

function Clear-UserTemp {
    $ActiveUsers = Get-ActiveUsersList
    $UserDirs = Get-ChildItem -Path "C:\Users\*" -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @("Public", "Default", "All Users") }

    foreach ($UserDir in $UserDirs) {
        $AccountName = $UserDir.Name
        if ($ActiveUsers -contains $AccountName) {
            Write-Log "⚠️ Пропуск активной учётной записи: $AccountName"
            continue
        }

        $TempPath = Join-Path $UserDir.FullName "AppData\Local\Temp"
        if (Test-Path $TempPath) {
            Write-Log "Проверка: C:\Users\$AccountName\AppData\Local\Temp"
            $items = Get-ChildItem -Path $TempPath -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$TempAgeDays) }
            $count = 0
            foreach ($item in $items) {
                try { Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop; $count++ } catch {}
            }
            if ($count -gt 0) {
                Write-Log "✅ Удалено $count элементов из Temp учётной записи $AccountName"
            } else {
                Write-Log "ℹ️ Ничего не удалено из Temp учётной записи $AccountName"
            }
        } else {
            Write-Log "ℹ️ Папка Temp не найдена у учётной записи $AccountName"
        }
    }
}

function Clear-TSClientCache {
    $ActiveUsers = Get-ActiveUsersList
    $UserDirs = Get-ChildItem -Path "C:\Users\*" -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @("Public", "Default", "All Users") }

    foreach ($UserDir in $UserDirs) {
        $AccountName = $UserDir.Name
        if ($ActiveUsers -contains $AccountName) {
            Write-Log "⚠️ Пропуск активной учётной записи: $AccountName"
            continue
        }

        $TSPath = Join-Path $UserDir.FullName "AppData\Local\Microsoft\Terminal Server Client\Cache"
        if (Test-Path $TSPath) {
            Write-Log "Проверка: C:\Users\$AccountName\AppData\Local\Microsoft\Terminal Server Client\Cache"
            $items = Get-ChildItem -Path $TSPath -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$TempAgeDays) }
            $count = 0
            foreach ($item in $items) {
                try { Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop; $count++ } catch {}
            }
            if ($count -gt 0) {
                Write-Log "✅ Удалено $count элементов из TS Client Cache учётной записи $AccountName"
            } else {
                Write-Log "ℹ️ Ничего не удалено из TS Client Cache учётной записи $AccountName"
            }
        } else {
            Write-Log "ℹ️ Папка TS Client Cache не найдена у учётной записи $AccountName"
        }
    }
}

function Clear-WER {
    $ActiveUsers = Get-ActiveUsersList
    $UserDirs = Get-ChildItem -Path "C:\Users\*" -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @("Public", "Default", "All Users") }

    foreach ($UserDir in $UserDirs) {
        $AccountName = $UserDir.Name
        if ($ActiveUsers -contains $AccountName) {
            Write-Log "⚠️ Пропуск активной учётной записи: $AccountName"
            continue
        }

        $WERPath = Join-Path $UserDir.FullName "AppData\Local\Microsoft\Windows\WER"
        if (Test-Path $WERPath) {
            Write-Log "Проверка: C:\Users\$AccountName\AppData\Local\Microsoft\Windows\WER"
            $items = Get-ChildItem -Path $WERPath -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$TempAgeDays) }
            $count = 0
            foreach ($item in $items) {
                try { Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop; $count++ } catch {}
            }
            if ($count -gt 0) {
                Write-Log "✅ Удалено $count элементов из WER учётной записи $AccountName"
            } else {
                Write-Log "ℹ️ Ничего не удалено из WER учётной записи $AccountName"
            }
        } else {
            Write-Log "ℹ️ Папка WER не найдена у учётной записи $AccountName"
        }
    }
}

function Clear-AppCache {
    $ActiveUsers = Get-ActiveUsersList
    $UserDirs = Get-ChildItem -Path "C:\Users\*" -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @("Public", "Default", "All Users") }

    foreach ($UserDir in $UserDirs) {
        $AccountName = $UserDir.Name
        if ($ActiveUsers -contains $AccountName) {
            Write-Log "⚠️ Пропуск активной учётной записи: $AccountName"
            continue
        }

        $AppCachePath = Join-Path $UserDir.FullName "AppData\Local\Microsoft\Windows\AppCache"
        if (Test-Path $AppCachePath) {
            Write-Log "Проверка: C:\Users\$AccountName\AppData\Local\Microsoft\Windows\AppCache"
            $items = Get-ChildItem -Path $AppCachePath -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$TempAgeDays) }
            $count = 0
            foreach ($item in $items) {
                try { Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop; $count++ } catch {}
            }
            if ($count -gt 0) {
                Write-Log "✅ Удалено $count элементов из AppCache учётной записи $AccountName"
            } else {
                Write-Log "ℹ️ Ничего не удалено из AppCache учётной записи $AccountName"
            }
        } else {
            Write-Log "ℹ️ Папка AppCache не найдена у учётной записи $AccountName"
        }
    }
}

function Clear-CrashDumps {
    $ActiveUsers = Get-ActiveUsersList
    $UserDirs = Get-ChildItem -Path "C:\Users\*" -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @("Public", "Default", "All Users") }

    foreach ($UserDir in $UserDirs) {
        $AccountName = $UserDir.Name
        if ($ActiveUsers -contains $AccountName) {
            Write-Log "⚠️ Пропуск активной учётной записи: $AccountName"
            continue
        }

        $CrashPath = Join-Path $UserDir.FullName "AppData\Local\CrashDumps"
        if (Test-Path $CrashPath) {
            Write-Log "Проверка: C:\Users\$AccountName\AppData\Local\CrashDumps"
            $items = Get-ChildItem -Path $CrashPath -Recurse -Force -ErrorAction SilentlyContinue
            $count = 0
            foreach ($item in $items) {
                try { Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop; $count++ } catch {}
            }
            if ($count -gt 0) {
                Write-Log "✅ Удалено $count элементов из CrashDumps учётной записи $AccountName"
            } else {
                Write-Log "ℹ️ Ничего не удалено из CrashDumps учётной записи $AccountName"
            }
        } else {
            Write-Log "ℹ️ Папка CrashDumps не найдена у учётной записи $AccountName"
        }
    }
}

function Clear-ChromeCacheExtended {
    $ActiveUsers = Get-ActiveUsersList
    $UserDirs = Get-ChildItem -Path "C:\Users\*" -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @("Public", "Default", "All Users") }

    foreach ($UserDir in $UserDirs) {
        $AccountName = $UserDir.Name
        if ($ActiveUsers -contains $AccountName) {
            Write-Log "⚠️ Пропуск активной учётной записи: $AccountName"
            continue
        }

        $ChromePaths = @(
            "AppData\Local\Google\Chrome\User Data\Default\Cache",
            "AppData\Local\Google\Chrome\User Data\Default\Cache2\entries",
            "AppData\Local\Google\Chrome\User Data\Default\Cookies",
            "AppData\Local\Google\Chrome\User Data\Default\Media Cache",
            "AppData\Local\Google\Chrome\User Data\Default\Cookies-Journal"
        )

        foreach ($ChromePath in $ChromePaths) {
            $FullChromePath = Join-Path $UserDir.FullName $ChromePath
            if (Test-Path $FullChromePath) {
                Write-Log "Проверка Chrome: C:\Users\$AccountName\$ChromePath"
                $items = Get-ChildItem -Path $FullChromePath -Recurse -Force -ErrorAction SilentlyContinue |
                    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$TempAgeDays) }
                $count = 0
                foreach ($item in $items) {
                    try { Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop; $count++ } catch {}
                }
                if ($count -gt 0) {
                    Write-Log "✅ Удалено $count элементов из $ChromePath для учётной записи $AccountName"
                } else {
                    Write-Log "ℹ️ Ничего не удалено из $ChromePath для учётной записи $AccountName"
                }
            } else {
                Write-Log "ℹ️ Папка Chrome не найдена: C:\Users\$AccountName\$ChromePath"
            }
        }
    }
}

# === Основной блок выполнения ===
Write-Log "=== НАЧАЛО РАСШИРЕННОЙ ОЧИСТКИ ===" "Header"

Clear-SystemTemp
Clear-UserTemp
Clear-TSClientCache
Clear-WER
Clear-AppCache
Clear-CrashDumps
Clear-ChromeCacheExtended

Write-Log "=== РАСШИРЕННАЯ ОЧИСТКА ЗАВЕРШЕНА ===" "Header"