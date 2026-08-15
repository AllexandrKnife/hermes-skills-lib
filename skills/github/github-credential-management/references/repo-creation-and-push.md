# Create a repo and push from CLI (no gh needed)

Working recipe, tested 2026-08 on WSL with a classic PAT.

## 1. Check the name is free (optional, cheap)

```bash
curl -s -H "Authorization: token $TOKEN" \
  "https://api.github.com/search/repositories?q=<NAME>+in:name&per_page=5" -o /tmp/rs.json
```

Name is free when NO result has `name == "<NAME>"` (exact match, not substring).

## 2. Create a private repo (no auto-init)

```bash
curl -s -X POST -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -d '{"name":"<NAME>","private":true,"description":"...","auto_init":false}' \
  https://api.github.com/user/repos -o /tmp/repo.json
```

`auto_init:false` keeps full control of the first commit (README/LICENSE/.gitignore/install.sh).

## 3. Scaffold + first push

```bash
cd <project>
git init -q
git add -A
git -c user.name="..." -c user.email="..." commit -q -m "Initial commit"
git branch -M main
git remote add origin https://github.com/<owner>/<NAME>.git
git push -u origin main
```

Push uses the stored credential (credential.helper store) — no password prompt.

## 4. Verify

```bash
curl -s -H "Authorization: token $TOKEN" https://api.github.com/repos/<owner>/<NAME>   # private, default_branch, pushed_at
curl -s -H "Authorization: token $TOKEN" https://api.github.com/repos/<owner>/<NAME>/contents/  # root files
git ls-tree -r --name-only main | grep -c SKILL.md   # spot-check count, e.g.
```

## rtk-safe notes (this WSL env)

Extract the token rtk-safe (no regex/sed, no pipe to interpreter): see SKILL.md Pitfalls. curl to a temp file, parse in a separate python3 command. `git push` over HTTPS is the clean path — no API token in the command line.
