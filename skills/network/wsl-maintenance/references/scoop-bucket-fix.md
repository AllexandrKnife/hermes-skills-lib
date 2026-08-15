# Scoop bucket git fix

## Symptom
```
fatal: your current branch appears to be broken
fatal: ambiguous argument 'HEAD': unknown revision or path not in the working tree.
```

## Cause
Partial clone or interrupted `scoop bucket add` left a broken .git directory.

## Fix
1. Kill stale git processes:
   ```powershell
   Get-Process git* -ErrorAction SilentlyContinue | Stop-Process -Force
   ```
2. Remove bucket directory:
   ```powershell
   Remove-Item "$env:USERPROFILE\scoop\buckets\<name>" -Recurse -Force
   ```
3. Remove scoop bucket registration:
   ```powershell
   scoop bucket rm <name>
   ```
   (If git lock still held, repeat step 1 first)
4. Re-add:
   ```powershell
   scoop bucket add <name>
   ```

## Prevention
Avoid interrupting `scoop bucket add` with Ctrl+C. Use longer timeout:
```bash
pwsh.exe -NoProfile -Command "scoop bucket add extras"
```
Default 300s timeout is sufficient for good connections.
