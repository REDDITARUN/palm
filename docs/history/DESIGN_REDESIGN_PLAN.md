# Plam design and interaction redesign

6 September 2026 · Research and implementation plan · No application code changed in this audit

Plam works, but its interface does not yet have the consistency, restraint, or interaction reliability we want. The next design pass should replace the shared foundations and simplify complete workflows. Changing a few colors and corner radii will not resolve the current feel.

The proposed direction is a quiet Mac learning workspace: compact navigation, readable documents, clear actions, and dependable feedback. Use Linear for navigation hierarchy, Notion for document presentation, Apple for platform behavior, and Airbnb for component consistency. This is one complete redesign; the implementation order below describes dependencies, not separate product versions.

## Evidence from the app

I inspected the running personal app, then the newer `dist/PlamTest.app` with the existing disposable `.review/ui-library`. The personal process was still showing an older interface. Findings below distinguish that from defects that remain in the newer build or source. This was an audit, not a full regression test or performance profile.

| Finding | Evidence | Consequence |
| --- | --- | --- |
| Sidebar whitespace does not activate a row | **Reproduced in the newer test build.** Clicking the empty right side of Notebook did nothing; clicking the label navigated successfully. | The visible row promises a larger target than the app provides. |
| Hover behavior is incomplete | `InteractiveSurface` uses a 4.5% primary-color overlay. Several controls use `.plain` directly and bypass it. Sidebar labels do not define a full-row interaction shape. | Some controls give very faint feedback; others have no shared hover treatment. This does not mean every button lacks hover code. |
| Theme is inconsistent across windows | **Observed:** main window light, Settings dark, with Light selected. The appearance override is attached to the main window but not the Settings scene. | The app visibly changes design language when opening settings. |
| Keyboard support covers isolated actions | ⌘2 navigation worked. Tab focused course search; the next Tab stayed there. macOS keyboard-navigation settings were not inspected, so that alone is not proof of a Plam bug. Source has a few shortcuts and two text focus states, but no comprehensive navigation/focus policy. | Mouse-free completion and reliable focus restoration have not been established. |
| Persistent layout repeats context | The newer UI still has a top destination label plus a page title. Notebook repeats its name in the workspace header and its list pane. | Several layers consume attention before the actual content. |
| Course detail overstates progress visually | **Observed:** progress ring, topic/level/time pills, completion banner, module counts, and lesson completion icons on one screen. | Multiple components compete to communicate similar information. |
| Menus and selectors do not share a presentation system | Note/flashcard actions use native `Menu`; Settings and onboarding mix default pickers and segmented controls. The model chooser uses a potentially long menu. | Sizing, alignment, density, and interaction cues vary. |
| Notebook toolbar has too many competing modes | **Observed:** Note/Flashcards and Read/Edit segmented controls, reading-time label, pin, overflow, plus a separate tutor area. | The document feels surrounded by controls. |
| Several rows are only partly actionable | `LessonRow` is a passive container with a trailing Start/Revisit button. Other row-like elements are buttons. | Similar-looking rows have different click behavior. |
| Small copy competes with large decoration | Source uses many 10–11 pt secondary labels alongside large icons, rounded headings, cards, and repeated helper sentences. | It is sparse in some places but visually busy in others. |
| Keyboard submission needs collision review | Next question has an unmodified Return shortcut while the tutor can be open; tutor and answer fields have local ⌘Return behavior. | A focused editor must never accidentally advance a lesson. This is a source-identified risk, not a reproduced failure. |
| Some metrics disagree | Progress counts practice days from lesson attempts, while its activity chart includes flashcard reviews. Sidebar due badge counts topic reviews only. | The same apparent concept can show different totals. |

Relevant code: [shared controls](../../Sources/Plam/DesignSystem.swift), [window and sidebar](../../Sources/Plam/PlamApp.swift), [courses](../../Sources/Plam/CourseViews.swift), [notebook](../../Sources/Plam/LibraryViews.swift), [lesson](../../Sources/Plam/LessonView.swift), [settings and progress](../../Sources/Plam/TrackerSettings.swift).

## What the references actually suggest

| Source | Useful principle | Application to Plam |
| --- | --- | --- |
| [Linear UI refresh, March 2026](https://linear.app/changelog/2026-03-12-ui-refresh) | Consistent headers and view controls, quieter sidebar, more consistent icon sizing. | One window shell and toolbar grammar; let the learning content carry the strongest visual weight. |
| [Linear redesign process, March 2024](https://linear.app/now/how-we-redesigned-the-linear-ui) | Test appearance, environment, and hierarchy across real layouts and states. | Review a small set of representative screens together before propagating components everywhere. |
| [Notion page styling](https://www.notion.com/help/customize-and-style-your-content) | Reading width, optional metadata, and contextual formatting can keep a document focused. | Constrain prose width; disclose tags, backlinks, sources, and editing tools when useful. |
| [Notion keyboard shortcuts](https://www.notion.com/help/keyboard-shortcuts) | Search, back/forward navigation, and editing commands are accessible through a consistent keyboard vocabulary. | Add command search, route history, scoped editor commands, and discoverable shortcuts. |
| [Airbnb: Building a Visual Language, August 2016](https://medium.com/airbnb-design/building-a-visual-language-behind-the-scenes-of-our-airbnb-design-system-224748775e4e) | Audit complete screens and define reusable components with clear required elements. The article specifically reflects on inconsistent row patterns. | Define a small family of complete rows and controls, including states and behavior. This is a historical design-system case study, not a claim about Airbnb's current UI. |
| [Apple: SwiftUI focus cookbook](https://developer.apple.com/videos/play/wwdc2023/10162/) | Focus is contextual; text editing and button activation behave differently. Mac button tab navigation depends on the system keyboard-navigation setting. | Respect Mac conventions, test with keyboard navigation enabled, and design explicit focus transfer and restoration. |
| [Apple: native menu bar](https://developer.apple.com/documentation/swiftui/building-and-customizing-the-menu-bar-with-swiftui) | System menus provide a consistent command surface. | Keep a native menu bar with the same actions and shortcuts used inside the app. |

These references inform the direction. The measurements and component choices below are Plam-specific proposals, not copied brand specifications. The project's [interface cheat sheet](../../design_cheat_sheet.md) also supports semantic colors, full hit regions, visible focus, restrained motion, and readable line lengths. Its web-specific implementation advice needs native equivalents.

## Visual system to lock in

- **Typography:** SF Pro for interface and prose, SF Mono for code. Default body 15–16 pt, question 17–18 pt, page title 24 pt, section title 16–18 pt, secondary labels 12–13 pt. Avoid rounded display typography throughout the workspace. Preserve reading-size customization without scaling toolbars or wrapping controls unpredictably.
- **Reading width:** approximately 60–75 characters per line for ordinary prose. Code and diagrams can expand beyond that column in an explicit wider view. Long titles wrap; important content must remain accessible when truncated in navigation.
- **Color:** neutral light and dark surfaces; one restrained teal accent for the primary action and intentional emphasis. Neutral selection in navigation. Separate hover, pressed, selected, focus, success, error, and warning tokens. Red/green feedback includes a label and symbol.
- **Surfaces:** page, subtle navigation surface, and floating popover surface. Prefer spacing and alignment for grouping. Add a border only when it clarifies an input, selection, or distinct region. Avoid a card around every paragraph or statistic.
- **Geometry:** spacing scale 4/8/12/16/24/32 pt. Controls use a shared radius, approximately 8 pt; larger containers approximately 12 pt. Nested corners are optically consistent. Avoid capsules for ordinary metadata.
- **Targets:** full visible bounds must activate. Aim for 40–44 pt primary controls and navigation rows, 36–40 pt toolbar hit regions, and at least 48 pt multiline answer rows. These are desktop layout proposals; expand for accessibility and never overlap neighboring hit regions.
- **Hierarchy:** one dominant next action in each workflow region. Secondary actions remain available with quieter styling. The title, task, and next step should be apparent without reading helper prose.
- **Appearance:** main window, Settings, sheets, popovers, Markdown, code, and diagrams follow the same preference. Verify dark mode independently; do not merely invert colors.

## Interaction contract for every component

| State | Required behavior |
| --- | --- |
| Idle | Actionable controls look distinct from passive text; icons have accessible names and useful tooltips. |
| Hover | Full-target background changes visibly in both themes. Hover does not masquerade as selection or reveal essential actions exclusively. |
| Pressed | Immediate restrained fill feedback; at most a slight compression for standalone buttons. Avoid shrinking whole lists or text-heavy answer rows. |
| Selected | Persistent selection remains different from transient hover; selected state is exposed to accessibility. |
| Keyboard focus | Clear focus outline or native focus treatment, independent of selection; never removed without a replacement. |
| Disabled | Muted but legible, cannot activate, and has an adjacent explanation when the reason is not apparent. |
| Loading | Preserve control size and context, indicate the active operation, prevent duplicate submission, offer cancellation where supported. |
| Error | Explain the problem beside the affected action and offer retry without losing input. Use global alerts only where appropriate. |

Implement full label layout and `contentShape` at the correct level inside shared button/row components. Audit decorative overlays for event interception; do not cover interactive descendants with a catch-all gesture. Keep real buttons, selection controls, and accessibility semantics. A whole-row primary action must not contain nested buttons: use sibling primary and accessory action regions with explicit bounds.

Shared components should cover action buttons, icon buttons, navigation rows, selectable content rows, answer rows, tabs, fields, action popovers, searchable selectors, status messages, and the tutor composer. Create a native component gallery containing every state before using these across screens. Continue with SwiftUI/AppKit, SF Symbols, Textual, and the existing renderers; a web component library would not fix native hit testing or focus.

## Menus and keyboard behavior

For **in-app actions**, use one compact styled popover: consistent width, padding, row height, optional shortcut column, one selected indicator, and a separated destructive group. Note, course, and flashcard overflow actions use it. Large model/repository selectors need search and scrolling; simple settings choices can use the same selection component or a quiet two/three-option control. The six Settings categories should use a small navigation list instead of a crowded segmented strip.

These popovers must support arrow navigation, activation, Escape, outside-click dismissal, focus return to the trigger, screen-edge positioning, disabled items, and VoiceOver. Use native hosting and accessibility rather than drawing a menu with unlabelled text. Styling only the current `Menu` trigger will not restyle its system-owned content. Keep the Mac menu bar, standard text-editing context menus, and file dialogs native.

| Context | Planned keyboard behavior |
| --- | --- |
| Workspace | ⌘K opens command/search; existing ⌘1–4 routes stay compatible; all destinations are available in the menu bar and command search. |
| Navigation history | ⌘[ and ⌘] navigate back/forward when the active editor does not own those commands. Preserve scroll and selection. |
| Search | ⌘F searches the active document or focuses the current list search, according to context. |
| New content | Keep ⌘N for a note and ⇧⌘N for a course; ⌘, opens Settings. |
| Lists/selectors | Arrow keys move within a focused list; Return opens/chooses; selection and focus are distinct. |
| Quiz options | When the question owns focus, 1–4 choose options and a deliberate submit command checks the answer. Typing in the tutor or an editor never triggers option shortcuts. |
| Written answer/tutor | Return creates a newline in multiline input; ⌘Return submits only the focused composer or answer. |
| Feedback | Move focus or announce the result appropriately; Next cannot intercept Return inside another editor. Prevent held-key or repeated-click skipping. |
| Flashcards | Space reveals when review owns focus; 1–4 rate only after reveal. No key event carries through into the next card's rating. |
| Sheets/popovers | Escape dismisses the top presentation appropriately; restore focus to its trigger. Preserve drafts or explicitly handle unsaved edits. |
| Accessibility | Tab/Shift-Tab with macOS Keyboard Navigation enabled, plus a separate Full Keyboard Access/VoiceOver walkthrough. No global remapping of system preferences. |

Commands should share the same action implementation as pointer controls. Shortcuts appear in menus, tooltips, and a searchable help view rather than a long persistent instruction string.

## Screen-by-screen changes

| Screen | Proposed change |
| --- | --- |
| Window/sidebar | Compact brand and navigation; remove the persistent motivational goal card and personal-library footer. Keep a clear Settings control. Add collapsible navigation and a meaningful breadcrumb/toolbar rather than a repeated destination strip. |
| Today | Lead with Resume or the next useful review. Show topic and card due counts clearly, with units; keep the optional streak secondary. Use compact recent-course rows. Move detailed metrics to Progress. New course is secondary when an unfinished lesson exists. |
| Courses | One title and compact search/filter toolbar. Use consistent rows as the default for a personal library; title, next topic, and one progress summary. Replace the Archived switch with an appropriate filter. Remove marketing subtitles, decorative course icons, and external-link arrows for internal navigation. |
| Course detail | Title, a short summary, one progress measure, and the next action. Put outcomes behind an optional disclosure after the course has begun. Use uniform module/lesson rows with full actionable areas. Collapse completed modules where useful; keep them easy to revisit. |
| Welcome/new course | Simple topic-focused form. Keep model connection and repository choice understandable, with advanced configuration disclosed. Remove slogan-heavy headings. Use one consistent choice control for experience level and the diagnostic. Preserve back navigation and entered values. |
| Lesson reading | A document column with examples and restrained callouts. Keep prediction and worked examples intact. Place the step and course context in one toolbar. Remove generic motivational subtitles and boxed wrappers that add no meaning. |
| Quiz | Small progress text, readable Markdown question, code only once, answer controls, and a stable action area. Remove the question-type pill and repeated helper lines. Correctness feedback uses a small semantic accent and explanation, with dispute/hint/source actions available contextually. Keep explicit checkpoint and assistance information where it affects interpretation. |
| Tutor | One consistent optional inspector across lessons and notes. Border-light composer with a compact send/stop button, one context attachment, and focus feedback. Preserve drafts and scroll position; do not duplicate the selected passage above and inside the composer. Keep relevant answers and attached sources discoverable. |
| Notebook | Quiet list plus document. One Note/Flashcards tab row; a single Edit/Done action replaces the second segmented control. Put infrequent metadata and actions in the overflow. Show formatting tools during editing or selection. Keep the document title only once. |
| Markdown/code/diagrams | Consistent headings, inline-code baseline, code backgrounds, formula spacing, list indentation, and link styling. Horizontal scrolling for long code; selectable content; copy feedback. Diagrams inherit theme and offer expanded viewing and readable source fallback. Avoid decorative diagrams with no explanatory purpose. |
| Flashcards | Keep them beside notes. Compact deck list, clear due count, one Review action, and accessible editing. Review presents the prompt, reveal, and four rating actions with stable placement. Completion is brief; saved scheduling remains unchanged by visual work. |
| Review | Present topic reviews and flashcards with explicit units and consistent ordering. Avoid mixing them into an unexplained number. Show the next useful review and let the user choose the other mode. |
| Completion | Brief success state, what was completed, saved notes, and one next step. Show a newly earned milestone once, with details available in Progress. Avoid confetti or repeated congratulatory banners during ordinary navigation. |
| Progress | One activity visualization and compact summaries; separate activity from learning evidence. Reconcile lesson and flashcard counts. Milestones and streaks remain available without dominating study screens. |
| Settings | Match app theme. Use consistent form rows, category navigation, searchable model selection, contextual validation, and clear saved/error states. Move shortcut help into its own discoverable view. |

## Motion and layout stability

Use immediate or very short hover feedback, roughly 100–140 ms press feedback, and approximately 160–220 ms transitions for disclosures and panels. These are initial tuning values, not performance claims. Avoid entrance cascades, bouncing cards, and animation on routine list hovering. Keep reading position stable when feedback arrives; only scroll when the result would otherwise be offscreen. Respect Reduce Motion and avoid interpolating the whole theme.

Preserve view identity and state deliberately. The current route-wide `.id` replacement needs review because it can discard local search, focus, and scroll state. At narrow Mac window sizes, collapse navigation or present the inspector as an overlay instead of squeezing text between fixed-width panes. Test minimum supported size, normal laptop size, and a large window with default and largest reading sizes.

## Implementation order and release gate

1. **Interaction defects:** fix sidebar targets; audit all controls' whitespace; unify theme propagation; resolve submission/focus collisions. Validate before cosmetic changes obscure the evidence.
2. **Foundation:** semantic state tokens, typography, shared controls, accessible popovers, and command/focus infrastructure. Build the component gallery and compare all states in light/dark.
3. **Reference screens:** finish Today, one rich-code quiz with feedback and tutor, and a long note with formulas/diagrams/flashcards together. Check sparse and dense content before applying the layout broadly.
4. **Complete rollout:** courses, onboarding, review, completion, repositories, progress, and settings. Remove replaced components and redundant copy; preserve stored learning data and existing features.
5. **Review and fix:** run the actual journeys below, correct failures, then produce before/after evidence with the same content and window sizes for user review.

Acceptance requires observable results:

- Clicking the center, icon, text, and whitespace near every visible control edge invokes exactly the intended action. Outside bounds do not activate it. Test selected and unselected rows separately.
- Hover is visibly distinguishable in both themes; focus and selection remain separately recognizable. Check contrast on actual rendered backgrounds and Increased Contrast, not just palette values.
- Complete onboarding, find a course, answer each supported question format, open/close the tutor, finish a topic, edit a note, create/review a flashcard, and change settings with keyboard navigation. No accidental submission or focus traps.
- Check all eight question kinds with long Markdown, inline code, code blocks, and the largest reading size; verify answer selection, grading, ordering, and feedback behavior remain intact.
- Test menus at window edges, keyboard dismissal, screen-reader labels, focus restoration, and disabled actions. Test native text selection/copy/paste/undo still works in editors.
- Open Settings and every presentation in Light, Dark, and System modes; Markdown/code/diagrams must match. Repeat under Reduce Motion.
- Simulate slow generation, cancellation, error/retry, empty results, long titles, and large libraries. Drafts, scroll position, and control sizes remain stable.
- Reopen the app and verify course progress, notes, flashcard schedules, and drafts survive. Run relevant existing regression tests and targeted interaction tests.
- No screenshot-only sign-off: the redesign is ready when the controls and full workflows pass, and the final visual review finds a clear hierarchy without redundant chrome.

No new model/provider calls were needed for this audit. The personal library was not edited. UI inspection used the disposable test library after identifying the older personal process. The click and theme defects are confirmed; broad hover, keyboard, accessibility, and animation coverage remains work for implementation and verification.
