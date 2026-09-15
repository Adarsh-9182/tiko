# Tiko

A buddy that lives next to your cursor on macOS: hold a shortcut, ask out loud,
and it sees your screen, answers by voice, and points at the thing you need.
Inspired by [Clicky](https://github.com/farzaa/clicky), rebuilt on a free stack
(Gemini free tier, Apple on-device speech, macOS system voices).

## Build

Needs macOS 14+ and the Command Line Tools (no Xcode).

```bash
./scripts/build-app.sh
open build/Tiko.app
```

The app is ad-hoc signed, so macOS asks for its permissions again after every rebuild.

## Roadmap

1. Menu bar app skeleton ← **done**
2. Permissions (accessibility, screen recording, microphone, speech)
3. Cursor buddy overlay
4. Push-to-talk shortcut (⌃ control + ⌥ option)
5. Voice → text (Apple Speech, en-IN, on-device)
6. Screenshot + question → Gemini
7. Pointing at on-screen elements
8. Speaking the reply
9. Tests, including a live pointing-accuracy check
10. Distribution (API proxy, signing)
