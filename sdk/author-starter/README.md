# TypeScript 離線主題範本

此範本顯示 API v1 握手、CPU／GPU／RAM／磁碟／網路單位、unavailable 與持續更新，各目標依自己的 viewport 排版。第三方主題一律視為不受信任內容；目前沒有完整沙箱保證。

## 安裝

先解壓 SDK ZIP，再把本目錄完整複製到新的作者目錄，例如 `%USERPROFILE%\DrillPaperTests\我的主題`。以下在新目錄的 PowerShell 執行；`$sdkRoot` 須指向包含 `sdk` 與 `scripts` 的實際解壓根目錄：

```powershell
$sdkRoot = Join-Path $env:USERPROFILE 'DrillPaperTests\SDK'
npm ci --ignore-scripts --no-audit --no-fund
npm run configure -- (Join-Path $sdkRoot 'sdk\javascript')
npm run check
npm run build
```

作者環境需要 Node.js 22+、npm 及 PowerShell；`package-lock.json` 固定 TypeScript 5.9.3 與套件 integrity。首次 npm ci 需取得 compiler，之後建置只讀本機檔案。`check` 實際呼叫 compiler，正確 SDK／MockHost 用法必須通過，四個錯誤用法必須得到指定診斷；不是以 Node 執行 TypeScript 代替型別檢查。`configure` 必須提供 SDK 宣告目錄，缺檔即停止。

## 使用

修改 `static/theme.json` 的 id、名稱、作者與版本，編輯 `src/main.ts` 和 `static/` 內 HTML／CSS。再次 `npm run check`、`npm run build`。`src` 的 `.d.ts` 僅供編譯；`dist` 只有編譯 JS、HTML、CSS、manifest，不含 compiler、Node、來源或宣告。

```powershell
$themePackage = Join-Path (Split-Path -Parent $PWD.Path) 'my-theme.dmt'
& (Join-Path $sdkRoot 'scripts\package-theme.ps1') -ThemeDirectory .\dist -OutputFile $themePackage
& (Join-Path $sdkRoot 'scripts\validate-theme-package.ps1') -Path $themePackage
```

SDK 執行模組由正式封裝器加入，請勿自行在 dist 放入同名 `desktop-monitor-sdk.js`／`mock-host.js`，以免碰到保留名稱檢查。不要直接封裝整個作者目錄；`.ts`／`.d.ts`／`.mjs` 不在匯入白名單內。打包後 app 離線執行不需要作者目錄、Node 或 TypeScript。

於 DrillPaper 原生管理視窗匯入 `.dmt`，選擇主題並預覽，再勾選目標、選桌布模式並套用儲存。同 id／version 不覆寫；更新時增加版本，或切換至 Minimal 後從管理視窗確認移除舊版本，再重新匯入。內建主題不可移除。沒有提供 HTML 管理命令；網路預設關閉，範本無外部依賴。詳見 SDK 的 `docs/theme-sdk.md` 與 `docs/theme-security.md`。
