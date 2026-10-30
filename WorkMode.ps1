# Windows PowerShell 5.1; save this file as UTF-8 with BOM.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'WorkMode.Core.ps1')
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$settingsDir = Join-Path $env:LOCALAPPDATA 'WorkModeLauncher'
$settingsPath = Join-Path $settingsDir 'settings.json'
$form = New-Object System.Windows.Forms.Form
$form.Text = '工作模式啟動器'
$form.ClientSize = New-Object System.Drawing.Size(620, 365)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.Font = New-Object System.Drawing.Font('Microsoft JhengHei', 10)

function Add-Label([string]$Text, [int]$Y) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.SetBounds(20, $Y, 580, 24)
    $form.Controls.Add($label)
}
function Add-Input([int]$Y, [int]$Width = 580) {
    $inputBox = New-Object System.Windows.Forms.TextBox
    $inputBox.SetBounds(20, $Y, $Width, 28)
    $form.Controls.Add($inputBox)
    return $inputBox
}
function Add-Button([string]$Text, [int]$X, [int]$Y, [int]$Width) {
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.SetBounds($X, $Y, $Width, 36)
    $form.Controls.Add($button)
    return $button
}
Add-Label 'Horizon Server（例如 horizon.company.com）' 16
$serverBox = Add-Input 44
Add-Label '你準備好的文字檔（只記住路徑，不讀取內容）' 82
$notesBox = Add-Input 110 475
$browseButton = Add-Button '選擇檔案' 505 106 95
Add-Label '本機 Chrome 網址（選填；登入 Horizon 後再按下方按鈕）' 150
$urlBox = Add-Input 178
$saveButton = Add-Button '儲存設定' 20 222 115
$startButton = Add-Button '進入工作模式' 145 222 185
$webButton = Add-Button '登入完成，開啟 Chrome' 340 222 260
$status = New-Object System.Windows.Forms.Label
$status.SetBounds(20, 273, 580, 76)
$status.Text = '先填入固定 Server 與文字檔路徑，再按「進入工作模式」。'
$form.Controls.Add($status)

function Show-Problem($Problem) {
    [System.Windows.Forms.MessageBox]::Show(
        [string]$Problem, '無法完成操作', 'OK', 'Warning') | Out-Null
}
function Save-Settings {
    # Only non-secret preferences are saved; the notes file is never read.
    $null = ConvertTo-HorizonUri $serverBox.Text
    $null = Resolve-NotesPath $notesBox.Text
    if ($urlBox.Text.Trim()) { $null = ConvertTo-WebUrl $urlBox.Text }
    $null = New-Item -ItemType Directory -Path $settingsDir -Force
    $settings = @{
        server = $serverBox.Text.Trim()
        notesPath = $notesBox.Text.Trim()
        webUrl = $urlBox.Text.Trim()
    }
    $settings | ConvertTo-Json | Set-Content -LiteralPath $settingsPath -Encoding UTF8
}

if (Test-Path -LiteralPath $settingsPath) {
    try {
        $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
        $serverBox.Text = [string]$settings.server
        $notesBox.Text = [string]$settings.notesPath
        $urlBox.Text = [string]$settings.webUrl
    } catch {
        $status.Text = '原設定無法讀取，請重新填寫並儲存。'
    }
}
$browseButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = '文字檔 (*.txt)|*.txt'
    if ($dialog.ShowDialog() -eq 'OK') { $notesBox.Text = $dialog.FileName }
    $dialog.Dispose()
})
$saveButton.Add_Click({
    try { Save-Settings; $status.Text = '已儲存 Server、檔案路徑與網址。' }
    catch { Show-Problem $_.Exception.Message }
})
$startButton.Add_Click({
    try {
        Save-Settings
        Start-HorizonWork -Server $serverBox.Text -NotesPath $notesBox.Text
        $status.Text = '已送出 Horizon 連線要求並開啟文字檔。請在 Client 完成登入／MFA；此工具無法確認連線成功。'
    } catch {
        Show-Problem ($_.Exception.Message + "`n請確認已安裝 Horizon Client，且 Windows 已註冊 vmware-view 通訊協定。")
    }
})
$webButton.Add_Click({
    try {
        Start-WorkWebsite -Url $urlBox.Text
        $status.Text = '已要求本機 Chrome 開啟網址；請在網頁完成登入。'
    } catch { Show-Problem $_.Exception.Message }
})
$form.AcceptButton = $startButton
[void]$form.ShowDialog()
$form.Dispose()
