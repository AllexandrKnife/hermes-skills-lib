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

Всего вынесено: 43 скиллов. Лог переноса: /root/idea-gen/skill-graph-move-log.txt