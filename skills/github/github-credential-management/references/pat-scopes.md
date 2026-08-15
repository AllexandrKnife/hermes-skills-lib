# GitHub Classic PAT Scopes — Capabilities and Danger Levels

Classic PATs (`ghp_` prefix) report their scopes in the `X-OAuth-Scopes` response header.
Fine-grained tokens do NOT (empty header) — verify those by attempting a private-repo operation.

## Audit command (session-tested)

```bash
curl -s -D - -o /dev/null -H "Authorization: token $TOKEN" https://api.github.com/user | grep -i x-oauth-scopes
```

Also check `X-RateLimit-Limit` — 5000 = authenticated, 60 = anonymous.

## Scope map

| Scope | Allows | Danger |
|---|---|---|
| repo | Full CRUD on repos incl. private: push/force-push, branches, collaborators, deploy keys | HIGH |
| workflow | Modify .github/workflows — inject code into CI/CD pipelines | HIGH |
| delete_repo | Delete entire repositories (irreversible) | CRITICAL |
| admin:org | Full org control: members, teams, permissions, org deletion | CRITICAL |
| admin:enterprise | Enterprise admin: orgs, policies, billing | CRITICAL |
| admin:org_hook / admin:repo_hook | Create/modify webhooks — can exfiltrate every repo event | HIGH |
| admin:public_key | Add/remove account SSH keys → access to ANY server where the account key is deployed | CRITICAL |
| admin:ssh_signing_key | Manage SSH signing keys | HIGH |
| admin:gpg_key | Manage GPG keys | MEDIUM |
| user | Profile, email, name, bio; private user info | MEDIUM |
| gist | Create/delete gists | LOW |
| notifications | Read user notifications | LOW |
| project | Manage projects (org/user) | MEDIUM |
| audit_log | Read org audit logs — full action history | HIGH |
| codespace | Create/launch Codespaces (billing) | MEDIUM-HIGH |
| copilot | Manage Copilot settings | MEDIUM |
| write:packages / delete:packages | Publish and delete packages/containers | HIGH |
| write:discussion | Manage discussions | LOW |
| write:network_configurations | Manage org network configurations | MEDIUM |

## Interpretation

- Typical read/write dev token: `repo` + `workflow` (+ `read:org`).
- Any CRITICAL scope (admin:*, delete_repo, admin:enterprise) = account takeover in the hands of an attacker.
- Practical demos of maximal rights:
  - delete any repo: `curl -X DELETE -H "Authorization: token $T" https://api.github.com/repos/<owner>/<repo>`
  - inject an SSH key: `curl -X POST -H "Authorization: token $T" https://api.github.com/user/keys -d '{"title":"x","key":"ssh-rsa ..."}'`
  - rewrite CI: push to .github/workflows
  - read org audit logs
- Recommendation when scopes exceed need: revoke → reissue as fine-grained (repo-scoped, e.g. Contents: read/write on the specific repo).

## Storage hygiene checklist

- ~/.git-credentials: perms 600 (write via `umask 077 && printf ... > ~/.git-credentials`)
- Token file format: `https://<user>:<token>@github.com` (URL-encode special chars; ghp_ tokens are alnum, safe)
- Never store tokens in persistent memory, skills, configs, cron
- Chat-pasted tokens are in session transcript + approval logs → advise revoke/rotate
- `unset GITHUB_TOKEN` after API work; check `~/.bash_history` for traces

## Session example (2026-08)

Token returned `x-oauth-scopes` listing every classic scope (admin:enterprise, admin:org,
delete_repo, workflow, audit_log, codespace, copilot, ...) → verdict "максимальные права /
полный доступ к аккаунту", rotation to fine-grained recommended. Account AllexandrKnife,
25 repos (5 private) — private-repo `git ls-remote` confirmed auth end-to-end.
