# Semantic Core Pipeline (masks → Wordstat → negatives → groups)

Source: Monster Context webinar «Сбор семантического ядра через ИИ»
(К. Горбунов, Р. Скороходов, 2026-10-06, rutube/YouTube 3:11:01). Slides
checked against the video frames; the numbers below marked *(speaker)* were
stated aloud and not verified. Use this file for `/direct keywords`,
`/direct negative`, `/direct create` and any "собери семантику" request.

The webinar is a sales pitch for a course, so treat tooling claims
("no limits", "any text passes API application review") as marketing and
verify before relying on them. The **rules** (grouping, negatives, checks)
are the useful part.

## 1. Pipeline

```
доступы → 1. маски → 2. сбор Wordstat (+ топ-10 второй проход)
        → 3. чистка: минус-фразы + дубли → 4. группы → структура РК
```

Human decisions stay with the human: the agent proposes, the user picks
(architecture, strategy, weekly budget, which candidate negatives to apply).

## 2. Access (do once, reuse for all projects)

**Wordstat via Yandex Cloud (already used by `scripts/yd-wordstat.sh`)**
1. Register at `aistudio.yandex.ru`.
2. Attach a payment account. Balance may stay ≈0 but without a linked
   account the API often returns 403 *(speaker: min. top-up 4000 ₽ when
   billing starts)*.
3. Create an API key with scope `yc.search-api.execute` (the scope field is
   not shown on every account). The key is displayed once, save it.
4. Cloud console: copy the Folder ID; in IAM verify the role
   `search-api.webSearch.user` is on the key's service account.

**Direct API v5 / v4**
1. `oauth.yandex.ru` → create app of type «для доступа к API или отладки»,
   rights `direct:api` (+ `metrika:read` if Metrika is needed). Save
   ClientID and secret.
2. Apply for API access in the Direct cabinet:
   `direct.yandex.ru/registered/main.pl?cmd=apiCertificationRequestList`.
3. Token: `oauth.yandex.ru/authorize?response_type=token&client_id=<ID>`
   while logged in as the account that got the approval.
4. One application can serve many client accounts (agency/representative
   account shares them). Passport-organisation accounts (Елама, Витамин)
   often get API applications declined — use a representative or managing
   account *(speaker)*.

**Backend selection for keyword parsing** (`wordstat_backend` in their tool):

| Mode | Behaviour |
|---|---|
| `auto` (default) | Direct API v4 first; on failure (no Direct, points exhausted, timeout) fall back to Cloud |
| `direct` | Direct v4 only (free, per-account limits) |
| `cloud` | Cloud Search API only, no Direct OAuth |

Both backends return the same Wordstat data (identical phrase counts and
shows in the speakers' side-by-side run). Direct v4 limits are per account;
the workaround is rotating several connected accounts. In this skill the
Cloud API is capped at 100 req/h (see `yd-wordstat.sh`), so plan batches.

## 3. Masks

A **mask** is a short phrase (1–3 words, sometimes 4) as people search for the
product. «окна» is not a mask; «пластиковые окна под ключ» is.

Sources, in order of preference:
1. Written by hand: 5–20 phrases as the client's customer would say them.
2. AI from the client's site/brief (agent proposes, user prunes).
3. Competitor landing pages: 1–8 URLs (top-10…50 possible); the agent takes
   commercial phrases from H1/titles/SEO blocks.
4. Optional: Yandex Images, Direct competitor ads (needs anti-captcha
   handling, not reliable at volume).

Order: **narrow masks first** (product + qualifier), broad ones last. Merge
close variants, set aside informational/other-niche masks (design project,
cosmetic repair) as separate groups instead of deleting them. Output
`masks.txt` as input for the next step.

Do not just ask a chat model to "collect keywords": it takes phrases from
SEO sites and cannot return real frequency — Wordstat access is required.

## 4. Wordstat collection

- Source: Wordstat through Direct API (the «Подбор слов» mechanism) or Cloud.
- Take the **left column** («запросы, где есть все слова маски»,
  `SearchedWith`) with `Shows` (monthly). Structure: one mask = one group,
  phrases sorted by Shows inside.
- v4 Live flow per batch: `CreateNewWordstatReport` (≤10 masks per batch,
  GeoID e.g. 213 Москва) → poll `GetWordstatReportList` until Done (~15 s)
  → `GetWordstatReport` → `DeleteWordstatReport` (reports are limited, always
  delete). Save `raw.json` + `phrases.csv` (group, phrase, shows). Keep the
  token in `.env`, never print it in chat.
- A response holds at most ~2000–2500 phrases *(speaker)*. For broad masks
  that is not the full tail → second pass.

**Second pass (топ-10):** mask → report 1 (up to ~200 phrases) → take the
10 highest-frequency phrases of the group → report 2 for each → merge into
the *same group*, remove duplicates. Pro: many more tail phrases (needed for
negative-keyword analysis and autotargeting). Con: each mask costs ~11
phrases of the daily limit instead of 1. Depth (top-10/20) is configurable.
Overly broad masks («cherry», «окно») should be refused or deepened by the
agent instead of parsed as-is.

Search suggestions (поисковые подсказки) are a second source for both masks
and negative candidates.

## 5. Negative keywords

Operators (how they match — put these rules in the prompt, otherwise the agent
writes plain words only):

| Minus | Removes |
|---|---|
| `автомобиль` | all word forms (кинолог, кинолога…), word order irrelevant |
| `!автомобиль` | only this exact word form |
| `"автомобиль"` | only a query consisting of that one word («для автомобиля» stays) |
| `"!автомобиль"` | only a one-word query in exactly this form |

Morphology can be turned off for the whole list ("exact forms only").

**Candidate method:** a candidate is a word that occurs in phrases of a group
but not in the mask/group name. For each candidate record the count of
phrases containing it, then the human selects. Boundaries: a minus from one
group must not hit the mask or phrases of another group — recompute after
every accepted minus (a new minus can remove half of the phrases of an
unrelated tail).

Agents should also compare with a **common negatives list**:
- Учёба: реферат, курсовая, диплом, доклад, презентация, определение
- Халява: скачать, торрент, кряк
- Работа: вакансия, резюме, зарплата, стажировка
- Площадки: вайлдберриз, wildberries, озон, авито
- Regions not in the targeting (cities) — see below.

**Do not mass-minus «бесплатно» / «что такое»** without checking the niche:
for a free webinar, info-business or education they are target demand
(speaker's slide). The same for info-queries when masks are informational
(course for seamstresses).

**Regions:** with expanded geo targeting and personalisation both
non-disableable (speaker: since Aug 2026), non-target cities are added as
negative keywords or via the exclusion settings for autotargeting/
personalisation. Collect them as a separate negative group.

Negative keywords also work for **autotargeting**, which is why they are
collected even when keywords themselves are few (Yandex help states that
minus-phrases apply to autotargeting).

Additional source: Search queries report after launch — keep feeding it into
negatives («докрутка минусов через API, не на глаз»).

## 6. Deduplication

- Remove phrase duplicates and word-order duplicates; keep one (the
  higher-frequency one). Also catch English/Russian spelling duplicates.
- After negatives are applied re-check duplicate word forms remaining.
- Clean typos/odd abbreviations that came from suggestions before they go
  into ads.

## 7. Grouping

Rule set (their `keyword-group-v2`):
- **One mask = one group** (default; best for autotargeting: headlines and
  texts are written per group).
- A word repeated **3 times** in a mask's phrases (the rarest such word)
  starts a separate sub-group → avoids both too-narrow groups and mega-groups.
- Words that never become a group: prepositions, conjunctions, question
  words, numbers, very frequent words. Turn this off for info niches where
  question phrases are legitimate masks.
- Do not split brands/models mechanically (e.g. car dealers: Chery,
  Jaecoo, Omoda — group by weight of the word, not by string similarity).
- Group by meaning too: each meaning-group is a candidate for its own
  landing page; ask the agent for a landing page TЗ per group.

When grouping is not needed: narrow masks («ремонт квартир под ключ»,
«остекление балконов») — each already is a ready group. When it is needed:
broad collection («ремонт», «окна», «семантическое ядро») where one answer
mixes different intents. Inputs for grouping: cleaned phrases (after
negatives and dedupe) and the negative list.

## 8. Pre-launch checklist (campaign builder)

1. Offer, geo, landing pages, client login connected to the project.
2. Budget and priority (narrow vs broad masks, search vs РСЯ order).
3. Semantic map → campaign architecture: one or several campaigns, 1:1
   groups, separate retargeting/ЕПК(feed)/autotargeting campaigns as needed.
4. Competitors + landing analysis (optional).
5. Masks → Wordstat → negatives → dedupe/morphology → groups.
6. Strategy choice: ask (clicks vs conversions, which conversion, weekly
   budget) — never silently default.
7. Ads per group: headlines/texts matching the mask; autotargeting reads
   titles and texts, so groups = meaning units.
8. Settings: disable personalisation/alt text where required, geo, negatives
   attached at the right level, UTM, extensions.
9. Dry run / audit of the plan before create (API validation, e.g. error
   422 on missing required fields); create as draft (campaign OFF).
10. Final audit, then launch.

**After launch:** daily check on *impressions* (`Impressions > 0`), not only
clicks; periodic negative top-up from search queries; separate control of
budget, bids and Metrika goals on the landing.

## 9. Safety rules for AI that edits an account

- Read freely; **write only after explicit approval** for anything beyond
  trivial (candidate negatives, stopping ads, budget changes).
- Allowed autonomously: narrow guard-rails such as pausing a campaign that
  keeps spending at ~3–5 ₽/click for several hours (checked hourly/2-hourly).
- «Включи все / выключи все» is dangerous: restore to the *previous* state
  from a change log, not to "all enabled". Keep a full change log (who/what/
  when: AI, human, system) that supports rollback — the cabinet's own change
  history is not enough.
- Don't paste secrets into chat; keep tokens in `.env`; run a security audit
  of the repo periodically.
- Complex niches (info-business, ambiguous negatives): AI highlights the
  problems, the human decides.
- One chat = one project/account. When several accounts are connected, the
  active account must be switched explicitly ("revolver"), never inferred.

## 10. Not possible through the API (as of the webinar, Oct 2026)

- Master campaigns (МК) and ЕПК-from-scratch setup: browser automation only.
- Some social/marketplace sources need browser automation (no API).
- Fully correct automation needs a complete Direct API; the speakers state
  the specialist is not replaced, only the routine (setup in ~1 hour per
  project, reporting, daily checks).

## 11. How this maps onto this skill

| Task | Use |
|---|---|
| frequency / related phrases | `scripts/yd-wordstat.sh top|region` |
| account negative-keyword audit | `references/audit-methodology-gorbunov.md` (negatives as themes) |
| campaign structure checks | `references/yandex-audit.md` |
| group/mask rules, operator table, candidate method | this file |
