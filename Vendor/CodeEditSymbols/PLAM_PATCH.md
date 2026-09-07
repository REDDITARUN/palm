# Original compatibility module

This is not a copy of upstream CodeEditSymbols. It is an original, empty compatibility module under Plam's MIT license.

The pinned CodeEditSourceEditor imports `CodeEditSymbols` in `FindPanelView.swift` without using any of its symbols. The root package's local dependency satisfies that module import. No upstream source, custom symbol assets, or documentation is included here.

When updating CodeEditSourceEditor, check whether it begins using this dependency's API. Implement only what is needed with original code and permitted system APIs, or use a clearly licensed replacement. Do not restore the old asset catalogue without establishing redistribution rights.
