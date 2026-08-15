# Windows Disk Cleanup Session Reference

## Context
Real session: C:\ had 8.6 GB free out of 237 GB. Freed to 18.9 GB (+10.3 GB).

## Key findings by folder

### AppData\Local\Programs — 7.45 GB
Installed portable apps. Each should be checked individually:
- Perplexity\Comet (Comet Browser) — 1.8 GB after uninstall (profiles in AppData)
- Node projects with node_modules — can be 1-2 GB each
- Python .venv — 200-500 MB per project

### .cache — 1.75 GB
pip/uv/huggingface cache. Safe to delete entirely.

### .rustup — 1.18 GB + .cargo\registry — 543 MB
Rust toolchain. Only needed for Rust development. Ask user first.

### npm-cache — 883 MB + .npm — 33 MB
Node.js package cache. Safe to delete.

### pip cache — 586 MB
Python package cache. Safe to delete.

### Temp — 852 MB
Windows temp files. Safe to delete (some files may be locked).

### Edge + Chrome cache — 40 + 28 MB
Browser caches. Safe to delete.

### Downloads — 4.5 GB
Old installers (Auto-Claude 191MB, kiro-ide 187MB, Windsurf 162MB, Cursor 139MB, Antigravity 152MB, GitHub-Store 153MB), old archives (whatsapp_2.2325.3.zip 184MB from 2024). Ask user which to remove.

### Documents — 6 GB
- "Резерв Outlook" (archive.pst) — 1.3 GB. Outlook PST archive. Ask before deleting.
- "1-С База" — 1.3 GB. 1С database. Ask before deleting.
- Wondershare — 1 GB. Portable app. Ask.
- ABBYY FineReader Portable — 0.7 GB. Portable app. Ask.

## Per-step space gains (real session)

| Step | Freed | C:\ free |
|---|---|---|
| Was (before) | — | 8.6 GB |
| Caches (Temp, .cache, npm, pip, Edge, Chrome) | +3.2 GB | 11.8 GB |
| Installers from Downloads (7 files) | +1.2 GB | 13.0 GB |
| Rust toolchain (.rustup + .cargo) | +1.3 GB | 14.3 GB |
| Comet Browser (uninstall + AppData leftover) | +1.8 GB | 16.0 GB |
| Hermes-agent repo on Windows (cmd /c rmdir) | +2.9 GB | 18.9 GB |

## Typical cleanup sequence

1. Check df -h for both / and /mnt/c to identify where the problem is
2. Clean /tmp/ on WSL (camoufox installers, APK files, temp scripts — often 1-2 GB)
3. On Windows: check caches first (safe wins, 3-5 GB)
4. Present findings as numbered list, let user choose
5. Check Downloads top-10 largest files, user picks which to delete
6. Check Documents large folders, ask before deleting
7. Use cleanmgr /lowdisk for Windows Update cleanup
8. Track freed space per step, present final table

## Tools that work from WSL

- `cmd /c rmdir /s /q "path"` — fastest for large dirs (node_modules)
- `powershell.exe -Command "Get-PSDrive C"` — check disk space
- `powershell.exe -Command "Start-Process cleanmgr.exe -ArgumentList '/lowdisk' -Wait"` — Windows Disk Cleanup GUI
- PowerShell scripts on `C:\Users\Public\` — for any complex cleanup with $_ or env vars
