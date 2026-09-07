# Progress, notebook, and knowledge map redesign

Updated September 7, 2026.

## Design decisions and sources

Progress now puts the learning tree and milestones first. Review actions remain on the dedicated Review page. Three factual measures replace a broad mastery score: completed topics, correct independent answers, and earned achievements. Course details expand by clicking the whole row.

- [Duolingo's achievement redesign](https://blog.duolingo.com/achievement-badges/) and [streak milestone design](https://blog.duolingo.com/streak-milestone-design-animation/) informed visible collectible awards, explicit earning criteria, and shareable cards. These are product design references, not evidence that collecting badges itself causes learning.
- [Notion's database views and filters](https://www.notion.com/help/views-filters-and-sorts) informed persistent course, tag, and pinned filters, searchable course choices, and lightweight sorting.
- [Linear's latest design refresh](https://linear.app/now/behind-the-latest-design-refresh) and [earlier UI redesign](https://linear.app/now/how-we-redesigned-the-linear-ui) informed quieter navigation, consistent placement of controls, and separation through spacing and surface tone.
- [Obsidian's graph documentation](https://obsidian.md/help/plugins/graph) informed direct node selection, connection highlighting, pan/zoom, local neighborhoods, and filters.
- [Apple's motion guidance](https://developer.apple.com/design/human-interface-guidelines/motion) and [Airbnb's motion engineering](https://medium.com/airbnb-engineering/motion-engineering-at-scale-5ffabfc878) informed stable element identity and motion confined to the changing component. [Airbnb's visual language](https://medium.com/airbnb-design/building-a-visual-language-behind-the-scenes-of-our-airbnb-design-system-224748775e4e) informed reusable controls rather than isolated screen styling.

## Learning tree and achievements

A leaf represents a day with recorded question answers or flashcard reviews. Breaks do not erase the tree. The current consecutive-day streak remains a separate label; the seven-day achievement uses the historical longest streak. Dates after the current clock are excluded from tree growth and award calculations. The canopy shows the latest 56 practice days; the full count and activity history remain available.

Eight achievements use recorded learning evidence. Repeated completion of the same topic counts once toward topic milestones. Hinted or revealed answers do not earn independent-answer awards. A delayed-recall achievement requires a review at least 24 hours after a prior completion. A course achievement requires completion records for all its topics.

Any achievement card opens its criteria. Earned awards can be featured on the Progress showcase, up to three. Progress and achievement cards can be copied or saved as a 1040 × 1180 PNG. This exports locally; it does not post to a social service.

## Notebook and map

Notes show a consistent colored course label in both the list and document header. Course, tag, pinned, text search, and sorting compose. Personal notes have their own filter. The note editor keeps its identity as selection changes; the toolbar and tutor are not recreated for every document. At narrow widths the tutor overlays the document instead of removing notebook navigation.

The graph uses deterministic spring layout and real saved relationships: course ownership, explicit note links, and learning memories. Color matches course identity. It supports search with neighboring context, type/course filters, focus at one or two connection steps, node dragging, background dragging, trackpad navigation, zoom controls, fit, and keyboard pan/zoom. Selecting a node opens a readable inspector; notes and courses can be opened directly. Graph layout is calculated away from the main actor; the index is cached so hovering does not rebuild the entire note-link index.

The graph renders at most 300 matching nodes at once. Filtering reveals other parts of a larger library. Dragged positions last while the map is open. This is a graph of saved relationships, not an invented semantic mastery map.

## Motion and surfaces

Permanent input outlines are replaced by soft fills and focused feedback. Tab selection moves a local indicator and honors Reduce Motion. Main route changes do not animate the entire workspace. Lesson transitions are scoped to lesson content. Existing hover states and full content hit areas are retained.

## Validation

The automated suite includes new checks for permanent streak achievements, future dates, duplicate topic completions, composed notebook filters, bounded graph neighborhoods, and deterministic finite graph layouts. Native UI checks and any remaining limitations are recorded in the implementation review after the final build.
