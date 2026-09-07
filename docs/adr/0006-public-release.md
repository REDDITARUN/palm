# ADR 0006: Source release, Mac disk image, and static GitHub Pages site

Date: 2026-09-07
Status: Accepted

## Context

People need a straightforward way to understand, download, install, and contribute to Palm without a hosted app service.

## Decision

Publish original source under MIT in REDDITARUN/palm, retain dependency licenses, distribute an Apple silicon Release app in a drag-to-Applications DMG, and host a dependency-free website from a gh-pages branch. Keep source and release artifacts separate.

## Alternatives considered

An App Store release adds distribution requirements; a cloud app changes privacy and operating costs. Checking binaries into Git bloats history.

## Consequences

The initial build is ad-hoc signed and not notarized because no Developer ID distribution identity is available. Document per-app macOS approval clearly. Audit source/assets for personal data, publish checksums, and use normal pushes preserving remote history.
