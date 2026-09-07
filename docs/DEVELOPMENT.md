# Development

## Requirements

- Apple silicon Mac, macOS 15 or later.
- Xcode and command-line tools; tested with Xcode 26 / Swift 6. The source uses Swift 5 language mode with Swift tools 6.
- Git, Python 3 for project generation, and Node 22+ / npm for editor development.

## Native app

```sh
git clone https://github.com/REDDITARUN/palm.git
cd palm
swift test
bash Scripts/build-native.sh --test
PALM_TEST_DATA="$PWD/.test-data/manual" dist/PalmTest.app/Contents/MacOS/Palm
```

The test bundle uses isolated storage and does not read a real model key. For fixture-backed generation, run `Scripts/fixture-server.py` and use `PALM_TEST_ENDPOINT` as needed. Read the fixture script's options before running it.

For the normal app, use `bash Scripts/build-native.sh` (Debug) or `bash Scripts/build-native.sh --release`. The generator creates `Palm.xcodeproj`; you may then use its **PalmMac** scheme. SwiftPM alone is appropriate for tests, while the native target produces the full resource-bearing `.app`.

`Package.resolved` pins Swift dependencies. An original CodeEditSymbols compatibility module satisfies an unused transitive import without shipping upstream artwork. See its `PALM_PATCH.md`.

## Embedded editor

```sh
cd Editor
npm ci
npm run typecheck
npm test
npm run build
```

The build updates `Sources/PalmCore/Resources/Editor/index.html` and license notices. Commit the source, lockfile, and generated artifact together. Do not commit `node_modules`.

## Website

`site/` is plain HTML, CSS, and JavaScript with no build dependencies, trackers, or external fonts.

```sh
python3 -m http.server 4173 --directory site
```

Check desktop/mobile widths, keyboard interaction, reduced motion, download links, and the interactive preview. Publishing instructions are in [RELEASING.md](RELEASING.md).

## Checks

Run `swift test` for the offline suite; live tests skip without explicit credentials. Keep API-backed tests opt-in because they send context and can incur provider charges. Use synthetic source and learner data for UI tests, recordings, and screenshots. `python3 Scripts/audit-public.py` reports common credentials, private paths, and generated/private artifacts without printing matched secrets.
