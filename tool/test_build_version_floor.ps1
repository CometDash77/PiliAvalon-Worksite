param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pili-build-version-floor-" + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    New-Item -ItemType Directory -Path (Join-Path $tempRoot 'lib/scripts') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'lib/scripts/build.ps1') -Destination (Join-Path $tempRoot 'lib/scripts/build.ps1')
    @'
name: test_app
version: 2.0.8+1
'@ | Set-Content -Path (Join-Path $tempRoot 'pubspec.yaml') -Encoding UTF8

    git -C $tempRoot init | Out-Null
    git -C $tempRoot config user.email test@example.invalid | Out-Null
    git -C $tempRoot config user.name Test | Out-Null
    git -C $tempRoot add pubspec.yaml lib/scripts/build.ps1 | Out-Null
    git -C $tempRoot commit -m init | Out-Null

    $env:GITHUB_ENV = Join-Path $tempRoot 'github-env.txt'
    $env:PILI_VERSION_CODE_FLOOR = '5150'

    Push-Location $tempRoot
    try {
        & .\lib\scripts\build.ps1 android
    }
    finally {
        Pop-Location
    }

    $release = Get-Content -Raw -Path (Join-Path $tempRoot 'pili_release.json') | ConvertFrom-Json
    if ($release.'pili.code' -ne 5150) {
        throw "Expected pili.code 5150, got $($release.'pili.code')"
    }

    $pubspec = Get-Content -Raw -Path (Join-Path $tempRoot 'pubspec.yaml')
    if ($pubspec -notmatch '\+5150') {
        throw "Expected pubspec version build suffix +5150, got: $pubspec"
    }

    Write-Host 'build-version-floor-ok'
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item Env:\PILI_VERSION_CODE_FLOOR -ErrorAction SilentlyContinue
}
