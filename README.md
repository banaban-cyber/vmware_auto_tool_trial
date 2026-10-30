# 工作模式啟動器

Windows 10／11 的本機小工具，使用內建 Windows PowerShell 5.1 與視窗元件，免裝 Python、Node.js 或 Chrome 擴充功能。

## 功能

- 按「進入工作模式」：透過 `vmware-view://…/?action=start-session` 要求 Horizon Client 連線唯一指定的 Server，再用記事本開啟你事先準備的 `.txt`。
- 按「登入完成，開啟 Chrome」：在**本機** Chrome 新視窗開啟指定網址。
- 記住 Server、文字檔路徑與網址。之後雙擊啟動器、按一次按鈕即可進入工作模式。

第一版以手動按鈕切換工作模式；不偵測 Windows 模式或背景監控。啟動 Client 不等於已成功登入，工具無法判斷 Horizon 的驗證、MFA 或桌面連線狀態，因此不使用倒數計時假裝連線完成。Chrome 按鈕由你在登入完成後操作；尚未實作網頁帳密自動填寫。

## 本機使用

1. 安裝 VMware／Omnissa Horizon Client，確認能手動連線公司 Server，並已註冊 `vmware-view` URL 通訊協定。公司所需 VPN 也請先連好。
2. 將本目錄下載到 Windows 的固定位置。用記事本準備自己的文字檔，例如 `C:\Users\你的名字\Documents\work-notes.txt`，可包含你需要的帳號及遠端 IP。
3. 雙擊 `Start-WorkMode.cmd`。若出現下載檔案封鎖提示，先檢閱列出的兩個腳本，確認信任後輸入 `YES`；只會解除這兩個檔案的下載標記，不修改系統原則。
4. 填入 Server，例如 `horizon.company.com` 或 `https://horizon.company.com:443`；選擇文字檔；選填本機 Chrome 網址，例如 `https://intranet.company.com/login`。
5. 按「儲存設定」或直接按「進入工作模式」。在 Horizon 完成公司要求的登入，再按 Chrome 按鈕。

可為 `Start-WorkMode.cmd` 建立桌面捷徑，或在捷徑內容設定快速鍵。

設定儲存在 `%LOCALAPPDATA%\WorkModeLauncher\settings.json`。移除該資料夾可重設偏好，不會刪除你的文字檔。

啟動器以目前程序的 `RemoteSigned` 原則執行，不修改系統執行原則。若 Windows 將下載的腳本標記為網際網路檔案，啟動器會在執行腳本前詢問是否解除 `WorkMode.ps1` 與 `WorkMode.Core.ps1` 的下載封鎖。直接按 Enter 可取消。若公司群組原則要求簽署腳本或禁止腳本執行，啟動器會停止，請使用公司核准的方式。

### 舊版出現「未經數位簽署／PSSecurityException」

這通常是 GitHub ZIP 解壓後的腳本仍帶有 Windows 下載標記。可以下載最新版，或針對既有檔案處理：

1. 確認信任程式碼後，在 `WorkMode.ps1` 上按右鍵 →「內容」→ 勾選「解除封鎖」→「套用」。
2. 對同資料夾的 `WorkMode.Core.ps1` 做相同操作。
3. 再雙擊 `Start-WorkMode.cmd`。

也可以在這兩個腳本所在的資料夾開啟 PowerShell，執行下列指令（不需要系統管理員權限）：

```powershell
Unblock-File -LiteralPath .\WorkMode.ps1, .\WorkMode.Core.ps1
```

如果沒有「解除封鎖」選項，或處理後仍然被擋，執行 `Get-ExecutionPolicy -List` 查看是否有 `MachinePolicy` 或 `UserPolicy` 限制；若有，交由公司 IT 確認可用方式。

## 帳密與後續擴充

工具不讀取文字檔內容，也不把帳密放入 Horizon 命令列、網址或設定檔。若你自行在文字檔放密碼，它仍是明文；請留在自己的受控資料夾，避免上傳 Git 或分享。較佳做法是文字檔只放帳號／IP，密碼交由公司允許的密碼管理器處理。

Chrome 的普通擴充功能無法直接任意啟動 Windows 程式，通常還需要本機 Native Messaging 主程式；目前需求用本機啟動器較簡單。若後續要自動填寫本機登入頁，可針對該網站做擴充功能：需要登入頁網址與欄位結構，再選擇公司允許的密碼管理方式。請勿提供真實密碼；MFA／驗證碼仍依公司流程完成。

## 驗證

核心測試不開啟實際 Client、記事本或 Chrome：

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Core.Tests.ps1
```

完整流程須在 Windows 本機驗收：固定 Server 正確開啟、記事本顯示選定檔案、完成 Horizon 登入後 Chrome 開啟正確網頁。本專案的 Linux 雲端無法驗證 Windows GUI、實際 Horizon 連線與公司網站登入。
