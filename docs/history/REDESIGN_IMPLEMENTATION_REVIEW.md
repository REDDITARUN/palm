# Palm interaction and visual redesign

6 September 2026

## Implemented

- Shared neutral surface, selection, hover, press, disabled, and field-focus states. Full button and row content shapes fix the reproduced sidebar whitespace-click defect. Primary, secondary, text, icon, choice, and navigation controls use the shared styles.
- Compact collapsible sidebar and navigation toolbar, back/forward history, searchable command palette (⌘K), and shortcut guide. Course and notebook search text survives switching sections. Removed the route-wide forced view replacement.
- Quieter Today, course lists and lesson rows, course details, review, progress, completion, and notebook layouts. Smaller question typography and Markdown/code rendering; fewer repeated headings, decorative icons, pills, and progress summaries.
- Shared in-app action popovers, searchable selectors, and tabs replace the inconsistent pickers. Standard application menus and file dialogs retain macOS behavior.
- Settings now follows the chosen appearance, with category navigation and searchable model selection. Provider credentials remain in Keychain.
- Multiline tutor composer with native newline behavior, context attachment, focus treatment, and scoped ⌘Return. Lesson inspector becomes an overlay when the available content width is narrow.
- Quiz option number keys, scoped submission, focus restoration after grading, and Return continuation outside text editors. Ordering submissions now read the latest stored draft instead of an outdated view snapshot.
- Flashcard Space-to-reveal and 1–4 ratings, guarded until reveal and against repeat events. Prose editors support Tab/Shift-Tab navigation; the Markdown note editor keeps its editing conventions.
- Cleaner notebook toolbar, Note/Flashcards tabs, single Edit/Done action, copy confirmation for code, and expanded diagrams. Note tutor cancellation no longer publishes a canceled response or clears newer draft text.
- A shared-control gallery is available only in the isolated test app.

## Verification performed

- Native macOS build and strict code-signature verification.
- Standard Swift test suite: 48 tests executed, 42 passed, 6 optional live-provider tests skipped, no failures.
- Isolated UI walkthrough across all eight question types: choice, true/false, cloze, trace, explain, diagnose, order, transfer. Confirmed wrong-answer feedback, correct written-answer feedback, order changes immediately followed by submission, and written-answer Return continuation.
- Prediction, tutor question, reflection, course completion, and opening the generated recap. SQLite inspection confirmed a completed session, eight attempts, saved notes, and two flashcard reviews. Fixture model responses were used; no new real-provider quality claim is made for this redesign.
- Flashcards: reveal, rate, next-card reveal reset, ignore ratings before reveal, completion, and persisted schedules.
- Sidebar whitespace navigation, search/command keyboard activation, searchable selector activation and Escape dismissal, disabled gallery control, code-copy confirmation, and expanded Mermaid diagram.
- First launch, optional provider setup, preference entry, back navigation preserving values, and entering the workspace. Removed duplicate empty-state creation actions and zero-value Today counters found during this walkthrough.
- New-course form, keyboard selection of starting level, and generation through the local fixture provider.
- Light/dark Settings consistency and rendered notes; native Tab focus ring and Space activation with macOS Keyboard Navigation enabled. The original system setting was restored afterward.

## Review boundaries

This is an implemented redesign, not a claim that every aspirational item in the design plan has passed exhaustive certification. Full Keyboard Access, VoiceOver, Increased Contrast, system-level Reduce Motion, very large libraries, and every window-size/content-length combination have not received complete manual walkthroughs. Existing Reduce Motion handling remains in place.

Notebook tutoring currently uses the compact expandable composer and an answer sheet; lesson tutoring uses the side inspector. Persisted partial-response streaming, per-document scroll restoration, and a unified note conversation inspector remain additional work. Lesson feedback still scrolls into view when grading finishes. Back/forward shortcuts are ⌘⌥[ and ⌘⌥] to avoid editor shortcuts.

All automated UI work used disposable libraries under `.review/`. Personal learning data was not replaced with fixtures. The source backup for this change is `.review/before-redesign.tar.gz`.

## Installed build

The signed app is installed and open at `[local development path]`. The personal library was checked after launch against a pre-update SQLite backup; courses, notes, sessions, flashcards, and repositories are unchanged. Previous app location: `.review/redesign-installed-backup-path.txt`.
