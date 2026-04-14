# OpenNow Release Readiness

## Repo-Side Status
- Bundle ID is set to `com.dahengchen.OpenNow`.
- macOS sandbox entitlements are enabled with user-selected read-only access and app-scope bookmarks.
- Local StoreKit configuration is wired into the shared `OpenNow` scheme.
- App category is `public.app-category.productivity`.
- Launch now restores the last document again when restore is allowed.
- UI tests no longer trigger folder-tree authorization prompts from launch-environment fixtures.
- Default `OpenNow` scheme is now repo-health focused: build plus unit tests.
- UI layout and launch automation remain in the shared `OpenNowUI` scheme and require local macOS Accessibility / Automation availability.

## Remaining Manual App Store Connect Blockers
- Banking information must be added for the paid apps agreement.
- Tax information must be completed.
- Trader / compliance information still needs to be completed if App Store Connect keeps showing that requirement.
- A distributable macOS build still needs to be uploaded and attached to the app version.
- App Store metadata still needs final review before submission:
  - screenshots
  - description / keywords / support metadata
  - in-app purchase attachment on the version page

## Submission Notes
- The app is a read-only Markdown reader; support purchases must stay optional and must not imply feature unlocks.
- Sandbox behavior is the real shipping path. Do not sign off launch quality based only on non-sandbox local runs.
- Before submission, run build, test, and a Release archive using the distribution signing path rather than a development archive.
- Before relying on `OpenNowUI`, confirm `System Events` UI scripting is enabled and the machine has granted the required Automation / Accessibility permissions to the test tooling.
