# Public release review — 1.0.0

> Historical review: the temporary download pause ended after the reporter clarified the standard macOS verification warning. This installer remains unnotarized. See [current release status](RELEASING.md).

Reviewed September 7, 2026 on an Apple silicon Mac.

## Verified

- Native offline suite: 65 passed, 6 opt-in live-provider tests skipped, no failures.
- Embedded editor: TypeScript check, 2 tests, and production bundle succeeded.
- Native Release build compiled with the original local symbol compatibility module; no unlicensed upstream symbol artwork is included.
- Final app passed strict ad-hoc signature verification. The packaged disk image passed its integrity check and SHA-256 verification.
- Packaged app launched from the mounted disk image into onboarding using a disposable library. Provider selection, model instructions, and optional setup were reviewed.
- Runtime installation succeeded with a minimal system PATH: pinned uv, OpenCode, Python, Serena, and memory dependencies. Version/import/Serena help checks passed.
- Website reviewed at desktop and mobile widths. Practice feedback, keyboard-operated preview tabs, tree stages, and installation help worked without browser errors or horizontal overflow.
- Public-file audit found no matching credentials, personal absolute paths, or private runtime/library artifacts. The final app payload contained no development home-directory paths or library database.

## Limits

This build is Apple silicon only, requires macOS 15+, and is not Developer ID signed or notarized. The local launch check does not reproduce Gatekeeper quarantine on another Mac.

Live model calls were not repeated for this packaging review. Provider availability, free-model limits, and output quality can change. The automated public-file audit checks specific patterns; it is not a guarantee that arbitrary imported repository content is safe to send to a provider.

See [releasing](RELEASING.md) for the repeatable build and publishing process.
