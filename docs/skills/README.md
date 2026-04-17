# zk-llm agent skills

Copy-paste skills for coding agents to drive `zk-llm` on behalf of the user.

## Installation (Claude Code)

```bash
cp -r docs/skills/zk-llm-search ~/.claude/skills/
cp -r docs/skills/zk-llm-associative-recall ~/.claude/skills/
cp -r docs/skills/zk-llm-deep-research ~/.claude/skills/
```

Restart your Claude Code session (or re-run skill discovery). When the user's message matches a skill's `description` trigger, the agent loads the skill and follows its instructions.

## Installation (other agents)

Each `SKILL.md` is plain markdown with YAML frontmatter. Adapt to your agent's skill-loading convention:

- Frontmatter `name` — the skill identifier.
- Frontmatter `description` — the trigger prompt (when to activate).
- Body — the agent's instructions.

The only Claude-specific element in the skill bodies is `AskUserQuestion` (used by `zk-llm-associative-recall` and `zk-llm-deep-research` for interactive pivot/narrow steps). Each skill notes a plain-text fallback.

## The three skills

| Skill | Triggers on | Strategy |
|---|---|---|
| `zk-llm-search` | Literal lookups. "Find my note about X." | Single query, read YAML, call `show` if needed. |
| `zk-llm-associative-recall` | Fuzzy/vibe queries. "That idea I had about..." | Fan out 5–8 literal probes, aggregate, rank, offer pivots. |
| `zk-llm-deep-research` | Topic exploration. "Trace X through my notes." | Graph crawl + selective read + iterative extraction + synthesis. |

## Prerequisites

Users need `zk-llm` on `PATH` and an archive configured via `--archive`, `ZK_LLM_ARCHIVE`, or `~/.config/zk-llm/config.yaml`. See the main project README.
