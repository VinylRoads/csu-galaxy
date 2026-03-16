$dir = "Расписание"
$scheduleOut = "schedule.json"
$groupsOut = "groups.json"

$groups = @{}
$faculties = @{}

# Регулярка: ищет от 1 до 5 букв, затем возможен пробел/тире/нижнее подчеркивание, затем ровно 3 цифры.
$regex = '(?<![А-Яа-яЁёA-Za-z])([А-Яа-яЁёA-Za-z]{1,5})[_ \-]?(\d{3})(?![0-9])'

Get-ChildItem -Path $dir -Filter *.pdf | ForEach-Object {
    $fileName = $_.Name
    $matches = [regex]::Matches($fileName, $regex)

    if ($matches.Count -eq 0) {
        # === ОБЩИЕ ДОКУМЕНТЫ ===
        if (-not $groups.ContainsKey("Общие документы")) {
            $groups["Общие документы"] = New-Object System.Collections.ArrayList
        }
        if (-not $groups["Общие документы"].Contains($fileName)) {
            [void]$groups["Общие документы"].Add($fileName)
        }
        
        # Создаем эту "планету" в списке факультетов
        if (-not $faculties.ContainsKey("Общие документы")) {
            $faculties["Общие документы"] = New-Object System.Collections.ArrayList
        }
    } else {
        # === ОБЫЧНЫЕ ГРУППЫ ===
        foreach ($m in $matches) {
            $prefix = $m.Groups[1].Value.ToUpper()
            $num = $m.Groups[2].Value
            $groupName = "$prefix-$num" 

            # Привязка расписания
            if (-not $groups.ContainsKey($groupName)) {
                $groups[$groupName] = New-Object System.Collections.ArrayList
            }
            if (-not $groups[$groupName].Contains($fileName)) {
                [void]$groups[$groupName].Add($fileName)
            }

            # Логика факультетов
            $isDistance = $false
            $basePrefix = $prefix

            if ($prefix.EndsWith("Д") -and $prefix -ne "СМТД") {
                $isDistance = $true
                $basePrefix = $prefix.Substring(0, $prefix.Length - 1)
            }

            $facultyName = "Неизвестный факультет"
            switch -Regex ($basePrefix) {
                "^(КЭ|КЭБУ)$" { $facultyName = "Экономика" }
                "^(М|МБЛ|СМТД)$" { $facultyName = "Менеджмент" }
                "^(КЛ|ПИП)$" { $facultyName = "Лингвистика" }
                "^(КРФ|ФОЖ)$" { $facultyName = "Филология" }
                "^(КЮ|КЮГ|КЮУ)$" { $facultyName = "Юриспруденция" }
            }

            if ($isDistance) { $facultyName += " (Дистант)" }

            if (-not $faculties.ContainsKey($facultyName)) {
                $faculties[$facultyName] = New-Object System.Collections.ArrayList
            }
            if (-not $faculties[$facultyName].Contains($groupName)) {
                [void]$faculties[$facultyName].Add($groupName)
            }
        }
    }
}

function Build-JsonBlock ($dict) {
    $sb = New-Object System.Text.StringBuilder
    $sb.AppendLine("{") | Out-Null
    $firstKey = $true
    
    $sortedKeys = $dict.Keys | Sort-Object
    
    foreach ($k in $sortedKeys) {
        if (-not $firstKey) { $sb.AppendLine(",") | Out-Null }
        $firstKey = $false
        $sb.Append('  "' + $k + '": [') | Out-Null
        $firstVal = $true
        
        $sortedValues = $dict[$k] | Sort-Object
        
        foreach ($v in $sortedValues) {
            if (-not $firstVal) { $sb.Append(", ") | Out-Null }
            $firstVal = $false
            $sb.Append('"' + $v + '"') | Out-Null
        }
        $sb.Append("]") | Out-Null
    }
    $sb.AppendLine().AppendLine("}") | Out-Null
    return $sb.ToString()
}

[System.IO.File]::WriteAllText($scheduleOut, (Build-JsonBlock $groups), [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText($groupsOut, (Build-JsonBlock $faculties), [System.Text.Encoding]::UTF8)

Write-Host "Сборка завершена. Добавлена планета Общие документы."

# Записываем время последнего обновления в лог-файл
$timestamp = Get-Date -Format "dd.MM.yyyy HH:mm:ss"
"Последнее обновление: $timestamp" | Out-File "last_build.log"