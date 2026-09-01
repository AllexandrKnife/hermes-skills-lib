# Palmier Pro Evaluation — 2026-06-21

## Project
**palmier-io/palmier-pro** — macOS video editor built for AI
https://github.com/palmier-io/palmier-pro
https://www.palmier.io

## Stats at evaluation
- Stars: 4,785
- Forks: 367
- Open issues: 38
- Created: 2026-04-07
- Last push: 2026-06-21 (launched mid-June)
- License: GPL-3.0
- Language: Swift
- Topics: ai-video, claude, macos, mcp, seedance2, swift, video-editor

## Company
- Palmier, Inc., YC Summer 2024
- Two-person team: Marcos Rico Peng (ex-LinkedIn infra) + Harrison Tin (ex-Microsoft)
- Originally built "AI that understands any codebase" before pivoting to video
- Produced 15+ cinematic launch videos for YC companies before public launch

## Platform requirements
- macOS 26 (Tahoe) or later on Apple Silicon only
- No Windows, no Linux, no older macOS

## Pricing
- Editor + MCP server: FREE, no account required
- Pro: $29/mo (launch) → $49/mo regular, 5,000 credits
- Max: $69/mo (launch) → $99/mo regular, 12,000 credits
- 5,000 credits ≈ 333 images or 3-7 min video (varies by model/resolution)
- Credits only burn on AI generation: video, image, audio, upscaling, Palmier chat
- Editing and export always free

## MCP capabilities
- Local MCP server, one-click setup from Help menu
- Agent can: generate images/video/audio onto timeline, trim, split, reorder, adjust clips
- Agent sees full project context (prompt history, reference images, frame controls)
- Supported agents: Claude Desktop, Codex, Cursor, Claude Code

## Supported generation models
- Kling V3, Seedance 2.0, Veo 3.1, Grok Imagine

## Key differentiator
- AI generation is a TIMELINE PRIMITIVE, not an import from a web tool
- Prompt history stays with each clip — no more "final_v3_actually_final.mp4"
- Open-core: editor is open source, generation models are the paid part

## Rough edges
- macOS 26 only — hard wall for most users
- Brand new (days old at evaluation) — no G2/Capterra/Reddit reviews
- Name confusion: "Palmier" is a French pastry, also collides with an older dev tool
- Two-person team → longevity risk
- Open-core split is clean today but future pricing friction is unknown

## Verdict
- For: founders/marketers/creators on modern Mac who already generate AI clips and are sick of the generate-download-import-regenerate loop
- Against: anyone on Windows/Linux/older macOS, or who edits traditional footage without AI generation
- Risk: high — macOS-only + tiny team + brand new
