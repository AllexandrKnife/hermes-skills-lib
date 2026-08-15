# WSL PATH pollution → subprocess PermissionError (execvp EACCES)

Case (2026-08-01): `hermes doctor` crashed at the end with
`PermissionError: [Errno 13] Permission denied: 'gh'` in `_gh_authenticated()`
(doctor.py). Root cause was NOT a broken gh — it was PATH semantics.

## Root cause chain

1. Windows PATH (BOTH user and machine scope) contained
   `C:\WINDOWS\system32\config\systemprofile\AppData\Local\Microsoft\WindowsApps`
   — the SYSTEM profile's WindowsApps dir. Junk in a user PATH (only the
   SYSTEM account needs it), likely injected by something running as SYSTEM.
2. WSL appends the Windows PATH to the Linux PATH (default interop behavior).
3. From Linux, `stat()` on that dir returns EACCES (drvfs surfaces the
   Windows ACL denial as permission denied — even `ls` fails).
4. glibc `execvp` semantics: on EACCES from stat() for ANY PATH candidate it
   ABORTS the search with EACCES (only ENOENT continues to the next entry).
   So `subprocess.run(["gh", ...])` raises `PermissionError`, never the
   `FileNotFoundError` the caller expects.
5. `_gh_authenticated()` caught only `(FileNotFoundError, TimeoutExpired)` →
   crash.

## Scope

ANY `subprocess.run(["<missing-cmd>"])` in that environment raised
PermissionError (verified with `definitely-not-a-real-cmd-xyz`). Interactive
bash is NOT affected (bash does its own access() checks and skips
inaccessible entries); only execvp-based searches break (Python subprocess,
C execvp). So this breaks hermes doctor, Python scripts, and any tool that
probes for optional CLIs.

## Diagnosis recipe

```bash
# 1. Repro — should be FileNotFoundError, comes out PermissionError:
python3 -c "import subprocess; subprocess.run(['definitely-not-a-real-cmd-xyz'], capture_output=True)"

# 2. Pinpoint the offending PATH entry (errno != 2):
python3 - <<'EOF'
import os
for d in os.environ["PATH"].split(":"):
    if not d: continue
    try: os.stat(os.path.join(d, "gh"))
    except OSError as e:
        if e.errno != 2: print(e.errno, e.strerror, d)
EOF
# → ERRNO 13 (Permission denied): '/mnt/c/WINDOWS/system32/config/systemprofile/.../WindowsApps'

# 3. Confirm the entry origin on Windows:
powershell.exe -NoProfile -Command "[Environment]::GetEnvironmentVariable('Path','User')" | tr ';' '\n' | grep -i WindowsApps
powershell.exe -NoProfile -Command "[Environment]::GetEnvironmentVariable('Path','Machine')" | tr ';' '\n' | grep -i WindowsApps
```

## Fixes applied (both)

1. **Code-side (crash-proof):** in the Python caller, widen the except:
   `except (FileNotFoundError, subprocess.TimeoutExpired)` →
   `except (OSError, subprocess.TimeoutExpired)` — OSError is the parent of
   FileNotFoundError AND PermissionError. Applied to
   `/usr/local/lib/hermes-agent/hermes_cli/doctor.py`.
2. **Env-side (root fix, whole class):** `/etc/profile.d/99-wsl-path-clean.sh`
   (content in `templates/clean-wsl-path.sh`) — drops PATH entries that are
   not accessible directories (`[ -d ]` test: EACCES + nonexistent + non-dir
   dropped; empty entries preserved). Only NEW login shells get the clean
   PATH.

## Verification

- `bash -lc 'echo $PATH | grep -c systemprofile'` → 0
- `bash -lc` + subprocess missing cmd → FileNotFoundError (correct)
- `hermes doctor` → EXIT=0, graceful "No GITHUB_TOKEN" warning instead of crash

## Caveats / follow-ups

- Filter applies to new shells only — restart long-running processes
  (gateway daemon, running hermes sessions) to clear their stale PATH.
- Windows-side removal was NOT possible: entry lives in the machine PATH and
  the user has no admin rights on the corporate box. The WSL-side filter is
  the durable fix.
- `/usr/local/lib/hermes-agent` is a git checkout — `hermes update` may
  revert the doctor.py patch. Worth an upstream issue: "doctor crashes with
  PermissionError when PATH contains an unstat-able directory".
- General lesson for code: when probing optional CLIs via subprocess, catch
  `OSError` (covers FileNotFoundError, PermissionError, exec failures), never
  just FileNotFoundError.
