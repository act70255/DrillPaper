# DesktopMonitor agent instructions

- Before changing product behavior, read `DesktopMonitor_Codex_Handoff.md` and the relevant entry in `docs/STATUS.md`.
- Keep collection, runtime policy, Win32 hosting, WebView2, and theme loading behind the boundaries in `docs/ARCHITECTURE.md`.
- Use the confirmed public test seams: metrics values and collectors, runtime state and bounded queues, theme manifest/package validation, and protocol/SDK behavior. Write one failing behavior test before its smallest implementation, then run it and the related checks.
- Record each phase's scope, commands, results, blockers, and commit in `docs/STATUS.md`. Mark anything not executed `NOT RUN` and include why.
- 每階段完成其實作與相關驗證後，先更新 `docs/STATUS.md`，再使用 `commit-msg` skill 產生繁體中文 Conventional Commit，立即 commit 並 push 該階段功能分支至 `origin`；不等待全部階段結束。
- Treat desktop attachment, WebView2 rendering, power/session handling, and physical hardware reads as Windows integration checks. Unit tests do not establish those results.
- Treat imported themes as untrusted content. Document and test each enforced boundary; claim sandboxing only when the boundary has been demonstrated.
- Preserve the handoff's C++20, Win32, WebView2, offline theme, least-privilege, and no-telemetry requirements. Record alternatives in `docs/adr/`.
