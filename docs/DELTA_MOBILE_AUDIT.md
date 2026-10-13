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

## Acceptance criteria

- No regression in existing automated tests.
- New regression tests reproduce the original defect and pass after the fix.
- Generated artifacts match source and the repository's deterministic build checks.
- Errors, unsupported capabilities, unknown transport outcomes, and incomplete analyses are disclosed rather than silently treated as success.
- Live Delta compatibility remains marked **unverified** until the test is run in that environment.
