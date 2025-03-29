Get-ChildItem -Recurse -File | Where-Object { $_.Name -match "`r" } | ForEach-Object {
    $newName = $_.Name -replace "`r", ""
    $newPath = Join-Path -Path $_.DirectoryName -ChildPath $newName
    Rename-Item -Path $_.FullName -NewName $newPath
}

Get-ChildItem -Recurse -File | ForEach-Object {
    $content = Get-Content -Path $_.FullName -Raw
    $newContent = $content -replace "`r", "" -replace "\s+$", ""
    Set-Content -Path $_.FullName -Value $newContent
}
