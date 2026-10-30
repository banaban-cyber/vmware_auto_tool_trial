Set-StrictMode -Version Latest

function ConvertTo-HorizonUri {
    param([Parameter(Mandatory)][string]$Server)
    $value = $Server.Trim()
    if ($value -notmatch '^[a-zA-Z][a-zA-Z0-9+.-]*://') { $value = 'https://' + $value }
    $uri = $null
    if (-not [Uri]::TryCreate($value, [UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -ne 'https' -or -not $uri.Host -or
        $uri.HostNameType -eq [UriHostNameType]::Unknown -or $uri.Port -lt 1 -or
        $uri.UserInfo -or $uri.Query -or $uri.Fragment -or $uri.AbsolutePath -ne '/' -or
        $value -match '[\s\\]') {
        throw 'Server must be a hostname or IP, optionally with an HTTPS port. Do not include credentials or a path.'
    }
    return 'vmware-view://' + $uri.Authority + '/?action=start-session'
}

function Resolve-NotesPath {
    param([Parameter(Mandatory)][string]$Path)
    $expanded = [Environment]::ExpandEnvironmentVariables($Path.Trim())
    if (-not (Test-Path -LiteralPath $expanded -PathType Leaf) -or
        [IO.Path]::GetExtension($expanded) -ine '.txt') {
        throw 'Please select an existing .txt file for your work notes.'
    }
    return (Get-Item -LiteralPath $expanded -ErrorAction Stop).FullName
}

function ConvertTo-WebUrl {
    param([Parameter(Mandatory)][string]$Url)
    $uri = $null
    if (-not [Uri]::TryCreate($Url.Trim(), [UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -notin @('http', 'https') -or -not $uri.Host -or $uri.UserInfo) {
        throw 'Enter an HTTP or HTTPS URL without embedded credentials.'
    }
    return $uri.AbsoluteUri
}

function Find-Chrome {
    foreach ($key in @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe'
    )) {
        if (Test-Path -LiteralPath $key) {
            $candidate = (Get-Item -LiteralPath $key).GetValue('')
            if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $candidate }
        }
    }
    foreach ($base in @($env:LOCALAPPDATA, $env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if ($base) {
            $candidate = Join-Path $base 'Google\Chrome\Application\chrome.exe'
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
        }
    }
    throw 'Google Chrome was not found. Install Chrome first.'
}

function Start-HorizonWork {
    param([string]$Server, [string]$NotesPath)
    # Validate both inputs before starting any application.
    $target = ConvertTo-HorizonUri $Server
    $notes = Resolve-NotesPath $NotesPath
    Start-Process -FilePath $target -ErrorAction Stop | Out-Null
    Start-Process -FilePath 'notepad.exe' -ArgumentList ('"' + $notes + '"') -ErrorAction Stop | Out-Null
}

function Start-WorkWebsite {
    param([string]$Url)
    $target = ConvertTo-WebUrl $Url
    $chrome = Find-Chrome
    Start-Process -FilePath $chrome -ArgumentList @('--new-window', ('"' + $target + '"')) -ErrorAction Stop | Out-Null
}
