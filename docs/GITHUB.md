# Learn from a GitHub repository

GitHub is optional. You can study any technical topic without connecting an account.

## Public repository

1. Copy the repository's HTTPS URL, such as `https://github.com/owner/repository`.
2. In Plam, open **Repositories** and paste it into the GitHub field.
3. Choose **Import from GitHub**, then **Build a course** on the saved repository.
4. Describe the area you want to understand: request flow, a module, an algorithm, or a particular feature.

Cloning uses `/usr/bin/git` and requires Apple's command-line tools. If needed, run `xcode-select --install` in Terminal and follow Apple's installer. Alternatively download the repository ZIP from GitHub, extract it, and use **Open folder**.

## Private repository

1. Open [GitHub fine-grained tokens](https://github.com/settings/personal-access-tokens/new).
2. Select the repository owner and only the repositories you need. Set a suitable expiration.
3. Under repository permissions, grant **Contents: Read-only**; GitHub adds Metadata access automatically. Organization repositories may require administrator approval.
4. Copy the token into **Plam → Settings → Local tools → GitHub token**, then choose **Save tool credentials**.
5. Import the same HTTPS repository URL. Never put the token in the URL.

Tokens are stored in Keychain and passed to Git without writing credentials into the repository's remote URL. Plam does not create commits or push to the connected repository.

## What gets used

Plam makes an immutable copy of selected source files. Common dependency/build folders, hidden files, symlinks, oversized files, and common credential filenames are excluded. Review the repository for sensitive content yourself. Relevant code may be sent to your configured model provider, whose terms must permit that content.

**Prepare tools** enables optional Serena symbol/reference exploration. Language servers may require the language's own toolchain. Refresh the snapshot after source changes; existing lessons retain their original evidence.

See [GitHub's token guidance](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) and [data/privacy](DATA_AND_PRIVACY.md).
