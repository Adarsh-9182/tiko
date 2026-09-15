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

1. Open the menu bar icon, allow the permissions, and paste a free Gemini API key
   from [aistudio.google.com/apikey](https://aistudio.google.com/apikey). The key is
   saved only on this Mac, in a file only your user can read.
2. Hold **⌃ Control + ⌥ Option**, ask your question out loud, and let go.
3. Tiko answers out loud and points at what you need. Press **Esc** to stop it at
   any time; replies can be muted from the panel.

## Check

```bash
swift run TikoCheck          # offline checks of the Gemini client, model choice, settings
swift run TikoCheck --live   # also asks Gemini a real question using your saved key
```

## Roadmap

See [ROADMAP.md](ROADMAP.md): where Clicky falls short, how Tiko does better,
and the phase-by-phase plan.
