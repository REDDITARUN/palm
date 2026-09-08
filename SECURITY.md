# Security and privacy

Palm keeps its library on your Mac and stores provider credentials in macOS Keychain. Selected learning context, including relevant code and notes, is sent to your chosen model provider. Provider retention and training policies vary. Inkling's free endpoint logs prompts and outputs for model improvement and prohibits confidential/personal data; choose an appropriate provider for private material.

Repository imports exclude common secret filenames and build folders, but this is not a comprehensive secret scanner. Inspect what you import. Custom MCP tools run with the access granted by their configuration; install tools you trust.

For a vulnerability, use [GitHub private vulnerability reporting](https://github.com/REDDITARUN/palm/security/advisories/new) if enabled. Do not put exploit credentials, personal databases, or private source code in a public issue. Report the affected version, impact, and a minimal reproduction with synthetic data.

The downloadable community builds are ad-hoc signed and not Apple-notarized. macOS may say Apple could not verify Palm. This wording does not report a malware detection. The earlier report of a “will damage your computer” warning was corrected by the reporter; the precautionary download pause has ended. Signature integrity and download checksums passed, but neither establishes that software is safe.

Only use [the first-open instructions](docs/GETTING_STARTED.md) for the verification warning and a copy you trust. Do not override an actual “will damage your computer” or malware-detection alert. When reporting an alert, include the exact screenshot, macOS version, Palm version, and download URL. Keep private data and credentials out of reports.
