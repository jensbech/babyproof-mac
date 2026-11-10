# Baby Mode

A macOS menu bar app that locks the keyboard, trackpad and mouse so a baby can bash keys safely. Each key press shows a big colourful letter with confetti over the current screen.

## Build and run

    ./build.sh            # builds the app and its icon, then ad-hoc signs "Baby Mode.app"
    ./test.sh             # runs the key-sequence tests
    open "Baby Mode.app"

Requires macOS 12+ and Accessibility permission (System Settings > Privacy & Security > Accessibility). Rebuilding changes the ad-hoc signature, so you may need to remove and re-add the app there.

## Use

- **Start:** press Return, V, Return, with less than 1.5 s between presses and no modifiers held. You can also start it from the menu bar icon.
- **Stop:** press Return 5 times in a row. Any other key resets the count.
- **Change keys:** open **Settings…** from the menu bar icon and record new sequences. A start sequence can be 2–8 keys and a stop sequence 3–12 keys. Modifier keys can't be used.

While locked, the cursor is hidden, the Dock and menu bar are hidden, app switching and Force Quit are disabled, and display sleep is prevented.

## Limits

- The power button, closing the lid and power loss still work as normal.
- It won't start, and stops itself, while a password field has secure input enabled.
- If Accessibility permission is revoked or the input tap fails, the lock ends.
