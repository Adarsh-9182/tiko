# Tiko roadmap

Tiko is a buddy that lives next to your cursor on macOS: hold a shortcut, ask
out loud, and it sees your screen, answers by voice, and points at what you
need. It started from the idea behind [Clicky](https://github.com/farzaa/clicky)
and aims to do the job better.

## Where Clicky falls short

Taken from Clicky's own issue tracker:

| Problem | Clicky issue | Tiko's answer |
|---|---|---|
| Won't stop once it starts speaking | [#36](https://github.com/farzaa/clicky/issues/36) | Esc or a new question stops speech instantly |
| Runs out of credits, can't bring your own key | [#27](https://github.com/farzaa/clicky/issues/27) | Free: your own Gemini key, on-device speech, system voices |
| Struggles with non-English, forgets context | [#7](https://github.com/farzaa/clicky/issues/7) | Hinglish-first; conversation memory |
| Broken on multiple monitors | [#24](https://github.com/farzaa/clicky/issues/24) | Every screen captured and mapped |
| Pointing skipped on slightly negative coordinates | [#128](https://github.com/farzaa/clicky/issues/128) | Coordinates clamped onto the screen |
| Misses detail when you say "here" | [#77](https://github.com/farzaa/clicky/issues/77) | High-resolution crop around the cursor sent with every question |
| No transcript or settings in the panel | [#76](https://github.com/farzaa/clicky/issues/76), [#60](https://github.com/farzaa/clicky/issues/60) | History and settings in the panel |
| Can't copy the answer | [#43](https://github.com/farzaa/clicky/issues/43) | Copy last answer |
| Privacy worries | [#34](https://github.com/farzaa/clicky/issues/34) | Speech never leaves the Mac; screenshots only on keypress; no proxy |

Beyond fixing those, Tiko adds:

- **Zoom-refined pointing** — after a first guess on the full screen, Tiko asks again on a zoomed crop around that guess, and the accuracy gain is measured, not assumed.
- **Guided tours** — multi-step answers point at each step in turn; tap the shortcut to advance.

## Phases

| # | Phase | How it works | Status |
|---|---|---|---|
| 1 | Menu bar app | Accessory app, status item, popover panel, `.app` built without Xcode | done |
| 2 | Permissions | Accessibility, Screen Recording, Microphone, Speech; polled every 1.5s | done |
| 3 | Cursor buddy | Click-through overlay window per screen; event-driven mouse tracking | done |
| 4 | Push-to-talk | Listen-only CGEvent tap for ⌃ Control + ⌥ Option; a third key cancels; waveform from mic level | done |
| 5 | Voice → text | AVAudioEngine → on-device `SFSpeechRecognizer` (en-IN); live transcript bubble | done |
| 6 | Brain | ScreenCaptureKit screenshots + cursor crop + transcript + last 10 exchanges → Gemini; model fallback on rate limits | |
| 7 | Pointing | `[POINT:x,y:label:screenN]` on Gemini's 0–1000 grid → AppKit coordinates; clamping; bezier flight; zoom refinement | |
| 8 | Voice out | `AVSpeechSynthesizer` plus captions; interruptible | |
| 9 | Guided tours | Multi-step point tags; tap the shortcut for the next step | |
| 10 | Settings | Hotkey, language, voice, history, copy last answer | |
| 11 | Accuracy benchmark | Synthetic screens with known targets; single-pass vs zoom-refined hit rate | |
| 12 | Distribution | Unsigned zip and install guide; Developer ID signing when budget allows | |
