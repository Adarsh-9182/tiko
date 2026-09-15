# Installing Tiko

Tiko is free and open source. It isn't signed with a paid Apple Developer ID
yet, so macOS asks you to confirm it the first time you open it. This page
walks through that and everything else, start to finish.

## What you need

- A Mac with Apple silicon (M1 or later) running macOS 14 Sonoma or newer
- A free Gemini API key from [Google AI Studio](https://aistudio.google.com/apikey)
- An internet connection for answers (speech recognition itself runs on your Mac)

## 1. Download

1. Download `Tiko-0.1.0.zip` from the [latest release](https://github.com/Adarsh-9182/tiko/releases).
2. Optional — check the download is intact. In Terminal, run
   `shasum -a 256 ~/Downloads/Tiko-0.1.0.zip` and compare the result with the
   `Tiko-0.1.0.zip.sha256` file from the same release.
3. Double-click the zip, then drag **Tiko** into **Applications**.

## 2. Open it the first time

macOS stops apps from unidentified developers the first time they're opened.

1. Double-click **Tiko** in Applications. macOS says it can't be opened; click **Done**.
2. Open **System Settings → Privacy & Security**, scroll down to the message about Tiko,
   and click **Open Anyway**. Confirm with your password or Touch ID.
3. Tiko's icon appears in the menu bar, near the clock.

On macOS 14 you can instead Control-click Tiko in Applications and choose **Open**.

## 3. Allow the permissions

Click Tiko's menu bar icon. The panel lists what Tiko needs; click **Allow** on each.

| Permission | Why |
|---|---|
| Accessibility | Notice the push-to-talk shortcut in any app |
| Screen Recording | See your screen when you ask a question |
| Microphone | Hear your question |
| Speech Recognition | Turn your voice into text |

After allowing Screen Recording, click **Restart** in the panel — macOS only applies
that permission to a freshly opened app.

## 4. Add your Gemini key

1. Create a free key at [aistudio.google.com/apikey](https://aistudio.google.com/apikey).
2. Paste it into Tiko's panel and click **Save**. Tiko checks the key and picks the
   fastest model it can use. With a paid key or more quota, **Settings… → Answers from**
   picks a stronger flash or pro model; if it's busy, Tiko falls back to the fast ones.

The key is saved only on your Mac, in a file only your user account can read.

## 5. Ask something

- Hold **⌃ Control + ⌥ Option**, ask out loud — "wifi kahan hai?" — and let go.
- Tiko answers out loud and points at what you need. **Esc** stops it.
- For something that takes several clicks, Tiko shows one step at a time: do it, then
  tap the shortcut (or say "next") for the next step.
- **Settings…** in the panel changes the shortcut (including a one-key Right ⌥), the
  language you speak, the voice, and shows your history.

## Troubleshooting

**The shortcut does nothing.** Make sure Accessibility is on for Tiko in System Settings →
Privacy & Security → Accessibility.

**Permissions stopped working after updating Tiko.** Releases are signed with the same
certificate so permissions carry over, but if an update ever asks again: in System Settings →
Privacy & Security, remove Tiko with **−** from Accessibility and Screen Recording, then allow
it again from Tiko's panel.

**Anything else.** Tiko → Settings… → General → **Show log** opens a log of what Tiko did
and how long each step took. It never contains your key, your screen or what you said, so
it's safe to share when reporting a problem.

**"Gemini ka free quota abhi busy hai".** The free tier limits requests per minute. Wait a
minute and ask again.

**"kuch sunai nahi diya".** Check Microphone permission, and that the right input is
selected in System Settings → Sound → Input.

**The voice sounds robotic.** Download an enhanced English (India) voice in System
Settings → Accessibility → Spoken Content → System voice → Manage Voices, then choose it
in Tiko's Settings → Voice.

**Tiko points at the wrong spot.** Pointing is right most of the time on our
[benchmark screens](benchmarks/RESULTS.md), but real apps vary. Press Esc and ask again,
naming what you can see on screen.

## Uninstall

1. Click **Quit Tiko** in its panel.
2. Delete Tiko from Applications.
3. Delete `~/Library/Application Support/Tiko`, which holds your Gemini key and history.
4. Optionally remove Tiko from the lists in System Settings → Privacy & Security.
