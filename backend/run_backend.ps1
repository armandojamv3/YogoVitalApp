param(
    [switch]$Dev,
    [string]$JwtSecret = ''
)

# Load .env if present (simple parser: KEY=VALUE)
$envFile = Join-Path $PSScriptRoot '.env'
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) { return }
        $idx = $line.IndexOf('=')
        if ($idx -lt 0) { return }
        $key = $line.Substring(0, $idx).Trim()
        $value = $line.Substring($idx + 1).Trim()
        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        if ($key -ne '') { Set-Item "env:$key" $value }
    }
}

if ($Dev) { Set-Item -Path 'env:DEV' -Value 'true' }
if ($JwtSecret -ne '') { Set-Item -Path 'env:JWT_SECRET' -Value $JwtSecret }

Write-Host ("Starting backend (DEV={0})..." -f (Get-Item env:DEV).Value)

# Ensure pub-cache bin is available in PATH for dart_frog
$pubCache = Join-Path $env:USERPROFILE '.pub-cache\bin'
if (-not ($env:Path -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -eq $pubCache })) {
    $env:Path = $env:Path + ';' + $pubCache
}

cd $PSScriptRoot

try {
    dart_frog dev
} catch {
    Write-Error "Failed to start dart_frog: $_"
    throw
}
