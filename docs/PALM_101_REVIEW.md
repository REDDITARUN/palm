# Palm 1.0.1 review

> Historical review: the temporary download pause ended after the reporter clarified the standard macOS verification warning. This installer remains unnotarized. See [current release status](RELEASING.md).

Reviewed September 7, 2026.

- 67 native offline tests passed, including opening an existing library through the renamed app's directory resolver; 6 opt-in live-provider tests skipped.
- Editor TypeScript check, 3 tests, and production build passed. Offline Shiki highlighting preserves source text and produces distinct light/dark syntax colors.
- Native practice review verified lettered choices, selection, enabled submission, and correct-answer state. Code remains selectable with syntax-aware context actions.
- Native notebook review verified editable content, generated flow diagrams, highlights, inline code, and syntax-highlighted code blocks. Browser review checked light/dark content surfaces; the native host supplies the background behind the transparent editor.
- The release app compiled and passed strict ad-hoc signature verification. The disk image passed its integrity/checksum checks. Public-source audit reported no matching private artifacts, credentials, or personal absolute paths.

The rename preserves internal storage/security identifiers needed by existing installations. Fresh libraries use the Palm folder. See [ADR 0007](adr/0007-palm-brand-and-reading-surfaces.md).

The build is still Apple silicon/macOS 15+ and not notarized. No live model calls were needed for these renderer changes. Existing saved content receives the updated styling automatically.
