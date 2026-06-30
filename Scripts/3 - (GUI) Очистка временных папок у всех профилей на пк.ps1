#requires -RunAsAdministrator
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# === Настройки ===
$LogPath = "C:\Logs\Cleanup-Temp-Advanced-Resizable-GUI-Verbose.log"
$TempAgeDays = 1

# === Создание GUI ===
$form = New-Object System.Windows.Forms.Form
$form.Text = "Расширенная очистка RDP-сервера"
$form.Size = New-Object System.Drawing.Size(820, 800)
$form.StartPosition = "CenterScreen"
$form.MaximizeBox = $true
$form.MinimizeBox = $true
$form.SizeGripStyle = "Show"

# Label заголовка
$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(10, 10)
$label.Size = New-Object System.Drawing.Size(760, 20)
$label.Text = "Выберите типы очистки:"
$label.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($label)

# Checkbox'ы
$cbSystemTemp = New-Object System.Windows.Forms.CheckBox
$cbSystemTemp.Location = New-Object System.Drawing.Point(10, 40)
$cbSystemTemp.Size = New-Object System.Drawing.Size(300, 20)
$cbSystemTemp.Text = "Системная Temp (C:\Windows\Temp)"
$cbSystemTemp.Checked = $true
$form.Controls.Add($cbSystemTemp)

$cbUserTemp = New-Object System.Windows.Forms.CheckBox
$cbUserTemp.Location = New-Object System.Drawing.Point(10, 65)
$cbUserTemp.Size = New-Object System.Drawing.Size(300, 20)
$cbUserTemp.Text = "Пользовательские Temp"
$cbUserTemp.Checked = $true
$form.Controls.Add($cbUserTemp)

$cbChrome = New-Object System.Windows.Forms.CheckBox
$cbChrome.Location = New-Object System.Drawing.Point(10, 90)
$cbChrome.Size = New-Object System.Drawing.Size(300, 20)
$cbChrome.Text = "Кэш Chrome"
$cbChrome.Checked = $true
$form.Controls.Add($cbChrome)

$cbFirefox = New-Object System.Windows.Forms.CheckBox
$cbFirefox.Location = New-Object System.Drawing.Point(10, 115)
$cbFirefox.Size = New-Object System.Drawing.Size(300, 20)
$cbFirefox.Text = "Кэш Firefox"
$cbFirefox.Checked = $true
$form.Controls.Add($cbFirefox)

$cbEdge = New-Object System.Windows.Forms.CheckBox
$cbEdge.Location = New-Object System.Drawing.Point(10, 140)
$cbEdge.Size = New-Object System.Drawing.Size(300, 20)
$cbEdge.Text = "Кэш Edge"
$cbEdge.Checked = $true
$form.Controls.Add($cbEdge)

$cbOffice = New-Object System.Windows.Forms.CheckBox
$cbOffice.Location = New-Object System.Drawing.Point(10, 165)
$cbOffice.Size = New-Object System.Drawing.Size(300, 20)
$cbOffice.Text = "Кэш Office"
$cbOffice.Checked = $true
$form.Controls.Add($cbOffice)

$cbUpdates = New-Object System.Windows.Forms.CheckBox
$cbUpdates.Location = New-Object System.Drawing.Point(10, 190)
$cbUpdates.Size = New-Object System.Drawing.Size(300, 20)
$cbUpdates.Text = "Старые обновления Windows"
$cbUpdates.Checked = $false
$form.Controls.Add($cbUpdates)

$cbPrefetch = New-Object System.Windows.Forms.CheckBox
$cbPrefetch.Location = New-Object System.Drawing.Point(10, 215)
$cbPrefetch.Size = New-Object System.Drawing.Size(300, 20)
$cbPrefetch.Text = "Prefetch"
$cbPrefetch.Checked = $false
$form.Controls.Add($cbPrefetch)

# === Новые чекбоксы из примера ===
$cbTSClientCache = New-Object System.Windows.Forms.CheckBox
$cbTSClientCache.Location = New-Object System.Drawing.Point(320, 40)
$cbTSClientCache.Size = New-Object System.Drawing.Size(400, 20)
$cbTSClientCache.Text = "TS Client Cache (RDP)"
$cbTSClientCache.Checked = $true
$form.Controls.Add($cbTSClientCache)

$cbWER = New-Object System.Windows.Forms.CheckBox
$cbWER.Location = New-Object System.Drawing.Point(320, 65)
$cbWER.Size = New-Object System.Drawing.Size(400, 20)
$cbWER.Text = "Windows Error Reporting (WER)"
$cbWER.Checked = $true
$form.Controls.Add($cbWER)

$cbAppCache = New-Object System.Windows.Forms.CheckBox
$cbAppCache.Location = New-Object System.Drawing.Point(320, 90)
$cbAppCache.Size = New-Object System.Drawing.Size(400, 20)
$cbAppCache.Text = "Windows AppCache"
$cbAppCache.Checked = $true
$form.Controls.Add($cbAppCache)

$cbCrashDumps = New-Object System.Windows.Forms.CheckBox
$cbCrashDumps.Location = New-Object System.Drawing.Point(320, 115)
$cbCrashDumps.Size = New-Object System.Drawing.Size(400, 20)
$cbCrashDumps.Text = "Crash Dumps"
$cbCrashDumps.Checked = $true
$form.Controls.Add($cbCrashDumps)

$cbChromeCache = New-Object System.Windows.Forms.CheckBox
$cbChromeCache.Location = New-Object System.Drawing.Point(320, 140)
$cbChromeCache.Size = New-Object System.Drawing.Size(400, 20)
$cbChromeCache.Text = "Chrome: Cache, Cookies, Media Cache"
$cbChromeCache.Checked = $true
$form.Controls.Add($cbChromeCache)

# RichTextBox для лога — с изменяемым размером
$richTextBox = New-Object System.Windows.Forms.RichTextBox
$richTextBox.Location = New-Object System.Drawing.Point(10, 250)
$richTextBox.Size = New-Object System.Drawing.Size(780, 400)
$richTextBox.ReadOnly = $true
$richTextBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$richTextBox.BackColor = [System.Drawing.Color]::Black
$richTextBox.ForeColor = [System.Drawing.Color]::White
$richTextBox.Anchor = "Top, Bottom, Left, Right"
$form.Controls.Add($richTextBox)

# Кнопка запуска — прижата к низу
$button = New-Object System.Windows.Forms.Button
$button.Location = New-Object System.Drawing.Point(330, 670)
$button.Size = New-Object System.Drawing.Size(160, 40)
$button.Text = "Запустить очистку"
$button.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$button.Anchor = "Bottom, Left, Right"
$form.Controls.Add($button)

# === Функция цветного логирования ===
function Write-ColoredLog {
    param(
        [hashtable[]]$Fragments
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $plainText = "[$Timestamp] " + ($Fragments | ForEach-Object { $_.Text }) -join ""

    if (-not (Test-Path (Split-Path $LogPath -Parent))) {
        New-Item -ItemType Directory -Path (Split-Path $LogPath -Parent) -Force | Out-Null
    }
    Add-Content -Path $LogPath -Value $plainText

    $richTextBox.SelectionStart = $richTextBox.TextLength
    $richTextBox.SelectionLength = 0
    $richTextBox.SelectionColor = [System.Drawing.Color]::White
    $richTextBox.AppendText("[$Timestamp] ")

    foreach ($frag in $Fragments) {
        $color = switch ($frag.Color) {
            "User"      { [System.Drawing.Color]::Gold }
            "Path"      { [System.Drawing.Color]::LightCyan }
            "Success"   { [System.Drawing.Color]::LightGreen }
            "Warning"   { [System.Drawing.Color]::Yellow }
            "Error"     { [System.Drawing.Color]::Red }
            "Header"    { [System.Drawing.Color]::Cyan }
            default     { [System.Drawing.Color]::White }
        }
        $richTextBox.SelectionStart = $richTextBox.TextLength
        $richTextBox.SelectionLength = 0
        $richTextBox.SelectionColor = $color
        $richTextBox.AppendText($frag.Text)
    }
    $richTextBox.AppendText("`r`n")
    $richTextBox.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
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

# === Функции очистки (теперь с подробным логированием) ===
function Clear-SystemTemp {
    $SystemTemp = "$env:SystemRoot\Temp"
    if (Test-Path $SystemTemp) {
        Write-ColoredLog -Fragments @(@{Text="Проверка: "; Color="White"}, @{Text=$SystemTemp; Color="Path"})
        $items = Get-ChildItem -Path $SystemTemp -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$TempAgeDays) }
        $count = 0
        foreach ($item in $items) {
            try { Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop; $count++ } catch {}
        }
        if ($count -gt 0) {
            Write-ColoredLog -Fragments @(@{Text="✅ Удалено $count элементов из системной Temp"; Color="Success"})
        } else {
            Write-ColoredLog -Fragments @(@{Text="ℹ️ Ничего не удалено из системной Temp"; Color="Warning"})
        }
    } else {
        Write-ColoredLog -Fragments @(@{Text="ℹ️ Папка системной Temp не найдена: $SystemTemp"; Color="Warning"})
    }
}

function Clear-UserTemp {
    $ActiveUsers = Get-ActiveUsersList
    $UserDirs = Get-ChildItem -Path "C:\Users\*" -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @("Public", "Default", "All Users") }

    foreach ($UserDir in $UserDirs) {
        $AccountName = $UserDir.Name
        if ($ActiveUsers -contains $AccountName) {
            Write-ColoredLog -Fragments @(@{Text="⚠️ Пропуск активной учётной записи "; Color="White"}, @{Text=$AccountName; Color="User"})
            continue
        }

        $TempPath = Join-Path $UserDir.FullName "AppData\Local\Temp"
        if (Test-Path $TempPath) {
            Write-ColoredLog -Fragments @(
                @{Text="Проверка: C:\Users\"; Color="White"},
                @{Text=$AccountName; Color="User"},
                @{Text="\AppData\Local\Temp"; Color="White"}
            )
            $items = Get-ChildItem -Path $TempPath -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$TempAgeDays) }
            $count = 0
            foreach ($item in $items) {
                try { Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop; $count++ } catch {}
            }
            if ($count -gt 0) {
                Write-ColoredLog -Fragments @(
                    @{Text="✅ Удалено $count элементов из профиля учётной записи "; Color="Success"},
                    @{Text=$AccountName; Color="User"}
                )
            } else {
                Write-ColoredLog -Fragments @(
                    @{Text="ℹ️ Ничего не удалено из Temp учётной записи "; Color="Warning"},
                    @{Text=$AccountName; Color="User"}
                )
            }
        } else {
            Write-ColoredLog -Fragments @(
                @{Text="ℹ️ Папка Temp не найдена у учётной записи "; Color="Warning"},
                @{Text=$AccountName; Color="User"}
            )
        }
    }
}

# === НОВЫЕ ФУНКЦИИ С ПОДРОБНЫМ ЛОГИРОВАНИЕМ ===
function Clear-TSClientCache {
    $ActiveUsers = Get-ActiveUsersList
    $UserDirs = Get-ChildItem -Path "C:\Users\*" -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @("Public", "Default", "All Users") }

    foreach ($UserDir in $UserDirs) {
        $AccountName = $UserDir.Name
        if ($ActiveUsers -contains $AccountName) {
            Write-ColoredLog -Fragments @(@{Text="⚠️ Пропуск активной учётной записи "; Color="White"}, @{Text=$AccountName; Color="User"})
            continue
        }

        $TSPath = Join-Path $UserDir.FullName "AppData\Local\Microsoft\Terminal Server Client\Cache"
        if (Test-Path $TSPath) {
            Write-ColoredLog -Fragments @(
                @{Text="Проверка: C:\Users\"; Color="White"},
                @{Text=$AccountName; Color="User"},
                @{Text="\AppData\Local\Microsoft\Terminal Server Client\Cache"; Color="White"}
            )
            $items = Get-ChildItem -Path $TSPath -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$TempAgeDays) }
            $count = 0
            foreach ($item in $items) {
                try { Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop; $count++ } catch {}
            }
            if ($count -gt 0) {
                Write-ColoredLog -Fragments @(
                    @{Text="✅ Удалено $count элементов из TS Client Cache учётной записи "; Color="Success"},
                    @{Text=$AccountName; Color="User"}
                )
            } else {
                Write-ColoredLog -Fragments @(
                    @{Text="ℹ️ Ничего не удалено из TS Client Cache учётной записи "; Color="Warning"},
                    @{Text=$AccountName; Color="User"}
                )
            }
        } else {
            Write-ColoredLog -Fragments @(
                @{Text="ℹ️ Папка TS Client Cache не найдена у учётной записи "; Color="Warning"},
                @{Text=$AccountName; Color="User"}
            )
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
            Write-ColoredLog -Fragments @(@{Text="⚠️ Пропуск активной учётной записи "; Color="White"}, @{Text=$AccountName; Color="User"})
            continue
        }

        $WERPath = Join-Path $UserDir.FullName "AppData\Local\Microsoft\Windows\WER"
        if (Test-Path $WERPath) {
            Write-ColoredLog -Fragments @(
                @{Text="Проверка: C:\Users\"; Color="White"},
                @{Text=$AccountName; Color="User"},
                @{Text="\AppData\Local\Microsoft\Windows\WER"; Color="White"}
            )
            $items = Get-ChildItem -Path $WERPath -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$TempAgeDays) }
            $count = 0
            foreach ($item in $items) {
                try { Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop; $count++ } catch {}
            }
            if ($count -gt 0) {
                Write-ColoredLog -Fragments @(
                    @{Text="✅ Удалено $count элементов из WER учётной записи "; Color="Success"},
                    @{Text=$AccountName; Color="User"}
                )
            } else {
                Write-ColoredLog -Fragments @(
                    @{Text="ℹ️ Ничего не удалено из WER учётной записи "; Color="Warning"},
                    @{Text=$AccountName; Color="User"}
                )
            }
        } else {
            Write-ColoredLog -Fragments @(
                @{Text="ℹ️ Папка WER не найдена у учётной записи "; Color="Warning"},
                @{Text=$AccountName; Color="User"}
            )
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
            Write-ColoredLog -Fragments @(@{Text="⚠️ Пропуск активной учётной записи "; Color="White"}, @{Text=$AccountName; Color="User"})
            continue
        }

        $AppCachePath = Join-Path $UserDir.FullName "AppData\Local\Microsoft\Windows\AppCache"
        if (Test-Path $AppCachePath) {
            Write-ColoredLog -Fragments @(
                @{Text="Проверка: C:\Users\"; Color="White"},
                @{Text=$AccountName; Color="User"},
                @{Text="\AppData\Local\Microsoft\Windows\AppCache"; Color="White"}
            )
            $items = Get-ChildItem -Path $AppCachePath -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$TempAgeDays) }
            $count = 0
            foreach ($item in $items) {
                try { Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop; $count++ } catch {}
            }
            if ($count -gt 0) {
                Write-ColoredLog -Fragments @(
                    @{Text="✅ Удалено $count элементов из AppCache учётной записи "; Color="Success"},
                    @{Text=$AccountName; Color="User"}
                )
            } else {
                Write-ColoredLog -Fragments @(
                    @{Text="ℹ️ Ничего не удалено из AppCache учётной записи "; Color="Warning"},
                    @{Text=$AccountName; Color="User"}
                )
            }
        } else {
            Write-ColoredLog -Fragments @(
                @{Text="ℹ️ Папка AppCache не найдена у учётной записи "; Color="Warning"},
                @{Text=$AccountName; Color="User"}
            )
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
            Write-ColoredLog -Fragments @(@{Text="⚠️ Пропуск активной учётной записи "; Color="White"}, @{Text=$AccountName; Color="User"})
            continue
        }

        $CrashPath = Join-Path $UserDir.FullName "AppData\Local\CrashDumps"
        if (Test-Path $CrashPath) {
            Write-ColoredLog -Fragments @(
                @{Text="Проверка: C:\Users\"; Color="White"},
                @{Text=$AccountName; Color="User"},
                @{Text="\AppData\Local\CrashDumps"; Color="White"}
            )
            $items = Get-ChildItem -Path $CrashPath -Recurse -Force -ErrorAction SilentlyContinue
            $count = 0
            foreach ($item in $items) {
                try { Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop; $count++ } catch {}
            }
            if ($count -gt 0) {
                Write-ColoredLog -Fragments @(
                    @{Text="✅ Удалено $count элементов из CrashDumps учётной записи "; Color="Success"},
                    @{Text=$AccountName; Color="User"}
                )
            } else {
                Write-ColoredLog -Fragments @(
                    @{Text="ℹ️ Ничего не удалено из CrashDumps учётной записи "; Color="Warning"},
                    @{Text=$AccountName; Color="User"}
                )
            }
        } else {
            Write-ColoredLog -Fragments @(
                @{Text="ℹ️ Папка CrashDumps не найдена у учётной записи "; Color="Warning"},
                @{Text=$AccountName; Color="User"}
            )
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
            Write-ColoredLog -Fragments @(@{Text="⚠️ Пропуск активной учётной записи "; Color="White"}, @{Text=$AccountName; Color="User"})
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
                Write-ColoredLog -Fragments @(
                    @{Text="Проверка Chrome: C:\Users\"; Color="White"},
                    @{Text=$AccountName; Color="User"},
                    @{Text="\$ChromePath"; Color="White"}
                )
                $items = Get-ChildItem -Path $FullChromePath -Recurse -Force -ErrorAction SilentlyContinue |
                    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$TempAgeDays) }
                $count = 0
                foreach ($item in $items) {
                    try { Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop; $count++ } catch {}
                }
                if ($count -gt 0) {
                    Write-ColoredLog -Fragments @(
                        @{Text="✅ Удалено $count элементов из "; Color="Success"},
                        @{Text="$ChromePath для учётной записи "; Color="Path"},
                        @{Text=$AccountName; Color="User"}
                    )
                } else {
                    Write-ColoredLog -Fragments @(
                        @{Text="ℹ️ Ничего не удалено из "; Color="Warning"},
                        @{Text="$ChromePath для учётной записи "; Color="Path"},
                        @{Text=$AccountName; Color="User"}
                    )
                }
            } else {
                Write-ColoredLog -Fragments @(
                    @{Text="ℹ️ Папка Chrome не найдена: C:\Users\"; Color="Warning"},
                    @{Text=$AccountName; Color="User"},
                    @{Text="\$ChromePath"; Color="Path"}
                )
            }
        }
    }
}

# === Обработчик кнопки ===
$button.Add_Click({
    $button.Enabled = $false
    $button.Text = "Выполняется..."
    $button.BackColor = [System.Drawing.Color]::LightGray

    Write-ColoredLog -Fragments @(@{Text="=== НАЧАЛО РАСШИРЕННОЙ ОЧИСТКИ ==="; Color="Header"})

    if ($cbSystemTemp.Checked) { Clear-SystemTemp }
    if ($cbUserTemp.Checked) { Clear-UserTemp }
    if ($cbTSClientCache.Checked) { Clear-TSClientCache }
    if ($cbWER.Checked) { Clear-WER }
    if ($cbAppCache.Checked) { Clear-AppCache }
    if ($cbCrashDumps.Checked) { Clear-CrashDumps }
    if ($cbChromeCache.Checked) { Clear-ChromeCacheExtended }

    Write-ColoredLog -Fragments @(@{Text="=== РАСШИРЕННАЯ ОЧИСТКА ЗАВЕРШЕНА ==="; Color="Header"})
    [System.Windows.Forms.MessageBox]::Show("Очистка завершена!`nЛог сохранён в:`n$LogPath", "Готово", "OK", "Information")

    $button.Text = "Запустить очистку"
    $button.Enabled = $true
    $button.BackColor = [System.Drawing.SystemColors]::Control
})

# === Проверка администратора ===
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    [System.Windows.Forms.MessageBox]::Show("Запустите скрипт от имени АДМИНИСТРАТОРА!", "Ошибка", "OK", "Error")
    exit 1
}

# === Старт GUI ===
Write-ColoredLog -Fragments @(@{Text="Готов к работе. Выберите типы очистки и нажмите «Запустить очистку»."; Color="White"})
$form.ShowDialog() | Out-Null