$ErrorActionPreference = 'Stop'

function Read-PathItem($value, $prompt) {
    if (-not $value) { $value = Read-Host $prompt }
    if ([string]::IsNullOrWhiteSpace($value)) { throw 'No path entered.' }
    Get-Item -LiteralPath ($value.Trim().Trim('"')) -Force
}

try {
    Write-Host 'Client Pick Extractor'
    $list = Read-PathItem $env:PICKS_LIST 'Selection list (.txt)'
    $source = Read-PathItem $env:PICKS_SOURCE 'Original RAW folder'
    if ($list -isnot [IO.FileInfo] -or $list.Extension -ne '.txt') { throw 'Select a .txt file.' }
    if ($source -isnot [IO.DirectoryInfo]) { throw 'Select a RAW folder.' }

    $output = [IO.Path]::Combine($list.DirectoryName, 'Selected RAW')
    $cmp = [StringComparison]::OrdinalIgnoreCase
    if ($source.FullName.TrimEnd('\').Equals($output, $cmp) -or $source.FullName.StartsWith($output + '\', $cmp)) {
        throw 'Choose an original RAW folder outside the output folder.'
    }
    if ([IO.Directory]::Exists($output) -and ([IO.File]::GetAttributes($output) -band [IO.FileAttributes]::ReparsePoint)) {
        throw 'Output folder is a link or junction. Choose another location for the list.'
    }

    $raw = '.arw', '.cr2', '.cr3', '.dng', '.nef', '.nrw', '.orf', '.raf', '.rw2', '.pef', '.srw'
    $known = $raw + @('.jpg', '.jpeg')
    $requests = [Collections.Generic.List[string]]::new()
    $hits = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::OrdinalIgnoreCase)
    $lineNumber = 0
    foreach ($line in [IO.File]::ReadLines($list.FullName, [Text.UTF8Encoding]::new($false, $true))) {
        $lineNumber++
        $name = $line.Trim()
        if (-not $name) { continue }
        if ($name.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0) { throw "Line ${lineNumber}: enter a filename, not a path or pattern." }
        if ([IO.Path]::GetExtension($name) -in $known) { $name = [IO.Path]::GetFileNameWithoutExtension($name) }
        if ([string]::IsNullOrWhiteSpace($name) -or $name -in '.', '..') { throw "Line ${lineNumber}: empty or invalid filename." }
        if (-not $hits.ContainsKey($name)) {
            $hits.Add($name, [Collections.Generic.List[string]]::new())
            $requests.Add($name)
        }
    }
    if (-not $requests.Count) { throw 'The selection list is empty.' }

    Write-Host "Scanning: $($source.FullName)"
    $folders = [Collections.Generic.Stack[IO.DirectoryInfo]]::new()
    $folders.Push($source)
    while ($folders.Count) {
        $dir = $folders.Pop()
        foreach ($entry in $dir.EnumerateFileSystemInfos()) {
            if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
            if ($entry -is [IO.DirectoryInfo]) {
                if (-not $entry.FullName.Equals($output, $cmp)) { $folders.Push($entry) }
            } elseif ($entry.Extension -in $raw -and $hits.ContainsKey($entry.BaseName)) {
                $hits[$entry.BaseName].Add($entry.FullName)
            }
        }
    }

    $null = [IO.Directory]::CreateDirectory($output)
    $report = Join-Path $output ('report-{0:yyyyMMdd-HHmmss}-{1}.txt' -f (Get-Date), [guid]::NewGuid().ToString('N').Substring(0,8))
    $writer = [IO.StreamWriter]::new([IO.File]::Open($report, 'CreateNew', 'Write', 'Read'), [Text.Encoding]::UTF8)
    function Log-Line([string] $text) { $writer.WriteLine($text); Write-Host $text }
    $counts = @{ COPIED = 0; MISSING = 0; AMBIGUOUS = 0; EXISTS = 0; FAILED = 0 }
    try {
        Log-Line "List: $($list.FullName)"
        Log-Line "Output: $output"
        foreach ($name in $requests) {
            $paths = $hits[$name]
            if ($paths.Count -eq 0) { $status = 'MISSING' }
            elseif ($paths.Count -gt 1) { $status = 'AMBIGUOUS' }
            else {
                $dest = Join-Path $output ([IO.Path]::GetFileName($paths[0]))
                if ([IO.File]::Exists($dest)) { $status = 'EXISTS' }
                else {
                    try { [IO.File]::Copy($paths[0], $dest, $false); $status = 'COPIED' }
                    catch { $status = 'FAILED'; Log-Line "  $($_.Exception.GetBaseException().Message)" }
                }
            }
            Log-Line "[$status] $name"
            foreach ($path in $paths) { Log-Line "  $path" }
            $counts[$status]++
        }
        Log-Line (('COPIED','MISSING','AMBIGUOUS','EXISTS','FAILED' | ForEach-Object { "${_}: $($counts[$_])" }) -join ' | ')
    } finally { $writer.Dispose() }
    Write-Host "Report: $report"
    if ($counts.FAILED) { exit 1 }
    if ($counts.MISSING -or $counts.AMBIGUOUS -or $counts.EXISTS) { exit 2 }
} catch {
    [Console]::Error.WriteLine($_.Exception.GetBaseException().Message)
    exit 1
}
