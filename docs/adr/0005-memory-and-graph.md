# ADR 0005: Rebuildable memory index and a graph of saved relationships

Date: 2026-09-07
Status: Accepted

## Context

Tutoring benefits from past questions and notes, but inferred weaknesses and opaque semantic graphs can mislead learners.

## Decision

Keep learner observations editable in SQLite. Use Mem0/local Qdrant with local embeddings as a derived index. Build graph edges from explicit note links, course membership, and saved evidence; label shared-tag suggestions separately. Render camera/pointer interaction in a native canvas.

## Alternatives considered

A vector database as the only record would make backup, correction, and deletion harder to reason about. Automatically inferred graph edges would appear more complete but conceal uncertainty.

## Consequences

Index rebuilding must not destroy authoritative records. A forgotten memory can return after restoring an old backup. Graph views are capped at 300 matching nodes and filters reveal further context. Layout is calculated off the main actor.
