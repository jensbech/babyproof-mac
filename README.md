# Baby Mode

Hand a baby the keyboard. Every key press shows a big colourful letter or digit with a confetti burst, drawn over whatever is already on screen. All keyboard and trackpad/mouse input is swallowed so nothing underneath can be touched.

## Build

    ./build.sh

Produces `Baby Mode.app` in this folder (Swift + AppKit, no dependencies, no Xcode GUI needed) and ad-hoc signs it with identifier `no.bechsor.babymode`.

Run the unlock-logic tests with `./test.sh`.

## Launch and grant permission

    open "Baby Mode.app"

Baby Mode runs in the background with a smiley icon in the menu bar, and does not lock on launch. It needs Accessibility permission to read keys and intercept input. On first launch a window explains how to enable it in System Settings > Privacy & Security > Accessibility.

To have it ready after a restart, add it under System Settings > General > Login Items.

macOS ties the Accessibility grant to the code signature. Ad-hoc signatures change with every rebuild, so after rebuilding you may need to remove "Baby Mode" from the Accessibility list (select it and press minus) and add or enable it again.

## Start

Press Enter, V, Enter, with no more than 1.5 seconds between presses and no modifier held, or use the menu bar icon. The first Enter and the V still reach the app you are in; the last Enter does not. Keys typed in password fields are hidden from Baby Mode, so the sequence does not work there.

## Unlock

Press Enter 5 times in a row to return to the background. Any other key, including a modifier, starts the count again. Holding Enter down counts as one press, and there is no time limit between presses.

## Limits

- The power button (and Touch ID button) cannot be blocked; a long press will still power off the Mac.
- Closing the lid, unplugging power or battery running out behave as usual.
- If the event tap dies and cannot be re-enabled, or Accessibility permission is revoked, the lock ends rather than leave a dead overlay.
- Display sleep is prevented while running; the assertion is released on exit.
