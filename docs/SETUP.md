# Install and run aftercopy

## Build and install

From the repository, build Release with a separate output directory:

```sh
xcodebuild build -project aftercopy.xcodeproj -scheme aftercopy -configuration Release -destination 'platform=macOS' -derivedDataPath /tmp/aftercopy-release
```

Quit any running aftercopy. In Finder, copy
/tmp/aftercopy-release/Build/Products/Release/aftercopy.app to
/Applications/aftercopy.app and launch the installed app from Finder.
The menu bar icon appears and history restores automatically.

## Direct paste

Choose **Enable Direct Paste…**, then allow the installed app in System Settings
→ Privacy & Security → Accessibility. Without permission, selection still copies
and you can paste with Cmd+V.

Keep the app in /Applications. Ad-hoc signing means a stable path alone cannot
guarantee permission retention across rebuilds. If direct paste stops after an
update, remove the old Accessibility entry and add the installed app again,
then quit and relaunch without rebuilding.

## Launch at Login

Off until you opt in. Choose **Launch at Login** beside **Clear History**.
A checkmark means macOS reports it enabled. If approval is required, the status
line directs you to System Settings → General → Login Items; clicking the toggle
again opens that pane. Allow aftercopy there, then reopen the menu.
External changes are reflected on each menu opening.

Uncheck to unregister. If already blocked in System Settings, remove or disable
its entry there. Failed changes show a message and preserve the previous
checkmark until the next refresh.

Verify by logging out and back in. Disable “Reopen windows when logging back in”
when checking the off case so session restoration does not mimic registration.

## Update

Quit, build a new Release app, replace /Applications/aftercopy.app, and relaunch.
History lives separately at ~/Library/Application Support/aftercopy/history.json.
Check direct paste and Launch at Login again; refresh Accessibility if needed.
Developer ID signing, notarization, public distribution, installers, and automatic
updates are outside this local installation workflow.
