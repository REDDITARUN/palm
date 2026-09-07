# Learning workspace implementation review

Date: September 7, 2026

## Delivered behavior

### Notes and tutor

- Always-editable BlockNote document bundled inside a native WKWebView. No separate editing mode or remote editor service.
- Slash menu, block controls, selection formatting, highlighting, inline code, lists, tables, LaTeX, and Mermaid diagrams. A slim selection toolbar includes Ask Plam.
- Explicit import/export handling for legacy Markdown math, highlights, code fences, diagrams, and wiki links. Structured block JSON is the lossless document; Markdown remains the portable and retrieval representation.
- Stable note links and a linked-from row. Typing `[[` opens note suggestions.
- Shared adjacent tutor in notes and lessons, with an adjustable inspector divider and keyboard-accessible width control.
- Direct-provider SSE streaming and OpenCode event streaming. Connection, reasoning, and writing states reflect provider events; internal reasoning text is not shown. Stop preserves an interrupted response; failed responses can be retried.
- Persisted conversations and drafts. Editing a previous message preserves the original conversation as a separate branch.
- Ask and Edit note modes. Edit proposals are previewed before applying. Applying preserves the previous note revision and refuses to overwrite a note changed since generation.
- Revision history can restore the structured document; restoration also checkpoints the current version.
- Flashcards remain beside notes, with the existing local scheduling and review flow.

### Learning and repository understanding

- Plain, literal, example-led teaching instructions across generation routes. Six independently editable teaching prompts cover planning, questions, feedback, before/after notes, and tutoring.
- Curricula get a separate critique and revision pass covering prerequisites, coverage, checkpoints, and a capstone. Lesson generation targets 8–15 questions. Existing courses and completed work are not automatically rewritten.
- Nine question formats: choice, true/false, cloze, trace, explain, diagnose, order, transfer, and diagram choice.
- Diagram choices have stable answer IDs and readable descriptions. Choices remain deterministic to grade; written responses use the model rubric.
- Repository prompts request meaningful source excerpts, execution/data-flow reasoning, and questions about specific code decisions.
- Tree-sitter syntax ancestors for supported languages let a code selection expand to an expression, declaration, or enclosing construct. Ordinary text selection remains available without a grammar.
- Previous-question navigation retains submitted answers. Try again stores a separate supported attempt; it never replaces the first attempt or improves independent evidence by replaying an exposed answer.
- Existing prediction, worked-example, practice, reflection, and spaced-review flows remain in place.

### Knowledge, progress, and settings

- Native knowledge map of saved notes, courses, and non-forgotten observations, with explicit links, search, selection details, and navigation.
- Related-note retrieval combines lexical relevance with explicit relationships. It complements the existing Mem0/Qdrant local semantic learner-memory index.
- Progress emphasizes due review work, independent delayed recall, course coverage, and dated answer evidence with sample sizes. Supported attempts, disputes, and uncertain grades are excluded from independent evidence. Earned milestones are collapsed by default.
- Model profiles can assign planning, lessons, grading, notes, tutor, and research roles. Unassigned roles use the default provider.
- MCP registry for local executable commands and remote HTTPS connections, optional Keychain bearer tokens, explicit allowed-tool rules, and enable/disable controls. These connections are available to the repository researcher.
- Reusable enabled teaching skills are included in prompts and written to app-managed OpenCode SKILL.md files. Disabled managed files are removed without deleting unrelated files.
- App icon packaging now explicitly names the bundled icon and verifies the final code signature.

### Local persistence

Notes and conversations have dedicated SQLite tables and targeted writes. Existing state records migrate without deleting their notes or chats. Block documents, conversations, model routes, MCP configuration, teaching skills, and retries travel with library backups. Credentials remain in Keychain and are not sent to the embedded editor.

The editor loads only bundled resources. Its content security policy disallows network connections. Diagram rendering is local and restricts generated diagram configuration and links.

## Verification completed

- Swift suite: **59 tests, 0 failures; 6 opt-in live tests skipped**. Includes legacy decoding, SQLite document/conversation migration, history and backups, deletion/reopening, full-text search, knowledge relationships and forgotten-memory exclusion, diagram validation, provider stream framing, Unicode chunks, truncated-response handling, process output, and Unicode Tree-sitter selection offsets.
- Editor: TypeScript check, production build, and **2 integration tests** using the real BlockNote schema. Tests cover Markdown/block round trips for formulas, highlights, diagrams, code, and stable note links, plus incomplete delimiters.
- Real provider: **Inkling free integration passed** in an isolated library. It generated a three-lesson course and an eight-question lesson, accepted a correct written answer, rejected an incorrect answer, and returned a tutor explanation. Personal repository content was not used for this test.
- Native walkthrough in a separate fixture library: direct note editing; slash-menu keyboard selection; highlighting, formulas and diagrams; note-link navigation; tutor resizing; streamed note proposal; applying the proposal; rejecting a stale proposal; revision loading and restoration; editing a previous message and retained branch; prediction and explanation; keyboard answering; diagram-choice grading; previous-question navigation; and a deliberately wrong retry preserving the correct first attempt.
- Native visual checks: light and dark notebook/tutor rendering, knowledge map, progress layout, and agent settings. Saving a teaching skill was verified through the UI.
- Native build and code-signature verification are recorded in `.review/workspace-native.log` and `.review/workspace-production.log`.

UI review caught and fixed missing slash-menu CSS, an incompatible Mermaid preview renderer, oversized editor headings, SSE blank-line framing, first-open revision history loading, inactive graph controls in answer cards, and the progress chart's date scale. These were actual native observations, not only source inspection.

## Installed app

The production bundle is installed at `[local development path]` and was launched successfully. The installed progress chart was clicked to verify the displayed day and sample size. The installed notebook opened an existing personal note in the block editor with the adjacent tutor. A read-only comparison against the pre-install SQLite backup confirmed that courses, sessions, notes, reviews, memories, and flashcards were preserved exactly through migration.

The previous app bundle and `before-workspace-install-final.sqlite` are retained under `.review/`.

## Practical limits

- This is a native Mac application with an embedded block editor. It does not include phone sync or a hosted service.
- Generated material can still be factually wrong. Structural validation and an additional curriculum pass do not prove teaching quality or mastery. Dispute controls and source inspection remain necessary features of the learning flow.
- The knowledge map uses explicit saved relationships and deterministic placement. It is not a force-directed Obsidian clone or a separate inferred knowledge database. Related notes are retrieved in a bounded context, not by sending the entire library on every question.
- Syntax selection depends on the available language grammar. It does not itself perform cross-file semantic resolution; Serena handles repository symbols and references. Automated AST coverage currently exercises JavaScript Unicode offsets.
- MCP connections are configured for the repository researcher. The settings page does not claim a server is connected merely because it is enabled, and it does not yet discover tools or implement an OAuth sign-in flow. Custom third-party MCP servers were not all exercised live.
- The native shell renders tutor Markdown. The embedded editor stores richer blocks; generic Markdown export cannot represent every possible block appearance. Malformed/unknown structured content produces an error instead of silently replacing a saved document.
- The model may emit a whole response in one event, especially through a harness. The UI displays actual events rather than simulating token streaming.
- Editing an older lesson chat currently uses the active lesson/question context when resending. The archived conversation is retained, but it is not a full historical fork of the lesson state.
- The app build is locally signed for this Mac, not notarized for public distribution.

## Where to review

Open Notebook, select a note, type `/`, and open the note tutor. Try an Edit note proposal, review it, apply it, and inspect Revision history. Open Knowledge map to follow links. In a lesson, revisit a submitted answer and use Try again. Open Settings → Agents and Teaching to inspect model roles, connections, skills, and prompts.

The research behind the choices remains in [LEARNING_WORKSPACE_RESEARCH.md](LEARNING_WORKSPACE_RESEARCH.md). Source and pre-install library backups are retained under `.review/`.

## September 7: border refinement

Removed permanent separators between the global sidebar, note list, document toolbar, and tutor sections. The document uses a quiet canvas tone against the navigation/tutor background. The resizer has an eight-point hit target and reveals a small grip only on hover. Shared secondary buttons and input fields use soft fills; focused fields retain a restrained focus outline. Tutor input no longer has a persistent border or colored frame.

Verified the native notebook in light and dark appearances, accessible width increments, and pointer dragging of the resizer. Both native builds compiled and passed code-signature verification. This is a visual refinement with no data-model or learning-behavior changes.


## September 7: Progress, notes, and knowledge map redesign

Installed and launched `[local development path]`. Research and design rationale: [Progress and notebook redesign](PROGRESS_NOTEBOOK_REDESIGN.md).

- Progress places the growing practice tree and eight milestones first. It has a featured award showcase, award criteria, local image sharing, a compact activity calendar, and course completion details. Review tasks remain in Review.
- Notes have course identity labels, course/tag/pinned filters, text search, and sorting. The editor and tutor retain identity while documents change. Narrow layouts keep notebook navigation visible.
- The map has separate connected groups, course colors, hover highlighting, search with context, local focus, node dragging, background pan, zoom/fit, keyboard controls, and direct opening of notes/courses. At low zoom, note labels reveal on hover to prevent overlap.
- Native light/dark visual review completed. Verified full milestone card interaction, pinning an earned achievement, locked criteria, actual PNG exports, attached save-sheet return, combined note filters, note switching, graph search/focus/pan/zoom/keyboard navigation, and opening the selected graph note.
- A typed sentence persisted only to its original note after switching documents immediately, confirmed in the disposable SQLite library.
- Fixed an exclusive-access crash in achievement pinning found during UI testing; corrected nested save presentation and achievement accessibility roles.
- `swift test`: 65 cases, 59 passed, 6 opt-in live-model cases skipped, 0 failures. Both native test and production builds succeeded. No AI pipeline changes required live provider calls.
- Compared decoded records before and after installation: personal state, all 3 documents, both conversations, and all 6 note revisions are unchanged. Backup: `.review/library-before-progress-1bd11c92.sqlite`. JSON byte ordering changed on routine save; decoded records match exactly.
- Image artifacts: `.review/Plam-first.png` and `.review/Plam-progress.png`. Verification logs use the `redesign-progress-*` prefix.

Limits: the graph renders up to 300 matching nodes at once and keeps dragged positions only while open. The tree canopy displays the latest 56 practice days; total growth remains recorded. Export saves or copies locally and does not publish externally.


### Pixel-tree visual refinement

Replaced the line-and-leaf illustration with native pixel artwork: a complete leafy sapling at early growth, a broader layered canopy as practice accumulates, shaded bark, a small ground shadow, and highlighted practice-day clusters. Day clusters retain native button semantics and hover/selection feedback with Reduce Motion support. The same artwork is used by share cards.

Verified the two-day light-mode tree and 22-day dark-mode tree in an isolated app, including practice-day selection. Native test and production builds succeeded. Installed the signed update at `[local development path]` and verified the saved library remained identical. macOS requested Keychain access on relaunch; the protected system dialog requires the user to complete it. No credential or Keychain policy was modified. Backups and build logs: `.review/pixel-tree/`.
