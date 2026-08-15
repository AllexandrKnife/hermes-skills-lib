# Deploy to /etc/profile.d/99-wsl-path-clean.sh (chmod 644) on WSL boxes whose
# Linux PATH inherits Windows dirs. Fixes: Python subprocess raising
# PermissionError (instead of FileNotFoundError) for any missing command.
#
# Mechanism: glibc execvp aborts with EACCES if stat() on ANY PATH candidate
# returns EACCES — which happens for Windows dirs that Linux cannot stat
# (drvfs ACL denial), e.g.
#   C:\WINDOWS\system32\config\systemprofile\AppData\Local\Microsoft\WindowsApps
# This filter drops every PATH entry that is not an accessible directory.
# Empty entries are preserved (POSIX cwd semantics). New shells only —
# restart long-running processes (gateway, daemons) to pick up the clean PATH.
_clean_path() {
  local out="" d
  IFS=: read -ra _dirs <<< "$PATH"
  for d in "${_dirs[@]}"; do
    if [ -z "$d" ] || [ -d "$d" ]; then
      out="${out:+$out:}$d"
    fi
  done
  export PATH="$out"
}
_clean_path
unset -f _clean_path
