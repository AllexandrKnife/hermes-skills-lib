---
name: github-release-install
description: "Use when GitHub release CLI install: SHA256 verify,"
critic_status: done
version: 1.0.0
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [github, install, devops, security, cli]
    category: devops
---

# GitHub Release Binary Install

Securely download and install single-binary CLI tools from GitHub releases, with hash verification and corporate-machine hygiene. Covers the full path: discover latest release → verify checksum → install → disable auto-update → smoke test on a real artifact.

## When to Use

- User asks to install a CLI tool / binary distributed via GitHub releases (e.g. "ставь" after evaluating a repo)
- Need to prove a downloaded binary is authentic before running it on a corporate/work machine
- Evaluating a new tool before deciding to install

## Steps

1. **Get the latest release via API** (no browser needed):
   `curl -s https://api.github.com/repos/OWNER/REPO/releases/latest`
   Extract tag_name, published_at, assets[] (name, size, browser_download_url). Releases often ship a `SHA256SUMS` asset — grab it.

2. **Pick the right asset.** glibc Linux/WSL → `-linux-x64`; Alpine/musl → `-alpine-*`; Windows → `-win-x64.exe`. Check `uname -m` if unsure.

3. **Download binary + SHA256SUMS to /tmp, then verify:**
   ```
   sha256sum ./tool-linux-x64
   grep tool-linux-x64 SHA256SUMS
   ```
   The two hex strings must match exactly.

   PITFALL: GitHub SHA256SUMS files use CRLF line endings. `sha256sum -c -` fails with "no properly formatted SHA256 checksum lines found" even when hashes are correct. Don't panic — normalize first:
   `tr -d '\r' < SHA256SUMS | sha256sum -c -`

4. **Install:** `chmod +x /tmp/tool && mv /tmp/tool /usr/local/bin/tool` (sudo only if needed; WSL root usually doesn't need it).

5. **Disable auto-update** if the tool has one — on a corporate machine a silent background updater is both a supply-chain risk and an unrequested network caller. Examples: `officecli config autoUpdate false`; per-invocation skip env vars (`OFFICECLI_SKIP_UPDATE=1`). Verify the setting stuck (config get/status).

6. **Smoke test on a real artifact**, not just `--version`: create a sample file the tool is meant to process, run it, confirm real output. A version string proves the binary runs, not that it does the job.

## Evaluation checklist (before installing)

- License — check `spdx_id` in the API response (Apache-2.0/MIT fine)
- Project age vs star count: young + many stars = hype risk for corporate data
- Runtime behavior: auto-update phone-home, skill-injection into agent configs (`officecli install` injects its SKILL.md into detected AI agents — avoid on shared machines), telemetry
- Does it touch case data? Foreign binary on sensitive corporate documents is a conscious supply-chain decision: pin the version, keep auto-update off

## Pitfalls

- **tar.gz с man/ и completions/ — find подхватывает не тот файл.** Реальный кейс 12.08.2026 (tirith): `find /tmp/extract -maxdepth 2 -type f -name 'tirith*'` вернул первым `man/tirith.1` (troff), и в ~/.local/bin уехала man-страница вместо ELF (симптом: `bash: syntax error near unexpected token` при запуске). Правило: копировать ЯВНЫЙ путь к бинарю (корень архива), перед `cp` и после — `file` (должно быть `ELF 64-bit`); при несовпадении не продолжать, пересобрать.
- **Smoke test — реальным вызовом потребителя, а не выдуманным интерфейсом.** `--version` доказывает только запуск. Для инструмента, встроенного в другое ПО (tirith → Hermes), повторить ТОЧНО тот вызов, которым пользуется потребитель: аргументы читаются из кода потребителя (`grep -n 'subprocess.run' <потребитель>.py`), не угадываются. Кейс 12.08.2026: проверка `tirith -` (stdin) упала `unrecognized subcommand`; реальный вызов Hermes — `tirith check --json --non-interactive --shell posix -- <cmd>`.
- `sha256sum -c` CRLF failure (step 3) — the most common false alarm; hash is usually fine
- Piping `curl | bash` from the project's own install script skips verification entirely and runs unverified code as root — prefer manual download + verify
- Some tools self-install and inject agent skills on bare invocation (`officecli` does) — read the README's install section before running an unknown binary
- Auto-update defaults ON for many new tools — flip it explicitly and verify

## References

- `references/officecli.md` — OfficeCLI (iOfficeAI) install specifics + formula-evaluation usage for audit workflows
