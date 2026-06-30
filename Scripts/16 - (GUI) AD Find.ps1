# Устанавливаем кодировку UTF-8 для вывода консоли
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Add-Type -AssemblyName PresentationFramework
Import-Module ActiveDirectory

# Вспомогательная функция: конвертирует DN в читаемый путь (domain.com/OU1/OU2)
function Convert-DNToPath {
    param([string]$DN)

    if (-not $DN) { return "" }

    $parts = $DN -split ',' | ForEach-Object {
        if ($_ -match '^(CN|OU|DC)=(.+)$') { $matches[2] } else { $_ }
    }

    if (-not $parts) { return $DN }

    $dcParts = ($DN -split ',' | Where-Object { $_ -like 'DC=*' }) -replace 'DC=', ''
    $domain  = ($dcParts -join '.')

    $nonDcParts = ($DN -split ',' | Where-Object { $_ -notlike 'DC=*' }) -replace '^(CN|OU)=', ''
    $pathTail   = ($nonDcParts[1..($nonDcParts.Count-1)] + $nonDcParts[0]) -join '/'

    if ($domain) { return "$domain/$pathTail" } else { return $DN }
}

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Поиск групп AD" Height="650" Width="1200"
        WindowStartupLocation="CenterScreen">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>   <!-- поиск групп -->
            <RowDefinition Height="3*"/>     <!-- таблица групп -->
            <RowDefinition Height="Auto"/>   <!-- панель поиска пользователей -->
            <RowDefinition Height="2*"/>     <!-- пользователи + группы пользователя -->
            <RowDefinition Height="Auto"/>   <!-- кнопки добавления -->
        </Grid.RowDefinitions>

        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="2*"/>   <!-- группы + пользователи -->
            <ColumnDefinition Width="1.5*"/> <!-- группы пользователя -->
        </Grid.ColumnDefinitions>

        <!-- Поиск групп -->
        <StackPanel Orientation="Horizontal" Grid.Row="0" Grid.ColumnSpan="2" Margin="0,0,0,10">
            <TextBlock Text="Поиск по имени группы:" VerticalAlignment="Center"/>
            <TextBox x:Name="SearchText" Width="220" Margin="10,0,0,0"/>
            <Button x:Name="SearchButton" Content="Найти группы" Width="120" Margin="10,0,0,0"/>
            <Button x:Name="ClearGroupsButton" Content="Очистить" Width="80" Margin="10,0,0,0"/>
        </StackPanel>

        <!-- Список групп -->
        <DataGrid x:Name="GroupsGrid" Grid.Row="1" Grid.Column="0"
                  AutoGenerateColumns="False" IsReadOnly="True"
                  SelectionMode="Extended">
            <DataGrid.Columns>
                <DataGridTextColumn Header="Имя"         Binding="{Binding Name}"        Width="2*"/>
                <DataGridTextColumn Header="Описание"    Binding="{Binding Description}" Width="2*"/>
                <DataGridTextColumn Header="Путь"        Binding="{Binding Path}"        Width="3*"/>
            </DataGrid.Columns>
        </DataGrid>

        <!-- Панель поиска пользователей -->
        <StackPanel Grid.Row="2" Grid.Column="0"
                    Orientation="Horizontal" Margin="0,10,0,5">
            <TextBlock Text="Поиск пользователя (ФИО или логин):" VerticalAlignment="Center"/>
            <TextBox x:Name="UserSearchText" Width="220" Margin="10,0,0,0"/>
            <Button x:Name="UserSearchButton" Content="Поиск" Width="70" Margin="10,0,0,0"/>
            <Button x:Name="ShowUserGroupsButton" Content="Группы пользователя"
                    Width="150" Margin="10,0,0,0"/>
        </StackPanel>

        <!-- Список пользователей -->
        <DataGrid x:Name="UsersGrid" Grid.Row="3" Grid.Column="0"
                  AutoGenerateColumns="False" IsReadOnly="True"
                  SelectionMode="Single">
            <DataGrid.Columns>
                <DataGridTextColumn Header="Отображаемое имя" Binding="{Binding displayName}"    Width="2*"/>
                <DataGridTextColumn Header="Логин"            Binding="{Binding sAMAccountName}" Width="1.5*"/>
                <DataGridTextColumn Header="ОУ"               Binding="{Binding OUPath}"         Width="3*"/>
            </DataGrid.Columns>
        </DataGrid>

       <!-- Список групп пользователя + кнопка -->
        <GroupBox Grid.Row="1" Grid.RowSpan="3" Grid.Column="1"
                  Header="Группы пользователя" Margin="10,0,0,0">
            <Grid Margin="0,5,0,5">
                <Grid.RowDefinitions>
                    <RowDefinition Height="*"/>      <!-- таблица -->
                    <RowDefinition Height="Auto"/>   <!-- кнопка -->
                </Grid.RowDefinitions>

                <DataGrid x:Name="UserGroupsGrid" Grid.Row="0"
                          AutoGenerateColumns="False" IsReadOnly="True"
                          SelectionMode="Extended">
                    <DataGrid.Columns>
                        <DataGridTextColumn Header="Имя"         Binding="{Binding Name}"        Width="2*"/>
                        <DataGridTextColumn Header="Описание"    Binding="{Binding Description}" Width="2*"/>
                        <DataGridTextColumn Header="Путь"        Binding="{Binding Path}"        Width="3*"/>
                    </DataGrid.Columns>
                </DataGrid>

                <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,5,0,0">
                    <Button x:Name="CopyUserGroupsButton"
                            Content="Добавить группы в список"
                            Width="200"/>
                </StackPanel>
            </Grid>
        </GroupBox>

      <!-- Кнопки добавления -->
        <StackPanel Grid.Row="4" Grid.Column="0" Orientation="Horizontal" Margin="0,10,0,0">
            <Button x:Name="AddButton" Content="Добавить пользователя в выбранные группы"
                    Width="280"/>
        </StackPanel>

    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$SearchText            = $window.FindName('SearchText')
$SearchButton          = $window.FindName('SearchButton')
$GroupsGrid            = $window.FindName('GroupsGrid')
$UserSearchText        = $window.FindName('UserSearchText')
$UserSearchButton      = $window.FindName('UserSearchButton')
$ShowUserGroupsButton  = $window.FindName('ShowUserGroupsButton')
$UsersGrid             = $window.FindName('UsersGrid')
$UserGroupsGrid        = $window.FindName('UserGroupsGrid')
$AddButton             = $window.FindName('AddButton')
$CopyUserGroupsButton  = $window.FindName('CopyUserGroupsButton')
$ClearGroupsButton     = $window.FindName('ClearGroupsButton')

function Invoke-GroupSearch {
    $query = $SearchText.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($query)) {
        [System.Windows.MessageBox]::Show("Введите текст для поиска по имени группы.")
        return
    }

    try {
        $words = $query -split '\s+'
        $filterParts = foreach ($w in $words) {
            $safeWord = $w.Replace("'", "''")
            "Name -like '*$safeWord*'"
        }
        $filter = $filterParts -join ' -and '

        $rawGroups = Get-ADGroup -Filter $filter -Properties DistinguishedName,Description

        if (-not $rawGroups) {
            $GroupsGrid.ItemsSource = $null
            [System.Windows.MessageBox]::Show("Группы по запросу '$query' не найдены.")
            return
        }

        $list = foreach ($g in @($rawGroups)) {
            [PSCustomObject]@{
                Name              = $g.Name
                Description       = $g.Description
                Path              = Convert-DNToPath $g.DistinguishedName
                DistinguishedName = $g.DistinguishedName
            }
        }

        $GroupsGrid.ItemsSource = @($list | Sort-Object Name)
    }
    catch {
        [System.Windows.MessageBox]::Show("Ошибка при поиске групп: $($_.Exception.Message)")
    }
}

function Invoke-UserSearch {
    $query = $UserSearchText.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($query)) {
        [System.Windows.MessageBox]::Show("Введите текст для поиска пользователя.")
        return
    }

    try {
        $safe = $query.Replace("'", "''")
        # Использование оператора формата -f вместо вставки переменной внутрь строки во избежание сбоев парсера
        $ldap = "(&(objectCategory=person)(objectClass=user)(|(displayName=*{0}*)(sAMAccountName=*{0}*)))" -f $safe
        
        $rawUsers = Get-ADUser -LDAPFilter $ldap -Properties displayName,sAMAccountName,DistinguishedName

        if (-not $rawUsers) {
            $UsersGrid.ItemsSource = $null
            [System.Windows.MessageBox]::Show("Пользователи по запросу '$query' не найдены.")
            return
        }

        $list = @()
        foreach ($u in @($rawUsers)) {
            $ouPath = Convert-DNToPath $u.DistinguishedName
            $list += [PSCustomObject]@{
                displayName       = $u.displayName
                sAMAccountName    = $u.sAMAccountName
                OUPath            = $ouPath
                DistinguishedName = $u.DistinguishedName
            }
        }

        $UsersGrid.ItemsSource = @($list | Sort-Object displayName)
    }
    catch {
        [System.Windows.MessageBox]::Show("Ошибка при поиске пользователей: $($_.Exception.Message)")
    }
}

function Invoke-ShowUserGroups {
    $user = $UsersGrid.SelectedItem
    if (-not $user) {
        [System.Windows.MessageBox]::Show("Выберите пользователя в списке пользователей.")
        return
    }

    try {
        $groups = Get-ADPrincipalGroupMembership -Identity $user.sAMAccountName -ErrorAction Stop |
                  Sort-Object Name

        if (-not $groups) {
            $UserGroupsGrid.ItemsSource = $null
            [System.Windows.MessageBox]::Show("У пользователя '$($user.sAMAccountName)' нет групп (кроме встроенных).")
            return
        }

        $list = foreach ($g in @($groups)) {
            [PSCustomObject]@{
                Name              = $g.Name
                Description       = $g.Description
                Path              = Convert-DNToPath $g.DistinguishedName
                DistinguishedName = $g.DistinguishedName
            }
        }

        $UserGroupsGrid.ItemsSource = @($list | Sort-Object Name)
    }
    catch {
        [System.Windows.MessageBox]::Show("Ошибка при получении групп пользователя: $($_.Exception.Message)")
    }
}

# Обработчики для поиска групп
$SearchButton.Add_Click({ Invoke-GroupSearch })
$SearchText.Add_KeyDown({
    param($src,$e)
    if ($e.Key -eq 'Enter') {
        Invoke-GroupSearch
        $e.Handled = $true
    }
})

# Обработчики для поиска пользователей
$UserSearchButton.Add_Click({ Invoke-UserSearch })
$UserSearchText.Add_KeyDown({
    param($src,$e)
    if ($e.Key -eq 'Enter') {
        Invoke-UserSearch
        $e.Handled = $true
    }
})

# Показ групп пользователя
$ShowUserGroupsButton.Add_Click({ Invoke-ShowUserGroups })
$UsersGrid.Add_MouseDoubleClick({ Invoke-ShowUserGroups })

# Двойной клик по строке группы -> копировать только Имя
$GroupsGrid.Add_MouseDoubleClick({
    $sel = $GroupsGrid.SelectedItem
    if ($sel -and $sel.Name) {
        [System.Windows.Clipboard]::SetText($sel.Name)
    }
})

# Блокируем стандартное копирование DataGrid и делаем своё (только имена)
$copyCommandBinding = [System.Windows.Input.CommandBinding]::new(
    [System.Windows.Input.ApplicationCommands]::Copy
)

$copyCommandBinding.Add_Executed({
    param($sender, $e)
    
    $grid = $e.Source
    $selectedItems = @($grid.SelectedItems)
    
    if ($selectedItems.Count -gt 0) {
        $names = $selectedItems | ForEach-Object { $_.Name }
        $textToCopy = $names -join "`r`n"
        [System.Windows.Clipboard]::SetText($textToCopy)
    }
    
    $e.Handled = $true
})

# Применяем это правило к обеим таблицам (чтобы работало и слева, и справа)
$GroupsGrid.CommandBindings.Add($copyCommandBinding) > $null
$UserGroupsGrid.CommandBindings.Add($copyCommandBinding) > $null

# Очистка списка групп и поля поиска
$ClearGroupsButton.Add_Click({
    $SearchText.Text = ""
    $GroupsGrid.ItemsSource = $null
})

# Добавить выбранного пользователя в выбранные группы
$AddButton.Add_Click({
    $selectedGroups = @($GroupsGrid.SelectedItems)
    if (-not $selectedGroups -or $selectedGroups.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Выберите одну или несколько групп в верхнем списке.")
        return
    }

    $user = $UsersGrid.SelectedItem
    if (-not $user) {
        [System.Windows.MessageBox]::Show("Выберите пользователя в списке пользователей.")
        return
    }

    try {
        foreach ($g in $selectedGroups) {
            Add-ADGroupMember -Identity $g.DistinguishedName `
                              -Members $user.DistinguishedName `
                              -ErrorAction Stop
        }

        $groupNames = ($selectedGroups | ForEach-Object { $_.Name }) -join ", "
        [System.Windows.MessageBox]::Show("Пользователь '$($user.sAMAccountName)' успешно добавлен в группы: $groupNames.")
    }
    catch {
        [System.Windows.MessageBox]::Show("Ошибка при добавлении пользователя: $($_.Exception.Message)")
    }
})

# Скопировать выбранные группы пользователя в основной список групп
$CopyUserGroupsButton.Add_Click({
    $userGroups = @($UserGroupsGrid.SelectedItems)
    if (-not $userGroups -or $userGroups.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Выберите одну или несколько групп в правом списке.")
        return
    }

    $current = @()
    if ($GroupsGrid.ItemsSource) {
        $current = @($GroupsGrid.ItemsSource)
    }

    foreach ($ug in $userGroups) {
        if (-not ($current | Where-Object { $_.DistinguishedName -eq $ug.DistinguishedName })) {
            $current += [PSCustomObject]@{
                Name              = $ug.Name
                Description       = $ug.Description
                Path              = $ug.Path
                DistinguishedName = $ug.DistinguishedName
            }
        }
    }

    $GroupsGrid.ItemsSource = @($current | Sort-Object Name)
})

$window.ShowDialog() | Out-Null