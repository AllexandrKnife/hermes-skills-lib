---
name: windows-admin-tasks-from-wsl
title: Windows Admin Tasks from WSL (no PowerShell interop / no admin)
description: Use when powershell.exe fails or admin Windows ops from WSL.
critic_status: done
domain: devops
tags: [wsl, windows, admin, cleanup, interop, powershell, vssadmin, dism]
priority: medium
triggers:
  - "powershell.exe fails with Exec format error / cannot execute binary file from WSL"
  - "user asks to clean Windows disk / free C: space without admin"
  - "admin-only Windows operation needed (restore points, WinSxS, $WinREAgent)"
  - "проверь interop WSL / включи powershell из WSL"
  - "no admin available for Windows cleanup"
---

# Windows Admin Tasks from WSL (no interop / no admin)

## When to Use

Trigger conditions: `powershell.exe` from WSL fails (Exec format error), user asks to free C: space / clean Windows disk without admin, or the operation is admin-only (restore points, WinSxS, $WinREAgent). Companion to `wsl-windows-interop` (Windows state querying + cleanup WITH working PowerShell). Use THIS skill when `powershell.exe` does not run from WSL, or when the operation itself requires Windows elevation that WSL cannot provide.

## 1. Interop check + fix

Symptom: `powershell.exe -Command "..."` → `cannot execute binary file: Exec format error`.

```bash
cat /proc/sys/fs/binfmt_misc/WSLInterop   # entry MISSING → interop is OFF
cat /proc/sys/fs/binfmt_misc/status       # 'enabled' = binfmt works, just no WSL entry
```

Fix (needs a Windows-side restart, which KILLS a live Hermes session — warn the user first):
- Permanent: add to `/etc/wsl.conf` `[interop] enabled=true`, then `wsl --shutdown` from Windows and restart the distro.
- Until reboot (root in WSL): `echo 1 > /proc/sys/fs/binfmt_misc/WSLInterop`.

Do NOT treat "powershell.exe doesn't work" as a permanent fact — it is a config state with a documented fix. Until fixed, proceed with sections 2-4.

## 2. Fallback: pure-WSL (9p) operations on /mnt/c

- **Targeted `du -sh` works** on small/medium dirs (Temp, Downloads, single cache dirs — seconds). Large trees (C:\Windows, whole AppData, dirs with many small files) hang 10-20+ min — run background + notify_on_complete and continue other work, or skip the measurement if the decision doesn't need the exact number.
- **`rm -rf` from /mnt/c works for user-writable dirs** (Downloads installers, Temp contents, cache contents). Locked in-use files fail with `Permission denied` and are silently skipped — normal, they free on reboot. Verify with `df -h /mnt/c` before/after.
- **TrustedInstaller-protected dirs cannot be removed from WSL** ($WinREAgent, WinSxS, SoftwareDistribution, other users' profiles) — hand off (section 4).
- Never `rm -rf` a user folder wholesale — delete by explicit file list (section 3).

## 3. Safety rules (apply to every destructive step)

- **Selective delete even after batch approval**: «удали установочники из Downloads» → delete ONLY installer extensions (.exe/.msi/.apk) by explicit filename list. NEVER delete identifiable data files (Backup-codes*.txt, document.*/.doc/.docx) just because they sit in Downloads. Re-verify the data files still exist after deletion.
- **Clarify timeout → report only**: if the user doesn't confirm within the limit, delete NOTHING; present findings and re-ask. Applies to every destructive step, even "safe" caches.
- Before/after each batch: `df -h /mnt/c | tail -1` and confirm the freed delta; report per-step freed space.
- Categorize findings as Safe / User-data / Program and present as a numbered table; user picks numbers.

## 4. Admin handoff block (user runs elevated)

User runs these one at a time in «Командная строка» as Administrator. State expected yield for each.

```cmd
:: Restore points (5-15 GB typical) — see size first
vssadmin list shadowstorage
vssadmin delete shadows /for=C: /all /quiet
vssadmin resize shadowstorage /for=C: /on=C: /maxsize=5GB   :: cap regrowth

:: $WinREAgent (0.5-2 GB, leftover WinRE cache after updates)
rd /s /q C:\$WinREAgent          :: skip if "занят" — Windows cleans it itself

:: WinSxS component store (2-10 GB, slow)
DISM /Online /Cleanup-Image /StartComponentCleanup
:: NO /ResetBase unless user accepts losing update rollback

:: GUI cleanup — user ticks «Очистка обновлений Windows», «Временные файлы»,
:: «Файлы оптимизации доставки», «Корзина»
cleanmgr /d C:
```

Expected total on a 94%-full disk: 10-25 GB; the first 1-2 GB (Downloads installers + Temp) is reachable without admin from WSL.

## 5. Pitfalls

- Sizing C:\Windows from WSL is a trap: it burns 10-20 min in background and the number doesn't change the plan (DISM/cleanmgr handle it) — skip it.
- `du -sh /mnt/c/<dir>/*` (per-child) times out faster than whole-dir du on file-heavy dirs — avoid per-child du on big dirs.
- cyrillic usernames in /mnt/c paths: quote the path, works fine.
- After cleanup, if free space is still <10%, the remaining fix is admin-only (restore points, DISM) — say so plainly, don't invent more "safe" targets.
