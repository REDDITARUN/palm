# Third-party notices

The MIT license at the repository root covers original Plam code. It does not replace the licenses of dependencies or vendored files.

- Native Swift dependencies and their pinned source revisions are listed in [Package.resolved](Package.resolved). Bundled texts are in [Resources/ThirdParty](Sources/PlamCore/Resources/ThirdParty).
- The BlockNote editor packages are **MPL-2.0**. Unmodified corresponding source is available from the exact versions in [Editor/package-lock.json](Editor/package-lock.json), the package version pages listed in the [editor notice](Sources/PlamCore/Resources/Editor/Licenses/NOTICE.txt), and [BlockNote upstream](https://github.com/TypeCellOS/BlockNote). Plam's integration source is published in `Editor/src`. No BlockNote XL AI component is included.
- The editor's production dependency notices and license texts, including React, Mermaid, KaTeX, and Lucide, are bundled in [Editor/Licenses](Sources/PlamCore/Resources/Editor/Licenses). KaTeX fonts and other packaged assets retain their applicable notices.
- A separate Mermaid renderer and its license are in [Resources/Diagrams](Sources/PlamCore/Resources/Diagrams).
- CodeEditSymbols is replaced by an original empty compatibility module for an unused import. No upstream artwork is shipped; see [the compatibility record](Vendor/CodeEditSymbols/PLAM_PATCH.md).
- Optional OpenCode, uv, Serena, Mem0, Qdrant, FastEmbed, language servers, and embedding weights are downloaded at runtime rather than bundled in the release. Their own licenses and model terms apply. Version pins are visible in `Sources/PlamCore/Resources/setup-runtime.sh`.

Regenerate dependency notices when updating a dependency. Preserve complete applicable license texts when redistributing the app. AI provider services and model weights have separate terms from the app's source-code license.
