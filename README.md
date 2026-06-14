# paper-list-outreach-skill

<img width="1774" height="887" alt="paper-list-outreach-skill-diagram" src="https://github.com/user-attachments/assets/c12434da-82bb-49c0-9b9f-205702022840" />


An agent skill that helps get a research paper added to curated GitHub paper-lists (`awesome-*`, surveys, `*-papers`, benchmark indexes).

It is written as a plain-Markdown skill (`SKILL.md` + helper scripts), so it works with any coding agent that can read a skill file and run shell commands, including Claude Code, OpenAI Codex, OpenClaw, and similar tools.

Given **a paper** (arXiv link or metadata) and **N** = how many relevant repos you want, the skill:

1. Discovers relevant repos across stated *and* latent topics (not just the abstract's keywords).
2. Skips repos that already list the paper (dedup).
3. Edits each repo locally in its exact entry format (one sub-task per repo).
4. Packages per-repo branches, patches, personalized PR messages, and a ranked summary for **you** to submit.

It never pushes anything. You stay in control of every PR.

## Outreach message style

PR/issue messages are written to read like a quick note from a real contributor, not marketing copy:

- Three-part body in one flowing paragraph: short opener + ask, "<Paper> is about ...", "It is relevant to your collection because ...".
- Third person (never implies you authored the paper), no emoji, no em/en-dashes.
- Links on a single line, then `Thanks!`.

Example:

> Hey, thanks for maintaining this list! Could I add GameplayQA to the Hallucination Benchmarks section? GameplayQA is about evaluating multi-video understanding in LVLMs/MLLMs (ACL 2026). It is relevant to your collection because its error analysis is organized around a structured distractor taxonomy that characterizes hallucination types in video understanding.
>
> Paper: https://arxiv.org/abs/2603.24329 | Project: https://hats-ict.github.io/gameplayqa/
>
> Thanks!

## Install

**Recommended: let your agent install it.** Just paste this repo link to your coding agent (Claude Code, Codex, OpenClaw, etc.) and ask it to install the skill, for example:

> Install the skill from https://github.com/wangyz1999/paper-list-outreach-skill into my skills directory.

The agent will clone the repo and place `skills/paper-list-outreach/` in the right location for your tool.

### Manual install

If you'd rather do it by hand, clone the repo:

```bash
git clone https://github.com/wangyz1999/paper-list-outreach-skill.git
```

**Claude Code** — copy the skill into a skills directory:

```bash
# user-level (available in every project)
cp -R paper-list-outreach-skill/skills/paper-list-outreach ~/.claude/skills/

# or project-level
cp -R paper-list-outreach-skill/skills/paper-list-outreach .claude/skills/
```

Then invoke it with `/paper-list-outreach` or just ask to "add my paper to awesome lists".

**Codex, OpenClaw, and other agents** — there is no special install step. Point the agent at `skills/paper-list-outreach/SKILL.md` (open it, reference it in your prompt, or drop it in the working directory) and ask it to follow the skill. The scripts in `scripts/` are plain shell and run anywhere.

## Requirements

- `git`, `curl`, `jq`
- `gh` (optional) for the auto-submit helper
- A `GITHUB_TOKEN` is recommended if N is large (raises GitHub search rate limits)

## Layout

```
skills/paper-list-outreach/
  SKILL.md              # the skill definition
  scripts/
    search.sh           # GitHub repo search -> TSV
    check-listed.sh      # dedup probe
    package-repo.sh      # commit + patch + manifest
    submit-pr.sh         # user-run submission helper (dry-run by default)
```
