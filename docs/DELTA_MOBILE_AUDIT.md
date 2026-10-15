# Android / Delta Mobile Compatibility Audit

Status: initial source review; no live Delta-device validation has been performed.

## Scope and rules

Target: ProjectUAI-TierSSS running inside Roblox Mobile through Delta Executor on Android.
Work must remain on the existing pull request branch. Do not merge into `main`.
Only report tests that were actually executed; synthetic tests and CI are not evidence of native executor behavior.

## Initial source findings

- `src/runtime/caps.lua` centralizes optional host capability probes. It checks executor HTTP functions, filesystem functions, clipboard, WebSocket, hook functions, script-source functions, thread identity, and executor identification.
- `src/net/http.lua` centralizes HTTP requests, redacted request history, transport selection, worker limits, body limits, deadlines, and retry classification.
- `src/runtime/config.lua` on the reviewed PR head currently configures a 600-second request timeout, enables `requestUnlimited`, uses a 48,000-token hard context budget with a 0.5 compaction fraction, and configures bounded tool concurrency. These settings do not override host-imposed limits.
- `docs/NATIVE_CLIENT.md` explicitly says native renderer, IME, host hook coexistence, permission propagation, and server effects are not proven by synthetic tests.
- `tools/test_native.js` defines a sequential, fail-fast verification gate, with separate build-only and verify-only phases. The documented process requires inspection of generated artifacts between phases.

## Verification evidence currently available

- GitHub Actions run `38430970133` for PR head commit `835a3045c35d2550d7270807bb67eb8c3af03dd1` completed successfully; PR metadata says the quality and bridge-browser jobs passed.
- GitHub Actions run `38458090741` for the audit-document commit `092b1a1763ab313b667d48186505f9d0b3068d4a` completed successfully. The `quality` and `bridge-browser` jobs both concluded `success`; two quality steps that publish/check a generated bundle on `main` were skipped. This confirms the run's reported jobs, not live executor compatibility.
- Runtime/transport source trace: `src/net/http.lua` caps a request at 600 seconds, 8 concurrent native workers, and 8 MiB response bodies; unknown transport outcomes at deadline are reported without automatic retry. A worker whose host call never returns can remain occupied, so the cap intentionally prevents unlimited accumulation but can leave capacity degraded if the executor permanently hangs. Existing tests cover timeout-versus-refusal retry policy and duplicate billing prevention.
- No code defect has yet been confirmed strongly enough to justify a source change in this phase; avoid changing retry/worker semantics without a regression fixture because it could duplicate billed requests or leak unbounded host calls.
- This is CI evidence only. No test was executed on a physical Android device or inside Delta during this audit.

## Sequential work plan

1. **Runtime/transport audit:** trace each capability probe and request path; map current tests to failure modes and identify confirmed defects.
2. **Fix and regressions:** make a narrowly scoped fix only when source and a reproducible test establish the defect.
3. **Context and retention:** test cancellation, large inputs, history/cache bounds, and compaction behavior.
4. **Lua/Luau workspace analysis:** test multi-file dependency mapping, dynamic imports, truncation reporting, and source provenance.
5. **Multi-model coordination:** test partial success, timeout, cancellation, duplicate dispatch, and truthful failure reporting.
6. **Mobile UI lifecycle:** test orientation, keyboard, focus, scroll, repeated mount/unmount, and bounded rendering using available fixtures.
7. **Release verification:** build, inspect bundle/manifest/site mirrors, run verify-only from a clean generated state, and review CI.
8. **Native acceptance:** provide a reproducible Delta test checklist and record device/executor/version and observed results separately from CI.

## Native acceptance checklist (prepared, not executed)

Run this checklist on the target Android phone inside the exact Delta Executor build used by the user. Record Roblox version, Delta version, Android version, device model, screen resolution, and date. CI/browser mocks do not count as native passes.

1. Install the PR-built script only after CI passes; keep the previous known-good loader available for rollback.
2. Launch UAI, open and minimize the panel repeatedly (at least 20 cycles), and confirm the launcher remains tappable and the transcript does not accumulate duplicate panels.
3. Rotate the device or change viewport orientation; verify the header, close/minimize controls, sidebar, settings rows, and transcript remain reachable without clipping.
4. Open the keyboard, type a long Thai and English prompt, dismiss the keyboard, then reopen it. Verify the composer and send/stop buttons stay visible and focus returns correctly.
5. Attach at least three Lua/Luau files from the phone through Bridge. Confirm the upload receipts refer to persisted `pastes/` files, then run `project_inspect(path="pastes")`. Check dependency edges, ambiguous/dynamic imports, file counts, and truncation warnings against the actual files.
6. Start a bounded game-analysis task. Record elapsed time, provider/model, reported or estimated prompt/completion tokens, number of tool calls, graph node/edge counts, and whether the graph was marked truncated. Repeat the same task once to observe whether unchanged project-source scans hit the lexical cache.
7. Start another analysis and press Stop during a tool call and during a model request. Confirm the UI responds, the task does not dispatch later tool batches, and a transport with an unknown outcome is not silently retried.
8. Set the task budget low enough to trigger a preflight stop. Confirm the transcript explains the budget stop and that no additional tool batch is executed.
9. Exercise two-model collaboration with the configured provider. Confirm GLM and DeepSeek are shown separately in usage accounting; then repeat with one model unavailable and confirm the surviving report is preserved.
10. Leave UAI running for 20 minutes while monitoring Roblox memory, UI responsiveness, and device temperature. Do not infer a memory or thermal pass from a shorter synthetic test.

Record each result as **PASS**, **FAIL**, **NOT RUN**, or **UNSUPPORTED**, attach logs/screenshots where possible, and distinguish estimated usage from provider-reported usage. If any step fails, preserve the exact transcript and transport error before changing retry behavior.

## Acceptance criteria

- No regression in existing automated tests.
- New regression tests reproduce the original defect and pass after the fix.
- Generated artifacts match source and the repository's deterministic build checks.
- Errors, unsupported capabilities, unknown transport outcomes, and incomplete analyses are disclosed rather than silently treated as success.
- Live Delta compatibility remains marked **unverified** until the test is run in that environment.
