# Скилл-граф Hermes — вынесенные в библиотеку скиллы (18.08.2026)

Назначение: скиллы вынесены из ~/.hermes/skills в /root/hermes-skills-lib/skills/ для
сокращения каталога available_skills. Вынесенные скиллы НЕ видны skill_view(name=...)
и НЕ индексируются Hermes — загрузка только через read_file по пути lib_path
(SKILL.md) или через оркестратор.

Правило роутера: задача совпала с триггером ниже → read_file(<lib_path>/SKILL.md).
Возврат в каталог: mv <lib_path> ~/.hermes/skills/<cat>/<name> (или skills-repos-push).

| скилл | категория | путь в библиотеке | триггер (Use when) |
|---|---|---|---|
| computer-use | autonomous-ai-agents | ~/hermes-skills-lib/skills/autonomous-ai-agents/computer-use | Use when | |
| architecture-diagram | creative | ~/hermes-skills-lib/skills/creative/architecture-diagram | Use when Dark-themed SVG architecture/cloud/infra |
| ascii-art | creative | ~/hermes-skills-lib/skills/creative/ascii-art | Use when ASCII art: pyfiglet, cowsay, boxes, |
| ascii-video | creative | ~/hermes-skills-lib/skills/creative/ascii-video | Use when ASCII video: convert video/audio to colored |
| baoyu-infographic | creative | ~/hermes-skills-lib/skills/creative/baoyu-infographic | Use when Infographics: 21 layouts x 21 styles (信息图, |
| claude-design | creative | ~/hermes-skills-lib/skills/creative/claude-design | Use when Design one-off HTML artifacts (landing, deck, |
| comfyui | creative | ~/hermes-skills-lib/skills/creative/comfyui | Use when Generate images, video, and audio via |
| design-md | creative | ~/hermes-skills-lib/skills/creative/design-md | Use when Author/validate/export Google's DESIGN.md |
| excalidraw | creative | ~/hermes-skills-lib/skills/creative/excalidraw | Use when Hand-drawn Excalidraw JSON diagrams (arch, |
| humanizer | creative | ~/hermes-skills-lib/skills/creative/humanizer | Use when Humanize text: strip AI-isms and add real |
| manim-video | creative | ~/hermes-skills-lib/skills/creative/manim-video | Use when Manim CE animations: 3Blue1Brown math/algo |
| p5js | creative | ~/hermes-skills-lib/skills/creative/p5js | Use when p5.js sketches: gen art, shaders, |
| popular-web-designs | creative | ~/hermes-skills-lib/skills/creative/popular-web-designs | Use when 54 real design systems (Stripe, Linear, |
| pretext | creative | ~/hermes-skills-lib/skills/creative/pretext | Use when Build creative browser demos with DOM-free |
| sketch | creative | ~/hermes-skills-lib/skills/creative/sketch | Use when Throwaway HTML mockups: 2-3 design variants |
| songwriting-and-ai-music | creative | ~/hermes-skills-lib/skills/creative/songwriting-and-ai-music | Use when Songwriting craft and Suno AI music prompts |
| touchdesigner-mcp | creative | ~/hermes-skills-lib/skills/creative/touchdesigner-mcp | Use when Control TouchDesigner via twozero MCP |
| codebase-inspection | github | ~/hermes-skills-lib/skills/github/codebase-inspection | Use when Inspect codebases w/ pygount: LOC, languages, |
| gif-search | media | ~/hermes-skills-lib/skills/media/gif-search | Use when Search/download GIFs from Tenor via curl + jq |
| songsee | media | ~/hermes-skills-lib/skills/media/songsee | Use when Audio spectrograms/features (mel, chroma, |
| youtube-content | media | ~/hermes-skills-lib/skills/media/youtube-content | Use when YouTube transcripts to summaries, threads, |
| evaluating-llms-harness | mlops | ~/hermes-skills-lib/skills/mlops/evaluation/evaluating-llms-harness | Use when lm-eval-harness: benchmark LLMs (MMLU, GSM8K, |
| huggingface-hub | mlops | ~/hermes-skills-lib/skills/mlops/huggingface-hub | Use when HuggingFace hf CLI: search/download/upload |
| llama-cpp | mlops | ~/hermes-skills-lib/skills/mlops/inference/llama-cpp | Use when llama.cpp local GGUF inference + HF Hub model |
| serving-llms-vllm | mlops | ~/hermes-skills-lib/skills/mlops/inference/serving-llms-vllm | Use when vLLM: high-throughput LLM serving, OpenAI |
| weights-and-biases | mlops | ~/hermes-skills-lib/skills/mlops/evaluation/weights-and-biases | Use when W&B: log ML experiments, sweeps, model |
| obsidian | note-taking | ~/hermes-skills-lib/skills/note-taking/obsidian | Use when Read, search, create, and edit notes in the |
| airtable | productivity | ~/hermes-skills-lib/skills/productivity/airtable | Use when Airtable REST API via curl. Records CRUD, |
| box | productivity | ~/hermes-skills-lib/skills/productivity/box | Use when Box manages cloud files, sharing, search, and |
| maps | productivity | ~/hermes-skills-lib/skills/productivity/maps | Use when Geocode, POIs, routes, timezones via |
| notion | productivity | ~/hermes-skills-lib/skills/productivity/notion | Use when Notion API + ntn CLI: pages, databases, |
| product-price-monitor | productivity | ~/hermes-skills-lib/skills/productivity/product-price-monitor | Use when Watch product, flight, or listing prices; |
| session-librarian | productivity | ~/hermes-skills-lib/skills/productivity/session-librarian | Use when Organize sessions by prompt: find, rename, |
| weekly-review-planning | productivity | ~/hermes-skills-lib/skills/productivity/weekly-review-planning | Use when Weekly reset: commitments, stalled work, |
| blogwatcher | research | ~/hermes-skills-lib/skills/research/blogwatcher | Use when Monitor blogs and RSS/Atom feeds via |
| competitor-news-monitor | research | ~/hermes-skills-lib/skills/research/competitor-news-monitor | Use when Watch named companies for material news; |
| llm-wiki | research | ~/hermes-skills-lib/skills/research/llm-wiki | Use when Karpathy's LLM Wiki: build/query interlinked |
| openhue | smart-home | ~/hermes-skills-lib/skills/smart-home/openhue | Use when Control Philips Hue lights, scenes, rooms via |
| xurl | social-media | ~/hermes-skills-lib/skills/social-media/xurl | Use when X/Twitter via xurl CLI: raw post search, |
| dogfood | software-development | ~/hermes-skills-lib/skills/software-development/dogfood | Exploratory QA of web apps: find bugs, evidence, reports. |
| node-inspect-debugger | software-development | ~/hermes-skills-lib/skills/software-development/node-inspect-debugger | Use when Debug Node.js via --inspect + Chrome DevTools |
| simplify-code | software-development | ~/hermes-skills-lib/skills/software-development/simplify-code | Use when Parallel 4-agent cleanup of recent code |
| spike | software-development | ~/hermes-skills-lib/skills/software-development/spike | Use when Throwaway experiments to validate an idea |

| open-source-project-evaluation | research | ~/hermes-skills-lib/skills/research/open-source-project-evaluation | Use when Structured evaluation of open-source projects |
| baoyu-article-illustrator | creative | ~/hermes-skills-lib/skills/creative/baoyu-article-illustrator | Use when Article illustrations: type × style × palette |
| minecraft-modpack-server | gaming | ~/hermes-skills-lib/skills/gaming/minecraft-modpack-server | Use when Host modded Minecraft servers (CurseForge, |
| blocked-page-recovery | research | ~/hermes-skills-lib/skills/research/blocked-page-recovery | Use when Recover blocked/paywalled/WAF'd pages via |
| segment-anything | mlops | ~/hermes-skills-lib/skills/mlops/models/segment-anything | Use when SAM: zero-shot image segmentation via points, |
| exa-search | ecc | ~/hermes-skills-lib/skills/ecc/exa-search | Neural search via Exa MCP for web, code, and company research. Use when the user needs web search, code examples, company intel, people lookup, or AI-powered deep research with Exa's neural search engine. |
| trl-fine-tuning | mlops | ~/hermes-skills-lib/skills/mlops/training/trl-fine-tuning | Use when TRL: SFT, DPO, PPO, GRPO, reward modeling for |
| jupyter-live-kernel | data-science | ~/hermes-skills-lib/skills/data-science/jupyter-live-kernel | Use when Iterative Python via live Jupyter kernel |
| data-scraper-agent | ecc | ~/hermes-skills-lib/skills/ecc/data-scraper-agent | Use when Build a fully automated AI-powered data |
| baoyu-comic | creative | ~/hermes-skills-lib/skills/creative/baoyu-comic | Use when Knowledge comics (知识漫画): educational, |
| e-commerce-pricing | research | ~/hermes-skills-lib/skills/research/e-commerce-pricing | Use when Research product prices across Russian |
| pokemon-player | gaming | ~/hermes-skills-lib/skills/gaming/pokemon-player | Use when Play Pokemon via headless emulator + RAM |
| creative-ideation | creative | ~/hermes-skills-lib/skills/creative/creative-ideation | Use when Generate project ideas via creative |

| academic-article-writing | academic | ~/hermes-skills-lib/skills/academic/academic-article-writing | Use when написание научной статьи (ВАК) с реальными данными |
| academic-profiling | academic | ~/hermes-skills-lib/skills/academic/academic-profiling | Use when Profile academic researchers and their |
| academic-publications | academic | ~/hermes-skills-lib/skills/academic/academic-publications | Use when сбор публикаций учёного, скачивание, профиль автора |
| adguard-vpn-dns | network | ~/hermes-skills-lib/skills/network/adguard-vpn-dns | Use when установка AdGuardHome на VPS, интеграция с sing-box/Amnezia VPN, DNS-оптимизация через unbound + upstreams |
| amnezia-vpn | network | ~/hermes-skills-lib/skills/network/amnezia-vpn | Use when Deploy, manage, and troubleshoot Amnezia VPN servers — container architecture, user management, error... |
| amneziawg-v1-server | network | ~/hermes-skills-lib/skills/network/amneziawg-v1-server | Use when WG блокируется DPI — AWG v1.0 сервер + Keenetic. |
| amneziawg-vpn | network | ~/hermes-skills-lib/skills/network/amneziawg-vpn | Use when WireGuard is DPI-blocked or deploying AmneziaWG. |
| cascade-exclusion | construction | ~/hermes-skills-lib/skills/construction/cascade-exclusion | Use when Каскадное исключение работ в строительных |
| construction-estimate-audit | construction | ~/hermes-skills-lib/skills/construction/construction-estimate-audit | Use when Audit construction estimates for overpricing |
| construction-estimate-fraud | construction | ~/hermes-skills-lib/skills/construction/construction-estimate-fraud | Use when Анализ строительных смет на предмет завышения |
| construction-estimate-fraud-analysis | construction | ~/hermes-skills-lib/skills/construction/construction-estimate-fraud-analysis | Use when Анализ строительных смет на предмет |
| debugging-hermes-tui-commands | hermes | ~/hermes-skills-lib/skills/hermes/debugging-hermes-tui-commands | Use when Debug Hermes TUI slash commands: Python, |
| dns-infrastructure-audit | network | ~/hermes-skills-lib/skills/network/dns-infrastructure-audit | Use when Audit and provision DNS infrastructure on |
| github-credential-management | github | ~/hermes-skills-lib/skills/github/github-credential-management | Use when storing/auditing GitHub PAT credentials. |
| github-interaction | github | ~/hermes-skills-lib/skills/github/github-interaction | Use when Complete GitHub interaction — authentication |
| github-issue-to-pr | github | ~/hermes-skills-lib/skills/github/github-issue-to-pr | Use when Carry a GitHub issue to a verified PR with |
| github-release-install | github | ~/hermes-skills-lib/skills/github/github-release-install | Use when GitHub release CLI install: SHA256 verify, |
| github-repo-publish | github | ~/hermes-skills-lib/skills/github/github-repo-publish | Use when пуш локального артефакта/репо в GitHub без gh CLI |
| hermes-agent-skill-authoring | hermes | ~/hermes-skills-lib/skills/hermes/hermes-agent-skill-authoring | Use when Author in-repo SKILL.md files: frontmatter |
| hermes-auxiliary-tasks | hermes | ~/hermes-skills-lib/skills/hermes/hermes-auxiliary-tasks | Use when Hermes auxiliary tasks fail: HTTP 400, json_schema. |
| hermes-external-toolkit-integration | hermes | ~/hermes-skills-lib/skills/hermes/hermes-external-toolkit-integration | Use when Evaluate, import, and adapt external agent |
| hermes-maintenance | hermes | ~/hermes-skills-lib/skills/hermes/hermes-maintenance | Use when Hermes сломан после обновления — патчи установки. |
| hermes-memory-audit | hermes | ~/hermes-skills-lib/skills/hermes/hermes-memory-audit | Use when Аудит памяти Hermes по 8 уровням: модель, |
| hermes-plugin-development | hermes | ~/hermes-skills-lib/skills/hermes/hermes-plugin-development | Use when Create Hermes Agent plugins with hooks (pre_tool_call, etc.) to intercept and modify tool calls. Cover... |
| hermes-provider-troubleshooting | hermes | ~/hermes-skills-lib/skills/hermes/hermes-provider-troubleshooting | Use when Hermes auxiliary tasks fail with provider errors. |
| hermes-s6-container-supervision | hermes | ~/hermes-skills-lib/skills/hermes/hermes-s6-container-supervision | Use when Modify, debug, or extend the s6-overlay |
| hermes-skill-autoload | hermes | ~/hermes-skills-lib/skills/hermes/hermes-skill-autoload | Use when Проверка и настройка авто-загрузки скиллов |
| hermes-skill-inventory | hermes | ~/hermes-skills-lib/skills/hermes/hermes-skill-inventory | Use when Инвентаризация скилов Hermes: кастомные vs |
| hermes-skill-migration | hermes | ~/hermes-skills-lib/skills/hermes/hermes-skill-migration | Use when перенос скиллов Hermes на другую машину. |
| inspecting-hermes-desktop-dom | hermes | ~/hermes-skills-lib/skills/hermes/inspecting-hermes-desktop-dom | Use when Read the live Hermes desktop DOM/CSS over CDP |
| keenetic-router | network | ~/hermes-skills-lib/skills/network/keenetic-router | Use when Manage Keenetic NDMS routers (KN-1210 / 4G) via RCI API — challenge-response auth, configuration queri... |
| keenetic-router-admin | network | ~/hermes-skills-lib/skills/network/keenetic-router-admin | Use when configuring a Keenetic router (KeeneticOS). |
| linux-vps-maintenance | network | ~/hermes-skills-lib/skills/network/linux-vps-maintenance | Use when VPS SSH: apt update/upgrade, чистка ядер. |
| merge-reconciler | github | ~/hermes-skills-lib/skills/github/merge-reconciler | Use when Neutral third-party resolution of agent merge |
| openclaw-hermes-migration | hermes | ~/hermes-skills-lib/skills/hermes/openclaw-hermes-migration | Use when миграция OpenClaw→Hermes на VPS, тот же бот. |
| openwrt-singbox-gateway | network | ~/hermes-skills-lib/skills/network/openwrt-singbox-gateway | Use when OpenWrt-гейтвей: sing-box VLESS/Reality, |
| openwrt-singbox-home-gateway | network | ~/hermes-skills-lib/skills/network/openwrt-singbox-home-gateway | Use when Cudy WR3000S: сток (WG Client) ИЛИ OpenWrt + |
| openwrt-vpn-gateway | network | ~/hermes-skills-lib/skills/network/openwrt-vpn-gateway | Use when OpenWrt-роутер как VPN-гейтвей: выбор, |
| osint-investigation | osint | ~/hermes-skills-lib/skills/osint/osint-investigation | Use when Follow the money via public records and |
| osint-research | osint | ~/hermes-skills-lib/skills/osint/osint-research | Use when OSINT / аналитические исследования — сбор данных из открытых источников (русскоязычные + англоязычные)... |
| russia-ukraine-osint | osint | ~/hermes-skills-lib/skills/osint/russia-ukraine-osint | Use when Multi-source balanced OSINT on Russia-Ukraine |
| russian-company-osint | osint | ~/hermes-skills-lib/skills/osint/russian-company-osint | Use when OSINT investigation of Russian legal entities |
| russian-construction-audit | construction | ~/hermes-skills-lib/skills/construction/russian-construction-audit | Use when Analyse Russian construction estimates for |
| russian-osint-data-collection | osint | ~/hermes-skills-lib/skills/osint/russian-osint-data-collection | Use when Bypass bot protection on Russian web sources |
| sherlock | osint | ~/hermes-skills-lib/skills/osint/sherlock | Use when Find accounts for a username across 400+ |
| sing-box-server-setup | network | ~/hermes-skills-lib/skills/network/sing-box-server-setup | Use when Поставить/обновить sing-box на VPS (sb.sh |
| tcp-2621 | construction | ~/hermes-skills-lib/skills/construction/tcp-2621 | Use when ТЦП 2621 18.1 — типовые ценовые показатели |
| tcp-vedomost-audit | construction | ~/hermes-skills-lib/skills/construction/tcp-vedomost-audit | Use when Проверка ведомостей ВИР/ВВР по ТЦП на двойную |
| vpn-adguard-dns-optimization | network | ~/hermes-skills-lib/skills/network/vpn-adguard-dns-optimization | Use when настройка связки VPN + AdGuardHome с unbound, parallel upstreams, агрессивными фильтрами на VPS |
| vpn-egress-tunnel | network | ~/hermes-skills-lib/skills/network/vpn-egress-tunnel | Use when Туннель WSL→VPS: обход CF-блокировок, |
| vps-adguard-dns-integration | network | ~/hermes-skills-lib/skills/network/vps-adguard-dns-integration | Use when Deploy AdGuardHome and integrate it as the |
| vps-file-transfer | network | ~/hermes-skills-lib/skills/network/vps-file-transfer | Use when copying files between WSL and VPS over SSH. |
| vps-vpn-provisioning | network | ~/hermes-skills-lib/skills/network/vps-vpn-provisioning | Use when provisioning VPN/proxy services on user's VPS. |
| windows-admin-tasks-from-wsl | network | ~/hermes-skills-lib/skills/network/windows-admin-tasks-from-wsl | Use when powershell.exe fails or admin Windows ops from WSL. |
| wsl-cross-distro-transfer | network | ~/hermes-skills-lib/skills/network/wsl-cross-distro-transfer | Use when передача данных между WSL-образами на одной машине. |
| wsl-distro-diagnostics | network | ~/hermes-skills-lib/skills/network/wsl-distro-diagnostics | Use when диагностика соседнего WSL-образа: сеть, процессы. |
| wsl-maintenance | network | ~/hermes-skills-lib/skills/network/wsl-maintenance | Use when Diagnose, tune, and clean WSL2 environments — disk space, .wslconfig, cache cleanup, Windows interop p... |
| wsl-vpn-on-demand | network | ~/hermes-skills-lib/skills/network/wsl-vpn-on-demand | Use when WSL VPN egress on demand: sing-box client, |
| wsl-windows-interop | network | ~/hermes-skills-lib/skills/network/wsl-windows-interop | Use when Query Windows host state, manage WSL |
Всего вынесено: 115 скиллов (56 декларированных ранее + 63 легаси-коллекция, внесены 01.09.2026). Лог переноса: /root/idea-gen/skill-graph-move-log.txt