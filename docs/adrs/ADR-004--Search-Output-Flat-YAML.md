---
title: "ADR-004: Search Output as Flat YAML with Depth and Via Metadata"
date: 2026-04-17
deciders:
  - Christian Tietze
consulted:
  - Claude Sonnet 4.5
status: accepted
related:
  - ADR-005
---

# ADR-004: Search Output as Flat YAML with Depth and Via Metadata

## Context

`zk-llm search` emits a graph-expanded result set: direct hits plus a bounded neighborhood reached by following outgoing wiki-link edges up to `--depth` hops (default 3, cap 10). The output is consumed by coding agents.

The question is the *shape* of the output:

- Should it be a nested tree rooted at each direct hit?
- A flat list with metadata describing each node's relationship to the hit set?
- A pair of lists (nodes + edges) modeling the graph explicitly?
- Something else?

The constraints that matter:

1. **Agent context cost.** Every byte of output consumes agent context. Compactness matters. A node reachable via three different direct hits should not appear three times.
2. **Cycle safety.** Zettelkasten graphs contain cycles. The output must be finite and deterministic regardless of graph shape.
3. **Interpretability.** An agent reading the output must be able to answer: "which of these are direct matches vs. neighborhood context?" and "how did I get to this node from a hit?"
4. **Stability.** Running the same query twice against the same archive must produce the same output ordering (critical for agent caching and change detection).

## Decision

Emit a **flat YAML list** where each node appears exactly once, with two metadata fields distinguishing its role:

```yaml
- ref: "202503091430 Mental Models.md"
  title: "Mental Models"
  snippet: "...second-order thinking is about tracing the chain..."
  tags: [learning, thinking]
  links: ["202504151200 Second Order.md", "202505100900 Inversion.md"]
  depth: 0
  via: null
- ref: "202504151200 Second Order.md"
  title: "Second Order"
  tags: [thinking]
  links: ["202506010800 Compounding.md"]
  depth: 1
  via: "202503091430 Mental Models.md"
```

### Field semantics

- **`ref`**: the NoteRef (filename). Uniquely identifies the node.
- **`title`**: filename stem with the 12-digit timestamp prefix stripped.
- **`snippet`**: ~120 characters of non-code text centered on the first predicate hit. Only present when `depth == 0`.
- **`tags`**: hashtag names without the leading `#`, document order, deduped. Leaf annotation only — tags are not graph-traversal edges (design spec §1).
- **`links`**: resolved outgoing wiki-link NoteRefs, document order, deduped. Unresolved links are not emitted.
- **`depth`**: shortest-path hop count from the nearest direct hit. `0` means this node is itself a direct hit; `1` means one wiki-link hop away; up to `--depth`.
- **`via`**: the NoteRef of the parent on the shortest path. `null` when `depth == 0`.

### Ordering

- Direct hits (depth 0) come first, in `rg` file-list iteration order.
- Expansion nodes follow, in BFS visit order.
- Within a depth level, siblings appear in the order they were enqueued (which follows document order of the wiki-links in the parent).

### Empty result

A literal `[]` on a single line. Never a missing key or a non-empty-but-malformed document.

## Alternatives Considered

### A. Nested tree per direct hit

```yaml
- ref: "202503091430 Mental Models.md"
  title: "Mental Models"
  snippet: "..."
  tags: [...]
  children:
    - ref: "202504151200 Second Order.md"
      title: "Second Order"
      tags: [...]
      children: [...]
```

**Rejected because:**

- A node reachable via multiple direct hits appears N times. For densely linked archives, this explodes. In a worst-case graph where every note links to every other, depth-3 from 20 hits could emit 20 × 20 × 20 × 20 = 160,000 entries even though only ~20 unique notes exist.
- Cycle handling requires inventing a placeholder or truncation marker; the flat-with-visited-set form sidesteps this entirely.
- Agents can reconstruct the tree from the flat form using `via`, but the reverse (flat from tree) requires deduping — harder and more error-prone.

### B. Explicit nodes + edges (adjacency list)

```yaml
nodes:
  - {ref: "A.md", title: "A", tags: [...], depth: 0}
  - {ref: "B.md", title: "B", tags: [...], depth: 1}
edges:
  - {from: "A.md", to: "B.md"}
```

**Rejected because:** more verbose than the flat list with no added information the agent needs. The `via` + `links` fields already encode the edges implicitly. Two top-level sections double the YAML surface area for no gain.

### C. Flat list without `depth` / `via`

Just ref, title, tags, links, snippet. Agent infers role by whether snippet is present.

**Rejected because:** loses the distance information. An agent wanting to prioritize "closer" neighborhood nodes (depth 1 > depth 3) can't do so without re-parsing the graph from `links`. The two extra fields cost ~20 bytes per node and eliminate that work.

### D. JSONL (one JSON object per line)

Same data, different encoding.

**Rejected because:** YAML is more readable to humans during the demo and costs roughly the same tokens for the agent. The prototype is demoed live; readability on stdout matters. If a downstream pipeline needed JSON, a future flag (`--format json`) is a small addition.

## Consequences

### Positive

- **Compact.** Each node appears once. Payload scales with |visited set|, not with reach paths.
- **Cycle-safe by construction.** BFS visited-set dedup ensures termination.
- **Deterministic ordering.** `rg` file order is stable; BFS within that is stable; within a depth level, sibling order is document order.
- **Agent-friendly.** The agent can partition by `depth == 0` (hits) vs `depth > 0` (context), or reconstruct the graph from `via` + `links` if it wants a tree.
- **Reads cleanly on stdout** during the demo.

### Negative

- **Loses alternate paths.** A node reached via both direct hit A and direct hit B shows only one `via` (the first path the BFS found). The `links` arrays on other nodes implicitly carry the full edge set, so the information is recoverable, but not immediately visible.
- **`via` relationships point "toward" the hit** rather than away from it, which takes a moment to internalize.

### Neutral

- **`--format` is not implemented for the prototype.** YAML is the only emitter. Adding JSON later is trivial (reuse the same struct serializer).
- **Snippet is only on depth-0 nodes.** Expansion nodes are context, not matches. If the demo surfaces a need for snippets on expansion nodes (e.g., to explain "why is this node here?"), that's an additive change.
