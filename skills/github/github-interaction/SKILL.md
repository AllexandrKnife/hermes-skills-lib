---
name: github-interaction
description: "Use when Complete GitHub interaction — authentication"
critic_status: done
version: 1.1.0
author: Hermes Agent (consolidated from github-auth, github-code-review, github-issues, github-pr-workflow, github-repo-management)
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [GitHub, Authentication, Code-Review, Issues, Pull-Requests, Repositories, Git, CI/CD, Automation]
    related_skills: [acp-coding-agents]
---
## When to Use

Use when Complete GitHub interaction — authentication.


# GitHub Interaction

Complete guide for all GitHub operations from Hermes: authentication, code review, issue management, PR lifecycle, and repository administration. Each section shows the `gh` CLI way first, then the `git` + `curl` fallback for machines without `gh`.

## Prerequisites

- A GitHub account with appropriate permissions
- Inside a git repository for repo-relative operations

## Shared Auth Detection (Used by All Sections)

```bash
if command -v gh &>/dev/null && gh auth status &>/dev/null; then
  AUTH="gh"
else
  AUTH="curl"
  if [ -z "$GITHUB_TOKEN" ]; then
    if [ -f ~/.hermes/.env ] && grep -q "^GITHUB_TOKEN=" ~/.hermes/.env; then
      GITHUB_TOKEN=$(grep "^GITHUB_TOKEN=" ~/.hermes/.env | head -1 | cut -d= -f2 | tr -d '\n\r')
    elif grep -q "github.com" ~/.git-credentials 2>/dev/null; then
      GITHUB_TOKEN=$(grep "github.com" ~/.git-credentials 2>/dev/null | head -1 | sed 's|https://[^:]*:\([^@]*\)@.*|\1|')
    fi
  fi
fi
echo "AUTH_METHOD=$AUTH"
```

### Extracting Owner/Repo from Git Remote

```bash
REMOTE_URL=$(git remote get-url origin)
OWNER_REPO=$(echo "$REMOTE_URL" | sed -E 's|.*github\.com[:/]||; s|\.git$||')
OWNER=$(echo "$OWNER_REPO" | cut -d/ -f1)
REPO=$(echo "$OWNER_REPO" | cut -d/ -f2)
echo "Owner: $OWNER, Repo: $REPO"
```

---

## Section 1: Authentication Setup

### Method 1: Git-Only (HTTPS with PAT)

1. Create token at https://github.com/settings/tokens (scopes: `repo`, `workflow`, `read:org`)
2. Configure git:
   ```bash
   git config --global credential.helper store
   git config --global user.name "Your Name"
   git config --global user.email "your-email@example.com"
   ```
3. Test: `git ls-remote https://github.com/<username>/<any-repo>.git`

### Method 2: Git-Only (SSH)

```bash
ssh-keygen -t ed25519 -C "your-email@example.com" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub  # Add at https://github.com/settings/keys
ssh -T git@github.com
git config --global url."git@github.com:".insteadOf "https://github.com/"
```

### Method 3: gh CLI

```bash
gh auth login  # Interactive browser or token-based
gh auth setup-git
```

### Setting Token for API Calls (without gh)

```bash
export GITHUB_TOKEN="<token>"
```

**Windows/WSL — extract from Windows gh CLI:**

```bash
# Extract existing token from Windows gh CLI (if installed)
cmd.exe /c "gh auth token" 2>/dev/null

# Or via PowerShell for cleaner capture
cd /mnt/c && powershell.exe -Command "gh auth token" 2>/dev/null

# Store to Windows filesystem (avoids WSL path issues with special chars)
cmd.exe /c "gh auth token" 2>/dev/null > /mnt/c/Users/Public/gh_token.txt
```

**Windows/WSL — set as Windows user env var for MCP servers:**
```bash
powershell.exe -Command \
  '[System.Environment]::SetEnvironmentVariable("GITHUB_TOKEN", "<token>", "User")'
```

**Extracting token from git credentials:**
```bash
grep "github.com" ~/.git-credentials | head -1 | sed 's|https://[^:]*:\([^@]*\)@.*|\1|'
```

### Troubleshooting

| Problem | Solution |
|---------|----------|
| `git push` asks for password | Use PAT as password, or switch to SSH |
| `remote: Permission to X denied` | Token may lack `repo` scope |
| `fatal: Authentication failed` | `git credential reject` then re-auth |
| `ssh: connect to host github.com port 22` | Add `Host github.com` with `Port 443` in `~/.ssh/config` |
| Multiple GitHub accounts | SSH with different keys per host alias |

---

## Section 2: Code Review

### 2a: Reviewing Local Changes (Pre-Push)

```bash
# Get the diff
git diff --staged                     # Staged changes
git diff main...HEAD                  # All changes vs main
git diff main...HEAD --stat           # File stats

# Common issue scans
git diff main...HEAD | grep -n "print(\|console\.log\|TODO\|FIXME\|debugger"
git diff main...HEAD --stat | sort -t'|' -k2 -rn | head -10
git diff main...HEAD | grep -in "password\|secret\|api_key\|token.*=\|private_key"
git diff main...HEAD | grep -n "<<<<<<\|>>>>>>\|======="
```

### 2b: Reviewing a Pull Request

**With gh:**
```bash
gh pr view 123
gh pr diff 123
gh pr checkout 123
```

**With git + curl:**
```bash
PR_NUMBER=123
curl -s -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/$OWNER/$REPO/pulls/$PR_NUMBER/files | \
  python3 -c "import sys,json; [print(f\"{f['status']:10} +{f['additions']:-4} -{f['deletions']:-4}  {f['filename']}\") for f in json.load(sys.stdin)]"

# Check out locally
git fetch origin pull/$PR_NUMBER/head:pr-$PR_NUMBER
git checkout pr-$PR_NUMBER
```

### 2c: Posting Review Comments

**Formal review with gh:**
```bash
gh pr review 123 --approve --body "LGTM!"
gh pr review 123 --request-changes --body "See inline comments."
```

**Inline comments with curl (atomic review):**
```bash
curl -s -X POST -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/$OWNER/$REPO/pulls/$PR_NUMBER/reviews \
  -d '{"event": "COMMENT", "body": "Review from Hermes", "comments": [
    {"path": "src/auth.py", "line": 45, "body": "Use parameterized queries."}
  ]}'
```

### Review Checklist

**Correctness:** Edge cases, error paths, contracts upheld
**Security:** No hardcoded secrets, input validation, no SQL injection/XSS/path traversal
**Code Quality:** Clear naming, single responsibility, DRY
**Testing:** New paths tested, happy and error cases covered
**Performance:** No N+1 queries, no blocking in async paths
**Documentation:** Public APIs documented, non-obvious logic explained

### Review Output Format

See `references/review-output-template.md` for the structured summary template (Critical / Warnings / Suggestions / Looks Good sections).

---

## Section 3: Issue Management

### Viewing Issues

**With gh:**
```bash
gh issue list
gh issue list --state open --label "bug"
gh issue list --assignee @me
gh issue view 42
```

**With curl:**
```bash
curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$OWNER/$REPO/issues?state=open&per_page=20" | \
  python3 -c "import sys,json; [print(f'#{i[\"number\"]:5}  {i[\"state\"]:6}  {\" \".join(l[\"name\"] for l in i[\"labels\"]):30}  {i[\"title\"]}') for i in json.load(sys.stdin) if 'pull_request' not in i]"
```

### Creating Issues

```bash
gh issue create --title "Bug: Login redirect ignores ?next=" \
  --body "## Description\n..." --label "bug,backend" --assignee "username"
```

Templates: `templates/bug-report.md`, `templates/feature-request.md`

### Managing Issues

| Action | gh | curl |
|--------|-----|------|
| Add labels | `gh issue edit N --add-label "bug"` | `POST /repos/o/r/issues/N/labels` |
| Assign | `gh issue edit N --add-assignee user` | `POST /repos/o/r/issues/N/assignees` |
| Comment | `gh issue comment N --body "..."` | `POST /repos/o/r/issues/N/comments` |
| Close | `gh issue close N` | `PATCH /repos/o/r/issues/N` |
| Reopen | `gh issue reopen N` | `PATCH /repos/o/r/issues/N` |

### Issue Triage Workflow

1. List untriaged: `gh issue list --label "needs-triage" --state open`
2. Categorize and apply labels/priority
3. Assign if owner is clear
4. Comment with triage notes

---

## Section 4: PR Lifecycle

### Branch Creation

```bash
git fetch origin && git checkout main && git pull origin main
git checkout -b feat/my-feature
```

Naming: `feat/`, `fix/`, `refactor/`, `docs/`, `ci/`

### Committing (Conventional Commits)

```bash
git add src/auth.py
git commit -m "feat: add JWT-based user authentication"
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `ci`, `chore`, `perf`

Format reference: `references/conventional-commits.md`

### Creating the PR

```bash
git push -u origin HEAD
gh pr create --title "feat: ..." --body "## Summary\n..." --label "enhancement"
```

### Monitoring CI

```bash
# Quick check
gh pr checks
gh pr checks --watch  # Polls every 10s

# With curl
SHA=$(git rev-parse HEAD)
curl -s -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/$OWNER/$REPO/commits/$SHA/status
```

CI troubleshooting reference: `references/ci-troubleshooting.md`

### Auto-Fix CI Loop

1. Check CI → identify failures
2. Read failure logs: `gh run view <RUN_ID> --log-failed`
3. Fix code, `git add && git commit -m "fix: ..." && git push`
4. Re-check CI (up to 3 attempts, then ask user)

### Merging

```bash
# Squash merge + delete branch
gh pr merge --squash --delete-branch

# Enable auto-merge
gh pr merge --auto --squash --delete-branch

# With curl
curl -s -X PUT -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/$OWNER/$REPO/pulls/$PR_NUMBER/merge \
  -d '{"merge_method": "squash"}'
```

PR body templates: `templates/pr-body-bugfix.md`, `templates/pr-body-feature.md`

---

## Section 5: Repository Management

### Cloning

```bash
git clone https://github.com/owner/repo-name.git  # or gh repo clone owner/repo-name
git clone --depth 1 https://github.com/owner/repo-name.git  # Shallow
```

### Creating Repos

```bash
gh repo create my-project --public --clone
gh repo create my-org/my-project --private --clone

# From existing local directory
cd /path/to/project && gh repo create my-project --source . --public --push
```

### Forking

```bash
gh repo fork owner/repo-name --clone
git remote add upstream https://github.com/owner/repo-name.git  # Add upstream
```

### Repository Settings

```bash
gh repo edit --description "Updated" --visibility public
gh repo edit --enable-wiki=false --enable-issues=true --default-branch main
gh repo edit --add-topic "machine-learning,python"
```

### Branch Protection

```bash
curl -s -X PUT -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/$OWNER/$REPO/branches/main/protection \
  -d '{"required_status_checks":{"strict":true,"contexts":["ci/test"]},"required_pull_request_reviews":{"required_approving_review_count":1}}'
```

### Secrets (GitHub Actions)

```bash
gh secret set API_KEY --body "your-secret-value"
gh secret list
```

### Releases

```bash
gh release create v1.0.0 --title "v1.0.0" --generate-notes
gh release create v1.0.0 ./dist/binary --title "v1.0.0"
gh release list
```

### GitHub Actions

```bash
gh workflow list
gh run list --limit 10
gh run view <RUN_ID>
gh run rerun <RUN_ID> --failed
gh workflow run ci.yml --ref main
```

### Gists

```bash
gh gist create script.py --public --desc "Useful script"
```

API cheatsheet for curl-only operations: `references/github-api-cheatsheet.md`

---

## Quick Reference Table

| Action | gh | curl |
|--------|-----|------|
| Auth check | `gh auth status` | `curl -H "Authorization: token $TOKEN" .../user` |
| List issues | `gh issue list` | `GET /repos/o/r/issues` |
| List PRs | `gh pr list` | `GET /repos/o/r/pulls` |
| View PR diff | `gh pr diff` | `git diff main...HEAD` |
| Create PR | `gh pr create` | `POST /repos/o/r/pulls` |
| Review PR | `gh pr review N` | `POST /repos/o/r/pulls/N/reviews` |
| View repo | `gh repo view o/r` | `GET /repos/o/r` |
| Fork repo | `gh repo fork o/r` | `POST /repos/o/r/forks` |
| Create release | `gh release create` | `POST /repos/o/r/releases` |
| Set secret | `gh secret set K` | `PUT /repos/o/r/actions/secrets/K` |
| Run workflow | `gh workflow run` | `POST .../workflows/id/dispatches` |
| Create gist | `gh gist create` | `POST /gists` |

## Common Pitfalls

- **Token scope missing**: Ensure `repo`, `workflow`, `read:org` scopes
- **`gh auth status` not authenticated**: Run `gh auth login` (browser) or pipe token to `gh auth login --with-token`
- **API rate limits**: Unauthenticated requests limited to 60/hour. Always use a token.
- **`$_` in inline commands from WSL**: PowerShell variables get mangled. Use script files on Windows filesystem.
- **`gh` not available**: All operations have `git` + `curl` fallbacks documented above
- **Multiple accounts**: Use SSH with different keys or per-repo credential URLs
