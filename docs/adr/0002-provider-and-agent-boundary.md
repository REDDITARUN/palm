# ADR 0002: Compatible model APIs with a real local agent harness

Date: 2026-09-07
Status: Accepted

## Context

Users should choose free or paid models while repository exploration needs controlled tools. Some free models require an agentic harness.

## Decision

Use OpenAI-compatible requests where supported and the actual OpenCode learning harness for Inkling free. Generate with source context from immutable snapshots; Serena supplies optional language-server exploration. Keep repository agent tools read-only and custom MCP configuration explicit.

## Alternatives considered

One hosted agent backend would reduce local installation work but centralize private code and create an operating cost. A spoofed harness header would not provide the required agent behavior.

## Consequences

First use may download local tools. Providers can change availability and terms. Never silently fall back to a paid model. Generated artifacts are validated, and untrusted source text is not an instruction channel.
