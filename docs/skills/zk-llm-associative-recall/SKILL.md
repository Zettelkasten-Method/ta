---
name: zk-llm-associative-recall
description: Use when the user describes a note by vibe, concept, or paraphrase rather than literal terms — "find notes about the feeling of X", "that idea I had about Y and Z", "something like ...", multilingual hints, or any query where you're not confident the user's exact words appear in the note. For literal lookups use zk-llm-search. For deep exploration of a topic use zk-llm-deep-research.
---

# Associative recall over a Zettelkasten

`zk-llm` is a literal retrieval tool — it matches exact strings, not concepts. Your job is to be the similarity engine wrapping it. Turn a fuzzy query into multiple literal probes, run them all, aggregate.

## The core workflow

```
User's vibe query
  → fan out 5–8 variants across three axes
  → run all variants in parallel with --depth 0
  → aggregate by ref, score by variant-overlap
  → present ranked list with firing-variant tags
  → offer 2–3 pivots via AskUserQuestion
  → recurse on pivot (maintain visited-refs set)
```

## Step 1 — Fan out across three axes

Generate 5–8 query variants total. Cover at least two of these three axes:

**Tag axis (2–4 variants).** Candidate tag names. Include variations the user might actually use:

- singular / plural (`#book` vs `#books`)
- hyphens / no hyphen (`#mental-models` vs `#mentalmodels`)
- camelCase / lowercase (`#JSON` vs `#json`)
- translations, if the archive is multilingual (German `#Ernährung` + English `#nutrition`)

**Phrase axis (2–3 variants).** Alternate phrasings of the concept as literal strings. Synonyms, common idioms, canonical book titles. For "procrastination and creativity": `"creative block"`, `"resistance to starting"`, `"getting stuck"`.

**Word axis (2–3 variants).** Distinctive single words for `--word` (respects word boundaries). For a note on inversion: `inversion`, `backward`, `pre-mortem`.

## Step 2 — Probe

Run each variant as a separate `zk-llm` invocation with `--depth 0`. Depth 0 gives clean direct hits without graph expansion, which matters for the aggregation step.

Empty-result queries are cheap and expected — fan out aggressively.

```bash
zk-llm search --tag procrastination --depth 0
zk-llm search --tag creativity --depth 0
zk-llm search --tag flow --depth 0
zk-llm search --phrase "creative block" --depth 0
zk-llm search --word resistance --depth 0
```

## Step 3 — Aggregate and score

Parse each YAML result. Merge by `ref`. For each ref:

- **+2** per variant that hit it
- **+1** if a tag-axis variant hit (tags are user-curated = high signal)
- **+1** if the snippet contains terms the user literally wrote in their query

Drop refs with score < 2 unless total results are sparse (fewer than 5 total refs).

## Step 4 — Present

Show 5–8 top-ranked refs. One line each, naming the variants that fired:

```
- "202503091430 Mental Models.md" — hit by #learning, "mental models" (score 5)
- "201011301103 Rules for an immutable note storage.md" — hit by #zettelkasten (score 3)
```

Always preserve the `.md` and quotation; the user may want to pass refs to `zk-llm show`.

## Step 5 — Offer pivots

While aggregating, also note:

- **Unasked tags** — tags that appeared on 2+ result refs but weren't in your query set. Strong signal that the user's own vocabulary has a term you missed.
- **Popular link targets** — refs that appeared in multiple `links:` arrays across your results but not as a direct hit themselves. These are graph hubs adjacent to the user's topic.
- **Recurring snippet phrases** — literal text that shows up across several snippets.

Pick the 2–3 strongest. Offer them with `AskUserQuestion`:

```
Which direction would you like to explore?
  - Notes tagged #productivity (appeared on 4 results)
  - Notes linking to "202503091430 Mental Models.md" (hub appeared in 3 link arrays)
  - Phrase "second-order thinking" (seen in 3 snippets)
```

**Non-Claude agent fallback:** ask in plain text. The point is the choice, not the tool.

## Step 6 — Recurse on pivot

Treat the chosen pivot as a new query. Maintain a `seen-refs` set across iterations so results don't repeat. Stop after 3 iterations unless the user keeps redirecting.

## Worked example

User: *"I remember writing something about how first impressions affect judgment, with a German word for it I think."*

Variants:

- `--tag bias` (tag guess)
- `--tag anchoring` (tag guess, common bias term)
- `--tag cognition` (tag guess)
- `--phrase "first impression"` (phrase)
- `--word Urteil` (German for "judgment")
- `--word anchoring` (word)

Run all six. Suppose `#anchoring` hits 3 refs, `"first impression"` hits 2 (one overlapping), `--word Urteil` hits 1. Ranked presentation leads with the overlap. Pivots to offer: if `#heuristics` appeared on 2 of the hits, that's a pivot. If one ref linked heavily to a `[[Kahneman]]` ref that wasn't a direct hit, that's another.

## Crucial framing

- `zk-llm` is literal. *You* are the similarity engine. Fan out aggressively.
- Empty-result queries are not a failure — they teach you what terms don't match.
- Mixed-language archives are common. If a title or tag looks German (or Japanese, Spanish, …), probe in that language too.
- Hashtags are user vocabulary. A user's tags are the best predictor of how they'd re-find a note. Bias variants toward the tag axis.

## Don't

- Don't run a single query and stop. The whole point of this skill is fan-out.
- Don't use `--depth > 0` in Step 2 — graph expansion pollutes the ranking signal.
- Don't invent pivots from thin air; extract them from the aggregated results.
- Don't skip Step 5 when the results are interesting. Offering pivots is where associative recall earns its keep.
