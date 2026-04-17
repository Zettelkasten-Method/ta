# ta agent skills

Copy-paste skills for coding agents to drive `ta` on behalf of the user.

## Installation (Claude Code)

```bash
cp -r docs/skills/ta-search ~/.claude/skills/
cp -r docs/skills/ta-associative-recall ~/.claude/skills/
cp -r docs/skills/ta-deep-research ~/.claude/skills/
```

Restart your Claude Code session (or re-run skill discovery). When the user's message matches a skill's `description` trigger, the agent loads the skill and follows its instructions.

## Installation (other agents)

Each `SKILL.md` is plain markdown with YAML frontmatter. Adapt to your agent's skill-loading convention:

- Frontmatter `name` — the skill identifier.
- Frontmatter `description` — the trigger prompt (when to activate).
- Body — the agent's instructions.

The only Claude-specific element in the skill bodies is `AskUserQuestion` (used by `ta-associative-recall` and `ta-deep-research` for interactive pivot/narrow steps). Each skill notes a plain-text fallback.

## The three skills

| Skill | Triggers on | Strategy |
|---|---|---|
| `ta-search` | Literal lookups. "Find my note about X." | Single query, read YAML, call `show` if needed. |
| `ta-associative-recall` | Fuzzy/vibe queries. "That idea I had about..." | Fan out 5–8 literal probes, aggregate, rank, offer pivots. |
| `ta-deep-research` | Topic exploration. "Trace X through my notes." | Graph crawl + selective read + iterative extraction + synthesis. |

## Prerequisites

Users need `ta` on `PATH` and an archive configured via `--archive`, `TA_DIR`, or `~/.config/ta/config.yaml`. See the main project README.
