# ADR 0009: Saved provider connections and ChatGPT authentication

Date: 2026-09-08
Status: Accepted

## Context

Editing a provider used to mutate active preferences immediately, reset custom model IDs, and reload a different Keychain account while the endpoint was being typed. Users also need more than one provider and a separate route for ChatGPT subscription access.

## Decision

Persist named `ProviderConnection` values and an active connection ID in the library. Forms edit drafts; Save persists a connection and Save & use activates it. A model catalogue is optional discovery, never a whitelist for saving custom IDs. Task-specific model profiles can reference a saved connection and inherit its authentication. New credentials use connection- and endpoint-specific Keychain accounts. Legacy connections retain their existing account; changing an endpoint detaches that credential. Forget API key deletes the Keychain entry and clears the active cached key.

Use OpenCode v1.18.21's documented provider OAuth API for ChatGPT: discover browser authentication, authorize, open the official OpenAI authorization URL, wait for callback, and reload the connected model catalogue. OpenCode owns PKCE, token refresh, and subscription model eligibility. Palm does not exchange subscription tokens against the general OpenAI API. ChatGPT generations and repository research use the OpenCode OpenAI provider, with no API-billing fallback. OpenCode’s background `small_model` is pinned to the same selected model, so housekeeping cannot quietly choose a paid model. Sign-out deletes only Palm's OpenCode OpenAI authentication.

OAuth is isolated from API-key runs in `ChatGPTAgentData` and `ChatGPTAgentConfig`. These directories have owner-only permissions. OpenCode manages its OAuth credential file inside that directory; Palm never reads or displays the tokens. These files are excluded from library backups and exports. API-key runs use separate state and explicit credentials. Child processes inherit only an allowlist of environment variables, not shell provider keys or arbitrary OpenCode configuration. Repository permissions remain read-only; untrusted project configuration is disabled. Learning generation denies all tools.

Deleting a course removes its sessions, reviews, course memories, and lesson conversations. Notes, revision history, and flashcards remain; course/session links are cleared. Removing a repository unlinks courses and removes saved exploration summaries, without touching original files. Saved source snapshots remain available to existing lessons. Both actions require a named confirmation and commit the new library before updating UI state.

## Consequences and validation

ChatGPT access is subject to account eligibility and provider limits. A real user must complete browser sign-in; an unsigned-in protocol test cannot establish subscription entitlement. Offline tests cover migration, independent credentials, endpoint changes, custom models, role routing, no API-key fallback, and deletion persistence. An opt-in test exercises authentication discovery, authorization, cancellation, and sign-out against the pinned OpenCode binary without opening a browser or accessing an account.

## Sources

- [OpenCode provider setup](https://opencode.ai/docs/providers/)
- [OpenCode server API](https://opencode.ai/docs/server/)
- [Pinned OpenCode OpenAI authentication implementation](https://github.com/anomalyco/opencode/blob/v1.18.21/packages/opencode/src/plugin/openai/codex.ts)
- [OpenAI Codex authentication](https://developers.openai.com/codex/auth/)
