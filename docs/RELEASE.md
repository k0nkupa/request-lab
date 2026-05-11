# Release Packaging

RequestLab ships as a zipped macOS `.app` bundle for now. The package script builds a release binary in a temporary staging directory, strips extended metadata, signs it, creates a zip archive, and writes a SHA-256 checksum.

The current app baseline includes REST and GraphQL request editing, global and collection environments, Keychain-backed secret values, Postman JSON import, cURL import/export, response inspection, local history, and the command palette. It does not include notarization, OAuth flows, a collection runner, OpenAPI import, Insomnia import, team sync, or cloud workspace services.

## Local Release Archive

```bash
rtk ./script/package_release.sh
```

Outputs:

```text
dist/release/RequestLab-<version>-<build>-macOS.zip
dist/release/RequestLab-<version>-<build>-macOS.zip.sha256
```

By default, the script uses:

- `APP_VERSION=0.1.0`
- `APP_BUILD=<current git short sha>`
- ad-hoc code signing

Override version metadata when cutting a release:

```bash
rtk APP_VERSION=0.1.0 APP_BUILD=1 ./script/package_release.sh
```

## Developer ID Signing

For public distribution outside the Mac App Store, use a Developer ID Application certificate:

```bash
rtk SIGN_IDENTITY="Developer ID Application: Example, Inc. (TEAMID)" ./script/package_release.sh
```

That signs with hardened runtime enabled. It does not notarize the app. Notarization needs Apple credentials and should be added when the project is ready for public binary releases, not while we are still sharpening the knife.

Minimum follow-up validation for a signed artifact:

```bash
rtk ditto -x -k dist/release/RequestLab-0.1.0-1-macOS.zip /tmp/requestlab-release-check
rtk codesign --verify --deep --strict /tmp/requestlab-release-check/RequestLab.app
rtk spctl -a -vv /tmp/requestlab-release-check/RequestLab.app
```

## Release Validation

Before publishing a release archive, run:

```bash
rtk swift test
rtk swift build
rtk ./script/build_and_run.sh --verify
rtk ./script/package_release.sh
```

Record the generated archive path and checksum from the package script output in the GitHub release notes.
