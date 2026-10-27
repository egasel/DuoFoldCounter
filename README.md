# DuoFoldCounter

Counts how many times your iPhone Duo is opened and closed: today, and in total.

## How it works

iOS doesn't let an app watch the hinge in the background. UIKit's `UIHingeInteraction` only
reports while the app is on screen, and extensions don't get hinge callbacks at all. So no app
can stay running and count folds by itself.

What *does* run on every fold is the Shortcuts trigger **When iPhone is Opened / Closed**. This project hooks into it:

```
fold the phone ──► Shortcuts "When iPhone is Closed" trigger ──► Log Fold Close (this app, runs in background)
                                                                     │
                                                       App Group storage (per-day counts)
                                                                     │
                                                        app screen + Home/Lock Screen widget
```

## What others have done

| Approach | Counts when app is closed? | Notes |
| --- | --- | --- |
| In-app hinge API (`UIHingeInteraction`), e.g. [harisnkr/duocount](https://github.com/harisnkr/duocount), [seichris/iphone-duo-fold-counter](https://github.com/seichris/iphone-duo-fold-counter) | No | Counts only while the app is on screen. seichris says outright that it isn't a 24/7 counter. duocount adds a widget button for folds it missed. |
| Shortcuts Opened/Closed automation ([Matthew Cassinelli](https://matthewcassinelli.com/iphone-duo-adds-a-shortcuts-automation-for-when-duo-is-opened-and-closed/), [Federico Viticci](https://x.com/viticci/status/2113320137042616559), [MacStories](https://www.macstories.net/stories/a-day-with-the-iphone-duo-first-impressions/)) | Yes | The system runs it. This project uses it. |
| Keyboard or other extensions | No | [KeyboardKit found](https://keyboardkit.com/blog/2026/10/14/ios-keyboard-extensions-can-t-detect-the-iphone-duo-fold) extensions never get hinge callbacks. |

## Option A: no Mac needed (Shortcuts only)

This works today with nothing to install. Every fold adds one line to a text file. A second
shortcut counts the lines.

1. **Shortcut for opens.** In Shortcuts, start a new shortcut and add the **When iPhone is Opened**
   trigger. Leave **Automation** on and turn **Notify** off. Add these actions from the Search bar:
   - **Format Date**: Current Date, Custom format `yyyy-MM-dd`
   - **Text**: `Formatted Date open`. Put the *Formatted Date* variable, a space, then `open`.
   - **Append to Text File**: append *Text* to `FoldCounter/folds.txt` in the Shortcuts folder,
     with **Make New Line** on
2. **Shortcut for closes.** Make the same shortcut with the trigger set to **Closed** and the word `close`.
3. **Shortcut "Fold Stats"**, which you run when you want to see the counts:
   - **Get File from Folder**: `FoldCounter/folds.txt` in the Shortcuts folder
   - **Format Date**: Current Date, `yyyy-MM-dd`
   - **Match Text** `Formatted Date open` in *File* → **Count** → **Set Variable** `todayOpens`
   - **Match Text** `Formatted Date close` in *File* → **Count** → **Set Variable** `todayCloses`
   - **Match Text** `open` in *File* → **Count** → **Set Variable** `totalOpens`
   - **Match Text** `close` in *File* → **Count** → **Set Variable** `totalCloses`
   - **Show Result**: `Today: todayOpens opens / todayCloses closes` on one line,
     `All time: totalOpens opens / totalCloses closes` on the next
4. To check it with one tap, add a Shortcuts widget for "Fold Stats" to your Home Screen.

## Option B: the native app (this repo)

It's a SwiftUI app with two App Intents (**Log Fold Open**, **Log Fold Close**) and a widget for
the Home Screen and Lock Screen. You get today's counts, all-time totals, the last 7 days, a
manual +1 for folds that were missed, and reset.

**You need** a Mac with Xcode 27.1 or later (so the app fills the Duo's inner display instead of
being letterboxed), [XcodeGen](https://github.com/yonaskolb/XcodeGen), and an Apple developer
account to install it on your phone.

1. `brew install xcodegen`
2. In `project.yml`, set `BUNDLE_ID_PREFIX` (for example `com.yourname`) and `DEVELOPMENT_TEAM`.
3. Run `xcodegen generate`, open `FoldCounter.xcodeproj`, and run it on your iPhone Duo.
4. In Shortcuts, make two shortcuts: **When iPhone is Opened** → *Log Fold Open*, and
   **When iPhone is Closed** → *Log Fold Close*. Leave **Automation** on and turn **Notify** off for both.
   The app shows these same steps.

The counts are stored by local calendar day in the App Group, so the app and the widget read the
same data. "Today" resets at midnight, and the all-time total keeps growing.

## Things to check on the device

These points haven't been confirmed on a real iPhone Duo yet:

- Whether the automation also fires while the phone is locked, or only after Face ID unlocks it.
- iOS limits how often a widget can refresh, so on heavy days the widget may lag behind the app.
  The app always shows the exact count.
