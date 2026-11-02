# RC 11 CI 證據（09-G1／A14）

分支 `feature/rc-11-gate-evidence`。只對 feature 分支執行，沒有合併 main、建立 release 或 tag。runner 為 GitHub-hosted `windows-2022`。

## 正式 workflow `windows.yml`（run 41396242703）

- 觸發：`workflow_dispatch`，`build_release_candidate=true`。精確 SHA `ae1c5e05e5562cd0297bcf22abf2e06b3749836f`，時間 2026-11-02 05:49:26～05:57:31Z。
- `windows-build-test`：**PASS**。包含 SDK／manifest 測試、主題 ZIP 正負驗證、還原釘選版本的 WebView2 SDK、bootstrap 邊界、Release configure／build 與 CTest。
- `release-candidate`：**FAIL，屬預期的 gate 拒絕**。同一 job 先跑完 CTest **53/53**，接著 `scripts/package.ps1` 擋下 RC 打包並丟出：「Release Candidate packaging is blocked: Release readiness is not established: native theme management, security, lifecycle and installation acceptance remain incomplete.」
- 產物：只有 `drillpaper-theme-sdk-examples`（14066 bytes），**沒有** `drillpaper-release-candidate-unsigned`。這證明 gate 拒絕時不會產生正式 RC 產物，沒有把 skipped 當成 PASS。

## 試用 workflow `trial.yml`

`trial.yml` 原本只有 `workflow_dispatch`，但 GitHub 只允許對預設分支已有的 workflow 手動觸發，因此依使用者決策加上 `feature/rc-*` 推送觸發。

- run 41396567346（a7f66a8）以及其後同類 run：**FAIL**。「Verify delivery inventory and hashes」這一步中，`verify-trial-archive.ps1` 已印出 PASS，但成功路徑沒有設定退出碼，`$LASTEXITCODE` 為 null，workflow 的 `$LASTEXITCODE -ne 0` 因此誤判失敗。此問題已在本機重現：null 會判為 wouldThrow=True。屬 CI／工具缺陷，不是產品問題。只改紀錄文件時重複觸發的 run 已取消。
- 修正 `c6951cf`：
  - 腳本成功時明確 `exit 0`。本機驗證成功時為 0、來源不符時為 1，`test-trial-package.ps1` 也通過。
  - `trial.yml` 加 `paths-ignore: docs/**, .scratch/**`，並設定同分支 concurrency 取消舊 run。
- run 41400372470（`c6951cf4da3a7579eb3998e589ee2925c783da33`）：**PASS**。
  - 相關 CTest 15/15。
  - 封裝契約正負案例 PASS。
  - 從精確 SHA 乾淨建置 `DrillPaper-0.1.0-trial.ci.7-win-x64-unsigned.zip`，SHA-256 `BD90E76ACB37CE3D41DC6DBB9F07350251F40BCF60747D6458437120D2025A62`。
  - 交付清單與 hash 驗證 PASS。
  - 產物 `drillpaper-trial-unsigned`（463206 bytes，artifact id 13121535485）。

## 判讀

- G1 中「精確 SHA 的 Windows configure／build／實際測試數」與「gate 拒絕時無 RC 產物」已有證據。
- CI 產出的是試用包，不是正式 RC。正式 RC 產物要在所有必要 gate 通過後才可能產生，目前仍拒絕放行。
- 本機互動測試使用的 trial.8（`ae1c5e0`）與 CI 的 trial.ci.7（`c6951cf`）之間只差 CI、工具與文件變更，產品來源相同。
