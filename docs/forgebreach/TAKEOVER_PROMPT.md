# FORGEBREACH — copy/paste handover

The repository already contains `CLAUDE.md`, a locked specification, a progress ledger, GitHub issues and a passing baseline workflow. There is **no need to upload documents, recreate the repository or run `/init`**. Work from `feature/forgebreach-controller-arena-crawl` in `kavemankai/Phone-of-thrones-`.

## Gameplay coding (Fable — recommended)

Use the Claude Code slash command after opening the repo:

`/forgebreach-takeover`

Or paste the following when slash skills are unavailable:

> Take over gameplay implementation of FORGEBREACH in repository `kavemankai/Phone-of-thrones-`, branch `feature/forgebreach-controller-arena-crawl`. Read `CLAUDE.md`, `docs/forgebreach/PROGRESS.md` and `docs/forgebreach/START_HERE.md` and the active issue. Do not redo planning or administrative setup. Start with the earliest uncompleted milestone (initially issue #3: controller-first landscape combat). Write and commit production Godot code, preserve existing v0.9 combat behaviour and tests, and update `PROGRESS.md`. Do not run automated tests or builds: GitHub Actions does that, with a separate cheaper-model QA agent reviewing failures. After completing the milestone's code, hand off the exact commit SHA and stop before the next milestone pending QA sign-off. Keep draft PR #9 open and do not merge.

## Testing/review (cheaper model — separate Claude Code session)

Select the lower-cost model first, then invoke:

`/forgebreach-qa`

Or paste:

> Review the latest FORGEBREACH gameplay milestone as independent QA. Read `docs/forgebreach/QA_PROTOCOL.md` and `PROGRESS.md`, check the GitHub Actions run for the **exact HEAD SHA**, add test-only coverage on a separate branch as needed, and give Fable reproducible failures with file/line evidence. Do not edit production gameplay. Never claim CI proves actual Windows execution or gamepad feel.

## Working references
- [Implementation issue #3](https://github.com/kavemankai/Phone-of-thrones-/issues/3)
- [Draft PR #9](https://github.com/kavemankai/Phone-of-thrones-/pull/9)
- [All implementation and QA issues](https://github.com/kavemankai/Phone-of-thrones-/issues)
- [Automated QA workflow](https://github.com/kavemankai/Phone-of-thrones-/actions/workflows/forgebreach-qa.yml)

**Skill availability:** Project skills in `.claude/skills/` load in local Claude Code and supported repository cloud sessions. Some Claude Code cloud project threads do not load repository-local skills; use the pasteable prompt above instead. If a fresh `.claude/` directory was added while Claude Code was already open, use `/reload-skills` or restart the session.
