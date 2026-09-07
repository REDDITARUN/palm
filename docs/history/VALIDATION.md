# Verification — 5 September 2026

## Delivered build

Native Apple silicon macOS application, built with the `PlamMac` Xcode scheme. `codesign --verify --deep --strict` succeeds. The bundle includes its resource packages, local-tool installer, memory worker, and custom icon. Runtime tools and local embedding weights were prepared in the personal app's Application Support folder.

## Automated checks

Final standard suite: **33 passed, 5 explicitly opt-in live tests skipped, 0 failures**.

Coverage includes equivalent-answer grading, subjective grading deferral, invalid generated question keys, prerequisite cycles, assistance and dispute accounting, FSRS scheduling identity, atomic and idempotent completion, saved drafts and chats, note revisions/search/export/backup, portable backup restoration after original snapshot deletion, note-history restoration, rejection of dangling references/duplicate IDs/snapshot symlinks, unreadable-library protection, immutable snapshots and source changes, subprocess cancellation, single-blank questions, ordering questions, checkpoint persistence, provider routing/authentication, actionable rate errors, malformed artifacts, truncated output, and rubric decoding.

## Real local integrations

- Serena MCP initialized successfully and returned actual `make_counter` / `increment` Python symbols from an invented repository.
- Mem0 and Qdrant passed add, search, canonical-record lookup, deletion, and verification of deletion.
- A second memory test used real local BGE embeddings through FastEmbed. It passed without a cloud credential or inference request.
- The installed application runtime completed preparation successfully.

## Live free-model checks

**Inkling free via the real OpenCode learning agent:** full pipeline passed twice, including after stricter quiz validation. The stricter run generated a three-lesson curriculum and ten questions, accepted a correct explanation, rejected a deliberately false explanation, and produced tutor guidance. It completed in about 88 seconds. A separate live OpenCode + Serena repository test passed in about 15 seconds and saved a source-linked evidence summary.

**Direct OpenRouter checks:** the key validated. Inkling and Inkling Small rejected direct chat requests with OpenRouter's agent-harness restriction. The app handles Inkling using its actual OpenCode integration, without impersonating another app through custom attribution headers.

MiniMax M3 free passed a short JSON probe and generated a curriculum, but full lesson requests failed or exhausted the output budget. NVIDIA's free Lightning model exhausted the short probe's output budget. These are not treated as equivalent validated defaults. Inkling is selected for the prepared personal library; other models remain selectable.

The key was saved through the app into macOS Keychain. No key is included in source, exported course artifacts, or this report. Test requests used generic Python concepts and an invented repository, not a personal source repository.

## Native UI walkthrough

Verified through the running app using a separate fixture library:

1. Welcome → key connection → learner preferences → workspace.
2. Topic and prior knowledge → dynamic diagnostic → generated course outline.
3. Lesson reading and worked example → mixed practice.
4. Wrong-answer feedback → dispute and undo → next question.
5. Native code editor rendering → selected code passed to the tutor.
6. Typed answer and tutor conversation surviving an app restart.
7. Assisted answer excluded from independent-answer totals.
8. Written explanation grading → final true/false item → reflection.
9. Topic/course congratulations → saved recap with reflection and tutor conversation.
10. Note title editing, tags, pinning, and reading view.
11. Progress chart and evidence totals, FSRS review queue, and saved-question practice.
12. OpenRouter selection in native onboarding and real key validation/storage.

The walkthrough caught and fixed an editor crash caused by dynamic NSColor brightness access. A later live request exposed errors hidden behind the course sheet; the form now displays them inline.

The Mac locked before the final visual recheck of the latest checkpoint/error-display changes. Those changes compile, and checkpoint persistence passes automated verification, but that final native visual pass remains unverified. Light-mode appearance and private GitHub authentication were not exercised in this walkthrough.

Structural checks and these examples cannot prove all generated material correct. The app retains source evidence and lets the learner dispute questions. Completed topics are recorded as completed practice, not a guarantee of mastery.

## Backup and restore audit

A full `.plambackup` export/restore now preserves note revisions and immutable code snapshots. The round-trip test deletes the original snapshot before restoration into a separate library, then checks code content, drafts, note history, FTS search, and reopening. Invalid imports leave the current library intact. Restored jobs are interrupted and vector IDs cleared for rebuilding. The storage-panel controls await native UI verification because the Mac remains locked.

## Full live repository-course lifecycle

A separate, explicitly opted-in Inkling free run completed in **274 seconds** with **0 failures**. It imported the invented Python repository, explored it with OpenCode/Serena, generated a three-topic course, completed all three lessons (30 questions, including an application checkpoint), generated and completed a fresh six-question review, verified stable review identity, saved four notes, reopened the library, and restored a portable backup into another directory. Answers were scripted canonical answers; this verifies the software pipeline, not educational effectiveness or the native UI.

The longer test exposed and fixed three integration issues: omitted empty auxiliary question fields, a model-generated transfer-question type needing rubric grading, and absolute/agent-metadata citations that could not open the actual snapshot. Source locations are now explicitly supplied and validated; repair feedback identifies missing fields and invalid values. Required answers and explanations remain mandatory. Earlier failed runs are not counted as passes.

Successful artifacts: `.test-data/live-agent-runtime/lifecycle-D3858446-1BE6-4CAD-99DA-CF001AFCCD7B/`. Test log: `/tmp/plam-lifecycle.log`. Reproduce with `python3 Scripts/verify-live-provider.py thinkingmachines/inkling:free --lifecycle`; it reads the authorized credential from Keychain and restricts models to free IDs.

Remaining gate: the installed native app's final live-course/checkpoint/light-appearance/backup-control walkthrough. macOS computer use continues to report that the Mac is locked. This remains unverified; the goal is not complete.

## User-feedback polish pass

Applied the root `design_cheat_sheet.md` to the native SwiftUI controls. The real Inkling UX test passed in **137 seconds**: three diagnostic questions with options, correct grading of equivalent prose for printed output, rejection of a genuinely wrong output, and a ten-question lesson with four choice questions. The lesson title also matched its specific topic. Test log: `/tmp/plam-ux-live.log`.

The isolated native UI walkthrough (`.test-data/ux-polish-20260905`) verified onboarding, choice diagnostics, “Not sure yet,” course generation, the complete four-question mixed quiz, semantic-grading routing, scrolling to feedback, resetting scroll position for new questions, reflection, congratulations, note reading, editing, multi-tag entry, undo/redo, and accepting a tutor suggestion. A restart preserved the completed session and note. The last screenshot verified that the focused diagnostic displays all four options and navigation together.

The walkthrough caught and fixed a wrapping “Note mode” label and moved the starting check out of the long setup form while answering. The Mac locked again before the final toolbar/dark-theme follow-up. These final visual checks remain pending. Personal learning records were not used as test fixtures or rewritten; UI testing used a separate library.

The final native build also disables edits to an answer during model evaluation, exposes Cancel check, and keeps evaluation status inside the question so the global status bar does not shift the lesson. These final controls compile; their in-flight visual state remains part of the pending unlocked-Mac follow-up. The fixture app/provider were stopped, and the installed app was reopened in normal personal-library mode.


## Rich notes refinement — native checks

Checked the original personal notebook visually before editing code; all mutation tests used `.test-data/ux-polish-20260905` with the UI Test identity.

- Native UI: highlighted a selected passage with the toolbar, switched to Read, and confirmed its persisted `==...==` Markdown after restart. Highlighting remains legible in light and dark appearances; inline code containing `==` stays literal.
- Native UI: edited the before-lesson teaching prompt, switched to the independent after-lesson prompt, and verified the saved customization in SQLite after restart.
- Native UI: Mermaid flowchart, native inline math, a display fraction, a 2×2 LaTeX matrix, comparison table, and text-arrow flow rendered. The first visual pass found multiline math delimiters displaying literally; the protected-math parsing fix was built and visually rechecked successfully.
- Native UI: invalid Mermaid source displays a readable error with source disclosure. All diagram assets are bundled; the diagram page disallows network connections.
- Native UI: wrong-choice feedback is red, answer key green, disputed feedback amber, with text/icons. A final pass verified full-opacity submitted option labels after removing disabled-control dimming.
- Native UI with the local fixture provider: completed four questions, reflection, congratulations, and automatic recap writing. Confirmed the new linked note, successful generation job, and revision history in SQLite. This checks integration, not model teaching quality.
- Real free Inkling/OpenCode: mixed lesson generation, three diagnostic questions, acceptance of equivalent prose output, rejection of wrong output, and customized Mermaid recap generation passed. An additional recap-only call passed in 22.8 seconds. The model's first recap was too long and report-like; defaults were tightened toward natural study explanations and explicit grounding in actual attempts. Generated explanations remain model output, not a guarantee of factual perfection.
- Standard tests added for old preference compatibility/customization round trips, Mermaid fence boundaries and local assets, LaTeX protection in code/matrix syntax, empty recap rejection/source preservation, and excluding uncertain grades from fallback mistake notes.

The latest app is installed at `$HOME/Applications/Plam.app`. Test libraries and test model routing are separate from the personal library.

Packaging verification also caught Xcode retaining an old resource seal after an incremental HTML-only change. `Scripts/build-native.sh` now signs the final copied bundle and runs strict deep signature verification; the installed final bundle passed.
