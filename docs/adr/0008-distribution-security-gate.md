# ADR 0008: Pause installers and require verified distribution

Date: 2026-09-07
Status: Accepted; amends ADR 0006

## Context

A user reports that macOS says Palm will damage the computer. This differs from an unidentified-developer alert. Local checks found a valid ad-hoc signature and a missing notarization ticket, but did not reproduce a malware-specific finding. The cause of the reported warning remains unresolved. Only a free Apple developer account is available.

## Decision

Keep existing release assets in GitHub drafts and point the website at an explicit download pause notice. Remove generic security-bypass instructions. Continue reviewed source updates and isolated local testing. Default packaging must require Developer ID Application signing, hardened runtime, a stapled notarization ticket, and local Gatekeeper acceptance. Local-only images require an explicit flag and carry LOCAL-TEST in their names.

## Consequences

Restoring downloads requires investigating the original alert and testing the final downloaded artifact on another Mac with normal protections enabled. Apple notarization cannot be completed with the available free-account credentials. Passing integrity checks or rebuilding does not establish that the original alert was a false positive. No Gatekeeper settings are changed.

See [release procedure](../RELEASING.md) and [Apple’s warning definitions](https://support.apple.com/en-us/102445).
