# Palm 1.0.3 verification

2026-09-12

## Changes

Long-running AI work uses streaming completions, extended network-silence limits, and an OpenCode process without a total-duration cutoff. Work status shows elapsed time and observed stages. A course can finish while its creation sheet is closed.

Repository paths open a searchable, read-only source snapshot. File/line references and inline directory paths are supported; code clicks retain the AST selection and tutor handoff. Removing a repository does not break a lesson's saved snapshot reference.

Written-answer and tutor inputs include local Parakeet dictation with a focused-input shortcut, ⌘⇧D. First use offers the model download. Audio is temporary, transcripts remain editable, and dictation never submits an answer.

Sparkle adds manual and optional automatic update checks. Signed GitHub release DMGs are verified before installation. The existing bundle ID, Keychain service, support-folder resolution, and data schema are preserved. A version change creates a SQLite recovery copy before migration.

## Verified

- 97 Swift tests: 91 passed, six cloud-provider opt-in tests skipped. This run includes actual OpenCode against a local compatible-provider fixture and actual Parakeet transcription of a generated spoken fixture.
- Streaming response assembly and interrupted-stream rejection; configured long request timeout and cancellable processes.
- Path and line parsing, relative link round trips, symlink containment, missing files, and directory links without interpreting fenced code.
- Existing-library reopen, note/card preservation, pre-upgrade SQLite backup, and independent recovery-copy loading.
- Native app: clicked a generated source path, verified the complete file and referenced-line highlight, and handed the selected code to the tutor. Inspected microphone controls and the Updates settings layout in an isolated library.
- Release build includes Sparkle's complete framework/helpers, explicit update feed/public key, microphone permission description, and matching release/build versions. The build script rejects missing update metadata.
- Signed-archive verification succeeds; a modified archive is rejected. The appcast points to the versioned GitHub release asset and records its exact size and signature.
- Public-file audit and Git whitespace checks.

## Not verified

The Mac locked before the final native Sparkle download/install/relaunch test could be completed. A disposable older test app and local signed test feed were prepared. Microphone hardware capture and its macOS consent prompt were not exercised; recognition itself passed using an audio fixture. Production cloud-provider limits and long live reasoning requests were not retested.

Community builds remain ad-hoc signed and unnotarized. Sparkle update signing does not constitute Apple notarization. Users upgrading from 1.0.2 need to install the new DMG once to obtain the updater.
