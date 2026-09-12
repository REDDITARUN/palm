# Data, privacy, and backups

The normal library is `~/Library/Application Support/Palm/`:

| Location | Purpose |
| --- | --- |
| `plam.sqlite` | Courses, sessions, answers, drafts, notes/revisions, conversations, reviews, observations, jobs |
| `Snapshots/` | Saved copies of imported source files |
| `Runtime/` | Downloaded optional local tools |
| `MemoryIndex/` | Rebuildable vector index and local embedding cache |
| `APIKeyAgentData/`, `Serena/` | Local agent working state |
| `ChatGPTAgentData/`, `ChatGPTAgentConfig/` | Owner-only OpenCode subscription state, including its OAuth credential cache |
| macOS Keychain | Model API keys, GitHub token, and other tool credentials |

The app has no Palm account, hosted library, built-in cloud sync, or analytics service. Cloud AI is different from cloud storage: selected learning context is sent to the model provider you choose. Provider logging, training, retention, pricing, and limits apply. External tools and MCP services may also have their own network behavior and policies.

Inkling's free research endpoint logs prompts/outputs for model improvement and prohibits confidential/personal information. Use suitable content or another provider. Repository source filters are not a full secret scanner.

Saved notes and lessons can be read offline, as can local choice/ordering practice. New generations, tutoring, and grading written answers require the configured model. The first local memory/tool setup needs internet downloads.

## Back up and restore

Use **Settings → Data → Back up library**. Keep the complete `.palmbackup` folder: it contains records, note revisions, and referenced source snapshots. Credentials, runtime executables, and derived indexes are excluded.

Restore validates records/snapshots, preserves a previous SQLite backup, relocates source references, and rebuilds derived memory indexes. JSON import/export contains records only and is not equivalent to a full backup. Restoring an old backup can restore memories that were later forgotten.

## Remove data

In **Settings → Model**, choose a saved API connection and **Forget API key** to remove its credential. ChatGPT connections have **Sign out**, which clears Palm's subscription authentication without signing other apps out. OpenCode manages the OAuth cache in Palm's protected support directory; API keys remain in Keychain. Neither is included in library backups or JSON exports.

Use **Course actions → Delete course** to remove a course and its practice history. Notes, revision history, and flashcards are kept independently. In **Repositories**, **Remove…** forgets the imported repository and unlinks related courses. The original folder is untouched; snapshots cited by existing lessons remain available.

Delete the application only to remove the executable; this preserves the library. To remove the library, quit Palm and delete its Application Support directory. Use Keychain Access to remove Palm credentials separately. Back up anything you wish to retain first.

## Name compatibility

Version 1.0.1 corrects the app name to Palm. Fresh installs use the Palm support folder; existing installations keep their Plam folder and source paths. The SQLite filename, bundle identifier, Keychain service, reminder identifier, and derived memory namespace remain stable internal identifiers. No credentials, library records, or source snapshots are reset.

## Voice and updates

Parakeet dictation runs locally after the model download. Temporary recordings are deleted after transcription or cancellation, and are never added to the library or sent to an ASR server. Draft transcripts follow the normal AI-provider boundary only when you submit them. Downloaded weights live under `~/Library/Caches/app.plam.learning/Parakeet` and can be removed while Palm is closed to reclaim space.

Sparkle checks the public GitHub Pages appcast and downloads signed GitHub release assets. Checks do not upload your courses or library; the hosting services still see ordinary network metadata. Automatic checks are opt-in. Update signing is separate from Apple notarization.

`UpgradeBackups/` holds SQLite recovery copies taken before the first launch of a new app version. These copies contain historical learning records and deleted items may remain in them. They do not include source-file snapshots and do not replace a full `.palmbackup`. You can remove older recovery copies manually after confirming your library is intact.
