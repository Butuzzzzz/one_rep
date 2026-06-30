Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# === Функция получения IPv4-адреса по имени ===
function Get-IPv4Address {
    param([string]$HostName)
    try {
        $addresses = [System.Net.Dns]::GetHostAddresses($HostName)
        foreach ($addr in $addresses) {
            if ($addr.AddressFamily -eq 'InterNetwork') { # IPv4
                return $addr.IPAddressToString
            }
        }
        return "—"
    } catch {
        return "—"
    }
}

# === Функция опроса ПК ===
function Get-PCInfo {
    param([string]$Target)

    $result = [PSCustomObject]@{
        Input    = $Target
        IP       = "—"
        Hostname = "—"
        Serial   = "—"
        User     = "—"
        Error    = $null
    }

    try {
        $isIP = $Target -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$'

        if ($isIP) {
            # Проверим, что это именно IPv4
            try {
                $ipObj = [System.Net.IPAddress]::Parse($Target)
                if ($ipObj.AddressFamily -ne 'InterNetwork') {
                    $result.Error = "Поддерживается только IPv4"
                    return $result
                }
            } catch {
                $result.Error = "Некорректный IP"
                return $result
            }

            $result.IP = $Target
            try {
                $hostEntry = [System.Net.Dns]::GetHostEntry($Target)
                $computerName = $hostEntry.HostName.Split('.')[0]
            } catch {
                $result.Error = "Не удалось определить имя по IP"
                return $result
            }
        } else {
            # По имени → получаем IPv4
            $computerName = $Target
            $result.IP = Get-IPv4Address -HostName $computerName
            if ($result.IP -eq "—") {
                $result.Error = "Не удалось получить IPv4 по имени"
                return $result
            }
        }

        # WMI-опрос
        $cs = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $computerName -ErrorAction Stop
        $bios = Get-WmiObject -Class Win32_BIOS -ComputerName $computerName -ErrorAction Stop

        $result.Hostname = $cs.Name
        $result.Serial = $bios.SerialNumber
        $result.User = if ($cs.UserName) { $cs.UserName } else { "<нет активной сессии>" }

    } catch {
        $result.Error = $_.Exception.Message
    }

    return $result
}

# === Создаём форму ===
$form = New-Object System.Windows.Forms.Form
$form.Text = "Информация о ПК"
$form.Size = New-Object System.Drawing.Size(850, 520)
$form.MinimumSize = New-Object System.Drawing.Size(600, 400)  # Минимальный размер
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::WhiteSmoke
$form.FormBorderStyle = "Sizable"  # ✅ Окно можно растягивать

$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(20, 20)
$label.Size = New-Object System.Drawing.Size(600, 20)
$label.Text = "Введите IP (IPv4) или имя компьютера:"
$label.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.Controls.Add($label)

$inputBox = New-Object System.Windows.Forms.TextBox
$inputBox.Location = New-Object System.Drawing.Point(20, 50)
$inputBox.Size = New-Object System.Drawing.Size(400, 24)
$inputBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$inputBox.Anchor = "Left,Top"
$form.Controls.Add($inputBox)


$goButton = New-Object System.Windows.Forms.Button
$goButton.Location = New-Object System.Drawing.Point(430, 50)
$goButton.Size = New-Object System.Drawing.Size(100, 24)
$goButton.Text = "Опросить"
$goButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$goButton.Anchor = "Top"
$form.Controls.Add($goButton)

# Таблица
$dataGridView = New-Object System.Windows.Forms.DataGridView
$dataGridView.Location = New-Object System.Drawing.Point(20, 90)
$dataGridView.Size = New-Object System.Drawing.Size(800, 360)
$dataGridView.ReadOnly = $true
$dataGridView.SelectionMode = "CellSelect"
$dataGridView.ClipboardCopyMode = "EnableWithoutHeaderText"  # ✅ Только данные, без заголовков!
$dataGridView.AutoSizeColumnsMode = "None"
$dataGridView.AllowUserToResizeColumns = $true
$dataGridView.AllowUserToResizeRows = $false
$dataGridView.EnableHeadersVisualStyles = $false
$dataGridView.GridColor = [System.Drawing.Color]::LightGray
$dataGridView.BackgroundColor = [System.Drawing.Color]::White
$dataGridView.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::SteelBlue
$dataGridView.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::White
$dataGridView.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$dataGridView.DefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$dataGridView.AlternatingRowsDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
$dataGridView.Anchor = "Top, Bottom, Left, Right"
$form.Controls.Add($dataGridView)

# Колонки (без "Домен")
$columns = @(
    @{ Name = "Input"; Header = "Введено"; Width = 100 },
    @{ Name = "IP"; Header = "IP (IPv4)"; Width = 120 },
    @{ Name = "Hostname"; Header = "Имя ПК"; Width = 140 },
    @{ Name = "Serial"; Header = "Серийный номер"; Width = 160 },
    @{ Name = "User"; Header = "Пользователь"; Width = 220 }
)

foreach ($col in $columns) {
    $dataGridView.Columns.Add((New-Object System.Windows.Forms.DataGridViewTextBoxColumn -Property @{
        Name = $col.Name
        HeaderText = $col.Header
        Width = $col.Width
        AutoSizeMode = "None"
    }))
}

# Ошибки
$errorLabel = New-Object System.Windows.Forms.Label
$errorLabel.Location = New-Object System.Drawing.Point(20, 460)
$errorLabel.Size = New-Object System.Drawing.Size(800, 20)
$errorLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$errorLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Italic)
$errorLabel.ForeColor = [System.Drawing.Color]::DarkRed
$errorLabel.Visible = $false
$errorLabel.Anchor = "Bottom, Left"
$form.Controls.Add($errorLabel)

# Кнопка
$goButton.Add_Click({
    $target = $inputBox.Text.Trim()
    if (-not $target) { 
        $errorLabel.Text = "⚠️ Введите IP или имя ПК"
        $errorLabel.Visible = $true
        return 
    }

    $dataGridView.Rows.Clear()
    $errorLabel.Visible = $false
    $form.Refresh()

    $info = Get-PCInfo -Target $target

    if ($info.Error) {
        $errorLabel.Text = "❌ $($target): $($info.Error)"
        $errorLabel.Visible = $true
    } else {
        $dataGridView.Rows.Add(
            $info.Input,
            $info.IP,
            $info.Hostname,
            $info.Serial,
            $info.User
        )
    }
})
# Обработчик кнопки "Опросить"
$goButton.Add_Click({
    $target = $inputBox.Text.Trim()
    if (-not $target) { 
        $errorLabel.Text = "⚠️ Введите IP или имя ПК"
        $errorLabel.Visible = $true
        return 
    }

    $dataGridView.Rows.Clear()
    $errorLabel.Visible = $false
    $form.Refresh()

    $info = Get-PCInfo -Target $target

    if ($info.Error) {
        $errorLabel.Text = "❌ $($target): $($info.Error)"
        $errorLabel.Visible = $true
    } else {
        $dataGridView.Rows.Add(
            $info.Input,
            $info.IP,
            $info.Hostname,
            $info.Serial,
            $info.User
        )
    }
})

# ✅ Обработчик нажатия Enter в поле ввода
$inputBox.Add_KeyDown({
    if ($_.KeyCode -eq 'Enter') {
        # Имитируем нажатие кнопки
        $goButton.PerformClick()
    }
})
[void]$form.ShowDialog()