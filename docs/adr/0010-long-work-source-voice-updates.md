# ADR 0010 — Long-running work, saved source, local dictation, and app updates

Accepted: 2026-09-12

## Context

Repository exploration can exceed a short HTTP request. Learners need to inspect the exact source used in a lesson, dictate written answers, and update Palm without rebuilding or losing their library.

## Decisions

- OpenCode generation has no total process timeout. Direct completions stream, with a 30-minute network-silence limit and a 24-hour resource ceiling. OpenCode provider header/chunk waits use 30 minutes without a total provider timeout. Short utility commands retain bounded limits. Cancellation remains available; provider-side rate limits or disconnects remain visible failures. Status shows elapsed time and observed work stages rather than invented percentages. Repository monitoring distinguishes working and retrying.
- Source references route to a read-only snapshot browser, including `path:line` and `path#Lstart-Lend`. The saved session snapshot takes precedence over a current repository, including after its removal. Paths are normalized and checked against the snapshot after resolving symlinks. No student code executes. Missing/binary/large files produce an explicit error; saved excerpts remain available.
- FluidAudio 0.15.7 runs Parakeet v3 locally. The first microphone action offers a model download. AVFoundation records a temporary mono WAV only after microphone consent. Stop transcribes; cancel/navigation invalidates late results. Transcripts append to the current draft without submitting it. Audio is removed after use. Weights live in Caches, separately from authoritative learning data; no external ASR service receives audio.
- Sparkle 2.9.6 installs Ed25519-signed GitHub release DMGs using an HTTPS appcast on GitHub Pages. The signing private key stays in the release maintainer's Keychain; only its public key is committed. Automatic checks are opt-in; installation is user initiated. The app bundle ID and Keychain service remain `app.plam.learning`, and existing `Plam/plam.sqlite` libraries remain in place.
- Before a new app version migrates an existing database, create a SQLite-consistent backup in the library's `UpgradeBackups` directory. The version stamp is per library. This release changes no study-data schema. Cached weights and the updater have no role in progress storage.

## Consequences

The first upgrade from 1.0.2 requires a manual DMG installation to gain Sparkle. Later versions can update in the app. Sparkle signatures authenticate Palm's release assets; they do not provide Apple notarization. Community builds remain clearly labeled unnotarized. Forks must change the feed URL and generate their own signing key.

Voice setup needs network and disk space once; recognition then runs offline. Parakeet is multilingual but is not a guarantee of perfect transcription, especially for technical identifiers. Users can edit the transcript before sending it.
