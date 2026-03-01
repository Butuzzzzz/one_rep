#requires -Version 5.1
# HR report parser GUI (WinForms)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

function ConvertFrom-HRText {
    param(
        [Parameter(Mandatory)]
        [string] $Text
    )

    $cleanText  = $Text -replace [char]160, ' '      # NBSP → space
    $eventTypes = @('Прием','Перемещение','Увольнение')
    $datePattern = '\d{2}\.\d{2}\.\d{4}'

    $lines = ($cleanText -split "`r?`n") | ForEach-Object { $_.Trim() }

    $currentDept    = $null
    $currentOrg     = $null
    $currentEvent   = $null
    $results = [System.Collections.Generic.List[object]]::new()

    function Get-NextNonEmpty {
        param([ref]$idx)
        while ($idx.Value -lt $lines.Count) {
            $s = $lines[$idx.Value]
            $idx.Value++
            if (-not [string]::IsNullOrWhiteSpace($s) -and $s -notmatch '^\d+$') { return $s }
        }
        return $null
    }

    $i = 0
    while ($i -lt $lines.Count) {
        $line = $lines[$i]
        $i++

        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        # Организация
        if ($line -match '\bООО\b|\bАО\b|\bПАО\b|\bЗАО\b|\bНАО\b') {
            $currentOrg = $line
            $currentDept = $null
            continue
        }

        # Пропуск заголовков/служебного
        if ($line -match '^(Параметры|Период|Детализировать|Отбор|Результат|Зарплата|Кадровые|Подразделение|Количество|Вид события|Сотрудник|Должность|_{3,})') { continue }
        if ($line -match 'Период.*Сотрудник.*Должность') { continue }
        if ($line -match '^(Сформированы отчеты|Зарплата и управление персоналом)') { continue }

        # Определение события
        $isEventLine = $false
        foreach ($ev in $eventTypes) {
            if ($line.StartsWith($ev)) {
                $currentEvent = $ev
                $isEventLine = $true
                break
            }
        }
        if ($isEventLine) { continue }

        # Запись сотрудника по дате
        if ($line -match "^($datePattern)(.*)$") {
            $dateStr    = $matches[1]
            $restOfLine = $matches[2].Trim()

            if (-not $currentEvent) { continue }

            # Вариант А: всё в одной строке
            $parts = $null
            if ($restOfLine.Contains("`t")) {
                $parts = $restOfLine -split "`t" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            }
            if (-not $parts -or $parts.Count -lt 2) {
                $parts = $restOfLine -split '\s{2,}' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            }

            if ($parts -and $parts.Count -ge 2) {
                $fio = $parts[0].Trim()
                $pos = $parts[1].Trim()
                $pos = $pos -replace '\s\d+(\/\d+)?$', ''   # убрать «1», «1/2» в конце

                $results.Add([pscustomobject]@{
                    Event = $currentEvent
                    Date  = $dateStr
                    FIO   = $fio
                    Pos   = $pos
                    Dept  = $currentDept
                    Org   = $currentOrg
                }) | Out-Null
                continue
            }

            # Вариант Б: вертикально
            if ([string]::IsNullOrWhiteSpace($restOfLine)) {
                $ref = [ref]$i
                $foundFio = Get-NextNonEmpty -idx $ref
                if ($foundFio) {
                    $foundPos = Get-NextNonEmpty -idx $ref
                    $i = $ref.Value

                    $results.Add([pscustomobject]@{
                        Event = $currentEvent
                        Date  = $dateStr
                        FIO   = $foundFio
                        Pos   = $foundPos
                        Dept  = $currentDept
                        Org   = $currentOrg
                    }) | Out-Null
                }
            }
            continue
        }

        # Подразделение (не число ставок)
        if ($line -notmatch '^\d+(\/\d+)?$') {
            $k = $i
            while ($k -lt $lines.Count -and [string]::IsNullOrWhiteSpace($lines[$k])) { $k++ }
            if ($k -lt $lines.Count) {
                $nextLine = $lines[$k]
                $nextIsEvent = $false
                foreach ($ev in $eventTypes) { if ($nextLine.StartsWith($ev)) { $nextIsEvent = $true; break } }
                if ($nextIsEvent -or $nextLine -match "^$datePattern") {
                    $currentDept = $line
                }
            }
        }
    }

    # Группировка и финальный формат
    $grouped = [ordered]@{}
    foreach ($ev in $eventTypes) { $grouped[$ev] = New-Object System.Collections.Generic.List[string] }

    foreach ($r in $results) {
        $dept = if ($r.Dept) { $r.Dept } else { '' }
        $org  = if ($r.Org)  { ' ' + $r.Org } else { '' }

        if ($dept) {
            $str = '{0} — {1}, {2} /{3}/{4}' -f $r.Date, $r.FIO, $r.Pos, $dept, $org
        } else {
            $str = '{0} — {1}, {2}{3}' -f $r.Date, $r.FIO, $r.Pos, $org
        }

        if (-not $grouped[$r.Event].Contains($str)) {
            $grouped[$r.Event].Add($str) | Out-Null
        }
    }

    return $grouped
}

function Format-HROutput {
    param([hashtable]$Grouped)
    $order = @('Увольнение','Прием','Перемещение')  # сначала увольнения
    $sb = New-Object System.Text.StringBuilder
    foreach ($ev in $order) {
        $items = $Grouped[$ev]
        if ($items -and $items.Count -gt 0) {
            [void]$sb.AppendLine("${ev}:")
            foreach ($s in $items) { [void]$sb.AppendLine($s) }
            [void]$sb.AppendLine()
        }
    }
    return $sb.ToString().TrimEnd()
}

# ---------------- GUI ----------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Парсер кадровых изменений"
$form.WindowState = 'Maximized'
$form.MinimumSize = New-Object System.Drawing.Size(800, 600)
$font = New-Object System.Drawing.Font("Segoe UI", 10)

$tableLayoutPanel = New-Object System.Windows.Forms.TableLayoutPanel
$tableLayoutPanel.RowCount = 2
$tableLayoutPanel.ColumnCount = 2
$tableLayoutPanel.Dock = 'Fill'
$tableLayoutPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50))) | Out-Null
$tableLayoutPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50))) | Out-Null
$tableLayoutPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$tableLayoutPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 50))) | Out-Null

# Левая панель (ввод)
$panelLeft = New-Object System.Windows.Forms.Panel
$panelLeft.Dock = 'Fill'
$panelLeft.Padding = New-Object System.Windows.Forms.Padding(10)
$lblIn = New-Object System.Windows.Forms.Label
$lblIn.Text = "Входной текст:"
$lblIn.Dock = 'Top'
$lblIn.Height = 25
$lblIn.Font = $font
$txtIn = New-Object System.Windows.Forms.TextBox
$txtIn.Dock = 'Fill'
$txtIn.Font = $font
$txtIn.Multiline = $true
$txtIn.ScrollBars = 'Both'
$txtIn.WordWrap = $false
$txtIn.MaxLength = 0
$panelLeft.Controls.Add($txtIn)
$panelLeft.Controls.Add($lblIn)

# Правая панель (результат)
$panelRight = New-Object System.Windows.Forms.Panel
$panelRight.Dock = 'Fill'
$panelRight.Padding = New-Object System.Windows.Forms.Padding(10)
$lblOut = New-Object System.Windows.Forms.Label
$lblOut.Text = "Результат:"
$lblOut.Dock = 'Top'
$lblOut.Height = 25
$lblOut.Font = $font
$txtOut = New-Object System.Windows.Forms.TextBox
$txtOut.Dock = 'Fill'
$txtOut.Font = $font
$txtOut.ReadOnly = $true
$txtOut.Multiline = $true
$txtOut.ScrollBars = 'Both'
$txtOut.WordWrap = $false
$txtOut.MaxLength = 0
$txtOut.BackColor = [System.Drawing.SystemColors]::Window
$panelRight.Controls.Add($txtOut)
$panelRight.Controls.Add($lblOut)

# Нижняя панель с кнопками
$panelBottom = New-Object System.Windows.Forms.FlowLayoutPanel
$panelBottom.Dock = 'Fill'
$panelBottom.Padding = New-Object System.Windows.Forms.Padding(10, 5, 0, 0)
$panelBottom.AutoSize = $false
$tableLayoutPanel.SetColumnSpan($panelBottom, 2)

$btnParse = New-Object System.Windows.Forms.Button
$btnParse.Text = "Разобрать"
$btnParse.Size = New-Object System.Drawing.Size(120, 35)
$btnParse.Font = $font
$btnParse.Margin = New-Object System.Windows.Forms.Padding(0, 0, 10, 0)

$btnCopy = New-Object System.Windows.Forms.Button
$btnCopy.Text = "Копировать результат"
$btnCopy.Size = New-Object System.Drawing.Size(180, 35)
$btnCopy.Font = $font
$btnCopy.Margin = New-Object System.Windows.Forms.Padding(0, 0, 10, 0)

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Text = "Очистить всё"
$btnClear.Size = New-Object System.Drawing.Size(140, 35)
$btnClear.Font = $font
$btnClear.Margin = New-Object System.Windows.Forms.Padding(0, 0, 10, 0)

$status = New-Object System.Windows.Forms.Label
$status.Text = ""
$status.AutoSize = $true
$status.Padding = New-Object System.Windows.Forms.Padding(0, 8, 0, 0)
$status.Font = $font

$panelBottom.Controls.AddRange(@($btnParse, $btnCopy, $btnClear, $status))
$tableLayoutPanel.Controls.Add($panelLeft, 0, 0)
$tableLayoutPanel.Controls.Add($panelRight, 1, 0)
$tableLayoutPanel.Controls.Add($panelBottom, 0, 1)
$form.Controls.Add($tableLayoutPanel)

# ЛОГИКА
$btnParse.Add_Click({
    try {
        if ([string]::IsNullOrWhiteSpace($txtIn.Text)) { $status.Text = "Пусто..."; return }
        $grouped = ConvertFrom-HRText -Text $txtIn.Text
        $txtOut.Text = (Format-HROutput -Grouped $grouped) -replace "(?<!`r)`n", "`r`n"
        $status.Text = "Готово."
    } catch {
        $txtOut.Text = "Ошибка: " + $_.Exception.Message
        $status.Text = "Ошибка."
    }
})

$btnCopy.Add_Click({
    if ($txtOut.Text) {
        Set-Clipboard -Value $txtOut.Text
        $status.Text = "Скопировано."
    }
})

$btnClear.Add_Click({
    $txtIn.Clear()
    $txtOut.Clear()
    $txtIn.Focus()
    $status.Text = "Все поля очищены."
})

[void]$form.ShowDialog()
