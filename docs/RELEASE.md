# Release Packaging

RequestLab ships as a zipped macOS `.app` bundle for now. The package script builds a release binary in a temporary staging directory, strips extended metadata, signs it, creates a zip archive, and writes a SHA-256 checksum.

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
