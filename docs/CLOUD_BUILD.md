# Build MyFinance online without installing Xcode locally

The included workflow is `.github/workflows/build-ios.yml`, named **Build unsigned iPhone IPA**. It uses Apple's tools installed on a GitHub-hosted `macos-15` runner. Your Mac does not need Xcode, and this workflow uses no Apple Account, paid developer membership, signing certificate or secrets.

Standard GitHub-hosted runners are free for public repositories under GitHub's current policy. Private repositories use the account's included allowance and applicable billing. See [GitHub runner documentation](https://docs.github.com/en/actions/reference/runners/github-hosted-runners). The workflow has a 35-minute timeout, cancels superseded runs on the same ref, and keeps artifacts for seven days.

## Publish the existing source

There is no separate template to clone. This repository already contains the app, project and workflow. A repository owner must authorize GitHub access before any assistant or CLI can create/push a repository on their behalf.

With GitHub CLI installed on the Mac, sign in using GitHub's browser flow:

```sh
gh auth login --hostname github.com --git-protocol https --web
```

Authenticate as the GitHub account that should own the project. Review the source before publication; it currently includes fictional fixtures, not personal financial records. Then, from this project directory:

```sh
gh repo create MyFinance --public --source=. --remote=origin --push
```

This creates a public repository and pushes the committed source. If a repository named MyFinance already exists, inspect it before connecting or pushing; do not replace an existing project accidentally. Do not commit Apple credentials, access tokens, real SMS, backups, exported CSVs or account data. The workflow needs only read access to repository contents and does not publish Releases.

## Run and download

The first push to `main` that includes the workflow triggers the build automatically. You can also use **Actions → Build unsigned iPhone IPA → Run workflow** on GitHub, after the workflow is present on the default branch.

The workflow:

1. Shows Xcode, Swift and iPhone SDK versions, and validates source/project references.
2. Runs the core XCTest suite with `swift test` and six IPA-input validation tests.
3. Selects an available iPhone simulator from the runner image and runs the native core/SwiftData suites with `xcodebuild test`.
4. Builds the main app for **generic/platform=iOS**, Release configuration, with code signing disabled.
5. Validates device metadata and an arm64 executable, then packages `Payload/MyFinance.app` into `MyFinance-unsigned.ipa` using `ditto`.
6. Uploads an artifact named **MyFinance-unsigned-IPA-<run number>**, containing the IPA and its SHA-256 checksum. A separate diagnostics artifact contains build logs and available native test results.

Open a successful run, find **Artifacts**, download the IPA artifact ZIP and extract it on your Mac. The `.ipa` inside is a native iOS application package. It is not a simulator build or website. An IPA is uploaded only after all prior test/build/package steps succeed.

You can inspect runs with:

```sh
gh run list --workflow build-ios.yml
gh run view RUN_ID --log-failed
gh run download RUN_ID --name MyFinance-unsigned-IPA-RUN_NUMBER
```

## Installation is a separate step

The result is **unsigned**. Tapping the file on the iPhone will not install it. A tool such as [Sideloadly](https://sideloadly.io/) must sign it with an Apple Account and install it. Free-account signing generally requires refreshing the app every seven days; consult the tool's current requirements. Do not enter Apple credentials into GitHub or workflow secrets: they are not needed to compile this project.

The optional widget target is not embedded in this IPA. App Groups are not required. Shortcuts registration, Face ID/device authentication and app lifecycle must still be tested on the actual iPhone after successful native compilation.

## Failures

If the workflow fails, no successful native build should be claimed. Open the red step's log or download diagnostics. The local development environment cannot perform iOS typechecking; the first online run may reveal SDK, SwiftData macro, signing-independent configuration or SwiftUI errors that require source fixes. The workflow deliberately keeps native tests as a gate rather than hiding those failures.

For a packaging error, confirm that the input is `Release-iphoneos/MyFinance.app`, that `CFBundleSupportedPlatforms` identifies iPhoneOS, and that the executable exists, is executable and contains arm64. Simulator `.app` bundles cannot be converted into iPhone apps by renaming or zipping them.

The packaging validation tests use explicitly fake metadata fixtures and do not claim an app compiled. Full `ditto` packaging and Mach-O checks require the actual cloud-built device app.
