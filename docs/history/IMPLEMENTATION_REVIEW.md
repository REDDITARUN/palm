# Plam implementation and review

6 September 2026

**Latest update:** See [the interaction and visual redesign review](REDESIGN_IMPLEMENTATION_REVIEW.md) for the newly installed build, command palette, keyboard fixes, and current verification. The notes below describe the earlier learning-feature release.

## Ready to review

- **Notebook → Flashcards:** manual creation, generation from the selected note, editable draft review, duplicate-front filtering, edit/pause/delete, and note-linked decks.
- **Flashcard practice:** reveal before self-rating, Again/Hard/Good/Easy, per-card FSRS schedules, review history, combined due-card review, and decks/drafts included in local storage and backups. Editing a card resets its scheduling state while preserving practice history.
- **Reading and questions:** shared Markdown rendering, smaller question text and headings, inline-code styling, language-tagged source display, fenced-code copy buttons, exact duplicate-code removal, readable option formatting, and reading-size settings.
- **Notes:** fixed duplicate title rendering and highlights spanning inline code, quieter diagram colors, cleaner previews, and creating a card from a selected passage through Note actions.
- **Learning:** new generated lessons have a separate ungraded prediction, followed by its explanation. Recap takeaways and earlier feedback are hidden until reveal. Prompts ask for progressively less guidance and changed examples without a fixed choice-question ratio. Existing saved lessons retain their original material.
- **Tutor:** multiline composer, attached selection, focused send shortcut, cancellation, saved session drafts, retry without duplicate user messages, and separate conceptual questions that do not count as hints.
- **Interface:** neutral surfaces, smaller sidebar, simpler Today metrics, hover/press feedback, restrained motion, no code minimap, meaningful milestones, optional practice streaks, and due-count refresh while the app stays open.

## Verification

- Standard regression suite: 42 passing tests; 6 optional live tests skipped in the standard run.
- New tests cover legacy decoding, flashcard scheduling/idempotency, persistence and portable restore, orphan/duplicate validation, streak dates, duplicate headings/code, and ungraded prediction storage.
- A real free OpenRouter Inkling call generated six valid cards from a technical note. Their content was inspected for correctness and useful examples.
- A real model learning pipeline generated a course and lesson, accepted a correct explanation, rejected an incorrect one, and answered a tutor question. A later rerun exposed malformed JSON from the provider. The app rejected it without saving; generation now requests a more concise lesson and permits at most two repair attempts. The final rerun passed in 81 seconds with eight questions, correct/incorrect grading, and a tutor response; the log is `.review/live-learning-final.log`.
- Native app walkthrough in an isolated fixture library: note rendering → generated draft → save → reveal/rate all four cards → completion → relaunch. The stored library retained all four review records.
- Native lesson walkthrough: incorrect ungraded prediction → explanation → mixed practice → conceptual tutor question → recall → completion → saved recap. Storage inspection confirmed the prediction was excluded from attempts and the separate tutor question added no assistance penalty.
- Light and dark notes, larger reading text, inline-code highlights, code blocks, Mermaid diagrams in notes and card answers, and the new settings were inspected visually.
- The Mac locked before the final keyboard walkthrough. Focus-scoped shortcut code compiles, but the last native keyboard interaction could not be completed while locked. Reduced Motion is handled in the affected code; a system-level Reduced Motion walkthrough was not performed.

## Review these first

1. Open an existing note and switch to **Flashcards**. Generate a draft or create a card yourself.
2. Review the deck, reveal answers, and choose ratings based on recall before reveal.
3. Create a new lesson to try the ungraded prediction. Saved lessons are not silently regenerated.
4. Check a code question with the tutor open, then try Notebook in both appearances.
5. Open Progress to inspect milestones and Settings → General to change reading size or hide the streak.

## Research items still open

The research document is the broader product backlog. This implementation does not claim every item is finished. Remaining larger work includes adaptive sequencing and stable concept-level lesson reviews beyond flashcards; a real code-execution/step-through lab; source-backed interactive repository maps; full block/slash editing; a command palette; incremental tutor streaming with durable partial responses; and optional weekly/rest-day goal rules. Diagrams have a local renderer and readable failure fallback, but do not yet have a model repair tool or chart-generation pipeline.

The signed update is installed at `$HOME/Applications/Plam.app`. The running previous app was left open while the Mac was locked; quit and reopen Plam to load the update. Its previous bundle is retained in `.review/` (path recorded in `.review/installed-backup-path.txt`).

No personal courses, notes, credentials, or learning history were replaced with fixture data. UI fixtures and cloud test inputs were separate from the personal library. The previous source snapshot is retained under `.review/before-learning-polish.tar.gz`.
