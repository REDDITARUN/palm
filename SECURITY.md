# Security and privacy

Palm keeps its library on your Mac and stores provider credentials in macOS Keychain. Selected learning context, including relevant code and notes, is sent to your chosen model provider. Provider retention and training policies vary. Inkling's free endpoint logs prompts and outputs for model improvement and prohibits confidential/personal data; choose an appropriate provider for private material.

Repository imports exclude common secret filenames and build folders, but this is not a comprehensive secret scanner. Inspect what you import. Custom MCP tools run with the access granted by their configuration; install tools you trust.

For a vulnerability, use [GitHub private vulnerability reporting](https://github.com/REDDITARUN/palm/security/advisories/new) if enabled. Do not put exploit credentials, personal databases, or private source code in a public issue. Report the affected version, impact, and a minimal reproduction with synthetic data.

The initial downloadable macOS build is ad-hoc signed, not Developer ID signed or notarized. Download only from this repository's releases and compare its SHA-256 checksum. Instructions use macOS's per-app approval flow; they never disable Gatekeeper globally.
