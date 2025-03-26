# Rimuove il carattere di ritorno a capo dai nomi dei file
Get-ChildItem -Recurse -File | Where-Object { $_.Name -match "`r" } | ForEach-Object {
    $newName = $_.Name -replace "`r", ""
    $newPath = Join-Path -Path $_.DirectoryName -ChildPath $newName
    Rename-Item -Path $_.FullName -NewName $newPath
}

# Rimuove il carattere di ritorno a capo e gli spazi dai fine riga dal contenuto dei file
Get-ChildItem -Recurse -File | ForEach-Object {
    $content = Get-Content -Path $_.FullName -Raw
    $newContent = $content -replace "`r", "" -replace "\s+$", ""
    Set-Content -Path $_.FullName -Value $newContent
}
