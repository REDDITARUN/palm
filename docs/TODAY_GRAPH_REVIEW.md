# Today, early growth, and graph interaction

Implemented and reviewed September 7, 2026.

## Today

Today presents a single suggested next step and every active course. Unfinished sessions come first, then due practice, then a prerequisite-ready lesson. New learning gives less recently practiced courses a chance to surface. Every course has its own resume/start action and shortcuts to its due topics and cards. Personal-note flashcards remain available separately. Archived courses and orphan topic reviews are excluded from the plan.

The daily intention uses recorded lesson-time buckets, including time in a session started on an earlier day. The seven-day strip uses actual answers and card reviews. Answer and completed-topic counts appear after activity; repeated completion of the same topic does not inflate the daily count. These are activity measures, not a claimed mastery score.

Reminders are opt-in through Today or General settings. The user chooses a local time. Plam schedules one repeating, silent local notification with a stable identifier, replaces it when the time changes, and removes it when disabled. Clicking the notification routes to Today. macOS notification permission is requested only when the user saves an enabled reminder. Focus and system notification settings still govern delivery. Test profiles save preferences without requesting notification permission or scheduling a notification.

[Apple's local notification documentation](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app) informed the calendar trigger and replace/cancel behavior. This is a notification feature of Plam, not an external scheduler or cloud service.

## Tree

Zero days shows a seed. One or two practice days produce a sprout; three through six produce a seedling with individual leaves. A crown starts after the first week and broadens with further practice. Bright leaves remain selectable day markers. Total practice grows the plant; the current streak is shown separately and breaks do not erase earned growth.

## Knowledge map

[Obsidian's graph documentation](https://obsidian.md/help/plugins/graph) informed starting with the current note's local neighborhood, adjustable depth, explicit focus, and whole-map exploration.

A single native canvas handles pointer navigation and drawing. Pan, zoom, and hover no longer rebuild the SwiftUI inspector. Hit testing prioritizes nearby dots and uses actual label bounds, replacing overlapping 145 × 70 invisible buttons. Background dragging retains the selection, node dragging rearranges one node, pinch/wheel zoom anchors at the pointer, and keyboard arrows/minus/plus/zero navigate the camera. Nodes also expose accessibility press actions.

The inspector provides a saved-note preview, incoming/outgoing links, course ownership, and related notes with shared tags. Shared-tag suggestions are explicitly separate from saved links. Search reaches beyond the current local neighborhood, retains immediate graph context, and debounces rendering. Open-note and open-course actions route to their saved records. The graph remains bounded to 300 matching nodes; course/type/search filters can reveal other parts of a larger library. Layout runs away from the main actor; parsed editor links are extracted once per note during indexing.

## Verification

- Final automated suite: 71 tests, 65 passed, 6 optional live-model tests skipped, no failures.
- New tests cover more than four courses, archived-course exclusion, prerequisite selection, resume/review ordering, orphan reviews, daily time buckets, unique completed topics, personal/course card ownership, cursor-anchored zoom with scale limits, and preference backward compatibility.
- Native production and test builds succeeded; installed bundle passed code-sign verification.
- Native UI checks: multiple-course Today, resume into the expected saved session, course-specific review, reminder enable/save/relaunch persistence in a disposable profile, two-day sprout and leaf selection, graph pan preserving selection, independent node dragging, keyboard zoom, accessible node selection, local/whole graph, cross-course search, and opening the selected saved note. Graph contrast checked in light and dark appearances.
- Actual scheduled notification delivery and the system permission dialog were not triggered during testing. These remain dependent on the user's opt-in and macOS settings.
- Updated the installed app at `$HOME/Applications/Plam.app`, backed up the prior bundle and personal database, launched with the personal library, and left Today open. Decoded state, documents, conversations, and note revisions matched the pre-install backup.
