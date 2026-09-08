<div align="center">
<img src="site/icon.png" width="88" alt="Palm icon" />
<h1>Palm</h1>
<p>A quieter way to learn code. A better way to remember it.</p>
<p>Free, open-source learning software for your Mac. Bring your own AI model.</p>
<p><a href="https://REDDITARUN.github.io/palm/">Website</a> · <a href="https://github.com/REDDITARUN/palm/releases/latest">Download for Mac</a> · <a href="docs/GETTING_STARTED.md">Get started</a> · <a href="docs/ARCHITECTURE.md">Architecture</a></p>
</div>

## Learn from questions. Learn from your code.

Pick a technical topic or a repository. Palm builds a learning path, explains ideas with examples, and gives you practice that asks you to think. Keep editable notes, ask a tutor about the part that does not click, and return to earlier ideas through spaced review.

- **Generated courses:** concepts, subtopics, checkpoints, reading, worked examples, and mixed questions.
- **Practice with feedback:** choices, true/false, fill-in-the-blank, code tracing, explanations, debugging, ordering, transfer, and flow-diagram choices. Written answers use model-based grading.
- **A connected notebook:** block editing, Markdown, code, math, diagrams, highlights, note links, flashcards, revisions, and a side tutor.
- **A daily learning habit:** next steps across courses, optional reminders, activity history, achievements, and a pixel tree that grows with practice.
- **Repository understanding:** saved source snapshots, code selections, optional Serena symbol exploration, and source-linked lessons.
- **Your models, your library:** saved OpenRouter, OpenAI API, ChatGPT, and compatible connections, local credentials, SQLite storage, and portable backups.

## Install

Download the [Palm 1.0.2 disk image](https://github.com/REDDITARUN/palm/releases/download/v1.0.2/Palm-1.0.2-macOS-arm64.dmg), open it, and drag Palm into Applications. Requires Apple silicon (M1 or later) and macOS 15+.

**This community build is ad-hoc signed and not Apple-notarized.** If macOS says Apple could not verify Palm and you trust your copy from this repository, attempt to open it once, then use **System Settings → Privacy & Security → Open Anyway → Open**. [Apple’s instructions](https://support.apple.com/en-us/102445). These steps are for the verification warning, not an alert that the app will damage your computer or contains malware.

The earlier download pause followed an incorrectly reported warning; the reporter clarified it was the standard “Apple could not verify” message. Downloads are restored with their unnotarized status explicit. Integrity checks passed, but they are not a guarantee of safety. Version 1.0.2 includes the saved connection manager, ChatGPT sign-in, and library removal controls.

## Start with a free model

Choose **OpenRouter** during onboarding, [create an API key](https://openrouter.ai/settings/keys), and paste it into Palm. The default is `thinkingmachines/inkling:free`; you may choose another free or paid model in Settings. Inkling uses the actual OpenCode learning harness, prepared on first use with a one-time local tools download.

**Palm costs nothing. Model pricing and rate limits belong to your provider.** Palm does not silently switch a free model to a paid one. Inkling's free endpoint logs prompts and outputs for model improvement and does not allow confidential/personal data. Read its [current model terms](https://openrouter.ai/thinkingmachines/inkling:free) before using it. For private material, choose a provider and settings appropriate to your needs.

OpenAI works with an [OpenAI API key](https://platform.openai.com/api-keys); API billing is separate from ChatGPT. Palm also supports **Settings → Model → ChatGPT → Add connection → Sign in with ChatGPT** through OpenCode. Finish browser sign-in, choose an available model, then **Save & use**. Your account's Codex access and limits apply; Palm does not fall back to API billing.

Save multiple named providers in **Settings → Model**. **Save** retains a connection; **Save & use** makes it the default. Custom model IDs work without a catalogue match. **Forget API key** removes a saved key. Use **Settings → Agents** to assign models from these connections to particular tasks.

## Connect GitHub (optional)

Open **Repositories**, paste `https://github.com/owner/repository`, and choose **Import from GitHub**. Public repositories need no token. For a private repository, add a fine-grained token with read-only **Contents** permission for that repository in **Settings → Local tools**. GitHub cloning needs Apple's command-line tools. You can instead extract a repository ZIP and use **Open folder**.

See the [GitHub guide](docs/GITHUB.md) for detailed steps. Repository imports filter common secret files; they are not a comprehensive secret scanner.

## Local data and offline use

Fresh libraries are stored in `~/Library/Application Support/Palm/`. Updates reuse an existing `~/Library/Application Support/Plam/` library to preserve saved source paths. Keys live separately in macOS Keychain. Selected context is sent to your chosen AI provider; local storage does not mean all computation is offline. Saved notes, lessons, and choice/ordering practice work offline. Generating lessons, tutor answers, and grading written responses require the configured model connection.

**Settings → Data → Back up library** exports records and source snapshots together. Credentials and downloaded tools are excluded. See [data and privacy](docs/DATA_AND_PRIVACY.md).

## Build and contribute

Use a Mac with Xcode (the project is tested with Xcode 26 / Swift 6). Node 22+ is needed when rebuilding the embedded editor.

```sh
git clone https://github.com/REDDITARUN/palm.git
cd palm
swift test
bash Scripts/build-native.sh --release
open dist/Palm.app
```

The prebuilt editor is committed for native-only development. For editor changes:

```sh
cd Editor
npm ci
npm run typecheck
npm test
npm run build
```

[Development guide](docs/DEVELOPMENT.md) · [Contributing](CONTRIBUTING.md) · [Agent instructions](AGENTS.md) · [Architecture decisions](docs/adr/README.md) · [Release guide](docs/RELEASING.md) · [Changelog](CHANGELOG.md)

## License

Original Palm code is [MIT licensed](LICENSE). Third-party components retain their own licenses, including BlockNote's MPL-2.0 components. See [third-party notices](THIRD_PARTY_NOTICES.md); the app also bundles dependency license texts. AI services have separate terms.
