# Plam: design and learning improvements

Research and specification · 6 September 2026

Status: proposed work, not implemented by this research pass. Based on inspection of the running Mac app, its Swift sources, the supplied design cheat sheet, official product documentation, and learning research. The scope remains a personal Mac app with local storage and optional cloud AI. Priorities below describe dependency order within the intended complete product.

## Direction to lock in

Use a quiet native Mac workspace: Linear’s consistent hierarchy, Notion’s emphasis on the document, and Apple’s controls, keyboard behavior, and accessibility. Keep SwiftUI, SF Pro/SF Mono, and the existing Markdown/editor components. Build a small shared component system around them. A web UI rewrite is unnecessary for these improvements.

Linear’s recent refresh emphasizes consistent headers and navigation and a quieter sidebar. Its earlier redesign explicitly addressed visual noise and alignment. These support simplifying Plam’s shell, rather than adding more decorative cards. [Linear, March 2026](https://linear.app/changelog/2026-03-12-ui-refresh), [Linear design process](https://linear.app/now/how-we-redesigned-the-linear-ui).

Proposed design targets, to verify in the actual app:

| Element | Target |
| --- | --- |
| Palette | Neutral surfaces, restrained teal accent; separate green/red/amber feedback roles |
| Navigation and metadata | Approximately 12–13 pt; secondary text still readable |
| Reading body | Approximately 14–15 pt with adjustable reading size |
| Question | Approximately 17–18 pt, regular or semibold SF Pro |
| Page title | Approximately 22–26 pt; only one dominant title per page |
| Code | Approximately 13 pt SF Mono; explicit language and user zoom |
| Reading measure | Roughly 60–75 characters where practical |
| Surfaces | Flat document area; borders only for grouping and interaction |
| Motion | Short, interruptible state changes; no layout movement on hover |

These numbers are product design starting points, not research-derived optimum values.

## What the current inspection found

| Area | Existing behavior | Concrete gap |
| --- | --- | --- |
| Questions | Plain `Text(question.prompt)`, 23 pt rounded font | Oversized; inline code and Markdown are not rendered semantically |
| Options | Plain text inside selectable rows | Formatting differs from notes and tutor content |
| Code reader | Existing source editor | Language inferred from `func`/`def`, otherwise JavaScript; needs explicit metadata |
| Today | Greeting, several metric cards, course cards, motivational panel | Too much chrome relative to the next learning action; truncated course copy |
| Notebook | Rich Markdown, math, diagrams, editor, history | Duplicate titles; inconsistent generated structure; a highlight containing inline code displayed literal `==` markers |
| Tutor | Contextual chat is functional | Basic detached input, repetitive helper copy, weak composition hierarchy |
| Interaction | Press scaling and route/feedback fades already exist | Shared controls lack consistent hover/focus states; timing alone will not fix layout jumps |
| Learning | Diagnostic questions, reading, worked example, mixed quiz | No integrated prediction/explanation loop for each concept; question-format quotas are rigid |
| Reviews | FSRS and saved review items already exist | Review identity is lesson-level; finer concept evidence is needed |

This was a targeted visual/source audit, not a complete accessibility or performance test. Existing LLM grading, uncertainty/disputes, Markdown/math, Mermaid, note history, and basic animations should be extended rather than rebuilt.

## Learning evidence and its limits

**Prediction before explanation:** attempting an answer before studying can improve subsequent learning, even when the answer is wrong, provided the learner then studies the correct information. Results vary with the procedure and assessment. This supports a brief, ungraded prediction; it does not establish that forced guessing is universally best. [Pan & Carpenter, 2023 review](https://link.springer.com/article/10.1007/s10648-023-09814-5).

**Retrieval and spacing:** practice testing and distributed practice have broad support. Self-explanation and interleaving are useful in appropriate settings but have more conditional evidence. Highlighting and rereading alone are weak foundations for durable learning. Notes should therefore support later recall, not simply grow longer. [Dunlosky et al., 2013 review](https://acs.ist.psu.edu/ist521/dunloskyRMNW13.pdf).

**Guidance that gradually decreases:** worked examples followed by progressively incomplete solutions can ease the transition to independent problem solving. Evidence for near transfer is clearer than for distant transfer. We should explicitly test a changed example rather than assume understanding transfers. [Renkl et al., 2002](https://doi.org/10.1080/00220970209599510).

**Programming-specific structure:** PRIMM organizes activity around Predict, Run, Investigate, Modify, Make. It is a good design reference for reading code before writing it. Its school-programming context differs from a personal adult AI tutor, so Plam’s adaptation needs evaluation. [PRIMM, author’s explanation](https://suesentance.net/primm-project/).

**Gamification:** a meta-analysis found average positive effects, with variation and less stable motivational/behavioral results in higher-rigor subsets. It does not establish that a particular streak or badge design improves understanding. Use rewards to acknowledge practice; measure learning separately. [Sailer & Homner, 2020](https://link.springer.com/article/10.1007/s10648-019-09498-w).

## Complete improvement list

### A. Layout, hierarchy, and navigation

1. **Simplify Today.** Lead with “Continue learning” and due reviews. Put activity numbers in one compact row. Remove the decorative quote panel and repeated motivational subtitles. Keep useful empty states.
2. **Reduce repeated chrome.** Show local/provider status when relevant, with details in Settings. Remove repeated workspace labels. Use one page title, one primary action, and quieter metadata.
3. **Make the course outline readable.** Prefer compact expandable topic rows with objective, progress, and next action. Let titles wrap. Explain prerequisites and allow an explicit placement check or override when skipping ahead.
4. **Use a consistent content frame.** Align page titles, reading columns, question bodies, and bottom actions. A tutor inspector should reduce width predictably without squeezing code into an unusable column.
5. **Unify semantic colors and icon treatment.** Teal means an action or selection; green/red/amber mean outcome. Always pair grading colors with words/icons. Avoid using warning amber as ordinary decoration.
6. **Make navigation preserve work.** Restore the selected course, question, note, scroll position, and draft when returning. Add searchable navigation and a command palette for courses, notes, reviews, and settings.

### B. Questions and code

7. **Share a rich-content renderer.** Render Markdown in questions, answer options, hints, explanations, and tutor messages using consistent typography. Support inline code, fenced code, lists, emphasis, and math where appropriate. Question text should be reading-sized, not a page headline.
8. **Separate semantics from presentation.** Store option IDs independently from rendered text. Formatting changes or option shuffling must not change grading. Preserve literal code characters and whitespace where meaningful.
9. **Improve code blocks.** Store the language explicitly; show syntax highlighting, copy, wrap, expand, and optional line numbers. Wide code can scroll horizontally; long code can expand. Do not guess every unfamiliar language is JavaScript.
10. **Make question types fit the thinking.** Use prediction choices, ordering, selecting a relevant line, completing a step, explaining a cause, modifying code, and finding a counterexample. Avoid superficial true/false questions and arbitrary format ratios.
11. **Keep feedback close and stable.** Retain the question and selected answer while explaining the result. Start with the specific reason, followed by a small worked example when useful. Expose “Why not this option?” without showing every explanation by default.
12. **Preserve trustworthy assessment.** Keep semantic LLM grading for open answers and deterministic grading for stable choices. Use explicit rubrics, partial credit when justified, and an uncertain result when evidence is inadequate. A failed grader must preserve the answer and offer retry. Disputes must not silently become permanent misconceptions.

### C. Interactivity and motion

13. **Define the complete state set.** Every interactive component needs default, hover, focus, pressed, selected, disabled, and loading treatment; outcome states where relevant. Shared buttons/options/rows should own these consistently.
14. **Use subtle hover feedback.** A slight surface or border change communicates clickability. Avoid scaling entire cards or moving neighboring content. Secondary actions can appear on hover, but must also appear on keyboard focus or an accessible menu.
15. **Finish keyboard behavior.** Predictable Tab order and visible focus; Space selects an option; numeric shortcuts only when an editor is not focused. Enter behavior must be consistent and must not accidentally submit multiline answers. Escape closes temporary panels.
16. **Animate meaningful transitions.** Candidate targets: roughly 120–180 ms for control feedback and 180–240 ms for small panels. Use a short fade or restrained slide for question replacement. Keep controls usable during animation; never add an artificial wait to make a transition visible.
17. **Prevent jumps instead of hiding them.** Preserve view identity, reserve appropriate loading space, maintain scroll anchors, and avoid re-rendering the whole document during streaming. Scroll to feedback only when it would otherwise be missed.
18. **Respect system preferences.** Reduced Motion removes scaling and unnecessary movement. Check light/dark appearance, increased contrast, VoiceOver labels, large reading sizes, and narrow windows. Theme changes should not animate every surface.

Apple recommends purposeful, brief motion and respecting reduced-motion preferences. The specific timings above are our proposed tuning targets. [Apple Motion](https://developer.apple.com/design/human-interface-guidelines/motion?changes=_3), [Reduced Motion criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria).

### D. Tutor experience

19. **Replace the detached field with one composer.** A restrained container holds an expanding multiline editor, attached Send/Stop control, and a small context row. Use ordinary language such as “Ask about this step.” Keep the model picker out of the main typing area unless needed.
20. **Make attached context visible.** Show removable chips for the current question, selected code, or note passage. Clicking a chip previews the attachment. Tutor responses should refer to that source, not merely the broad course topic.
21. **Offer a few useful starters.** Empty-state actions such as “Explain this line,” “Give a smaller example,” and “Give me a hint.” Hide them once the conversation is underway.
22. **Control answer disclosure.** Distinguish a conceptual explanation, a hint, and revealing the answer. Track assistance accurately. Asking an unrelated clarification should not automatically erase independent-practice evidence.
23. **Make streaming and recovery dependable.** Keep drafts and partial responses through navigation; support Stop and Retry. Do not force-scroll when the learner has scrolled up. Avoid per-character visual effects and noisy tool logs in the main conversation.
24. **Let explanations become durable.** Save a selected useful explanation to the relevant note with provenance and a preview. Preserve the learner’s own writing; AI suggestions remain reviewable edits.

### E. Lesson and review engine

25. **Start with a short, ungraded prediction.** Ask what a small example does, or which explanation seems plausible. Include “Not sure.” Record it as a hypothesis, never as a scored failure or established misconception.
26. **Teach in concept-sized steps.** After the prediction, reveal the result and explain why with a concrete example. Offer a small prerequisite explanation for beginners and a faster path for demonstrated knowledge. Do not require a guess before every paragraph.
27. **Fade support.** Show one worked example, ask the learner to complete a missing step, then ask for an independent solution. Learners who succeed can move faster; those struggling get a simpler explanation and bounded extra practice.
28. **Add a real code experiment.** For supported languages, let learners predict, run, inspect values, and modify a small isolated snippet. Display the actual runtime result. Keep simulated traces explicitly labeled. Generated snippets should run with resource limits and without access to the personal repository or credentials.
29. **Require meaningful application and repair.** Change the values, context, or representation; ask why the same principle applies. After a mistake, explain the cause and revisit a related task later. Avoid endless repeats of the same item and avoid treating a lucky choice as full understanding.
30. **Make recall and scheduling concept-specific.** Ask for a short explanation before revealing the recap. Give concepts stable IDs, prerequisites, and separate evidence for recognition, assisted practice, independent application, and delayed recall. Schedule reviews from reliable attempts; mix related learned concepts selectively. Keep session length bounded and allow a learner to stop without losing progress.

The proposed default loop is:

**Predict → observe the result → understand why → complete a step → apply to a changed example → recall later.**

Example: Python aliasing. Predict the result of mutating a list through a second variable; run it; show two names pointing to one list; complete a copying example; solve a changed case involving a nested list; revisit the distinction on a later day. This is our product adaptation, not a claim that the exact sequence has been validated in Plam.

### F. Notes and explanatory visuals

31. **Make notes read like an explanation.** Start with a concrete situation, explain the idea in natural language, walk through a small example, and describe when it is useful. Add a counterexample or pitfall only when it resolves likely confusion. Avoid repetitive headings and mandatory diagrams in every note.
32. **Give before/after notes different jobs.** Before a lesson: orientation, prerequisites, and the current step’s explanation without leaking future answers. After a lesson: a concise reference with examples, corrected confusions supported by the actual session, and a few recall prompts. Do not fabricate personal mistakes or uncertainty.
33. **Polish Markdown behavior.** Fix highlighting that spans inline code, duplicate heading output, code escaping, wide formulas, and tables. Add collapsible headings and a table of contents only for longer notes. Match editor and reading output closely.
34. **Make editing approachable.** Add a small block insertion/slash menu for headings, lists, code, formulas, callouts, and diagrams. Keep Markdown export, undo, autosave, and revision history. Preserve manual edits during regeneration. Notion’s slash-command pattern is a useful reference, not a reason to reproduce its whole workspace. [Notion commands](https://www.notion.com/en-gb/help/guides/using-slash-commands).
35. **Turn selected material into practice.** From a highlight or paragraph: “Explain with an example,” “Ask me about this,” or “Add to review.” Preview generated questions and avoid duplicating existing concept reviews. Keep reference reading separate from closed-book recall.
36. **Give the model a constrained visual tool.** Let it request a diagram or chart with a purpose, editable source, explanation, and source references. Render locally, validate syntax, attempt bounded repair, and fall back to readable text/source on failure. Validate relationships against evidence separately: a diagram that renders can still be wrong.

Recommended prompt contract for notes:

> Explain the current concept as a knowledgeable colleague would. Begin with a concrete example or problem. Explain how and why it works using short connected paragraphs. Use Markdown structure only where it improves comprehension. Use exact code, language tags, and verified results. Add math or a small labeled diagram only when it explains a relationship more clearly than prose. Include assumptions and important limits. Do not repeat the document title. For a recap, use actual session evidence; do not invent learner mistakes. Preserve user-authored material.

Settings should retain separate editable prompts for introductory teaching, recap notes, hints, and grading style, with defaults, reset, and a sample preview. Customization should not disable structural validation or force a confident grade when the result is uncertain.

### G. Progress and motivation

37. **Separate completion from knowledge evidence.** Show “Completed lesson,” “Applied independently,” and “Recalled later” separately. A completion ring or model-generated percentage must not imply a calibrated probability of mastery.
38. **Use a quiet practice rhythm.** One optional weekly activity strip and a simple streak. Count a meaningful completed learning action rather than merely launching the app or leaving it open. Incorrect but sincere practice still counts toward the habit.
39. **Make breaks humane and explicit.** Allow a weekly goal and planned rest days. Missing a day should not erase course progress or knowledge evidence. Keep streak rules visible and avoid guilt-oriented copy.
40. **Award evidence-based achievements.** Examples: first independent application, first successful delayed recall, revisiting and resolving a confusion, and tracing a repository flow with sources. Criteria should be understandable; grant each award once.
41. **Make completion useful.** A restrained celebration, what was learned, what needs another look, the saved note, and one clear next action. Let the user dismiss immediately. Reduce or remove celebratory motion under Reduced Motion.
42. **Use the tracker to guide action.** Show due concepts, recent independent applications, and review workload. Let users open the underlying evidence and correct a mistaken record. Keep all activity and reward history local.

### H. Repository understanding, memory, and quality

43. **Teach through a source-backed repository path.** From a real entry point, follow symbols and calls to the concept being taught. Every important code claim should link to a file, range, and snapshot. Offer a readable outline as well as a graph.
44. **Keep context current and scoped.** Reuse the existing exploration tools; refresh only affected repository evidence after changes. Show stale source references. Inspect the smallest relevant context instead of sending the full repository for every question.
45. **Make learner memory inspectable.** Store observations with source attempt, concept, time, and confidence. Distinguish a question asked, a guess before teaching, a grading dispute, and a demonstrated error. Let the learner edit or forget a memory.
46. **Validate generated learning content.** Require objectives, prerequisites, stable IDs, rubrics, sources, language tags, and activity types. Check ambiguity and executable outputs where feasible. Structural validity and a second model’s agreement do not establish factual correctness.
47. **Make long operations resilient.** Persist generation state, cancellation, and partial work. Retry a failed step without duplicating a course or erasing notes. Expose concise recoverable errors with useful next actions; keep technical logs in diagnostics.
48. **Evaluate the actual learning and UI experience.** Test delayed recall and changed examples, not just engagement. Log the minimum useful local evidence. Compare sessions cautiously: one person’s changing topics and familiarity do not establish a causal learning improvement.

## Diagram and chart tools: decisions

| Tool | Fit for Plam | Decision |
| --- | --- | --- |
| Mermaid | Generated flowcharts, sequences, state diagrams, small relationship maps; already bundled | Keep as the default. Apply one restrained light/dark theme, readable labels, zoom, copy source, and export. [Theming](https://mermaid.js.org/config/theming) |
| Swift Charts | Native activity charts and bounded plots from structured data | Use for actual numeric data with axes, units, and a text/table alternative. [Apple documentation](https://developer.apple.com/documentation/charts) |
| Small custom SwiftUI diagrams | Array indices, stack frames, list aliasing, variable traces | Use a limited family of validated components when learner-controlled stepping explains execution better than a static flowchart |
| D2 | More elaborate architecture layouts and styled diagrams | Optional if real examples exceed Mermaid’s capabilities. Its layout engines have different capabilities; do not assume identical output across them. [D2 layouts](https://d2lang.com/tour/layouts/), [themes](https://d2lang.com/tour/themes/) |
| Excalidraw | Manual sketches and an infinite whiteboard | Optional for learner drawing; its hand-drawn style is not the default note aesthetic. MIT-licensed, with a React integration cost in a native app. [Repository](https://github.com/excalidraw/excalidraw) |
| tldraw | Interactive canvas SDK | Do not lock it in. It is source-available under its own license; production requires a license key, including a discretionary hobby route. [License](https://tldraw.dev/community/license) |

The model should choose the simplest representation that answers the learning question: prose for a definition, a table for comparison, a sequence for interactions, a flowchart for decisions, and a value trace for state changes. Avoid mandatory “knowledge graphs” that grow into unreadable collections of nodes.

Suggested visual pipeline: **purpose + supported format + source → validation → local rendering → bounded repair if needed → cached artifact + readable fallback**. Keep diagram source and renderer version with the note. Do not execute arbitrary model-generated JavaScript to obtain a chart.

## Flashcards beside notes (added during implementation)

49. **Note-linked flashcards.** Create cards manually or generate an editable draft from a note. Both sides support Markdown, code, math, and diagrams. Keep recall hidden until reveal, then offer Again/Hard/Good/Easy self-ratings with per-card FSRS scheduling. Allow edit, pause, delete, review due cards across notes, and preserve decks/history in backups. Generated drafts must not silently become accepted learning material.

## Implementation order within the complete scope

| Priority | Work | Reason |
| --- | --- | --- |
| P0 | Shared content renderer, smaller type, code language metadata, highlight/title fixes, simpler layout, component states, tutor composer | Fixes problems encountered during almost every session |
| P1 | Concept IDs/evidence, prediction loop, fading guidance, changed examples, better feedback, concept reviews, active notes | Changes how learning works and creates trustworthy progress data |
| P1 | Source grounding, resilient generation, memory correction, context-aware tutoring | Supports accurate and dependable lessons |
| P2 | Diagram polish, code trace interactions, tracker, achievements, optional streaks | Builds on reliable content and learning evidence |
| Conditional | D2 or manual drawing canvas | Add only when a concrete explanatory/editing need justifies another renderer |

## Acceptance checks

- Complete welcome → configuration → topic/repository → course → lesson → feedback → recap → tracker → later review, with restart/resume along the way.
- Render the same inline code, fenced code, lists, formula, and highlight consistently in a question, option, note, and tutor message.
- Verify selected-answer grading survives Markdown formatting and option order changes.
- Test long prompts, unfamiliar code languages, wide matrices, large diagrams, mixed inline-code highlights, and malformed visual source.
- Navigate the main learning flow with keyboard and VoiceOver; check focus after question and panel changes.
- Inspect light/dark appearance, Reduced Motion, increased contrast, large text, and narrow/large windows.
- Stop/retry generation and grading under network failure; retain drafts, answers, notes, and partial messages.
- Ensure an initial guess, hint-assisted answer, uncertain grade, and disputed result update learning evidence differently.
- Regenerate a recap after manual editing without overwriting the learner’s work.
- Confirm cached notes and diagrams remain readable offline; state cloud-dependent actions clearly.
- Confirm rewards are granted once, review scheduling survives relaunch, and day/time-zone changes do not duplicate activity.
- Measure delayed recall and performance on changed examples separately from sessions completed and streak length.

The first design pass should be reviewed on three representative surfaces together: a code question with feedback, a rich note with a diagram, and an open tutor conversation. They exercise the shared typography, interaction, layout, and rendering decisions that will shape the rest of Plam.
