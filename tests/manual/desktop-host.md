# DesktopHost manual verification

Run these checks on each Windows build listed in `docs/compatibility-matrix.md`. Save the exact OS build and results. A Shell window enumeration is diagnostic evidence only; it does not prove a wallpaper window attaches correctly.

## Shell inventory

1. Run `powershell -ExecutionPolicy Bypass -File scripts/inspect-shell.ps1`.
2. Save the `Progman`, `WorkerW`, and `SHELLDLL_DefView` rows with the OS build.
3. Repeat after restarting Explorer.

## Application GUI gate

1. Start the app in `--preview`; confirm it opens, stays out of the desktop layer, and closes cleanly.
2. Start the experimental desktop host; confirm desktop icons and context menus remain clickable, the taskbar works, and Alt+Tab has no extra wallpaper entry.
3. Check focus, Win+D, virtual desktops, maximized/full-screen windows, taskbar auto-hide, resolution/DPI changes, lock/unlock, sleep/wake, and monitor removal.
4. Restart Explorer; confirm the host recovers or returns to a visible preview with an error.
5. Close the app; confirm no Explorer window or wallpaper state is left altered.

Current result: NOT RUN. The application has not been built, so no desktop attachment claim is made.
