# Yandex Direct skill — GPT Actions edition

Adapted package for building a Custom GPT (ChatGPT) equivalent of the
Claude Code `direct` skill, with **live** API access (not just the static
methodology that `yandex-direct-docs` already exports for Claude Projects).

## What's in here

```
gpt-instructions.md          # paste into the GPT Builder "Instructions" field
knowledge/
  yandex-direct-overview.md  # adapted SKILL.md — upload as a Knowledge file
  references/*.md            # same methodology files as the Claude skill — upload all
actions/
  direct-api.openapi.yaml    # campaigns/adgroups/ads/keywords/sitelinks/negative-sets/reports
  metrika-api.openapi.yaml   # on-demand: visits/goals
  wordstat-api.openapi.yaml  # on-demand: keyword research
```

## Setup (GPT Builder → Configure tab)

1. **Name/description/icon** — up to you.
2. **Instructions** — paste the body of `gpt-instructions.md` (everything
   after the `---`).
3. **Knowledge** — upload `knowledge/yandex-direct-overview.md` and every
   file under `knowledge/references/` (10 files total).
4. **Actions → Create new action**, three times, one per OpenAPI file:

   | Action | Schema | Auth type | Header name | Value to paste as the "key" |
   |---|---|---|---|---|
   | Direct API | `actions/direct-api.openapi.yaml` | API Key → **Bearer** | *(set automatically by Bearer scheme)* | the raw OAuth token from `~/.secrets/yandex-direct.json` → `oauth_token`, no prefix |
   | Metrika API | `actions/metrika-api.openapi.yaml` | API Key → **Custom** | `Authorization` | the literal string `OAuth <token>` (word "OAuth", space, token) |
   | Wordstat API | `actions/wordstat-api.openapi.yaml` | API Key → **Custom** | `Authorization` | the literal string `Api-Key <key>` (word "Api-Key", space, key) |

   Paste each schema's raw YAML into the "Schema" box (GPT Builder accepts
   OpenAPI 3.1 pasted directly, no URL hosting needed — these specs point
   straight at Yandex's real endpoints).

## Security — read this before pasting a real token in

- **This hands your live Direct/Metrika/Wordstat credentials to OpenAI's
  infrastructure**, not just to this VPS. A Custom GPT's Action auth is
  stored by OpenAI and sent with every call this GPT makes, by anyone who
  uses it (if you ever share it beyond yourself).
- Keep the GPT **private** ("Only me") unless you specifically intend to
  hand Direct-account access to someone else.
- If your Direct OAuth app can be scoped down (representative/read-focused
  account instead of full owner token), prefer that for the token you paste
  into the Direct Action — the write-confirmation rule in the instructions
  is a prompt-level safeguard only, not a hard technical restriction the way
  Claude Code's tool-permission system is.
- Rotate the token afterwards if this was ever meant to be a one-off test
  rather than a standing integration.
- None of this touches `~/.secrets/` on this machine — those files are only
  the *source* you copy the raw values from once, during setup.

## Known gaps vs. the Claude Code skill

- No slash commands, no subagents, no local filesystem — see
  "What's different" at the bottom of `knowledge/yandex-direct-overview.md`.
- No technical write-confirmation gate — enforced by instructions text only
  (principle 4). This is the single biggest risk difference; the Claude
  Code version blocks the call at the tool layer until a human approves it,
  this version relies entirely on the model choosing to ask first.
- `Client-Login` (for agency/representative accounts) is a plain header
  parameter on every Direct API operation, not a secret — tell the GPT which
  account you're working on in chat each session; it won't be remembered
  from Knowledge files.
