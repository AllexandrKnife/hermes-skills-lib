# WSL vhdx migration to USB/another drive (no admin) — verified 08.2026

Scenario: C: is full (5.5G free of 237G), the WSL distro's ext4.vhdx (28.5G) is the
big movable asset, no D: drive, admin rights absent. Goal: move the distro (hosting
Hermes) to a USB stick.

## Key facts established on dkolchin's machine (WSL 2.6.3.0, Win10 19044)

- Manually imported distro (wsl --import) vhdx lives at
  `C:\Users\<user>\AppData\Local\wsl\{GUID}\ext4.vhdx` — NOT under Packages.
  Locate fast from WSL (no Windows processes):
  `find /mnt/c/Users/<user>/AppData/Local -maxdepth 4 -iname "*.vhdx" 2>/dev/null`
  (find -maxdepth 2 from /mnt/c misses it — too shallow).
- `wsl --manage <distro> --set-sparse true` is DISABLED in WSL 2.6.3:
  exit `Wsl/Service/E_INVALIDARG`, message: «Поддержка разреженного VHD в настоящее
  время отключена из-за возможного повреждения данных. Чтобы принудительно
  использовать разреженный VHD... выполните: wsl.exe --manage <имя> --set-sparse --allow-unsafe».
  → compaction requires `--allow-unsafe` = explicit data-corruption risk.
- `fstrim -av` inside the guest alone does NOT shrink the vhdx: after fstrim
  (986 GiB trimmed) + wsl --shutdown the file stayed 28.5G. Sparse flag is what
  releases blocks, and it is gated.
- There is NO distro rename in WSL: the original name stays busy until the original
  distro is unregistered — re-registration under the real name must come after
  `wsl --unregister <orig>`.
- `wsl --unregister <distro>` deletes the registered vhdx file (frees the space).
- `wsl --export` needs ~17-19G tar — does not fit a full C: (5.5G free). Use
  --import-in-place instead.
- Target volume MUST be NTFS (exFAT/FAT32 unsupported for WSL2 vhdx; FAT32 caps
  files at 4G anyway). Verify with `Get-Volume -DriveLetter E | Format-List
  FileSystem,Size,SizeRemaining` (from WSL: `powershell.exe -NoProfile -Command ...`).

## Safe migration order (data-loss-safe, no admin)

Principle the user insisted on: delete the original ONLY after the copy is proven
bootable. Because the name is busy, the proof runs under a TEMP name.

1. `wsl --shutdown` ; check `wsl --list --verbose` → STATE Stopped.
2. Copy (long, do not interrupt): robocopy copies faster than explorer for big files:
   ```
   robocopy "C:\Users\<user>\AppData\Local\wsl\{GUID}" "E:\WSL\Ubuntu-22.04" ext4.vhdx /J /R:2 /W:2
   ```
   Verify size match:
   ```
   (Get-Item "C:\Users\<user>\AppData\Local\wsl\{GUID}\ext4.vhdx").Length -eq (Get-Item "E:\WSL\Ubuntu-22.04\ext4.vhdx").Length
   ```
   → True, else STOP (bad copy).
3. Register the copy under a temp name and boot-verify non-interactively:
   ```
   wsl --import-in-place Ubuntu-test "E:\WSL\Ubuntu-22.04\ext4.vhdx"
   wsl -d Ubuntu-test -c "df -h /; ls /root; echo CHECK_OK"
   ```
   OK only if CHECK_OK printed and data visible. On error — STOP, original untouched.
   Then drop the temp registration (file on USB is NOT deleted):
   ```
   wsl --unregister Ubuntu-test
   ```
4. Only after step 3 succeeded AND explicit user confirmation:
   ```
   wsl --unregister Ubuntu-22.04
   ```
   (frees the 28.5G on C:).
5. Re-register under the real name (instant, no re-copy):
   ```
   wsl --import-in-place Ubuntu-22.04 "E:\WSL\Ubuntu-22.04\ext4.vhdx"
   ```
6. Final check:
   ```
   wsl -d Ubuntu-22.04 -c "df -h /; echo RUN_OK"
   (Get-PSDrive C).Free/1GB   # expect ~34G free (5.5 + 28.5)
   ```

Warnings to repeat to the user:
- wsl --shutdown kills the Hermes session itself if the agent runs inside the
  distro — the agent cannot confirm the result; plan a restart after import.
- USB must stay plugged for the distro to run; USB 2.0 makes everything slow.
- Corporate laptop: USB writes may be blocked/logged by endpoint security —
  moving the work environment to removable media is a perimeter concern.
- The USB often already holds personal data — never format it, just add a folder.

## Delegation to Qwen Code (user pattern)

The user runs such multi-step Windows-side operations via Qwen Code CLI. Prompt
must include: exact source/target paths, the GUID dir, NTFS requirement, the
stop-rules (no self-directed fixes, no unregister without explicit user
confirmation, no commands outside the plan), per-step expected outputs
(Stopped / True / CHECK_OK / RUN_OK / free-space number), and an explicit
"report what actually happened, don't claim success". Full ready-to-paste prompt
was delivered in session 2026-08-10.
