# DrillPaper 0.1.0-rc1 — 發行閘門狀態

**DrillPaper app RC 尚未產生，不可發布或安裝。** `scripts/package.ps1 -Configuration Release -Version 0.1.0-rc1 -LocalToolchain` 實際完成 Release build 和測試後，因原生 `src/themes/theme_manager.cpp` 尚未實作而停止。沒有 app ZIP、安裝器或簽章。

另有已測試的 Theme SDK `1.0.0-rc3` 本機評估包：`artifacts/DrillPaper-Theme-SDK-1.0.0-rc3.zip`，49,107 bytes，SHA-256 `68E0B5F41FB2337B396A5335CA1707B0F6F5E275F3771EF913E1DF8210D01656`。ZIP 帶 Apache-2.0 LICENSE；解壓後 SDK tests 與兩個 `.dmt` 驗證通過。它不是 app RC。

目前 Release 仍受 Theme Manager/`.dmt` import、桌布與 Explorer GUI 驗收、Smart Sleep integration、網路設定接線及安全負面測試、長時間效能、CI 與乾淨安裝驗證阻擋。請以 [`docs/STATUS.md`](STATUS.md) 及 [`docs/FINAL_HANDOFF.md`](FINAL_HANDOFF.md) 的證據為準。本頁不是發布公告或下載通知。
