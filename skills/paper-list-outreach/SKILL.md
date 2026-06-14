---
name: paper-list-outreach
description: Boost a paper's visibility/citations by adding it to curated "awesome list" / paper-list GitHub repos. Given a paper (arXiv link or metadata) and a target number N of relevant repos, discovers relevant repos across stated AND latent topics, skips repos that already list the paper, edits each repo locally in its exact format, and packages per-repo branches + patches + personalized PR messages + a ranked summary for the user to submit. Use when the user wants to promote a paper, get it into awesome lists, increase citations, or do paper outreach.
---

# Paper-List Outreach

Get a paper added to curated GitHub paper-lists ("awesome-X", surveys, `*-papers`, benchmark indexes). The user provides **a paper** and **N = how many relevant repos** they want. You discover repos, dedup against ones that already list it, edit each locally, and package everything for the user to submit. **You never push PRs** — the user holds final control.

## Inputs
- **Paper**: an arXiv link (preferred) or metadata or raw pasted content. You must end up with: title, venue, arXiv abs+pdf, project page, code, dataset, authors.
- **N**: target number of relevant repos to edit. Set /goal and keep discovering+editing until you have N *genuine-fit* repos (after dedup and NO_FIT rejections), or until the relevant space is demonstrably saturated (then say so honestly rather than padding with weak fits).

If the paper or N is missing, ask for them before starting.

## Setup
1. Pick a workspace dir (e.g. `./paper-outreach/` or ask). Create `repos/`, `patches/`, `pr-messages/`.
2. Fetch the paper (WebFetch the arXiv abs + project page). Write `paper.json` with the metadata above plus a one-line summary.
3. Confirm tools: `git`, `curl`, `jq`. Check `gh` + auth (optional — only needed if the user later wants auto-submit). Check `curl -s https://api.github.com/rate_limit` (unauth: 10 searches/min, 60 core/hr; a token raises this a lot — suggest the user export `GITHUB_TOKEN` if N is large).

## Phase 1 — Keyword discovery (THE most important step)

A keyword list that only echoes the abstract is self-limiting. The best matches are fields the paper *enables* but never names — the authors themselves may not realize the paper matters there. **Reason from your own knowledge of the research landscape, not just the paper's text.** The paper is evidence, not the boundary.

Produce keywords in three tiers:
- **T1 Stated** — terms in the title/abstract.
- **T2 Adjacent** — implied by the paper's methods/data/tasks but not named as keywords.
- **T3 Latent** — fields the paper is *useful to* but doesn't address. Highest citation upside (those communities don't know the paper exists).

Run these **discovery lenses** to surface T2/T3 (each is a question, answered from your understanding):
1. **Method-as-tool** — what does the paper *produce* that another subfield could adopt as an instrument? (e.g. a distractor taxonomy → hallucination researchers)
2. **Who-cites / consumer** — which downstream fields would benchmark *against* this or use it as a dependency?
3. **Modality decomposition** — break the artifact into every property independently; each property is its own community/list (e.g. first-person→egocentric, multi-view→exocentric, long→long-form).
4. **Capability decomposition** — what latent capabilities does the task secretly test? (temporal reasoning, grounding, attribution, counting…) Each maps to a benchmark list.
5. **Abstraction ladder** — generalize the contribution up a rung or two; find lists at each level.
6. **Analogy/transfer** — where else does this exact structure appear? (application domains: medical, autonomous-driving, sports, security…)
7. **Method neighbors** — techniques it sits beside even if unused.

For **each** discovered topic, record three things in `keywords.tsv` (topic ⇥ tier ⇥ fit_rationale): the topic, its tier (T1/T2/T3), and a **defensible one-sentence rationale for why the paper fits** (this becomes the seed of the PR message). 

Then **score and prioritize**: rate each topic by *fit strength* (would a maintainer accept the PR without feeling spammed?) × *reach* (does an active, populated list exist?). Map to relevance tiers used later: 🟢 core / 🟡 strong / 🟠 moderate. Search high-fit topics first.

Guardrail: discover **liberally**, commit **conservatively**. A latent angle only survives if its rationale is real; Phase 4 must be willing to kill it (see NO_FIT). Overclaiming relevance to a hot field gets PRs rejected and burns goodwill.

Sanity check before moving on: *"What field would be surprised-but-glad to learn about this paper?"* If a tier is empty, push the lenses harder.

## Phase 2 — Search GitHub

Use `scripts/search.sh "<query>" [stars|updated]` (sorts by stars by default — do NOT default to "updated", it surfaces bot "awesome-stars" noise). For each priority topic, run several queries varying the name pattern — NOT just `awesome-*`:
`awesome <topic> in:name`, `<topic> survey in:name,description`, `<topic> papers in:name`, `<topic> paper-list in:name`, `<topic> benchmark in:name`, plus `topic:<tag>` searches.

Respect rate limits (sleep ~7s between searches unauth). Collect candidates into `candidates.tsv` (full_name ⇥ stars ⇥ pushed ⇥ description). Prioritize repos active in the current/recent year. De-noise: drop personal "awesome-stars" dumps, individual model/code repos, and unrelated hits.

## Phase 3 — Verify, filter, and DEDUP

For each candidate, before cloning:
1. **Confirm it's a real, editable curated list** (has a README/list with an entry format you can match) — not a prose-only survey, not a single model/code repo.
2. **DEDUP — check if the paper is already listed.** Run `scripts/check-listed.sh <owner/repo> "<paper title>" "<arxiv_id>" "<dataset/code url>"`. It fetches the repo's README/list files and greps for the title, arXiv id, project/dataset/code URLs, and a distinctive title n-gram. 
   - If **already listed** → mark it `ALREADY_LISTED` in `candidates.tsv`, record where, and **SKIP it for PRs** (do not clone/edit). Still report it in the summary under a separate "already lists the paper" section so the user knows.
   - If **not listed** → proceed.
3. **Scope check**: does the paper genuinely belong in this list's scope? If not, mark `NO_FIT` with a reason and skip.

Keep going until you have N repos that pass all three checks (real list + not-already-listed + in-scope). If you exhaust good candidates before N, report the shortfall honestly with the count reached.

## Phase 4 — Clone + edit (one subagent per repo)

Shallow-clone each surviving repo into `repos/<folder>` (prefix the owner to the folder name when basenames collide on case-insensitive filesystems). Dispatch **one general-purpose subagent per repo** (parallelize in batches) with this contract:

> Work ONLY inside `repos/<folder>`. Read the README (and any data file that generates it). Learn the EXACT entry format (table row? bullet+badges? structured JSON?). Find the single most appropriate section (benchmarks/datasets/evaluation usually). Insert ONE entry for the paper matching the surrounding format EXACTLY — same badge style, link order, date placement, ordering (chronological? append?). Touch nothing else. Frame the entry around THIS repo's specific angle (use the fit_rationale for the matching topic). If a data file generates the README, edit the data file. Then run `git -C <abs path> diff` to confirm a single clean insertion. If the paper genuinely doesn't fit, make NO edits and return `NO_FIT: <reason>`. Return: SECTION_USED, INSERTED_SNIPPET, MATCHING_TOPICS, PR_MESSAGE (**follow the PR-message style rules below — short, human, casual; NOT a polished abstract**), CONTRIBUTING_NOTES.

### PR-message style (MANDATORY — this is how the message gets accepted)
The PR/issue message is a quick note from one contributor to a maintainer, **not** marketing copy. Auto-generated promo text is obvious and gets ignored. Write what a real contributor would type:
- **Never imply you authored the paper** — write as a neutral suggestion from someone who came across it. Do NOT say "our paper", "my paper", "we propose", "our benchmark", etc. Refer to the paper by name in the third person.
- **Three-part body structure (MANDATORY)** — the body paragraph always follows this order: (1) **short opener + ask** — "Hey, thanks for maintaining this list! Could I add <Paper> to the <section> section?"; (2) **what the paper is about** — "<Paper> is about <plain clause>."; (3) **why it fits here** — "It is relevant to your collection because <one concrete, list-specific reason>." Keep all three in one flowing paragraph.
- **Short opener** — the greeting + ask is one short line; don't pile context into the opener (the "is about" and "relevant because" parts carry the context).
- **No line breaks inside the message body** — write the three parts (opener+ask, "is about", "relevant because") as one continuous flowing paragraph (no mid-message newlines). Then a single links line, then `Thanks!`. Match the structure of the example below exactly.
- **End with `Thanks!`** — the message always closes with `Thanks!` on its own line.
- **Concise** — keep the description to 1-3 plain sentences. No feature dumps, no stat-sheets ("~2.4K QA pairs across 15 task categories and 3 cognitive levels" becomes just "a video-QA benchmark for 3D gameplay").
- **Human + casual** — open like a person: "Hey, thanks for maintaining this list!". Perfect grammar is not required.
- **NO emoji** — none, anywhere in the message or title. Emoji read as AI/marketing.
- **NO em-dashes** (—) or en-dashes (–). Use a period, comma, or "and" instead. Em-dashes are a strong tell of AI-written text. (This applies to the prose message, not to links.)
- **Ask, don't announce** — phrase it as a request: "Could I add it?" / "thought it'd fit under X", not "Adds GameplayQA (ACL 2026)...".
- **One concrete reason** it fits *this* list (the section + the single most relevant angle), then the links. Stop there.
- **No buzzword stacking** — drop "diagnostic", "comprehensive framework", "Self/Other/World decomposition" etc. unless genuinely needed.
- **Links on one line** — `Paper: <arXiv> | Project: <project>` (add `| Code: <code>` if relevant). One line, separated by `|`.
- Vary the opener/wording per repo so messages don't look mass-produced.

Template (adapt, don't copy verbatim). Note the three-part body (opener+ask, "is about", "relevant because") as one flowing paragraph, then a links line, then `Thanks!`:
> Hey, thanks for maintaining this list! Could I add <Paper> to the <section> section? <Paper> is about <one plain clause on what it is> (<venue>). It is relevant to your collection because <one concrete, list-specific reason>.
>
> Paper: <arXiv> | Project: <project>
>
> Thanks!

Good:
> Hey, thanks for maintaining this list! Could I add GameplayQA to the Hallucination Benchmarks section? GameplayQA is about evaluating multi-video understanding in LVLMs/MLLMs (ACL 2026). It is relevant to your collection because its error analysis is organized around a structured distractor taxonomy that characterizes hallucination types in video understanding.
>
> Paper: https://arxiv.org/abs/2603.24329 | Project: https://hats-ict.github.io/gameplayqa/
>
> Thanks!

Bad (too markety, claims authorship, has em-dash + stat dump): *"Adds our GameplayQA (ACL 2026) — a diagnostic benchmark of ~2.4K QA pairs across 15 task categories and 3 cognitive levels for first-person/POV-synced multi-video understanding..."*

Before finalizing each message, scan it and: strip any emoji and any — or – characters; remove any first-person authorship wording ("our/my paper", "we"); confirm the body paragraph has no internal line breaks; confirm it ends with `Thanks!`.

Honor NO_FIT verdicts — remove that clone; do not force-fit. (NO_FIT and ALREADY_LISTED are *successes* of the filter, not failures.)

## Phase 5 — Package for submission

For each edited repo, use `scripts/package-repo.sh <folder>` which: configures a local git identity, commits the change on branch `add-paper` (configurable), exports `patches/<folder>.patch`, and appends `<folder> ⇥ slug ⇥ url` to `manifest.tsv`. Write each PR message to `pr-messages/<folder>.md` (line 1 = PR **title**, then the body). Keep the title short and plain too (e.g. *"Add GameplayQA (ACL 2026)"*) — not a sentence. The body must obey the PR-message style rules in Phase 4: one flowing greeting+ask+description paragraph with **no internal line breaks**, then the links line, then `Thanks!`; **never imply you authored the paper**, short, human, casual, an ask, **no emoji, no em/en-dashes**, always ending with `Thanks!`. Skim the finished `pr-messages/*.md` and rewrite any that drifted into abstract-style promo text or first-person authorship wording; grep the files for emoji and for `—`/`–` and strip any that slipped in, and confirm each ends with `Thanks!`.

Then generate `SUMMARY.md`: a table **ranked by relevance tier then stars** (not stars alone), with columns: `# | Tier | Repo | Link | ★ | Time (last push) | Matching topics | Personalized PR message`. Add sections for: tiering notes, **repos that already list the paper (skipped)**, repos considered but NO_FIT, and the search methodology. Copy `scripts/submit-pr.sh` into the workspace and write `HOW-TO-SUBMIT.md`.

## Phase 6 — Hand off (user submits)

Tell the user the counts (edited / already-listed-skipped / no-fit), point them at `SUMMARY.md` and `submit-pr.sh`. **Never push.** `submit-pr.sh <id|folder>` dry-runs; `<id|folder> --go` forks+pushes+opens the PR via `gh` (or prints manual steps if `gh` is absent). The user decides which to submit.

## Principles
- **Relevance over reach** — rank by fit, not stars; a 18k★ general list can rank below a tiny on-topic one.
- **Multiple match-axes** — one paper legitimately fits several distinct list categories; that's how you reach large N.
- **Dedup always** — never PR a paper into a list that already has it; detect, mark, skip, report.
- **Honest NO_FIT** — protects the author's reputation with maintainers.
- **Human, short PR messages** — every PR/issue note reads like a quick message from a real person ("Hey, thanks for maintaining this list! Could I add X?"), a short ask plus 1-3 plain sentences, an ask not an announcement, never a polished abstract. Never imply you authored the paper (no "our/my paper", no "we"). One flowing paragraph with no internal line breaks, a links line, then `Thanks!`. No emoji, no em/en-dashes. Marketing-tone messages get ignored. See Phase 4 PR-message style.
- **Human-in-the-loop** — nothing is pushed without the user's explicit `--go`.

## Bundled scripts (`scripts/`)
- `search.sh "<query>" [stars|updated]` — GitHub repo search → TSV.
- `check-listed.sh <owner/repo> "<title>" "<arxiv_id>" [url...]` — dedup probe; prints `ALREADY_LISTED:<evidence>` or `NOT_LISTED`.
- `package-repo.sh <folder> [branch]` — commit + patch + manifest line.
- `submit-pr.sh` — user-run submission helper (dry-run default; `--go` to push).
