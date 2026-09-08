# ADR 0008: Distribution checks and macOS warning handling

Date: 2026-09-07
Status: Amended after the reporter clarified the warning; amends ADR 0006

## Context

A user reports that macOS says Palm will damage the computer. This differs from an unidentified-developer alert. Local checks found a valid ad-hoc signature and a missing notarization ticket, but did not reproduce a malware-specific finding. The cause of the reported warning remains unresolved. Only a free Apple developer account is available.

## Decision

Keep existing release assets in GitHub drafts and point the website at an explicit download pause notice. Remove generic security-bypass instructions. Continue reviewed source updates and isolated local testing. Default packaging must require Developer ID Application signing, hardened runtime, a stapled notarization ticket, and local Gatekeeper acceptance. Local-only images require an explicit flag and carry LOCAL-TEST in their names.

## Consequences

Restoring downloads requires investigating the original alert and testing the final downloaded artifact on another Mac with normal protections enabled. Apple notarization cannot be completed with the available free-account credentials. Passing integrity checks or rebuilding does not establish that the original alert was a false positive. No Gatekeeper settings are changed.

See [release procedure](../RELEASING.md) and [Apple’s warning definitions](https://support.apple.com/en-us/102445).

## Correction after clarification

The reporter clarified that Palm installs successfully and macOS says Apple could not verify Palm is free of malware when opening it. This is the standard verification warning for this unnotarized build; the earlier wording was incorrect. No actual malware-detection report remains established by this exchange. The downloaded disk image mounts and copies successfully and the copied app passes signature-integrity checks. Gatekeeper still rejects the ad-hoc, unnotarized app.

Restore the previously published community releases unchanged, explicitly label them unnotarized, and document Apple's per-app approval flow only for a trusted copy with the verification warning. This does not claim Apple verification or guarantee safety. Retain the default verified-distribution packaging gate for future releases and the local-only flag for development images. Never automate changes to Gatekeeper settings. The previous pause requirements above record the response to the original, subsequently corrected report.

## Explicit community update packaging — 2026-09-08

The user continues to request app updates and publication with the free Apple account. Add an explicit `--community` packaging mode for honestly labeled unnotarized releases. It checks bundle integrity and includes the correct per-app first-open guidance. Default packaging still fails closed on missing Developer ID or notarization; local-only packages remain non-distributable. No existing release asset is replaced, no Apple verification is claimed, and no system protection is disabled.
