# Tiko

A buddy that lives next to your cursor on macOS: hold a shortcut, ask out loud,
and it sees your screen, answers by voice, and points at the thing you need.
Inspired by [Clicky](https://github.com/farzaa/clicky), rebuilt on a free stack
(Gemini free tier, Apple on-device speech, macOS system voices) and aiming to do
the job better.

## Build

Needs macOS 14+ and the Command Line Tools (no Xcode).

```bash
./scripts/build-app.sh
open build/Tiko.app
```

The app is ad-hoc signed, so macOS asks for its permissions again after every rebuild.

## Use

Hold **⌃ Control + ⌥ Option** and talk. Open the menu bar icon for permissions and settings.

## Roadmap

See [ROADMAP.md](ROADMAP.md): where Clicky falls short, how Tiko does better,
and the phase-by-phase plan.
