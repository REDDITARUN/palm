# ADR 0007: Palm name and shared learning surfaces

Date: 2026-09-07
Status: Accepted

## Context

The public website established a softer visual language for code, flow diagrams, highlights, and answers. These should appear in actual generated content. The intended product name is Palm.

## Decision

Rename public branding, source modules, and distribution artifacts to Palm. Keep the existing bundle/Keychain identifiers, database filename, notification identifier, and derived memory namespace. Reuse a legacy library in place so absolute snapshot and runtime paths remain valid; fresh libraries use the Palm folder.

Style the content renderers rather than relying on model-generated decoration. Native Markdown and editable notes share a Mermaid theme. Native code, notebook code, inline code, highlights, and answer cards use matching light/dark sage colors. Notebook syntax highlighting uses bundled Shiki grammars with a JavaScript regex engine and requires no network calls. Models supply semantic diagram structure without styling directives.

## Consequences

Existing notes pick up the new appearance without regeneration or content migration. Unsupported code languages remain readable as plain code. The old internal spelling remains only where compatibility requires it. Release 1.0.1 has a new installer name; 1.0.0 remains available in release history.
