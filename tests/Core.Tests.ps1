$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'WorkMode.Core.ps1')
$script:passed = 0
function Check([string]$Name, [scriptblock]$Test) {
    & $Test
    $script:passed++
    Write-Output "PASS $Name"
}
function Equal($Actual, $Expected) {
    if ($Actual -cne $Expected) { throw "Expected [$Expected], got [$Actual]" }
}
function Must-Throw([scriptblock]$Operation) {
    $threw = $false
    try { & $Operation | Out-Null } catch { $threw = $true }
    if (-not $threw) { throw 'Expected input to be rejected.' }
}
# Replace application launching, so tests cannot connect to any server.
$script:launches = New-Object System.Collections.Generic.List[object]
function Start-Process {
    param($FilePath, $ArgumentList, $ErrorAction)
    $script:launches.Add(@{ FilePath = $FilePath; Arguments = $ArgumentList })
}
function Find-Chrome { return 'C:\Program Files\Google\Chrome\Application\chrome.exe' }

$temp = Join-Path ([IO.Path]::GetTempPath()) ('work-mode-test-' + [Guid]::NewGuid().ToString())
$null = New-Item -ItemType Directory -Path $temp
$notes = Join-Path $temp 'my work notes.txt'
Set-Content -LiteralPath $notes -Value 'TEST DATA ONLY'
try {
    Check 'hostname connects using the Horizon start-session URI' {
        Equal (ConvertTo-HorizonUri ' horizon.example.com ') 'vmware-view://horizon.example.com/?action=start-session'
    }
    Check 'HTTPS server and custom port' {
        Equal (ConvertTo-HorizonUri 'https://horizon.example.com:8443/') 'vmware-view://horizon.example.com:8443/?action=start-session'
    }
    Check 'IPv4 server' {
        Equal (ConvertTo-HorizonUri '192.0.2.1') 'vmware-view://192.0.2.1/?action=start-session'
    }
    Check 'IPv6 server and port' {
        Equal (ConvertTo-HorizonUri '[2001:db8::1]:8443') 'vmware-view://[2001:db8::1]:8443/?action=start-session'
    }
    foreach ($bad in @('http://example.com', 'https://user:password@example.com',
        'example.com/login', 'example.com/?password=x', 'example.com/#x',
        'example.com other.exe', 'example.com\file', 'example.com:0')) {
        Check "reject invalid server [$bad]" { Must-Throw { ConvertTo-HorizonUri $bad } }
    }
    Check 'notes file exists and resolves despite spaces' {
        Equal (Resolve-NotesPath $notes) (Get-Item -LiteralPath $notes).FullName
    }
    Check 'missing notes rejected' {
        Must-Throw { Resolve-NotesPath (Join-Path $temp 'missing.txt') }
    }
    Check 'executable notes rejected' {
        $executable = Join-Path $temp 'not-notes.cmd'
        Set-Content -LiteralPath $executable -Value 'exit'
        Must-Throw { Resolve-NotesPath $executable }
    }
    Check 'invalid notes prevent any application launch' {
        $script:launches.Clear()
        Must-Throw { Start-HorizonWork 'horizon.example.com' (Join-Path $temp 'missing.txt') }
        Equal $script:launches.Count 0
    }
    Check 'work mode launches only Horizon then Notepad with quoted file path' {
        $script:launches.Clear()
        Start-HorizonWork 'horizon.example.com' $notes
        Equal $script:launches.Count 2
        Equal $script:launches[0].FilePath 'vmware-view://horizon.example.com/?action=start-session'
        Equal $script:launches[1].FilePath 'notepad.exe'
        Equal $script:launches[1].Arguments ('"' + $notes + '"')
    }
    Check 'website launches local Chrome with encoded URL in new window' {
        $script:launches.Clear()
        Start-WorkWebsite 'https://intranet.example.com/login?q=a b&next=home'
        Equal $script:launches.Count 1
        Equal $script:launches[0].FilePath 'C:\Program Files\Google\Chrome\Application\chrome.exe'
        Equal $script:launches[0].Arguments[0] '--new-window'
        Equal $script:launches[0].Arguments[1] '"https://intranet.example.com/login?q=a%20b&next=home"'
    }
    foreach ($bad in @('file:///C:/test.cmd', 'javascript:alert(1)', 'https://user:password@example.com')) {
        Check "reject unsupported website [$bad]" {
            $script:launches.Clear()
            Must-Throw { Start-WorkWebsite $bad }
            Equal $script:launches.Count 0
        }
    }
    Check 'all PowerShell files parse successfully' {
        foreach ($file in Get-ChildItem (Split-Path $PSScriptRoot -Parent) -Filter '*.ps1' -Recurse) {
            $tokens = $null
            $parseErrors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
            if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
        }
    }
    Write-Output "$script:passed checks passed. No real applications were launched."
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force
}
