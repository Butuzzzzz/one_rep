# Требуются права администратора
#Requires -RunAsAdministrator

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Глобальные переменные для доступа к элементам формы
$script:Form = $null
$script:LabelStatus = $null
$script:ActiveUserName = $null
$script:TargetComputer = $null

function Write-ProgressStatus {
  param([string]$Status)
  if ($null -ne $script:LabelStatus) {
    # $null слева
    $script:LabelStatus.Text = $Status
    $script:Form.Refresh()
    [System.Windows.Forms.Application]::DoEvents()
  }
}

function Test-PrinterServerConnection {
  param(
    [string]$ServerAddress,
    [int]$TimeoutSeconds = 10
  )
    
  $job = Start-Job -ScriptBlock {
    param($Server)
    try {
      $printers = Get-Printer -ComputerName $Server -ErrorAction SilentlyContinue
      return @{ Success = $true; Printers = $printers }
    }
    catch {
      return @{ Success = $false; Error = $_.Exception.Message }
    }
  } -ArgumentList $ServerAddress
    
  $startTime = Get-Date
  $timeout = $TimeoutSeconds * 1000
    
  do {
    Start-Sleep -Milliseconds 100
    if ($job.State -eq "Completed") {
      $result = Receive-Job -Job $job
      Remove-Job -Job $job
      return $result
    }
    $elapsed = ((Get-Date) - $startTime).TotalMilliseconds
  } while ($elapsed -lt $timeout)
    
  Stop-Job -Job $job
  Remove-Job -Job $job
  return @{ Success = $false; Error = "Таймаут подключения к $ServerAddress (более $TimeoutSeconds секунд)" }
}

function Get-PrintersFromServer {
  param(
    [string]$ServerIP,
    [string]$ServerHostname,
    [int]$TimeoutSeconds = 10
  )
    
  Write-ProgressStatus "Попытка подключения к серверу по IP: $ServerIP"
  $ipResult = Test-PrinterServerConnection -ServerAddress $ServerIP -TimeoutSeconds $TimeoutSeconds
    
  if ($ipResult.Success) {
    Write-ProgressStatus "Успешное подключение по IP. Найдено принтеров: $($ipResult.Printers.Count)"
    return $ipResult.Printers
  }
  else {
    Write-ProgressStatus "Не удалось подключиться по IP: $($ipResult.Error)"
  }
    
  if ($ServerHostname -and $ServerHostname -ne $ServerIP) {
    Write-ProgressStatus "Попытка подключения к серверу по имени: $ServerHostname"
    $hostnameResult = Test-PrinterServerConnection -ServerAddress $ServerHostname -TimeoutSeconds $TimeoutSeconds
        
    if ($hostnameResult.Success) {
      Write-ProgressStatus "Успешное подключение по имени. Найдено принтеров: $($hostnameResult.Printers.Count)"
      return $hostnameResult.Printers
    }
    else {
      Write-ProgressStatus "Не удалось подключиться по имени: $($hostnameResult.Error)"
    }
  }
    
  throw "Не удалось подключиться к серверу печати.`nПо IP ($ServerIP): $($ipResult.Error)`nПо имени ($ServerHostname): $($hostnameResult.Error)"
}

function Install-PrinterForUser {
  param([string]$PrinterPath)
    
  Write-ProgressStatus "Установка принтера: $PrinterPath"
    
  # Используем ТОЛЬКО Rundll32 - он надежно работает с любыми именами
  try {
    Write-ProgressStatus "Установка через Rundll32..."
    $process = Start-Process -FilePath "rundll32.exe" -ArgumentList "printui.dll,PrintUIEntry /in /q /n `"$PrinterPath`"" -Wait -PassThru -WindowStyle Hidden
        
    if ($process.ExitCode -eq 0) {
      Write-ProgressStatus "✅ Принтер установлен через Rundll32"
      return $true
    }
    else {
      Write-ProgressStatus "❌ Rundll32: Код ошибки $($process.ExitCode)"
      return $false
    }
  }
  catch {
    Write-ProgressStatus "❌ Ошибка установки: $($_.Exception.Message)"
    return $false
  }
}

function Install-PrinterForUser {
  param([string]$PrinterPath)
    
  Write-ProgressStatus "Установка принтера: $PrinterPath"
    
  # Метод 1: Пробуем как есть (может сработать для имен без пробелов)
  try {
    Write-ProgressStatus "Попытка 1: Прямая установка..."
    Add-Printer -ConnectionName $PrinterPath -ErrorAction Stop
    Write-ProgressStatus "✅ Принтер установлен через PowerShell"
    return $true
  }
  catch {
    Write-ProgressStatus "❌ Прямая установка: $($_.Exception.Message)"
  }
    
  # Метод 2: Используем Rundll32 (более надежно с именами с пробелами)
  try {
    Write-ProgressStatus "Попытка 2: Установка через Rundll32..."
    $process = Start-Process -FilePath "rundll32.exe" -ArgumentList "printui.dll,PrintUIEntry /in /q /n `"$PrinterPath`"" -Wait -PassThru -WindowStyle Hidden
    if ($process.ExitCode -eq 0) {
      Write-ProgressStatus "✅ Принтер установлен через Rundll32"
      return $true
    }
    else {
      Write-ProgressStatus "❌ Rundll32: Код ошибки $($process.ExitCode)"
    }
  }
  catch {
    Write-ProgressStatus "❌ Rundll32: $($_.Exception.Message)"
  }
    
  # Метод 3: WMI
  try {
    Write-ProgressStatus "Попытка 3: Установка через WMI..."
    $printerName = $PrinterPath.Split('\')[-1]
    Add-Printer -Name $printerName -DriverName "EPSON WF-C869R Series" -PortName $PrinterPath.Replace('\\', '').Replace('\', ':') -ErrorAction Stop
    Write-ProgressStatus "✅ Принтер установлен через WMI"
    return $true
  }
  catch {
    Write-ProgressStatus "❌ WMI: $($_.Exception.Message)"
  }
    
  Write-ProgressStatus "❌ Все методы установки не сработали"
  return $false
}

function Update-UserPrinters {
  param([string]$ComputerName, [string]$UserName)
    
  try {
    Write-ProgressStatus "Обновление интерфейса на компьютере $ComputerName..."
        
    # Выполняем команды на удаленном компьютере
    $result = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
      # Способ 1: Обновление через rundll32
      try {
        Start-Process -FilePath "rundll32.exe" -ArgumentList "printui.dll,PrintUIEntry /q /ga" -WindowStyle Hidden -Wait
      }
      catch { }
            
      # Способ 2: Перезапуск проводника для конкретного пользователя
      try {
        # Находим процессы explorer.exe конкретного пользователя
        $explorerProcesses = Get-WmiObject Win32_Process -Filter "Name='explorer.exe'" | 
        Where-Object { 
          $owner = $_.GetOwner()
          $owner.User -eq $using:UserName
        }
                
        if ($explorerProcesses) {
          # Останавливаем процессы explorer пользователя
          foreach ($process in $explorerProcesses) {
            Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
          }
                    
          # Даем время на завершение
          Start-Sleep -Seconds 3
                    
          # Запускаем explorer снова
          Start-Process "explorer.exe"
        }
      }
      catch { 
        Write-Output "Ошибка перезапуска explorer: $($_.Exception.Message)"
      }
            
      return "Обновление выполнено на удаленном компьютере"
    } -ErrorAction SilentlyContinue
        
    if ($result) {
      return $result
    }
    else {
      return "Не удалось выполнить обновление на удаленном компьютере"
    }
  }
  catch {
    return "Ошибка обновления: $($_.Exception.Message)"
  }
}

function Update-PrintersUI {
  param([string]$ComputerName, [string]$UserName)
    
  Write-ProgressStatus "Обновление интерфейса на $ComputerName для пользователя $UserName..."
    
  try {
    # Проверяем доступность компьютера
    if (-not (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet)) {
      return "❌ Компьютер $ComputerName недоступен"
    }
        
    # Выполняем команды на удаленном компьютере
    $result = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
      param($UserName)
            
      $log = @()
            
      # Способ 1: Обновление через rundll32
      try {
        $log += "Запуск rundll32 для обновления принтеров..."
        $process = Start-Process -FilePath "rundll32.exe" -ArgumentList "printui.dll,PrintUIEntry /q /ga" -WindowStyle Hidden -Wait -PassThru
        $log += "Rundll32 завершен с кодом: $($process.ExitCode)"
      }
      catch {
        $log += "Ошибка rundll32: $($_.Exception.Message)"
      }
            
      # Способ 2: Перезапуск проводника для конкретного пользователя
      try {
        $log += "Поиск процессов explorer.exe пользователя $UserName..."
        $explorerProcesses = Get-WmiObject Win32_Process -Filter "Name='explorer.exe'" | 
        Where-Object { 
          try {
            $owner = $_.GetOwner()
            $owner.User -eq $UserName
          }
          catch {
            $false
          }
        }
                
        $log += "Найдено процессов explorer: $($explorerProcesses.Count)"
                
        if ($explorerProcesses.Count -gt 0) {
          $log += "Останавливаем процессы explorer..."
          foreach ($process in $explorerProcesses) {
            try {
              Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
              $log += "Остановлен процесс: $($process.ProcessId)"
            }
            catch {
              $log += "Не удалось остановить процесс $($process.ProcessId): $($_.Exception.Message)"
            }
          }
                    
          Start-Sleep -Seconds 3
          $log += "Запускаем explorer.exe..."
          Start-Process "explorer.exe" -ErrorAction SilentlyContinue
          $log += "Explorer перезапущен"
        }
        else {
          $log += "Процессы explorer не найдены для пользователя $UserName"
        }
      }
      catch { 
        $log += "Ошибка перезапуска explorer: $($_.Exception.Message)"
      }
            
      return $log -join "`n"
            
    } -ArgumentList $UserName -ErrorAction Stop
        
    return "✅ Обновление выполнено. Лог:`n$result"
  }
  catch {
    return "❌ Ошибка обновления: $($_.Exception.Message)"
  }
}

# Добавим функцию проверки установки принтера на удаленном компьютере
function Test-RemotePrinterInstallation {
  param([string]$ComputerName, [string]$PrinterName)
    
  try {
    $result = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
      param($PrinterName)
            
      $printers = Get-Printer -Name "*$PrinterName*" -ErrorAction SilentlyContinue
      $printerObjects = @()
            
      foreach ($printer in $printers) {
        $printerObjects += @{
          Name         = $printer.Name
          Type         = $printer.Type
          DriverName   = $printer.DriverName
          Shared       = $printer.Shared
          ComputerName = $printer.ComputerName
        }
      }
            
      return $printerObjects
            
    } -ArgumentList $PrinterName -ErrorAction Stop
        
    return $result
  }
  catch {
    return @()
  }
}

function Show-PrinterInstallForm {
  # Создаем форму с вкладками
  $form = New-Object System.Windows.Forms.Form
  $form.Text = "Установка сетевого принтера"
  $form.Size = New-Object System.Drawing.Size(600, 500)
  $form.StartPosition = "CenterScreen"
  $form.MaximizeBox = $false
  $form.FormBorderStyle = "FixedDialog"
    
  # Создаем вкладки
  $tabControl = New-Object System.Windows.Forms.TabControl
  $tabControl.Location = New-Object System.Drawing.Point(10, 10)
  $tabControl.Size = New-Object System.Drawing.Size(565, 420)
  $form.Controls.Add($tabControl)

  # Вкладка 1: Установка принтера
  $tabInstall = New-Object System.Windows.Forms.TabPage
  $tabInstall.Text = "Установка принтера"
  $tabControl.Controls.Add($tabInstall)

  # Вкладка 2: Лог
  $tabLog = New-Object System.Windows.Forms.TabPage
  $tabLog.Text = "Лог выполнения"
  $tabControl.Controls.Add($tabLog)

  # Текстовое поле для лога
  $textBoxLog = New-Object System.Windows.Forms.TextBox
  $textBoxLog.Location = New-Object System.Drawing.Point(10, 10)
  $textBoxLog.Size = New-Object System.Drawing.Size(540, 350)
  $textBoxLog.Multiline = $true
  $textBoxLog.ScrollBars = "Vertical"
  $textBoxLog.ReadOnly = $true
  $textBoxLog.Font = New-Object System.Drawing.Font("Consolas", 9)
  $tabLog.Controls.Add($textBoxLog)

  # Функция для добавления записи в лог
  $script:LogTextBox = $textBoxLog
  function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    $script:LogTextBox.AppendText("$logEntry`r`n")
    $script:LogTextBox.ScrollToCaret()
  }

  # Обновляем функцию Write-ProgressStatus
  function Write-ProgressStatus {
    param([string]$Status)
    if ($null -ne $script:LabelStatus) {
      $script:LabelStatus.Text = $Status
      $script:Form.Refresh()
      [System.Windows.Forms.Application]::DoEvents()
    }
    Write-Log $Status
  }

  # === ВСЕ ЭЛЕМЕНТЫ ДОБАВЛЯЕМ НА ВКЛАДКУ $tabInstall ===

  # Поле целевого компьютера
  $labelComputer = New-Object System.Windows.Forms.Label
  $labelComputer.Location = New-Object System.Drawing.Point(10, 20)
  $labelComputer.Size = New-Object System.Drawing.Size(100, 20)
  $labelComputer.Text = "Компьютер:"
  $tabInstall.Controls.Add($labelComputer)  # Добавляем на вкладку установки

  $textBoxComputer = New-Object System.Windows.Forms.TextBox
  $textBoxComputer.Location = New-Object System.Drawing.Point(120, 20)
  $textBoxComputer.Size = New-Object System.Drawing.Size(200, 20)
  $textBoxComputer.Text = $env:COMPUTERNAME
  $tabInstall.Controls.Add($textBoxComputer)  # Добавляем на вкладку установки

  $buttonFindUser = New-Object System.Windows.Forms.Button
  $buttonFindUser.Location = New-Object System.Drawing.Point(330, 20)
  $buttonFindUser.Size = New-Object System.Drawing.Size(100, 23)
  $buttonFindUser.Text = "Найти пользователя"
  $tabInstall.Controls.Add($buttonFindUser)  # Добавляем на вкладку установки

  # Информация о текущем пользователе
  $labelCurrentUser = New-Object System.Windows.Forms.Label
  $labelCurrentUser.Location = New-Object System.Drawing.Point(10, 50)
  $labelCurrentUser.Size = New-Object System.Drawing.Size(460, 20)
  $labelCurrentUser.Text = "Укажите компьютер и нажмите 'Найти пользователя'"
  $labelCurrentUser.ForeColor = "Blue"
  $tabInstall.Controls.Add($labelCurrentUser)  # Добавляем на вкладку установки

  # Выпадающий список принт-серверов
  $labelServer = New-Object System.Windows.Forms.Label
  $labelServer.Location = New-Object System.Drawing.Point(10, 80)
  $labelServer.Size = New-Object System.Drawing.Size(100, 20)
  $labelServer.Text = "Принт-сервер:"
  $tabInstall.Controls.Add($labelServer)  # Добавляем на вкладку установки

  $comboBoxServers = New-Object System.Windows.Forms.ComboBox
  $comboBoxServers.Location = New-Object System.Drawing.Point(120, 80)
  $comboBoxServers.Size = New-Object System.Drawing.Size(300, 20)
  $comboBoxServers.DropDownStyle = "DropDownList"
  $tabInstall.Controls.Add($comboBoxServers)  # Добавляем на вкладку установки

  # Заполняем список серверов
  $printServers = @(
    @{Name = "СПб, офис"; Hostname = "spbhdqsrv066.stepcon.ru"; IP = "192.168.100.66" },
    @{Name = "СПб, БЦ Кантемировский, Huawei"; Hostname = "spbhdqcctv005.stepcon.ru"; IP = "192.168.39.75" },
    @{Name = "Когалым, ЖК ФК"; Hostname = "b-kgl-srv008.bem.spb.ru"; IP = "192.168.24.78" },
    @{Name = "Липецк, НЛМК-ВРУ20"; Hostname = "lpkrqsrv006.stepcon.ru"; IP = "192.168.22.76" },
    @{Name = "Выкса, ОФИС"; Hostname = "W225.stepcon.ru"; IP = "192.168.45.75" },
    @{Name = "Волгоград, ГРАСС"; Hostname = "vlgrqcctv005.stepcon.ru"; IP = "192.168.33.75" }
  )

  foreach ($server in $printServers) {
    $comboBoxServers.Items.Add("$($server.Name) | $($server.IP)") | Out-Null
  }
  $comboBoxServers.SelectedIndex = 1

  # Поле имени принтера
  $labelPrinter = New-Object System.Windows.Forms.Label
  $labelPrinter.Location = New-Object System.Drawing.Point(10, 110)
  $labelPrinter.Size = New-Object System.Drawing.Size(100, 20)
  $labelPrinter.Text = "Имя принтера:"
  $tabInstall.Controls.Add($labelPrinter)  # Добавляем на вкладку установки

  $textBoxPrinter = New-Object System.Windows.Forms.TextBox
  $textBoxPrinter.Location = New-Object System.Drawing.Point(120, 110)
  $textBoxPrinter.Size = New-Object System.Drawing.Size(200, 20)
  $textBoxPrinter.Text = ""
  $tabInstall.Controls.Add($textBoxPrinter)  # Добавляем на вкладку установки

  $buttonFindPrinters = New-Object System.Windows.Forms.Button
  $buttonFindPrinters.Location = New-Object System.Drawing.Point(330, 110)
  $buttonFindPrinters.Size = New-Object System.Drawing.Size(75, 23)
  $buttonFindPrinters.Text = "Список"
  $tabInstall.Controls.Add($buttonFindPrinters)  # Добавляем на вкладку установки

  # Список принтеров
  $listBoxPrinters = New-Object System.Windows.Forms.ListBox
  $listBoxPrinters.Location = New-Object System.Drawing.Point(120, 140)
  $listBoxPrinters.Size = New-Object System.Drawing.Size(350, 80)
  $listBoxPrinters.Visible = $false
  $tabInstall.Controls.Add($listBoxPrinters)  # Добавляем на вкладку установки

  # Статус
  $labelStatus = New-Object System.Windows.Forms.Label
  $labelStatus.Location = New-Object System.Drawing.Point(10, 240)
  $labelStatus.Size = New-Object System.Drawing.Size(460, 40)
  $labelStatus.Text = "Укажите компьютер и найдите активного пользователя"
  $tabInstall.Controls.Add($labelStatus)  # Добавляем на вкладку установки
  $script:LabelStatus = $labelStatus

  # Кнопки
  $buttonInstall = New-Object System.Windows.Forms.Button
  $buttonInstall.Location = New-Object System.Drawing.Point(300, 300)
  $buttonInstall.Size = New-Object System.Drawing.Size(85, 23)
  $buttonInstall.Text = "Установить"
  $tabInstall.Controls.Add($buttonInstall)  # Добавляем на вкладку установки

  $buttonCancel = New-Object System.Windows.Forms.Button
  $buttonCancel.Location = New-Object System.Drawing.Point(395, 300)
  $buttonCancel.Size = New-Object System.Drawing.Size(75, 23)
  $buttonCancel.Text = "Отмена"
  $tabInstall.Controls.Add($buttonCancel)  # Добавляем на вкладку установки

  # Сохраняем ссылку на форму
  $script:Form = $form

  # Делаем кнопку Установить по умолчанию для формы
  $form.AcceptButton = $buttonInstall

  # Обработка нажатия Enter для поля компьютера
  $textBoxComputer.Add_KeyDown({
      if ($_.KeyCode -eq "Enter") {
        $buttonFindUser.PerformClick()
        $_.SuppressKeyPress = $true
      }
    })

  # Обработка нажатия Enter для поля принтера
  $textBoxPrinter.Add_KeyDown({
      if ($_.KeyCode -eq "Enter") {
        $buttonFindPrinters.PerformClick()
        $_.SuppressKeyPress = $true
      }
    })

  # Обработка нажатия Enter в списке принтеров
  $listBoxPrinters.Add_KeyDown({
      if ($_.KeyCode -eq "Enter") {
        if ($listBoxPrinters.SelectedItem) {
          $textBoxPrinter.Text = $listBoxPrinters.SelectedItem
          $listBoxPrinters.Visible = $false
          $textBoxPrinter.Focus()
        }
        $_.SuppressKeyPress = $true
      }
    })

  # Обработка Escape для закрытия формы
  $form.Add_KeyDown({
      if ($_.KeyCode -eq "Escape") {
        $form.Close()
      }
    })

  # Функция получения выбранного сервера
  function Get-SelectedPrintServer {
    $selectedIndex = $comboBoxServers.SelectedIndex
    if ($selectedIndex -ge 0) {
      return $printServers[$selectedIndex]
    }
    return $null
  }

  # Обработчики событий
  $buttonFindUser.Add_Click({
      $computerName = $textBoxComputer.Text.Trim()
      if (-not $computerName) {
        Write-ProgressStatus "Введите имя компьютера!"
        return
      }

      $buttonFindUser.Enabled = $false
      $buttonFindPrinters.Enabled = $false
      $buttonInstall.Enabled = $false

      try {
        Write-ProgressStatus "Проверка доступности компьютера $computerName..."
            
        if (-not (Test-Connection -ComputerName $computerName -Count 1 -Quiet)) {
          Write-ProgressStatus "Компьютер $computerName недоступен!"
          $labelCurrentUser.Text = "Компьютер недоступен"
          $labelCurrentUser.ForeColor = "Red"
          $script:ActiveUserName = $null
          return
        }

        Write-ProgressStatus "Поиск активного пользователя на $computerName..."
        $userName = Get-LoggedOnUser -ComputerName $computerName
        
        if ($userName -like "Ошибка:*" -or $userName -eq "Не удалось определить") {
          Write-ProgressStatus "Не удалось найти активного пользователя"
          $labelCurrentUser.Text = "Активный пользователь не найден"
          $labelCurrentUser.ForeColor = "Red"
          $script:ActiveUserName = $null
        }
        else {
          $script:ActiveUserName = $userName
          $script:TargetComputer = $computerName
          $labelCurrentUser.Text = "Активный пользователь: $userName"
          $labelCurrentUser.ForeColor = "Green"
          Write-ProgressStatus "Пользователь найден. Можно устанавливать принтер."
        }
      }
      catch {
        Write-ProgressStatus "Ошибка: $($_.Exception.Message)"
        $labelCurrentUser.Text = "Ошибка при поиске пользователя"
        $labelCurrentUser.ForeColor = "Red"
      }
      finally {
        $buttonFindUser.Enabled = $true
        $buttonFindPrinters.Enabled = $true
        $buttonInstall.Enabled = $true
      }
    })

  $buttonFindPrinters.Add_Click({
      $server = Get-SelectedPrintServer
      if (-not $server) {
        Write-ProgressStatus "Сначала выберите принт-сервер!"
        return
      }

      $buttonFindUser.Enabled = $false
      $buttonFindPrinters.Enabled = $false
      $buttonInstall.Enabled = $false

      try {
        $listBoxPrinters.Items.Clear()
        $printers = Get-PrintersFromServer -ServerIP $server.IP -ServerHostname $server.Hostname -TimeoutSeconds 10

        if ($printers) {
          foreach ($printer in $printers) {
            if ($printer.Shared) {
              $listBoxPrinters.Items.Add($printer.Name) | Out-Null
            }
          }
          $listBoxPrinters.Visible = $true
          Write-ProgressStatus "Найдено принтеров: $($listBoxPrinters.Items.Count)"
        }
        else {
          Write-ProgressStatus "Принтеры не найдены"
        }
      }
      catch {
        Write-ProgressStatus $_.Exception.Message
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Ошибка", "OK", "Error")
      }
      finally {
        $buttonFindUser.Enabled = $true
        $buttonFindPrinters.Enabled = $true
        $buttonInstall.Enabled = $true
      }
    })

  $listBoxPrinters.Add_SelectedIndexChanged({
      if ($listBoxPrinters.SelectedItem) {
        $textBoxPrinter.Text = $listBoxPrinters.SelectedItem
        $listBoxPrinters.Visible = $false
        Write-ProgressStatus "Принтер выбран: $($listBoxPrinters.SelectedItem)"
      }
    })

  $buttonInstall.Add_Click({
      $server = Get-SelectedPrintServer
      $printerName = $textBoxPrinter.Text.Trim()

      if (-not $server -or -not $printerName) {
        Write-ProgressStatus "Выберите принт-сервер и принтер!"
        return
      }

      if (-not $script:ActiveUserName -or -not $script:TargetComputer) {
        Write-ProgressStatus "Сначала найдите активного пользователя!"
        return
      }

      $printerPath = "\\$($server.IP)\$printerName"

      try {
        Write-ProgressStatus "=== НАЧАЛО УСТАНОВКИ ==="
        Write-ProgressStatus "Принтер: $printerPath"
        Write-ProgressStatus "Компьютер: $script:TargetComputer"
        Write-ProgressStatus "Пользователь: $script:ActiveUserName"
        
        # Устанавливаем принтер
        $success = Install-PrinterForUser -PrinterPath $printerPath -ComputerName $script:TargetComputer -UserName $script:ActiveUserName
        
        if ($success) {
          Write-ProgressStatus "Ожидаем завершения установки..."
          Start-Sleep -Seconds 5
            
          # Проверяем установку
          $installedPrinters = Test-RemotePrinterInstallation -ComputerName $script:TargetComputer -PrinterName $printerName
            
          if ($installedPrinters.Count -gt 0) {
            Write-ProgressStatus "✅ ПРИНТЕР УСПЕШНО УСТАНОВЛЕН НА УДАЛЕННОМ КОМПЬЮТЕРЕ!"
                
            # Переключаем на вкладку лога
            $tabControl.SelectedTab = $tabLog
                
            [System.Windows.Forms.MessageBox]::Show(
              "Принтер успешно установлен!`nПроверьте вкладку 'Лог выполнения' для подробностей.",
              "✅ Успех", "OK", "Information"
            )
          }
          else {
            Write-ProgressStatus "❌ Принтер не найден на удаленном компьютере"
            $tabControl.SelectedTab = $tabLog
            [System.Windows.Forms.MessageBox]::Show(
              "Принтер не установился. Проверьте лог для диагностики.",
              "❌ Ошибка", "OK", "Error"
            )
          }
        }
      }
      catch {
        Write-ProgressStatus "❌ Критическая ошибка: $($_.Exception.Message)"
        $tabControl.SelectedTab = $tabLog
      }
    })

  $buttonCancel.Add_Click({
      $form.Close()
    })

  # Показываем форму
  $form.Add_Shown({ $form.Activate() })
  $form.ShowDialog() | Out-Null
}

# Добавим проверку драйверов в функцию установки
function Install-PrinterForUser {
  param([string]$PrinterPath, [string]$ComputerName, [string]$UserName)
    
  Write-ProgressStatus "Установка принтера: $PrinterPath на $ComputerName"
    
  # Метод 1: Установка через удаленное выполнение (с правами админа)
  try {
    Write-ProgressStatus "Установка через удаленное выполнение..."
    $result = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
      param($PrinterPath)
            
      try {
        # Пробуем установить через rundll32
        $process = Start-Process -FilePath "rundll32.exe" -ArgumentList "printui.dll,PrintUIEntry /in /q /n `"$PrinterPath`"" -Wait -PassThru -WindowStyle Hidden
                
        if ($process.ExitCode -eq 0) {
          return @{ Success = $true; Message = "Принтер установлен через Rundll32" }
        }
        else {
          return @{ Success = $false; Message = "Rundll32 код ошибки: $($process.ExitCode)" }
        }
      }
      catch {
        return @{ Success = $false; Message = "Ошибка: $($_.Exception.Message)" }
      }
            
    } -ArgumentList $PrinterPath -ErrorAction Stop
        
    if ($result.Success) {
      Write-ProgressStatus "✅ $($result.Message)"
      return $true
    }
    else {
      Write-ProgressStatus "❌ $($result.Message)"
      return $false
    }
  }
  catch {
    Write-ProgressStatus "❌ Ошибка удаленной установки: $($_.Exception.Message)"
    return $false
  }
}

# Обновляем функцию проверки установки
function Test-RemotePrinterInstallation {
  param([string]$ComputerName, [string]$PrinterName)
    
  try {
    Write-ProgressStatus "Проверка установки принтера на $ComputerName..."
    $result = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
      param($PrinterName)
            
      $printers = Get-Printer -Name "*$PrinterName*" -ErrorAction SilentlyContinue
      $printerList = @()
            
      foreach ($printer in $printers) {
        $printerList += @{
          Name         = $printer.Name
          Type         = $printer.Type
          DriverName   = $printer.DriverName
          Shared       = $printer.Shared
          ComputerName = $printer.ComputerName
          PortName     = $printer.PortName
        }
      }
            
      return $printerList
            
    } -ArgumentList $PrinterName -ErrorAction Stop
        
    Write-ProgressStatus "Найдено принтеров: $($result.Count)"
    return $result
  }
  catch {
    Write-ProgressStatus "❌ Ошибка проверки: $($_.Exception.Message)"
    return @()
  }
}
# Добавим функцию проверки
function Test-PrinterInstallation {
  param([string]$PrinterPath)
    
  $printerName = $PrinterPath.Split('\')[-1]
    
  # Проверяем в списке принтеров
  $installedPrinters = Get-Printer -Name "*$printerName*" -ErrorAction SilentlyContinue
  if ($installedPrinters) {
    return "✅ Принтер найден в системе: $($installedPrinters.Name)"
  }
    
  # Проверяем в реестре
  $regPrinters = Get-ChildItem "HKCU:\Printers\Connections" -ErrorAction SilentlyContinue
  if ($regPrinters) {
    return "⚠️ Принтер есть в реестре, но не отображается"
  }
    
  return "❌ Принтер не найден ни в системе, ни в реестре"
}

# Запускаем приложение
try {
  Write-Host "Запуск приложения установки принтеров..." -ForegroundColor Green
  Show-PrinterInstallForm
}
catch {
  [System.Windows.Forms.MessageBox]::Show("Ошибка запуска: $($_.Exception.Message)", "Критическая ошибка", "OK", "Error")
}