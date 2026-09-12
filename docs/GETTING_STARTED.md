# Your first session

## 1. Install Palm

Download the Apple silicon disk image from [Releases](https://github.com/REDDITARUN/palm/releases/latest), open it, and drag Palm into Applications. Requires macOS 15+. This community build is ad-hoc signed and not Apple-notarized.

If macOS says **Apple could not verify Palm**, and you trust the copy downloaded from this repository:

1. Attempt to open Palm once.
2. Open **System Settings → Privacy & Security**.
3. Find Palm’s warning, click **Open Anyway**, then confirm **Open**. Authenticate to macOS if asked.

This approves this app specifically; do not disable Gatekeeper globally. These instructions do not apply to a warning that the app **will damage your computer** or contains malware. [Apple’s guidance](https://support.apple.com/en-us/102445).

## 2. Connect a model

**Easy starting point:** choose OpenRouter, [create a key](https://openrouter.ai/settings/keys), paste it into Palm, and keep `thinkingmachines/inkling:free` as the model. Choose **Save & use**, then **Continue**. Your first generated session may take longer while local learning tools are downloaded.

Free models have limits and can become unavailable. Inkling free is a research endpoint that logs prompts/outputs for model improvement and disallows confidential/personal material. [Read its current terms](https://openrouter.ai/thinkingmachines/inkling:free). You can choose another free or paid model in Settings; Palm never silently upgrades you to a paid one.

For OpenAI, choose OpenAI and use an [API key](https://platform.openai.com/api-keys). API usage is separate from ChatGPT billing. To use a ChatGPT subscription, choose **ChatGPT → Add connection → Sign in with ChatGPT**, finish sign-in in your browser, choose a model, and **Save & use**. Available Codex models and limits depend on your account. Settings also accepts custom compatible endpoints. You may skip the key to explore the app, but generation needs a working model.

## 3. Pick something you want to understand

Choose **New course**. Try “How Python closures keep state” or “HTTP caching, from requests to cache invalidation.” Tell Palm your starting point and optionally take a short diagnostic. Review the generated course, then open a topic.

You can connect a repository later. See [GitHub setup](GITHUB.md).

## 4. Read, predict, practice

Use the worked example, answer the questions, and ask the tutor about anything unclear. Code selections can be sent with your question. Written responses use model grading; a failed connection preserves the answer rather than marking it wrong. Finish the reflection to save your recap and schedule review.

## 5. Return to what matters

Today suggests a next step across your courses. Notebook keeps editable notes, flashcards, and linked ideas. Review brings earlier material back. Progress shows recorded practice and achievements; a two-day start grows a sprout, not a mature tree. Enable an optional daily notification with **Today → Set a reminder**.

Before moving computers, use **Settings → Data → Back up library** and keep the whole exported folder. [Backup details](DATA_AND_PRIVACY.md).

## Updating from 1.0.0

Quit Plam, install Palm, then remove the old Plam.app from Applications to avoid opening the older copy. Your existing library and Keychain credentials are reused. Keep the Application Support folder; removing the old app does not require deleting your library.

## Source code and voice answers

In repository lessons, click a file path or choose **Browse code**. Search the saved snapshot, open a file, and click a code element to ask the tutor about it. Source links can point to individual lines. The original repository is never modified.

For written answers and tutor messages, click the microphone, or press **⌘⇧D** while the input is focused. The first use downloads Parakeet (about 471 MB of cached model files in this build) and requests microphone access. Stop recording to insert an editable transcript. Palm transcribes locally and deletes the recording afterward; it does not send the answer until you submit it.

## Updating without losing progress

Choose **Palm → Check for Updates…** or **Settings → Updates**. The update comes from this repository and its signature is verified before installation. Automatic checks are optional. Your library and model connections stay in their existing locations; replacing the app does not reset them. Palm also takes a database backup in `UpgradeBackups` before opening an existing library with a new app version.

If you have version 1.0.2 or earlier, download the current DMG and replace the app once to get the updater. Keep your Application Support folder. Community builds are still unnotarized; the installation guidance above continues to apply.
