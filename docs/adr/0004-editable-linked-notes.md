# ADR 0004: Bundled block editor with note identity and revisions

Date: 2026-09-07
Status: Accepted

## Context

Learners need code, math, diagrams, highlights, and conversational editing in a single note surface.

## Decision

Bundle BlockNote in WKWebView and publish its integration source. Send note IDs and revisions across the bridge so delayed events stay attached to the original document. Keep Markdown export, native revision storage, explicit links, and flashcards.

## Alternatives considered

A plain native text editor has fewer dependencies but does not provide the required structured editing. A hosted editor would weaken offline access and local data control.

## Consequences

The generated editor artifact and third-party notices are part of the app. BlockNote dependencies retain MPL-2.0. Changes to editor source require rebuild and regression checks for rapid note switching.
