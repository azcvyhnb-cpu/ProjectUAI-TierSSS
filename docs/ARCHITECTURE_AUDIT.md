# UAI Architecture Audit and Evidence-Driven Roadmap

- Date: 2026-10-12
- Audited ref: `main`
- Audited commit: `ac6091c90cdaa55526411be3faa7deae4cc5c98a`
- Scope: static review of the repository tree, agent context, prompt assembly, runtime config, analyzer pipeline/graph, persistent research memory, test harness, bundler and CI workflow.
- Status: design/audit document only. No runtime source changes are made by this commit.

## Executive summary

UAI already contains several of the capabilities this architecture needs. Do not replace them with a parallel REA-like subsystem. Extend the existing agent, analyzer, research notebook, context manager and quality gate.

Existing capabilities verified in source:
- Conversation compaction, model-window-aware limits, estimated prompt/tool overhead and calibration: `src/agent/context.lua`, `src/agent/usage.lua`.
- Bounded subagent history and resumability: `src/agent/subagent.lua`.
- Read-only game analyzer pipeline with normalization, evidence, entities, graph, classification, adaptive follow-up and a bounded timeline: `src/analyzer/engine.lua` and sibling modules.
- Place-scoped persistent research notes, confidence labels, bounded keyword search, deduplication and a 1.5 MiB file limit: `src/runtime/research_memory.lua`.
- Conditional task-specific prompt guidance and project-oriented source editing/build/test workflows: `src/agent/prompt.lua`.
- Regression suites for context compaction, context benchmarks, game analyzer, research memory and model collaboration; CI builds and tests a generated bundle: `.github/workflows/quality.yml`.

This is a source-level audit, not a claim that CI or a real Roblox/Delta runtime was executed during this review.

## Current architecture map

```text
User / UI
  -> agent session + loop
     -> context manager (history, compaction, prompt-pressure estimate)
     -> prompt builder (task-specific guidance + environment + tool descriptions)
     -> tool registry / bounded subagents
        -> game analyzer -> normalized snapshot -> evidence ledger
           -> semantic entities -> graph -> classifier -> adaptive follow-up
        -> research tools -> per-PlaceId persistent JSON notebook
        -> coding/workspace tools -> source edits -> build/analyze/test
     -> provider adapters / optional ai_collaborate
  -> transcript, usage stats, runtime filesystem and dist bundle
```

## Findings and risks

### F1 — Strong existing foundation; avoid duplicate architecture
**Evidence:** `src/analyzer/engine.lua`, `src/runtime/research_memory.lua`, `src/agent/context.lua`, `src/agent/subagent.lua`, `docs/game-analyzer.md`.

**Implication:** A new generic Knowledge Engine or second orchestration loop would duplicate state and create invalidation problems. Add stable interfaces around the existing components first.

### F2 — Analyzer graph is rebuilt on each analysis pass
**Evidence:** `src/analyzer/graph.lua` resets `nodes`, `edges`, `byType` and `byPath` before rebuilding. For each Stage, it classifies child nodes and constructs Wave-to-Enemy/Boss relationships with nested loops.

**Risk:** Repeated refreshes do repeated work, and relationship generation can grow multiplicatively for a Stage with many Waves and Enemies. A scan cap alone does not bound edge count tightly enough.

**Recommendation:** First add graph node/edge counters and a deterministic edge budget. Index entities by parent path and type once per pass. Only consider incremental graph updates after benchmarks prove the simpler indexed approach is insufficient. When a budget is reached, return explicit `truncated` and coverage metadata; never imply the graph is complete.

### F3 — Persistent notebook is bounded but retrieval is lexical
**Evidence:** `src/runtime/research_memory.lua` caps notes at 300, each body at 5,000 bytes, and a notebook at 1.5 MiB. Search ranks keyword matches over stored title/body/tags.

**Risk:** Lexical matching can miss synonyms and Thai text segmentation; a note marked verified may still be stale when the place or client-visible hierarchy changes. The analyzer's learned confidence summaries are currently in-memory state, not a durable evidence graph.

**Recommendation:** Preserve the current small notebook and schema for compatibility. Add optional structured metadata in a versioned schema: evidence IDs/source pointers, observation time, analyzer/schema version, place identity, freshness status and related entity/path IDs. Keep search lexical as a fallback; add indexed normalized tags/aliases before considering embeddings. Never persist secrets or raw unbounded dumps.

### F4 — Prompt construction has a recurring token cost
**Evidence:** `src/agent/prompt.lua` assembles the prompt per request and includes general collaboration guidance, while some task guides are conditional. `src/agent/context.lua` estimates history and prompt/tool overhead and calibrates from provider usage when available.

**Risk:** Correctly rebuilding dynamic environment state can still resend unrelated guidance on every turn. Estimated token counts can differ from provider accounting, especially for code, Thai text and tool schemas.

**Recommendation:** Keep dynamic environment and current task information fresh. Split prompt sections into core, task-matched, and explicitly requested collaboration sections. Measure real provider prompt tokens by provider/model; do not cache a full prompt across turns unless every dependency is versioned and invalidated correctly.

### F5 — Concurrency defaults are generous for a mobile runtime
**Evidence:** `src/runtime/config.lua` currently defines `toolConcurrency = 8` and `subagentConcurrency = 12`; subagents have bounded history/resumability, but independent work can still multiply provider requests and retained results.

**Risk:** Concurrent tool results, model calls and child contexts can raise peak memory and make the game/UI less responsive even if each context is individually bounded.

**Recommendation:** Add named resource profiles (Mobile Safe / Balanced / Desktop) rather than silently changing existing user settings. In Mobile Safe, lower concurrency and cap aggregate in-flight result bytes. Prioritize cancellation, deadline propagation and back-pressure before adding more parallelism. Never retry side-effecting game calls automatically.

### F6 — CI already has useful regression gates
**Evidence:** `.github/workflows/quality.yml` builds the bundle, runs the headless suite, context compaction, research memory, game analyzer, collaboration and context benchmarks; it checks that committed bundle output matches source.

**Recommendation:** Extend these gates with graph growth/edge-budget fixtures, stale-note behavior, retrieval ranking fixtures (including Thai terms), cancellation/back-pressure tests, and task-specific prompt-size assertions. Keep benchmark output deterministic and compare counters as well as elapsed time.

## Target architecture

```text
Task Router
  -> Task Plan (goal, steps, deadline, cancellation, success criteria)
  -> Context Budget Manager
       -> task-matched prompt sections
       -> relevant evidence IDs + bounded source excerpts
       -> bounded tool output
  -> existing tools / analyzer / coding workflow
  -> Evidence Normalizer
       -> observation ledger (source, time, confidence, scope)
       -> existing PlaceId research notebook (versioned metadata)
       -> compact search index
  -> Lua Validation Gate
       -> syntax / dependency diagnostics
       -> focused behavioral tests where executable
       -> runtime compatibility status (pass / fail / not run / unsupported)
  -> concise report + measured usage + persisted notes only when warranted
```

The two-model collaboration tool remains an optional worker behind the router, not a mandatory stage. Use one model for routine tasks. For complex work, give each model a bounded task and evidence packet; reconcile disagreement against source and tests, not majority vote. Cap total collaboration requests and wall-clock time.

## Recommended implementation sequence

### Phase 0 — Baseline and measurement (no behavior change)
1. Record the audited commit and existing CI status.
2. Run the current bundle build, full headless suite, context compaction, game analyzer, research memory, collaboration and context benchmark.
3. Save baseline counts: scanned nodes, graph nodes/edges, serialized result bytes, prompt tokens reported/estimated, compaction duration, active tools/subagents, and peak retained result bytes where measurable.
4. Do not merge performance changes without comparing against this baseline.

### Phase 1 — Resource budgets (smallest risk)
1. Introduce a single budget policy object for max active tasks, tool-result bytes, graph edges, context tokens and wall-clock deadline.
2. Propagate cancellation/deadlines through orchestration and tools.
3. Add Mobile Safe / Balanced profiles without overriding custom saved values.
4. Return explicit partial/truncated metadata whenever a budget stops work.

### Phase 2 — Analyzer scalability
1. Add fixtures with many siblings, many Stages/Waves/Enemies, duplicate names and incomplete scans.
2. Index by parent/type and enforce edge budgets.
3. Benchmark repeated refreshes and ensure graph counts stay within configured bounds.
4. Consider incremental graph diffs only if measured cost warrants the added complexity.

### Phase 3 — Evidence-linked research memory
1. Version the note schema and provide a migration path that preserves old notebooks.
2. Add evidence pointers, scope/freshness metadata and normalized aliases/tags.
3. Add tests for stale observations, corrupt files, size limits, duplicate updates, PlaceId isolation and Thai keyword retrieval.
4. Keep raw scans out of persistent storage by default.

### Phase 4 — Context routing and prompt efficiency
1. Categorize task intent before building optional prompt sections.
2. Retrieve only the smallest relevant evidence packet, with source IDs and confidence.
3. Enforce a preflight budget covering system prompt, conversation, tool schemas and expected output.
4. Prefer targeted follow-up scans over full rescans when evidence is incomplete.

### Phase 5 — Validation and release
1. Add task fixtures covering analyzer-to-Lua workflows.
2. Report syntax, tests, executor assumptions and unverified runtime behavior separately.
3. Build `dist/uai.lua` only through `tools/bundle.lua` / CI.
4. Merge to `main` only after all relevant checks pass; do not hand-edit generated bundles.

## Acceptance criteria

- No scan or graph operation exceeds explicit node/edge/result budgets.
- Incomplete scans and truncated graphs are visible to the model and user.
- A stored hypothesis cannot be presented as verified without new supporting evidence.
- Research notes are scoped to a PlaceId and carry freshness/source metadata.
- Prompt preparation stays under the configured budget or fails closed with a clear diagnostic.
- Concurrent work is bounded globally, cancellable, and does not retain completed child contexts indefinitely.
- Lua output reports `PASS`, `FAIL`, `NOT_RUN` or `UNSUPPORTED` for relevant checks.
- Existing source/bundle consistency and regression tests continue to pass.
- No claim of real Executor compatibility is made solely from mock tests.

## Out of scope for the first patch

- Replacing the agent loop or provider protocol.
- Making embeddings/vector search mandatory.
- Increasing concurrency or keeping all game data in memory.
- Claiming server-side game internals are discoverable from client-visible data.
- Automatically replaying Remote calls or applying game-changing actions without explicit authorization.
- Editing `dist/uai.lua` directly.

## Audit limitations

This review inspected repository structure and selected source/test/configuration files through GitHub. It did not execute LuaJIT, run GitHub Actions, run UAI in Delta Executor, profile a real mobile device, or validate the live Thirx endpoint. Findings about runtime performance are hypotheses grounded in source structure and must be confirmed by benchmarks.
