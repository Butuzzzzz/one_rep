Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Создаем главную форму
$form = New-Object System.Windows.Forms.Form
$form.Text = "Поиск оборудования по сотруднику"
$form.Size = New-Object System.Drawing.Size(1200, 700)
$form.StartPosition = "CenterScreen"
$form.WindowState = "Maximized" # Окно на весь экран

# Поле для ввода поиска
$labelSearch = New-Object System.Windows.Forms.Label
$labelSearch.Location = New-Object System.Drawing.Point(10, 20)
$labelSearch.Size = New-Object System.Drawing.Size(300, 20)
$labelSearch.Text = "Введите ФИО или любой текст для поиска:"
$form.Controls.Add($labelSearch)

$textBoxSearch = New-Object System.Windows.Forms.TextBox
$textBoxSearch.Location = New-Object System.Drawing.Point(10, 45)
$textBoxSearch.Size = New-Object System.Drawing.Size(300, 20)
$form.Controls.Add($textBoxSearch)

# Кнопка загрузки файла
$buttonLoad = New-Object System.Windows.Forms.Button
$buttonLoad.Location = New-Object System.Drawing.Point(320, 40)
$buttonLoad.Size = New-Object System.Drawing.Size(120, 30)
$buttonLoad.Text = "Загрузить файл"
$form.Controls.Add($buttonLoad)

# Кнопка поиска
$buttonSearch = New-Object System.Windows.Forms.Button
$buttonSearch.Location = New-Object System.Drawing.Point(450, 40)
$buttonSearch.Size = New-Object System.Drawing.Size(120, 30)
$buttonSearch.Text = "Найти"
$buttonSearch.Enabled = $false
$form.Controls.Add($buttonSearch)

# Таблица для отображения результатов
$dataGridView = New-Object System.Windows.Forms.DataGridView
$dataGridView.Location = New-Object System.Drawing.Point(10, 90)
$dataGridView.Size = New-Object System.Drawing.Size(1170, 550)
$dataGridView.AutoSizeColumnsMode = "Fill"
$dataGridView.ReadOnly = $true
$dataGridView.SelectionMode = "FullRowSelect"
$dataGridView.Anchor = "Top,Left,Bottom,Right"

# Обработчик для отрисовки ячеек с подсветкой
$dataGridView.Add_CellFormatting({
    param($gridSender, $e)
    
    if ($script:lastSearchText -and $script:lastSearchText.Trim() -ne "" -and $e.Value -ne $null) {
        $cellText = $e.Value.ToString()
        $searchText = $script:lastSearchText.Trim()
        
        # Ищем совпадения (регистронезависимо)
        $index = $cellText.IndexOf($searchText, [System.StringComparison]::CurrentCultureIgnoreCase)
        if ($index -ge 0) {
            $e.CellStyle.BackColor = [System.Drawing.Color]::LightYellow
            $e.CellStyle.SelectionBackColor = [System.Drawing.Color]::LightGoldenrodYellow
            $e.CellStyle.SelectionForeColor = [System.Drawing.Color]::Black  # Черный шрифт при выделении
            $e.CellStyle.ForeColor = [System.Drawing.Color]::Black          # Черный шрифт всегда
        } else {
            $e.CellStyle.BackColor = [System.Drawing.Color]::White
            $e.CellStyle.SelectionBackColor = [System.Drawing.Color]::LightBlue
            $e.CellStyle.SelectionForeColor = [System.Drawing.Color]::Black  # Черный шрифт при выделении
            $e.CellStyle.ForeColor = [System.Drawing.Color]::Black          # Черный шрифт всегда
        }
    } else {
        $e.CellStyle.BackColor = [System.Drawing.Color]::White
        $e.CellStyle.SelectionBackColor = [System.Drawing.Color]::LightBlue
        $e.CellStyle.SelectionForeColor = [System.Drawing.Color]::Black      # Черный шрифт при выделении
        $e.CellStyle.ForeColor = [System.Drawing.Color]::Black              # Черный шрифт всегда
    }
})

$form.Controls.Add($dataGridView)

# Текстовый прогресс-бар (статус) с цветами
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(10, 643)
$statusLabel.Size = New-Object System.Drawing.Size(1170, 20)
$statusLabel.Text = "Статус: Файл не загружен"
$statusLabel.Anchor = "Bottom,Left,Right"
$statusLabel.ForeColor = [System.Drawing.Color]::Gray
$form.Controls.Add($statusLabel)

# Функция для установки цвета статуса
function Set-StatusColor {
    param(
        [string]$StatusType,
        [string]$Message
    )
    
    switch ($StatusType) {
        "SUCCESS" {
            $statusLabel.ForeColor = [System.Drawing.Color]::Green
            $statusLabel.Text = $Message
        }
        "LOADING" {
            $statusLabel.ForeColor = [System.Drawing.Color]::Blue
            $statusLabel.Text = $Message
        }
        "ERROR" {
            $statusLabel.ForeColor = [System.Drawing.Color]::Red
            $statusLabel.Text = $Message
        }
        "INFO" {
            $statusLabel.ForeColor = [System.Drawing.Color]::Gray
            $statusLabel.Text = $Message
        }
    }
    [System.Windows.Forms.Application]::DoEvents()
}

# Функция для отображения данных в таблице
function Show-DataInTable {
    param(
        [array]$DataToShow,
        [string]$SearchText = ""
    )
    
    # Сохраняем текст поиска для подсветки
    $script:lastSearchText = $SearchText
    
    # Настраиваем колонки DataGridView только с нужными колонками
    $dataGridView.Columns.Clear()
    
    # Определяем нужные колонки в правильном порядке
    $requiredColumns = @(
        "Сотрудник",
        "Основное средство",
        "Инвентарный номер", 
        "Код ИМ/ Кто найдет код",
        "Мнение QWEN",
        "Где находится",
        "Какой проект",
        "МОЛ по Иму", 
        "Дата принятия к учету",
        "Первоначальная стоимость",
        "Основное средство.Код"
    )
    
    # Добавляем колонки в таблицу
    foreach ($column in $requiredColumns) {
        $dataGridView.Columns.Add($column, $column) | Out-Null
    }
    
    # Заполняем данными
    foreach ($result in $DataToShow) {
        $row = New-Object System.Windows.Forms.DataGridViewRow
        $row.CreateCells($dataGridView)
        
        # Заполняем каждую ячейку в правильном порядке
        $row.Cells[0].Value = $result."Сотрудник"
        $row.Cells[1].Value = $result."Основное средство"
        $row.Cells[2].Value = $result."Инвентарный номер"
        $row.Cells[3].Value = $result."Код ИМ/ Кто найдет код"
        $row.Cells[4].Value = $result."Мнение QWEN"
        $row.Cells[5].Value = $result."Где находится"
        $row.Cells[6].Value = $result."Какой проект"
        $row.Cells[7].Value = $result."МОЛ по Иму"
        $row.Cells[8].Value = $result."Дата принятия к учету"
        $row.Cells[9].Value = $result."Первоначальная стоимость"
        $row.Cells[10].Value = $result."Основное средство.Код"
        
        $dataGridView.Rows.Add($row)
    }
    
    # Принудительно обновляем отображение для подсветки
    $dataGridView.Refresh()
}

# Переменные для хранения данных
$excelData = $null
$filePath = $null
$employees = @() # Массив для хранения ФИО сотрудников
$processedData = @() # Обработанные данные с добавленным сотрудником
$lastSearchText = "" # Переменная для хранения последнего поискового запроса

# Функция загрузки Excel файла
$buttonLoad.Add_Click({
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Filter = "Excel files (*.xlsx)|*.xlsx"
    $openFileDialog.Title = "Выберите файл выгрузки из 1С"
    
    if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:filePath = $openFileDialog.FileName
        Set-StatusColor "LOADING" "Статус: Начинаю загрузку файла..."
        $buttonLoad.Enabled = $false
        $buttonLoad.Text = "Загрузка..."
        
        try {
            # Обновляем статус
            Set-StatusColor "LOADING" "Статус: Открываю Excel..."
            
            # Создаем COM объект для работы с Excel
            $excel = New-Object -ComObject Excel.Application
            $excel.Visible = $false
            $excel.DisplayAlerts = $false
            
            Set-StatusColor "LOADING" "Статус: Читаю файл $([System.IO.Path]::GetFileName($script:filePath))..."
            
            $workbook = $excel.Workbooks.Open($script:filePath)
            
            # Получаем данные из листа "Итоговая таблица"
            $worksheet = $workbook.Worksheets.Item("Итоговая таблица")
            $usedRange = $worksheet.UsedRange
            
            Set-StatusColor "LOADING" "Статус: Обрабатываю данные и определяю ФИО сотрудников..."
            
            # Читаем данные в массив и определяем ФИО сотрудников
            $script:excelData = @()
            $script:employees = @()
            $script:processedData = @()
            $rowCount = $usedRange.Rows.Count
            $columnCount = $usedRange.Columns.Count
            
            # Читаем заголовки (первая строка)
            $headers = @()
            for ($col = 1; $col -le $columnCount; $col++) {
                $headers += $usedRange.Cells.Item(1, $col).Text
            }
            
            # Переменная для хранения текущего сотрудника
            $currentEmployee = ""
            
            # Читаем данные начиная со второй строки
            for ($row = 2; $row -le $rowCount; $row++) {
                $rowData = New-Object PSObject
                $isEmptyRow = $true
                
                for ($col = 1; $col -le $columnCount; $col++) {
                    $cellValue = $usedRange.Cells.Item($row, $col).Text
                    $rowData | Add-Member -MemberType NoteProperty -Name $headers[$col-1] -Value $cellValue
                    
                    # Проверяем, не пустая ли строка
                    if ($cellValue -ne "") {
                        $isEmptyRow = $false
                    }
                }
                
                # Пропускаем пустые строки
                if (-not $isEmptyRow) {
                    $script:excelData += $rowData
                    
                    # Определяем ФИО сотрудников - строка считается ФИО если:
                    # - В колонке "Основное средство" есть текст
                    # - В колонке "Инвентарный номер" пусто
                    $mainAsset = $rowData."Основное средство"
                    $inventoryNumber = $rowData."Инвентарный номер"
                    
                    if ($mainAsset -ne "" -and $inventoryNumber -eq "") {
                        # Это строка с ФИО сотрудника
                        $currentEmployee = $mainAsset
                        $script:employees += $currentEmployee
                    } else {
                        # Это строка с оборудованием - добавляем сотрудника
                        $rowData | Add-Member -MemberType NoteProperty -Name "Сотрудник" -Value $currentEmployee -Force
                        $script:processedData += $rowData
                    }
                }
                
                # Обновляем статус каждые 100 строк
                if ($row % 100 -eq 0) {
                    Set-StatusColor "LOADING" "Статус: Обработано $row из $rowCount строк..."
                }
            }
            
            $workbook.Close()
            $excel.Quit()
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($worksheet) | Out-Null
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($workbook) | Out-Null
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
            
            $buttonSearch.Enabled = $true
            $buttonLoad.Enabled = $true
            $buttonLoad.Text = "Загрузить файл"
            Set-StatusColor "SUCCESS" "Статус: ФАЙЛ УСПЕШНО ЗАГРУЖЕН! Обработано $($script:processedData.Count) единиц оборудования. Найдено $($script:employees.Count) сотрудников. Введите текст для поиска или нажмите 'Найти' для полного списка."
            
        } catch {
            $buttonLoad.Enabled = $true
            $buttonLoad.Text = "Загрузить файл"
            Set-StatusColor "ERROR" "Статус: ОШИБКА ЗАГРУЗКИ ФАЙЛА: $($_.Exception.Message)"
            [System.Windows.Forms.MessageBox]::Show("Ошибка загрузки файла: $($_.Exception.Message)", "Ошибка")
        }
    }
})

# Функция поиска по всем колонкам
$buttonSearch.Add_Click({
    $searchText = $textBoxSearch.Text.Trim()
    
    if ($script:processedData -eq $null) {
        [System.Windows.Forms.MessageBox]::Show("Сначала загрузите файл", "Внимание")
        return
    }
    
    # Если строка поиска пустая - показываем весь список
    if ([string]::IsNullOrEmpty($searchText)) {
        Set-StatusColor "LOADING" "Статус: Загружаю полный список оборудования..."
        $buttonSearch.Enabled = $false
        $buttonSearch.Text = "Загрузка..."
        
        try {
            Show-DataInTable -DataToShow $script:processedData
            
            $buttonSearch.Enabled = $true
            $buttonSearch.Text = "Найти"
            Set-StatusColor "SUCCESS" "Статус: ПОЛНЫЙ СПИСОК ЗАГРУЖЕН! Отображено $($script:processedData.Count) единиц оборудования."
            
        } catch {
            $buttonSearch.Enabled = $true
            $buttonSearch.Text = "Найти"
            Set-StatusColor "ERROR" "Статус: ОШИБКА ЗАГРУЗКИ СПИСКА: $($_.Exception.Message)"
            [System.Windows.Forms.MessageBox]::Show("Ошибка загрузки списка: $($_.Exception.Message)", "Ошибка")
        }
        return
    }
    
    Set-StatusColor "LOADING" "Статус: Ищу '$searchText' во всех колонках..."
    $buttonSearch.Enabled = $false
    $buttonSearch.Text = "Поиск..."
    
    try {
        # Ищем строки, содержащие искомый текст в любой колонке
        $searchResults = @()
        
        foreach ($row in $script:processedData) {
            $found = $false
            
            # Проверяем все свойства строки на наличие искомого текста
            foreach ($property in $row.PSObject.Properties) {
                if ($property.Value -like "*$searchText*") {
                    $found = $true
                    break
                }
            }
            
            if ($found) {
                $searchResults += $row
            }
        }
        
        # Отображаем результаты
        $buttonSearch.Enabled = $true
        $buttonSearch.Text = "Найти"
        
        if ($searchResults.Count -gt 0) {
            Show-DataInTable -DataToShow $searchResults -SearchText $searchText
            Set-StatusColor "SUCCESS" "Статус: ПОИСК ЗАВЕРШЕН! Найдено $($searchResults.Count) строк содержащих '$searchText'"
            
        } else {
            $dataGridView.Rows.Clear()
            $dataGridView.Columns.Clear()
            Set-StatusColor "ERROR" "Статус: НИЧЕГО НЕ НАЙДЕНО по запросу '$searchText'"
            [System.Windows.Forms.MessageBox]::Show("Ничего не найдено по запросу '$searchText'", "Результат поиска")
        }
        
    } catch {
        $buttonSearch.Enabled = $true
        $buttonSearch.Text = "Найти"
        Set-StatusColor "ERROR" "Статус: ОШИБКА ПОИСКА: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show("Ошибка поиска: $($_.Exception.Message)", "Ошибка")
    }
})

# Обработчик нажатия Enter в поле поиска
$textBoxSearch.Add_KeyDown({
    if ($_.KeyCode -eq "Enter") {
        $buttonSearch.PerformClick()
    }
})

# Показываем форму
$form.Add_Shown({
    $form.Activate()
    Set-StatusColor "INFO" "Статус: Файл не загружен"
})
[void]$form.ShowDialog()