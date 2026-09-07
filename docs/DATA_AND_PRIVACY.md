# Data, privacy, and backups

The normal library is `~/Library/Application Support/Palm/`:

| Location | Purpose |
| --- | --- |
| `plam.sqlite` | Courses, sessions, answers, drafts, notes/revisions, conversations, reviews, observations, jobs |
| `Snapshots/` | Saved copies of imported source files |
| `Runtime/` | Downloaded optional local tools |
| `MemoryIndex/` | Rebuildable vector index and local embedding cache |
| `AgentData/`, `Serena/` | Local agent working state |
| macOS Keychain | Model API keys, GitHub token, and other tool credentials |

The app has no Palm account, hosted library, built-in cloud sync, or analytics service. Cloud AI is different from cloud storage: selected learning context is sent to the model provider you choose. Provider logging, training, retention, pricing, and limits apply. External tools and MCP services may also have their own network behavior and policies.

Inkling's free research endpoint logs prompts/outputs for model improvement and prohibits confidential/personal information. Use suitable content or another provider. Repository source filters are not a full secret scanner.

Saved notes and lessons can be read offline, as can local choice/ordering practice. New generations, tutoring, and grading written answers require the configured model. The first local memory/tool setup needs internet downloads.

## Back up and restore

Use **Settings → Data → Back up library**. Keep the complete `.palmbackup` folder: it contains records, note revisions, and referenced source snapshots. Credentials, runtime executables, and derived indexes are excluded.

Restore validates records/snapshots, preserves a previous SQLite backup, relocates source references, and rebuilds derived memory indexes. JSON import/export contains records only and is not equivalent to a full backup. Restoring an old backup can restore memories that were later forgotten.

## Remove data

Delete the application only to remove the executable; this preserves the library. To remove the library, quit Palm and delete its Application Support directory. Use Keychain Access to remove Palm credentials separately. Back up anything you wish to retain first.

## Name compatibility

Version 1.0.1 corrects the app name to Palm. Fresh installs use the Palm support folder; existing installations keep their Plam folder and source paths. The SQLite filename, bundle identifier, Keychain service, reminder identifier, and derived memory namespace remain stable internal identifiers. No credentials, library records, or source snapshots are reset.
