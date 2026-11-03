; DrillPaper 使用者層級安裝檔（Inno Setup 6）。
; 由 scripts/build-installer.ps1 呼叫 ISCC 並以 /D 傳入下列定義；不要直接手動編譯。
;   AppVersion        試用版號，例如 0.1.0-trial.9
;   NumericVersion    檔案版本資訊用的數字版號，例如 0.1.0.0
;   SourceDir         已通過 verify-trial-archive.ps1 驗證並解壓的試用包目錄（白名單內容）
;   OutputDir         安裝檔輸出目錄
;   OutputBaseFilename 安裝檔檔名（不含 .exe）
; 決策見 .scratch/rc-delivery/issues/17-inno-setup-installer.md：只做使用者層級、不需管理員權限、
; 靜態 CRT 不需 VC++、解除安裝時詢問是否刪除使用者資料（預設保留）、安裝檔與 EXE 皆未簽章。

#ifndef AppVersion
  #error 缺少 AppVersion 定義，請使用 scripts/build-installer.ps1 產生安裝檔。
#endif
#ifndef NumericVersion
  #error 缺少 NumericVersion 定義。
#endif
#ifndef SourceDir
  #error 缺少 SourceDir 定義。
#endif
#ifndef OutputDir
  #error 缺少 OutputDir 定義。
#endif
#ifndef OutputBaseFilename
  #error 缺少 OutputBaseFilename 定義。
#endif

[Setup]
AppId={{DC8FDCBC-C926-406F-9B9C-DBA6294EAD9C}
AppName=DrillPaper
AppVersion={#AppVersion}
AppVerName=DrillPaper {#AppVersion}（試用版，未簽章）
AppPublisher=DrillPaper
VersionInfoVersion={#NumericVersion}
VersionInfoProductVersion={#NumericVersion}
VersionInfoDescription=DrillPaper 安裝程式（試用版，未簽章）
DefaultDirName={localappdata}\Programs\DrillPaper
DisableProgramGroupPage=yes
DisableDirPage=auto
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBaseFilename}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\DrillPaper.exe
UninstallDisplayName=DrillPaper（試用版）
; 由 [Code] 透過 DrillPaper.exe --exit-running 正式結束同路徑實例，不使用 Restart Manager 強制關閉。
CloseApplications=no
RestartApplications=no
SetupLogging=yes

[Languages]
Name: "chinesetraditional"; MessagesFile: "ChineseTraditional.isl"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{userprograms}\DrillPaper"; Filename: "{app}\DrillPaper.exe"; Parameters: "--management"; WorkingDir: "{app}"; Comment: "開啟 DrillPaper 管理視窗"

[Run]
Filename: "{app}\DrillPaper.exe"; Parameters: "--management"; WorkingDir: "{app}"; Description: "立即啟動 DrillPaper"; Flags: nowait postinstall skipifsilent

[Code]
const
  WebView2ClientKey = 'Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}';
  WebView2Url = 'https://developer.microsoft.com/microsoft-edge/webview2/';

{ 讀取 WebView2 Evergreen Runtime 版本；未安裝時回傳空字串。 }
function WebView2Version(): String;
var
  Version: String;
begin
  Result := '';
  if RegQueryStringValue(HKLM, 'SOFTWARE\WOW6432Node\' + WebView2ClientKey, 'pv', Version) or
     RegQueryStringValue(HKCU, 'Software\' + WebView2ClientKey, 'pv', Version) then
    if (Version <> '') and (Version <> '0.0.0.0') then
      Result := Version;
end;

{ 要求同一路徑的執行中 DrillPaper 正式結束；回傳是否已沒有執行中的實例。 }
function ExitRunningInstances(const Executable: String): Boolean;
var
  Code: Integer;
begin
  Result := True;
  if not FileExists(Executable) then
    exit;
  if not Exec(Executable, '--exit-running', ExtractFileDir(Executable), SW_HIDE, ewWaitUntilTerminated, Code) then
    Result := False
  else
    Result := (Code = 0);
  Log(Format('DrillPaper --exit-running 結束碼：%d', [Code]));
end;

{ 安裝前檢查 WebView2；缺少時說明取得方式並由使用者決定是否繼續。 }
function InitializeSetup(): Boolean;
begin
  Result := True;
  if WebView2Version() = '' then
    Result := SuppressibleMsgBox(
      '找不到 Microsoft Edge WebView2 Runtime（Evergreen）。DrillPaper 需要它才能顯示桌布主題。' + #13#10#13#10 +
      '可由一般使用者自行安裝，下載網址：' + #13#10 + WebView2Url + #13#10#13#10 +
      '是否仍要繼續安裝？（之後安裝 WebView2 即可使用）',
      mbConfirmation, MB_YESNO, IDYES) = IDYES;
end;

{ 覆蓋安裝前正式結束執行中的同路徑實例，避免檔案被鎖住或被強制終止。 }
function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  if not ExitRunningInstances(ExpandConstant('{app}\DrillPaper.exe')) then
    Result := '無法自動結束執行中的 DrillPaper。請從系統匣圖示選擇「結束 DrillPaper」後再重新執行安裝。';
end;

{ 解除安裝前正式結束執行中的實例。 }
function InitializeUninstall(): Boolean;
begin
  Result := ExitRunningInstances(ExpandConstant('{app}\DrillPaper.exe'));
  if not Result then
    SuppressibleMsgBox('無法自動結束執行中的 DrillPaper。請從系統匣圖示選擇「結束 DrillPaper」後再解除安裝。',
      mbError, MB_OK, IDOK);
end;

{ 解除安裝完成後詢問是否刪除使用者資料；預設與靜默解除安裝一律保留。
  資料位置與 app 相同，取自 LOCALAPPDATA 環境變數。 }
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  DataDir: String;
begin
  if CurUninstallStep <> usPostUninstall then
    exit;
  DataDir := AddBackslash(GetEnv('LOCALAPPDATA')) + 'DrillPaper';
  if (GetEnv('LOCALAPPDATA') = '') or not DirExists(DataDir) then
    exit;
  if UninstallSilent then
  begin
    Log('靜默解除安裝，保留使用者資料：' + DataDir);
    exit;
  end;
  { 按鈕直接標示動作，避免與前一題「確定要移除？」的「是」混淆；第一個（預設）按鈕為保留。 }
  if TaskDialogMsgBox('要保留 DrillPaper 的使用者資料嗎？',
      '程式已移除。使用者資料包含設定、匯入的主題與日誌：' + #13#10 + DataDir + #13#10#13#10 +
      '保留資料後重新安裝可繼續使用；刪除後無法復原。',
      mbConfirmation, MB_YESNO, ['保留資料（建議）', '刪除資料'], 0) = IDNO then
  begin
    if DelTree(DataDir, True, True, True) then
      Log('已刪除使用者資料：' + DataDir)
    else
      MsgBox('部分使用者資料無法刪除，請手動刪除：' + #13#10 + DataDir, mbError, MB_OK);
  end
  else
    Log('使用者選擇保留資料：' + DataDir);
end;
