# Security and privacy

Palm keeps its library on your Mac and stores provider credentials in macOS Keychain. Selected learning context, including relevant code and notes, is sent to your chosen model provider. Provider retention and training policies vary. Inkling's free endpoint logs prompts and outputs for model improvement and prohibits confidential/personal data; choose an appropriate provider for private material.

Repository imports exclude common secret filenames and build folders, but this is not a comprehensive secret scanner. Inspect what you import. Custom MCP tools run with the access granted by their configuration; install tools you trust.

For a vulnerability, use [GitHub private vulnerability reporting](https://github.com/REDDITARUN/palm/security/advisories/new) if enabled. Do not put exploit credentials, personal databases, or private source code in a public issue. Report the affected version, impact, and a minimal reproduction with synthetic data.

Public installers are paused following a reported “Palm will damage your computer” alert. Do not bypass that warning. Local checks found an ad-hoc signature and missing notarization ticket, but have not reproduced the reported malware detection; its cause is unresolved. Checksums and signature integrity alone do not establish that an app is safe.

When reporting an installation alert, include its exact wording or screenshot, macOS version, Palm version, and download URL. Keep private data and credentials out of reports. Public installers must pass the checks in [the release guide](docs/RELEASING.md) before downloads resume.
