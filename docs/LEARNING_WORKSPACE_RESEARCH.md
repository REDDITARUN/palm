# Palm: learning workspace research and implementation specification

7 September 2026 · Research before implementation

This document covers the requested note editor, side-by-side AI editing, natural teaching language, useful progress, linked knowledge, repository questions, syntax selection, streaming conversations, question navigation, deeper curricula, AI configuration, and app icon. It combines inspection of the installed app and source with primary documentation and learning studies. Recommendations below are design decisions, not claims that these features are already implemented.

## Recommended direction

Keep the native macOS shell, local SQLite library, Keychain credentials, CodeEdit source reader, Serena exploration, and existing provider compatibility. Add a locally bundled BlockNote editor for the notebook, one resizable conversation inspector shared by notes and lessons, explicit knowledge relationships in SQLite, and a generation pipeline that validates content in several steps.

The app should feel like a calm workspace: editable document in the center, optional help on the right, and learning progress that points to the next useful action. Hover reveals controls; clicking places the caret. Moving the pointer alone must never start editing or steal focus.

## What the current app actually does

| Area | Verified current state | Consequence |
| --- | --- | --- |
| Notes | `LibraryViews.swift` switches between a Markdown renderer and `NativeTextViewWrapper`. | Reading and editing change the document layout. |
| Note AI | A bottom composer returns an answer sheet. Its prompt and answer live in view state. | It cannot act as a persistent conversation alongside the document. |
| Lesson chat | Entire responses arrive at once; the inspector has a fixed 320-point width. | Long explanations feel slow and cramped. |
| Prompts | Three teaching overrides exist, but course, quiz, diagnostic, tutor, and harness prompts are scattered. | A tone change in one setting does not cover all generation paths. |
| Curriculum | The outline prompt normally requests 3–5 modules with 2–3 lessons; ordinary lessons request eight questions. | Scope is constrained before the app has established what the goal requires. |
| Code | Text-range selection already works. CodeEdit includes Tree-sitter language support. | We can extend selection with syntax information rather than build another code reader. |
| Repository context | Ranked excerpts are capped; agent exploration has a 12-step limit. | Deep questions may lack caller, callee, test, or error-path context. |
| Memory | Local Mem0/Qdrant/FastEmbed indexes canonical learner memories with inference disabled. Notes have SQLite full-text indexing and simple backlinks. | A useful foundation exists, but a visual graph and global note retrieval are separate additions. |
| Progress | Cumulative counts, activity bars, milestones, and per-skill totals dominate. | It is hard to tell what to practice next or what remains untested. |
| Question navigation | `nextQuestion` exists; attempts are unique per question. | Adding Back requires separating navigation from reattempts and scoring. |
| Icon | `Assets/Palm.icns` is bundled; the installed `Info.plist` contains no icon keys. | The missing icon has a concrete packaging cause. The build generator requests an icon key, but the produced bundle does not contain it. |

Inspection did not modify personal notes, answers, or settings. No cloud-model calls were required for this research.

## 1. Notes: one document, always editable

### Library choice

| Option | Strength | Tradeoff | Decision |
| --- | --- | --- | --- |
| Existing SwiftMarkdownEngine | Native AppKit, live Markdown styling, wiki links, code and formula rendering hooks. | Block handles, slash insertion, embedded diagram editing, and structured AI replacements would require substantial custom work. | Keep as a migration/reference fallback; it can improve the present editor but does not supply the full requested block experience. |
| BlockNote | Block selection, dragging, slash menu, formatting menu, customizable UI, optional math and Mermaid packages. | Requires an embedded web editor and a careful content migration. | Preferred for the requested final notebook experience. |
| Tiptap directly | Highly customizable underlying editor; has a KaTeX mathematics extension. | More application code for block behavior and UI consistency. | Reasonable alternative, less complete for this particular requirement. |

These capabilities are documented by [SwiftMarkdownEngine](https://github.com/nodes-app/swift-markdown-engine), [BlockNote](https://github.com/TypeCellOS/BlockNote), and [Tiptap Mathematics](https://tiptap.dev/docs/editor/extensions/nodes/mathematics).

Use BlockNote's core, React, and shadcn packages, styled with Palm's typography and colors. The public npm registry currently reports version 0.54.0 for these and its math/diagram packages. Pin one compatible set during implementation. Core packages report MPL-2.0; the separate XL AI package has different terms and is unnecessary for Palm's existing model layer. This distinction is documented in [BlockNote's repository](https://github.com/TypeCellOS/BlockNote#license-) and [AI integration documentation](https://www.blocknotejs.org/docs/features/ai). This is dependency scoping, not a request for a subscription.

Bundle the editor's HTML, JavaScript, fonts, and styles inside the signed app. Run it in WKWebView, without a local web server or internet dependency for typing. Swift remains responsible for storage, models, tools, and credentials. The editor receives document data and editing commands, never provider keys. Disable arbitrary page navigation and external content execution in this editor surface.

### Editing behavior

- Click anywhere in a paragraph and type, with no Edit/Done switch or layout replacement.
- Show a small block handle and insertion control beside the hovered or keyboard-focused block.
- `/` inserts headings, lists, tasks, quote/callout, code, equation, diagram, table, or linked note.
- Selecting text opens a compact formatting menu: bold, italic, inline code, link, highlight, and Ask AI. Formatting remains keyboard-accessible.
- Equation and diagram blocks render in place. Click to edit their source locally, then return to the rendered block.
- Give code blocks language selection, copy feedback, and readable overflow. Keep large diagrams expandable.
- Keep Flashcards beside the note; allow selection → create card, with editable front/back before saving.
- Support Undo/Redo across ordinary typing, block moves, and accepted AI edits. Autosave must flush on note switch, window close, and app quit.

BlockNote documents dedicated [math](https://www.blocknotejs.org/docs/features/blocks/math), [diagram](https://www.blocknotejs.org/docs/features/blocks/diagrams), and [suggestion-menu](https://www.blocknotejs.org/docs/react/components/suggestion-menus) support. These are useful building blocks, not proof that their WKWebView integration already passes Palm's tests.

### Storage and migration

Use structured blocks with stable IDs as the canonical format for newly migrated notes. Preserve the original Markdown revision and maintain a Markdown export/search representation derived from those blocks. Never alternate between two independently editable authoritative copies.

BlockNote explicitly describes Markdown conversion as lossy and recommends its JSON document format for lossless storage. Therefore automatic Markdown import alone is insufficient for Palm's highlights, wiki links, LaTeX, and Mermaid. Implement explicit converters for these constructs; preserve unknown content as a readable source block instead of dropping it. Verify every existing note construct before marking a conversion complete. [Format interoperability](https://www.blocknotejs.org/docs/foundations/supported-formats).

Store note revisions transactionally. Move high-frequency note/conversation writes into dedicated tables rather than rewriting the complete application JSON and rebuilding the note index on every token or keystroke. Keep existing IDs and backups compatible through a versioned migration.

## 2. One AI inspector for notes and lessons

Use the same right-hand panel in both places. Default width around 380 points, draggable from roughly 300 to 620 subject to the available document width. Persist the chosen width. On a narrow window, collapse the notebook list first or overlay the inspector; keep a clear close control and keyboard resize alternative.

The inspector has a conversation and a small context row. Context can include the current note, selected blocks/code, linked notes, and repository sources. Show what was actually used through an expandable source list.

For note editing, support natural requests such as “Explain this more simply,” “Add an example of mutation,” “Replace this paragraph,” and “Turn these steps into a flowchart.” The assistant returns a focused block change with a visible preview. Applying it is one undoable document transaction. Whole-note rewrites are explicit operations. If the note changed after the request began, compare its revision and rebase or offer a new suggestion; never overwrite newer typing with an old response.

Persist conversations per note and per learning session. Add edit-and-resend, retry, stop, copy, and new conversation. Editing an earlier message creates a new conversation branch; existing later replies remain available rather than silently becoming answers to a different question. Accepted note changes are independent document revisions and are not rolled back by branching a conversation.

### Real streaming

Introduce one event contract across provider routes: request started, retrieval/tool activity, provider reasoning/status, text delta, usage, completed, canceled, failed. Both direct API and OpenCode routes must feed it. Render stable completed Markdown blocks while buffering incomplete formulas or diagram fences. Throttle UI updates; do not rerender a complete long document for every token.

Preserve partial output on cancel or failure and label it incomplete. Retry must not duplicate user messages. Autoscroll only while the learner is near the bottom; otherwise show a small new-content action. Save incrementally with a debounce and flush at terminal states.

OpenRouter supports SSE streaming through `stream: true`; its reasoning data varies by provider. OpenCode exposes SSE events as well. Use actual returned events for “Reading sources,” “Thinking,” and “Writing.” If reasoning is unavailable, use a neutral working state; do not invent reasoning text. [OpenRouter streaming FAQ](https://openrouter.ai/docs/faq), [reasoning fields](https://openrouter.ai/docs/guides/best-practices/reasoning-tokens), [OpenCode server](https://opencode.ai/docs/server/).

## 3. Natural language across every generation path

Create a shared teaching-style policy composed into diagnostics, outlines, lessons, questions, hints, grading explanations, recaps, flashcards, note editing, tutor replies, repository summaries, and the OpenCode harness. Keep schema and correctness rules separate from user style preferences.

Suggested shared instruction:

> Explain directly in ordinary language. Use concrete examples and describe what happens, why it happens, and when the idea applies. Introduce technical terms after establishing the idea and define them when first used. Avoid idioms, poetic phrasing, slogans, theatrical language, vague metaphors, and generic praise. Prefer the literal mechanism: say “This second check catches missing values before saving,” rather than “This is a belts-and-suspenders approach.” Use natural connected paragraphs. Markdown, code, formulas, lists, and diagrams are welcome when they clarify the explanation. Do not turn plain language into unformatted text. Do not describe your prompting, grading machinery, or internal workflow in the lesson.

Settings should have one global style field plus task-specific overrides with examples, reset, preview, and a record of which prompt version generated each artifact. Evaluate tone on representative topics, not merely a blacklist of phrases. A response can avoid idioms and still be vague or unhelpful.

## 4. Progress that helps decide what to do next

Replace the three cumulative headline counters and large milestone section with:

| Element | What it tells the learner |
| --- | --- |
| Next review | Which concepts/cards are due and why; start directly. |
| Concept coverage | Introduced, practiced with support, demonstrated independently, checked after a delay, or not yet assessed. |
| Recent evidence | Independent correct answers out of eligible attempts, with the denominator and date range visible. |
| Retention checks | Outcomes on delayed reviews, separate from immediate lesson performance and self-rated flashcards. |
| Focus areas | Specific concepts needing another example or unresolved questions, linked to the evidence. |
| Activity | A secondary, interactive 7/30/90-day chart with hover values and a list alternative. |

Do not infer mastery from one successful answer, a completed lesson, a node's size, or time spent. Do not classify “asked for help” as a misconception. Disputed/uncertain grades are unresolved evidence. Same-question retries after seeing the answer are supported practice, not fresh independent evidence. Display “Not enough evidence yet” instead of manufacturing a precise percentage.

Keep milestones and optional streaks in a small secondary disclosure. Move generation logs into AI activity/settings.

Use Swift Charts already in the project. Borrow shadcn's compact range control, restrained grid, readable tooltip, and simple legend; these are design patterns that translate to native Charts. Its published components use Recharts and are not SwiftUI packages. [shadcn area charts](https://ui.shadcn.com/charts/area), [Swift Charts](https://developer.apple.com/documentation/charts).

Dither texture can be an optional subtle fill for activity charts or a selected region. Keep labels, axes, and data boundaries crisp. Use ordinary bars when daily counts are sparse and avoid smoothing that implies unobserved data. Do not copy the reference's revenue metrics, dense cards, or continuous spring motion. The supplied [Amicro examples](https://amicro.vercel.app/dither-charts) were inspected in the browser; they use retro dotted chart treatments and range controls.

## 5. Linked knowledge and global reference

Build two related views over explicit data:

- **Note map:** notes and their links, with course/topic filters, search, hover connections, click-to-open, and a local neighborhood view.
- **Learning map:** concepts, prerequisites, lessons, relevant code symbols, and evidence of practice. A connection has a label and source, not just a decorative line.

Default to a local neighborhood of the current note/concept. An unrestricted global graph quickly becomes difficult to read. Obsidian's local graph supports adjustable connection depth, which is a useful interaction model. [Obsidian graph documentation](https://obsidian.md/help/plugins/graph).

Store typed nodes and edges in SQLite: note, concept, lesson, symbol, source; links-to, prerequisite-of, explains, exemplifies, supported-by. Each inferred relation needs source IDs, the source revision/snapshot, creation time, and an explicit inferred status. User corrections and deleted sources invalidate derived relations. Preserve stable IDs through renames; do not link solely by title.

The model accesses tools such as `search_notes`, `read_note`, `related_concepts`, `get_source`, and `get_learning_evidence`. Retrieval combines existing full-text search, semantic candidates, and a bounded expansion through relevant relationships. Return excerpts and source IDs. The tutor reads relevant records; it does not consume a screenshot of the graph or send the entire library with every question.

### Memory and graph options

| Component | Recommendation |
| --- | --- |
| Existing Mem0/FastEmbed index | Retain as a rebuildable semantic index while extending what can be retrieved. Canonical user data stays in SQLite. |
| App-specific relationships | Use GRDB/SQLite tables. Their rules are simpler and more transparent than model-inferred general-purpose memory. |
| Grape | Preferred native graph visualization candidate; it supplies SwiftUI graph marks and force simulation. Verify pinned-version interaction and performance before adopting. |
| Cytoscape.js | Strong fallback for richer graph interactions, bundled locally if Grape does not meet the interaction requirements. |
| Graphiti | Useful temporal-memory framework, but introduces another ingestion/runtime/backend layer. Do not add it merely to draw note links. |
| Mem0 graph memory | A separate capability from the vector-only integration currently used. Evaluate only if automatic relation extraction proves better than explicit note/concept links. |

Sources: [Grape](https://github.com/li3zhen1/Grape), [Cytoscape.js](https://js.cytoscape.org/), [Graphiti requirements](https://github.com/getzep/graphiti#installation), [Mem0 graph feature documentation](https://docs.mem0.ai/open-source/features/graph-memory). Memory documentation is changing; an older Mem0 graph URL redirected to migration guidance during research. Do not silently upgrade the existing runtime or assume old configuration examples still apply.

A force graph is a navigation aid. The reviewed studies do not establish that looking at an automatically generated graph improves programming mastery.

## 6. Repository understanding and syntax-aware questions

Keep Serena for semantic exploration. Expand the research brief to gather the relevant symbol, its callers/callees, key data types, tests, and failure paths. Scope exploration to the learner's question and stop when those evidence needs are met, with a configurable research budget rather than the current universal 12-call rule. Cache by repository snapshot and topic.

Provide longer snippets when needed to explain a mechanism: a complete function or a small call chain, with line numbers, file path, language, and snapshot. A working design range is often 15–50 lines, but this is a readability choice, not a research finding or a strict limit. Collapse unrelated sections and let the learner open neighboring source. Distinguish copied repository code from generated teaching examples.

Ask about behavior at several levels: what a particular expression computes, why a guard exists, how state changes across calls, which branch runs for a given input, how an error propagates, and what changes if one step moves. Supply enough context to answer without guessing invisible code.

### AST-assisted selection

A click/caret position should identify the smallest useful syntax node. Offer “expression → statement → function” selection expansion, show the selected range, and attach it to the tutor. Preserve ordinary drag selection as the default familiar behavior.

Tree-sitter identifies syntax and ranges; it does not by itself prove what an identifier resolves to or compute a trustworthy runtime call graph. Use Serena/language-server references when those semantic answers are available. Unsupported languages or incomplete snippets keep manual selection and clearly labeled partial parsing. Handle UTF-8 parser offsets versus AppKit UTF-16 text ranges correctly, including emoji and non-ASCII identifiers. [Tree-sitter queries](https://tree-sitter.github.io/tree-sitter/using-parsers/queries/1-syntax.html), [Swift bindings](https://github.com/tree-sitter/swift-tree-sitter), [Serena tools](https://oraios.github.io/serena/01-about/035_tools.html).

### Flow-based questions

Add first-class diagram choices rather than putting raw Mermaid strings into today's string-only options. Each option has an ID, graph specification, accessible text description, and explanation. Select an entire option card; an expand button remains a separate action. Correctness compares IDs.

Support choosing the correct flow, finding a wrong edge, ordering stages, completing a missing node, tracing an input through a branch, and explaining an error path. Generate a canonical directed graph with a known scenario, then plausible alternatives differing in meaningful edges or conditions. Use a consistent layout so the correct graph is not visually distinguishable by polish or complexity. Validate unique nodes, edge endpoints, answer IDs, renderability, and whether alternatives are genuinely distinct. For code-derived graphs, verify paths against the pinned source; static syntax alone does not establish runtime behavior.

## 7. Learning depth and going back

Add Previous/Next and a compact question navigator showing unanswered, answered, current, and needs-review states. Allow returning to any visited question and editing unsubmitted drafts. Revisiting a submitted question shows the original answer and explanation. “Try again” creates a new practice attempt linked to the original; it cannot erase the first attempt or inflate independent success. Checkpoints can permit answer revision before final submission and keep feedback hidden until then.

The curriculum should be demanding through reasoning, diagnosis, transfer, and delayed recall. A bigger fixed question count is not a definition of depth.

Use this generation workflow:

1. Resolve the goal and existing knowledge; gather version-specific repository/documentation evidence when relevant.
2. Generate a concept/prerequisite graph and observable outcomes.
3. Review the proposed scope for missing prerequisites, gaps, duplication, and final application tasks; repair it before presenting the course.
4. Generate a lesson and examples for the next objectives, with question formats chosen by what must be demonstrated.
5. Run schema validation and an independent content review. Check expected code behavior where a reliable fixture or static analysis permits it. A second LLM opinion is a useful check, not proof.
6. Adapt support based on previous evidence: worked example, partially completed task, independent application, or a new contrasting example.
7. Revisit concepts after a delay and mix related concepts once the learner can distinguish the basics.
8. Offer a capstone and cross-topic transfer tasks; show evidence and remaining gaps instead of declaring universal mastery.

Use additional model calls for evidence, critique, targeted repair, and useful variations. Reuse validated artifacts; prefetch the next likely lesson; cancel superseded work. Respect the selected model and route. Generous API use does not authorize silently moving from free to paid models. Show actual usage when available and allow a deep-research setting without flooding the UI with controls.

### Learning evidence and limits

Kornell, Hays, and Bjork found that unsuccessful retrieval attempts could improve later learning when answers were subsequently provided. Their experiments used general-knowledge questions and word associates. This supports a brief ungraded prediction followed by explanation; it does not establish that prolonged guessing is best for every programming task. [2009 study](https://pubmed.ncbi.nlm.nih.gov/19586265/).

A study of adaptive worked examples and tutored problem solving found better outcomes from choosing support based on the learner's needs than from a fixed sequence. Its SQL-tutoring context is relevant to technical learning, but the exact Palm workflow still needs evaluation. [Najar, Mitrovic, and McLaren, 2016](https://www.cs.cmu.edu/~bmclaren/pubs/NajarMitrovicMcLaren-LearningWithITSAndWorkedExamples-UMUAI2016.pdf).

Research reviews give stronger general support to practice testing and distributed practice than to highlighting alone. Therefore highlighting should feed an explanation, question, or flashcard, while spaced retrieval remains central. Interleaving is useful in some settings, not a rule to randomize every beginner lesson. [Dunlosky et al., 2013](https://journals.sagepub.com/doi/10.1177/1529100612453266), [Yan, Sana, and Carvalho, 2024](https://journals.sagepub.com/doi/10.1177/23727322231218906).

## 8. AI settings: models, tools, skills, and prompts

Make an AI section with Models, Tools, Skills, Prompts, and Activity. Keep ordinary learning screens focused on learning.

- **Models:** saved provider connections; separate optional routes for tutoring, curriculum, grading, and repository research; capability-aware settings for streaming, structured output, tools, reasoning, and context. Test a connection without changing the default. Record the actual model used per artifact.
- **Tools/MCP:** add local stdio or remote Streamable HTTP server, enable/disable, test connection, inspect available tools/resources/prompts, see recent errors, and choose which agent roles may use it. Store secrets in Keychain. Adding a server entry must not execute it until explicitly enabled/tested.
- **Skills:** managed local SKILL.md folders with description, enabled roles, editable instructions, and optional referenced resources. Load relevant skills when needed. A skill's text does not independently grant new tool permissions.
- **Prompts:** global teaching tone plus per-task overrides, reset, preview, and version history.
- **Activity:** actual stages, tools used, source coverage, duration, usage, cancellation, and actionable failures. Avoid logging credentials.

Extend the existing OpenCode MCP/skills integration first rather than create a competing agent framework. Its documentation supports configurable MCP servers and SKILL.md discovery. A shared Palm registry should translate to role-specific OpenCode configuration. The official Swift MCP SDK is an alternative if native direct tool sessions become necessary; adopting it does not by itself supply a complete agent loop. [OpenCode MCP](https://opencode.ai/docs/mcp-servers/), [OpenCode skills](https://opencode.ai/docs/skills/), [Agent Skills format](https://agentskills.io/specification), [Swift MCP SDK](https://github.com/modelcontextprotocol/swift-sdk).

## 9. Visual details and icon

The supplied orb reference includes a real SwiftUI package, `ThinkingOrbsKit`, whose manifest supports macOS 12+. It uses Canvas and TimelineView, has no package dependencies, and includes an explicit Reduce Motion path. This fits Palm's macOS 15 baseline. Vendor or package a pinned revision with its license, then verify inside the app. Use one small orb beside an accurate status label and stop animating when idle. [Orb reference](https://libraries.dev/orbs), [SwiftUI package](https://github.com/Jakubantalik/Libraries.dev/tree/main/packages/thinking-orbs/ports/ios/ThinkingOrbsKit).

Keep the document palette neutral with Palm's muted green for primary actions. Reserve green/red/amber for clearly explained feedback states; don't make every note block colorful. Hover and focus must remain distinguishable. Hide block handles when inactive without making keyboard access disappear.

For the icon, preserve the recognizable Palm leaf idea, simplify the silhouette, and check it at Dock and Finder sizes. First fix the generated bundle metadata; a new picture alone will not solve the current missing declaration. Verify the final installed bundle has the icon resource and a valid icon declaration, then inspect Dock, Finder, app switcher, and About. Follow [Apple's app-icon guidance](https://developer.apple.com/design/human-interface-guidelines/app-icons).

## Implementation order and completion checks

This is one complete upgrade with a dependency order, not separate product versions.

| Order | Work | Completion evidence |
| --- | --- | --- |
| 1 | Data contracts, revision migration, shared prompt policy, icon packaging | Old library and backups load; golden note conversions preserve content; generated bundle declares its icon. |
| 2 | Always-editable notebook and block UI | Click/type, slash, selection formatting, code, formulas, diagrams, Undo/Redo, autosave, relaunch, and Markdown export all work. |
| 3 | Shared resizable inspector, streaming, note changes, conversation branches | Partial output survives cancellation; old-message edit branches correctly; accepted changes are undoable; newer typing survives stale responses. |
| 4 | Knowledge links and retrieval | Renames retain links; deleted/forgotten data is excluded from retrieval; every returned source opens the right revision; map remains navigable with a keyboard. |
| 5 | Curriculum, repository evidence, AST selection, diagram questions, Previous/reattempt | All existing formats still work; graph distractors validate; syntax ranges map correctly; returning to a question preserves history and scoring. |
| 6 | Progress and AI configuration | Progress distinguishes coverage, delayed recall, and support; MCP configuration survives relaunch; model capabilities and tool failures are represented accurately. |
| 7 | Full native review and final install | Complete welcome → course → lesson → chat → recap → edit → flashcard → delayed review flow in isolated data, then verify the installed app preserves personal data. |

Test long documents, incomplete Markdown during streaming, keyboard-only use, input-method composition, light/dark appearance, small/large windows, Reduce Motion, VoiceOver, offline editor use, slow provider replies, disconnections, malformed graph output, canceled edits, and migration recovery. Pin dependency versions after the integration checks instead of tracking moving main branches.

The largest engineering risks are block-content migration, editor/WebKit focus and undo, streamed conversation persistence, and separating navigation/reattempts from learning evidence. Resolve these explicitly before calling the upgrade complete.
