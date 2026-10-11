BatteryHide 0.1.0 — user-configurable display filter
Target: iPhone / iOS 18 / rootless jailbreak such as Dopamine 3.

BUILD FROM YOUR IPHONE
Upload the supplied BatteryHide-build.yml as .github/workflows/build.yml in
GitHub. Run Actions > Build BatteryHide rootless > Run workflow. Download
BatteryHide-rootless, extract the .deb, install with Sileo, then close and
reopen Settings. The standalone workflow includes all source.
For a normal source repo, upload this folder's contents at repository root;
the workflow inside .github/workflows builds that checkout instead.

CHOOSE APPS
1. Open Settings > Battery and scroll the app usage list.
2. Open Settings > BatteryHide > Choose apps.
3. Turn on names to hide them, or tap Add app name and enter the exact label
   shown on Battery. Added names are selected immediately.
4. Return to Battery. If the old list remains, close and reopen Settings.
5. Turn a name off to show it again, or use Show all apps to clear selection.
   Disable Enable BatteryHide to restore all rows without clearing selections.

No app is preselected. Choices are saved in com.example.batteryhide.
Only Settings is injected. No app usage records are modified or deleted.
Battery charts, totals, percentages and other usage surfaces remain unchanged.

LIMITATIONS
This retains the original experimental UIKit table-row approach. A Battery
page whose responder controller bundle name contains Battery or PowerUsage
must host the row. Our own BatteryHide preference page is explicitly excluded.
Unknown/SwiftUI or collection-based lists are not handled. Hidden rows can
leave blank gaps. Learned names are candidates from icon-bearing rows, not
an installed-app inventory, so verify them. Exact case-sensitive display-name
matching cannot distinguish two apps using the same name, and a language
change may require updating names. This is not a privacy guarantee.

The stale hidden-state bug is addressed: state owned by BatteryHide is restored
before relayout and prepareForReuse, and only selected Battery rows are hidden
again. Preferences changes update tracked rows without requiring a respring.

VALIDATION
Plists, workflow YAML/shell syntax and embedded source bytes checked locally.
No iOS compiler/physical-device test available here. Compilation is checked by
GitHub's macOS runner. Verify on your phone: selected row hides; deselected row
returns; disable restores rows; scrolling does not hide unrelated reused cells;
BatteryHide's own chooser is never filtered; totals and charts remain unchanged.
