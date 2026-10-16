# Notaris/PPAT Git Troubleshooting Postmortem: Generated Windows Files

> Handoff for future contributors and AI sessions. This document records the Git/generated-file incident observed on 2026-10-16. The purpose is to preserve the evidence and improve troubleshooting discipline, not to pretend the exact root cause was proven.

## Scope and checkpoint

- Repository: [Tmichael86/notaris-flutter](https://github.com/Tmichael86/notaris-flutter)
- Branch: `integration/notaris-stabilization`
- Incident commit: `8cb0247` — `chore: update generated Windows plugin registration`
- Files involved:
  - `frontend_notaris/windows/flutter/generated_plugin_registrant.cc`
  - `frontend_notaris/windows/flutter/generated_plugins.cmake`
- Last confirmed result: push succeeded; local branch was reported aligned with origin and working tree clean.
- At that checkpoint, `flutter analyze` reported no issues and `flutter test` passed all 25 tests.
- `main` was not changed.

This is a historical incident record. Always inspect the current branch, HEAD, and working tree before acting.

## What happened

1. The two generated Windows files were modified to register `flutter_secure_storage_windows`.
2. The change was committed locally as `8d5f654`, but the first push was rejected because the remote branch had newer commits.
3. `git fetch origin` showed the local branch was ahead by one commit and behind by two. The remote-only commits were:
   - `5ea4d88` — `docs: add Notaris stabilization lessons and handoff`
   - `f3d3b39` — `docs: align process validation notes with schema v9`
4. A normal rebase onto `origin/integration/notaris-stabilization` succeeded. The local generated-file commit was rewritten as `8cb0247`.
5. `flutter analyze` passed and `flutter test` passed all 25 tests. Afterwards, `git status` showed both generated files as modified again.
6. Investigation produced these observations:
   - `git diff` and `git diff --numstat` showed no textual diff.
   - `git hash-object <file>` matched `git rev-parse :<file>` for both files.
   - `git -c core.autocrlf=false diff --ignore-space-at-eol -- <files>` was empty.
   - `git ls-files --eol` reported `i/lf w/lf` for both files.
   - `git diff-files --raw` still marked both paths modified.
   - `core.autocrlf=true` was set in the system Git config; `text` and `eol` attributes were unspecified. `core.filemode=false`.
   - `git update-index --refresh` and `git update-index --really-refresh` both reported `needs update`.
7. Re-running `git add` on only the two generated files cleared the modified status. A normal push then succeeded:
   - `f3d3b39..8cb0247 integration/notaris-stabilization -> integration/notaris-stabilization`
   - Final `git status -sb` showed `integration/notaris-stabilization...origin/integration/notaris-stabilization` with no modified paths.

## What is known, and what is not

### Established by the captured output

- The remote had two commits absent from the local branch at the time of the rejected push.
- Rebasing preserved those remote commits and replayed the local generated-file commit on top.
- The generated files in the working tree had the same content hashes as their index entries while Git still reported them modified.
- Re-staging the two files cleared the modified status.
- The normal push succeeded and the branch was clean and synchronized afterwards.

### Not established

**The precise root cause of the repeated modified status was not proven.**

The line-ending warning and `core.autocrlf=true` were clues, but the captured `i/lf w/lf` output and matching content hashes do not establish a line-ending-only problem. We also did not prove that `flutter analyze` or `flutter test` caused the status change; they were simply run before the status was observed.

Do not repeat the claim that “Flutter regenerated the files” or “CRLF caused it” as fact unless a future reproduction provides evidence. The practical fix in this incident was to re-stage the two files, but that is not a proven explanation of the underlying metadata/index behavior.

## Trackback protocol for future incidents

The key lesson is: **identify what happened immediately before the symptom, then test the smallest hypothesis that explains the evidence.** Do not make the user run the same checks repeatedly just because the first explanation was wrong.

1. **Record the exact symptom.** Capture the complete error or status, not a paraphrase.
2. **Identify the last known good state.** Use recent commands, diffs, status output, and commit history.
3. **Build a timeline.** Separate “this happened before the symptom” from “this caused the symptom.” Temporal order is not proof of causation.
4. **Choose one discriminating check.** Each command should distinguish between plausible causes. Avoid asking for more output that cannot change the decision.
5. **State confidence honestly.** Label conclusions as confirmed, likely, or unknown. A successful workaround does not automatically prove root cause.
6. **Make the smallest safe change.** Avoid broad resets, forced pushes, or global configuration changes when a narrow action is sufficient.
7. **Verify once.** Confirm the result and stop. Do not re-run tests that already passed unless new code or a relevant environment change justifies them.
8. **Preserve the user's time.** If a check returns no new evidence, change the diagnostic approach instead of repeating the same loop.
9. **Never sacrifice history to silence status output.** Do not use `git push --force`, `git reset --hard`, or indiscriminate `git restore` as a first response.
10. **Do not commit automatically.** Inspect the diff, stage only intended files, and commit/push only when the user has asked for it or clearly authorized that operation.

## Git divergence recovery checklist

When a push is rejected with `fetch first` or `non-fast-forward`:

```powershell
git status -sb
git fetch origin
git log --oneline --graph --decorate --left-right HEAD...origin/integration/notaris-stabilization
```

Then:

- Identify local-only and remote-only commits.
- Inspect the actual graph and file changes.
- If the local work should be preserved on top of the remote branch, rebase only after confirming that this is the intended history operation.
- If a conflict occurs, inspect it and resolve by behavior, not by blindly selecting `ours` or `theirs`.
- Run relevant tests after a history/content change.
- Push normally; do not force-push to bypass the rejection.
- Verify the final branch is aligned with origin and the working tree is clean.

For this incident, the correct recovery was a fetch, inspection of the two remote-only documentation commits, rebase, validation, re-staging the intended generated files, and normal push.

## Generated Flutter files: handling guidance

The files involved are Flutter-generated Windows plugin registration files. They should reflect the dependency graph and generated plugin configuration; they should not be hand-edited casually.

When they change:

1. Inspect the exact diff.
2. Confirm the plugin is declared by the app and appears in the resolved dependency graph.
3. Determine whether the change is an expected generated artifact for the supported Windows build.
4. Do not assume a line-ending warning is the same thing as a content change.
5. If Git says modified but the diff is empty, compare the working-tree hash and index blob hash and inspect `git ls-files --eol` before changing configuration.
6. If the hashes match but status remains modified, do not keep repeating refresh commands. Capture `git diff-files --raw`, inspect index/debug metadata if necessary, and choose the next check based on that evidence.
7. Stage only the intended generated files if their content is correct. Then verify `git status -sb`.
8. Avoid changing system-wide Git settings solely to silence one incident. Any repository-level line-ending policy change should be deliberate and reviewed separately.

Useful focused commands:

```powershell
git diff -- path/to/generated-file
git hash-object path/to/generated-file
git rev-parse :path/to/generated-file
git ls-files --eol -- path/to/generated-file
git diff-files --raw -- path/to/generated-file
git status -sb
```

## Project direction reminder

This project is a **rebuild and improvement of the Notaris/PPAT management application**, not a clone of the old Laravel application.

- Use Laravel as a reference for existing business behavior, data relationships, and schema history.
- Do not spend time auditing unfinished Laravel menus just because they exist or have suggestive route names.
- Decide and document the intended behavior for the new application when the legacy behavior is absent or incomplete.
- Flutter + Drift/SQLite remains local-first.
- Go is the intended new backend; server-side authentication, authorization, and business rules must be enforced independently of local checks.
- PostgreSQL is existing/target remote persistence, so inspect the real schema before migrations or data changes. Do not run destructive schema operations or blindly enable GORM auto-migration.
- Do not start full bidirectional sync until the API/data contract, identity mapping, conflict rules, idempotency, deletion propagation, and related-record behavior are defined.
- Keep `main` untouched unless the user explicitly approves promotion.

Read this alongside [NOTARIS_GIT_BRANCHING_AND_CONTINUITY.md](NOTARIS_GIT_BRANCHING_AND_CONTINUITY.md) before continuing branch or integration work.

## Final reminder to the next Grace

Be systematic, but do not confuse thoroughness with making the user run ten commands when two will do.

For every error, ask:

- What was the last known good state?
- What action happened immediately before the symptom?
- What evidence distinguishes the likely causes?
- What is the smallest safe next step?
- What do we know for sure, and what remains a hypothesis?

If a fix works, verify it, record the evidence, and move on. If the root cause remains unknown, say so plainly. Do not turn troubleshooting into a tour of the same room.

---

Incident recorded: 2026-10-16  
Last confirmed integration commit at incident close: `8cb0247`
