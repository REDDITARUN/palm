# ADR 0001: Native macOS app with local authoritative storage

Date: 2026-09-07
Status: Accepted

## Context

A personal learning app needs responsive editing, reliable offline access to saved work, and control over credentials.

## Decision

Use SwiftUI with focused AppKit/WKWebView bridges. Persist the library in SQLite through GRDB; store credentials in macOS Keychain. Keep cloud AI behind an explicit provider boundary.

## Alternatives considered

A web-first app and hosted database would simplify cross-device access but introduce accounts, hosting, and sync concerns.

## Consequences

The first release targets Apple silicon macOS 15+. There is no phone app or cloud sync. Local storage must never be described as entirely offline AI.
