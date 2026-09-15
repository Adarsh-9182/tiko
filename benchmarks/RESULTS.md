# Tiko pointing benchmark

Run 2026-09-15 17:59 · answered by gemini-flash-lite-latest · 29 questions on 6 screens × 2 runs = 58 attempts.

| Method | Hits | Hit rate | Median distance from centre | 90th percentile |
|---|---|---|---|---|
| Single guess on the full screenshot (Clicky's approach) | 47/58 | 81% | 8 pt | 159 pt |
| **Tiko: single guess + close-up check** | **48/58** | **83%** | **16 pt** | **198 pt** |

- The close-up check turned 2 misses into hits and 1 hits into misses.
- No point given: 1. Close-up check found nothing: 6 (first guess kept). Over the 5 s limit: 3 (first guess kept, as the app does).
- Median time to answer: 2.0 s. Median close-up check: 2.0 s.

## By screen

| Screen | Attempts | Single guess | With close-up check |
|---|---|---|---|
| [system-settings](screens/system-settings.png) | 10 | 6 (60%) | 7 (70%) |
| [text-editor](screens/text-editor.png) | 10 | 10 (100%) | 10 (100%) |
| [login-page](screens/login-page.png) | 10 | 10 (100%) | 10 (100%) |
| [finder-file-menu](screens/finder-file-menu.png) | 10 | 9 (90%) | 9 (90%) |
| [save-dialog](screens/save-dialog.png) | 6 | 6 (100%) | 6 (100%) |
| [spreadsheet](screens/spreadsheet.png) | 12 | 6 (50%) | 6 (50%) |

## How it's measured

- Each screen is drawn in code at 1440×900 points and 2 pixels per point, like a Retina MacBook, with macOS's own interface font sizes. The exact rectangle of every button, link, menu item and row is recorded while drawing. The screens are in [`screens/`](screens).
- Each question goes through the app's own path: the same system prompt (`CompanionPrompt`), a screenshot scaled to 1280 pixels wide, a 360-point close-up around a mouse parked mid-screen, and the same reply parser (`PointTag`).
- **Single guess** is where that reply points. The **close-up check** then crops 400 points around the guess at full detail and asks again (`PointRefiner`); as in the app, it replaces the guess only if it answers within 5 seconds.
- A point is a hit when it lands on the element or within 6 points of its edge. Distance is measured to the element's centre.
- Requests are spaced 4 seconds apart to stay inside the free tier's rate limit. Raw data for every attempt is in [`results/`](results).

## What this does and doesn't show

- "Clicky's approach" means one guess on the full screenshot with **the same Gemini model**. Clicky itself asks Claude, which this free benchmark doesn't call, so this compares the two methods, not the two products.
- The screens are tidier than real desktops: no overlapping windows, notifications or unusual themes. Read the numbers as a comparison between methods, not as the accuracy you'll get on your own Mac.
- Model answers vary from run to run; `--runs` adds repetitions for steadier numbers.

## Every attempt

| Run | Screen | Question | Target | Single guess | With close-up check | Reply |
|---|---|---|---|---|---|---|
| 1 | system-settings | wallpaper kaise badlu? | sidebar:Wallpaper | miss, 312 pt | miss, 312 pt | system settings mein niche Wallpaper pe click karo, wahan se change kar sakte ho. |
| 1 | system-settings | battery ki health kahan dekhu? | sidebar:Battery | miss, 672 pt | miss, 672 pt | battery health check karne ke liye sidebar mein Battery pe click karo. |
| 1 | system-settings | mac ki language hindi kaise karu? | row:Language & Region | hit, 159 pt | hit, 159 pt (check too slow) | step 1: General settings mein Language & Region pe click karo. |
| 1 | system-settings | date aur time galat hai, kahan theek karu? | row:Date & Time | hit, 111 pt | hit, 111 pt | system settings mein Date and Time pe click karo, wahan sahi ho jayega. |
| 1 | system-settings | airdrop kahan se on hota hai? | row:AirDrop & Handoff | hit, 283 pt | hit, 312 pt | general settings mein hi AirDrop and Handoff ka option hai, wahan click karo. |
| 1 | text-editor | is text ko bold kaise karu? | toolbar:Bold | hit, 2 pt | hit, 1 pt | yeh jo text select kiya hai, usko bold karne ke liye toolbar mein B pe click karo. |
| 1 | text-editor | document mein table kaise daalu? | toolbar:Insert table | hit, 1 pt | hit, 0 pt | toolbar mein jo table ka icon hai, wahan click karo. |
| 1 | text-editor | photo insert karni hai | toolbar:Insert photo | hit, 1 pt | hit, 0 pt | photo insert karne ke liye upar toolbar mein picture icon pe click karo. |
| 1 | text-editor | ye document share kaise karu? | toolbar:Share | hit, 2 pt | hit, 1 pt | document share karne ke liye upar right corner mein share button pe click karo. |
| 1 | text-editor | numbered list banani hai | toolbar:Numbered list | hit, 1 pt | hit, 1 pt | numbered list banane ke liye top toolbar mein numbered list icon pe click karo. |
| 1 | login-page | password bhool gaya, ab kya karu? | link:Forgot password? | hit, 2 pt | hit, 1 pt | email field ke right mein jo Forgot password link hai, uspe click kar do. |
| 1 | login-page | naya account kaise banau? | link:Create an account | hit, 2 pt | hit, 2 pt | form ke neeche Create an account pe click karo, wahan se naya account ban jayega. |
| 1 | login-page | google se login karna hai | button:Continue with Google | hit, 0 pt | hit, 0 pt | google se sign in karne ke liye neeche Continue with Google pe click karo. |
| 1 | login-page | remember me wala tick kahan hai? | checkbox:Remember me | hit, 48 pt | hit, 49 pt | remember me ka checkbox yahan email aur password field ke niche hai. |
| 1 | login-page | email kahan daalu? | field:Email | hit, 0 pt | hit, 62 pt | email box pe click karo jo sabse upar hai. |
| 1 | finder-file-menu | naya folder kaise banau? | menu:New Folder | hit, 72 pt | hit, 81 pt | naya folder banane ke liye menu mein New Folder pe click karo. |
| 1 | finder-file-menu | is file ki info kaise dekhu? | menu:Get Info | hit, 78 pt | hit, 83 pt | Get Info pe click karo, isse file ki sari details khul jayengi. |
| 1 | finder-file-menu | file ko zip kaise karu? | menu:Compress | hit, 85 pt | hit, 87 pt | file ko zip karne ke liye compress pe click karo. |
| 1 | finder-file-menu | ye file delete karni hai | menu:Move to Trash | hit, 40 pt | hit, 68 pt | file delete karne ke liye menu mein move to trash pe click karo. |
| 1 | finder-file-menu | file ki copy banani hai | menu:Duplicate | hit, 88 pt | hit, 81 pt | duplicate banane ke liye file menu mein duplicate select kar lo ya fir command aur d press karo. |
| 1 | save-dialog | bina save kiye band karna hai | button:Don't Save | hit, 16 pt | hit, 16 pt (check too slow) | agar changes nahi chahiye toh don't save pe click kar do. |
| 1 | save-dialog | haan save kar do | button:Save | hit, 2 pt | hit, 6 pt | save karne ke liye blue wale button pe click kar do. |
| 1 | save-dialog | ruko, abhi band nahi karna | button:Cancel | hit, 1 pt | hit, 4 pt | agar close nahi karna toh cancel pe click karke dialog hata do. |
| 1 | spreadsheet | nayi sheet kaise add karu? | button:Add sheet | hit, 2 pt | hit, 1 pt | sheet1 ke paas jo plus icon hai na, wahan click karke nayi sheet add kar sakte ho. |
| 1 | spreadsheet | zoom thoda badhana hai | button:Zoom in | no point | no point | neeche right corner mein jo zoom slider hai, usko aage ki taraf drag kar lo. |
| 1 | spreadsheet | zoom kam karna hai | button:Zoom out | hit, 2 pt | hit, 0 pt | zoom kam karne ke liye bottom right corner mein minus button pe click kar sakte ho, ya slider ko left drag karo. |
| 1 | spreadsheet | column ka total kaise nikalu? | toolbar:AutoSum | miss, 48 pt | miss, 59 pt | formula bar mein sum function likh ke range select karlo, jaise yahan B2 se B11 tak ka total nikala hai. |
| 1 | spreadsheet | is data ka chart banana hai | toolbar:Insert chart | miss, 120 pt | miss, 198 pt | chart banane ke liye pehle data select karna hoga, toh row 1 se column B ki saari values select kar lo. |
| 1 | spreadsheet | data filter kaise karu? | toolbar:Filter | hit, 2 pt | miss, 40 pt | data filter karne ke liye upar toolbar mein filter icon pe click kar sakte ho, yeh wahan formula bar ke paas hai. |
| 2 | system-settings | wallpaper kaise badlu? | sidebar:Wallpaper | miss, 626 pt | miss, 626 pt | system settings mein left side se Wallpaper pe click karo, wahan se change kar sakte ho. |
| 2 | system-settings | battery ki health kahan dekhu? | sidebar:Battery | miss, 159 pt | hit, 64 pt | battery ki health dekhne ke liye battery settings mein jaana padega. sidebar mein niche Battery pe click karo. |
| 2 | system-settings | mac ki language hindi kaise karu? | row:Language & Region | hit, 8 pt | hit, 8 pt | step 1: General settings mein Language and Region pe click karo. |
| 2 | system-settings | date aur time galat hai, kahan theek karu? | row:Date & Time | hit, 111 pt | hit, 111 pt | date aur time theek karne ke liye yahan Date and Time par click karo. |
| 2 | system-settings | airdrop kahan se on hota hai? | row:AirDrop & Handoff | hit, 283 pt | hit, 282 pt | general settings mein AirDrop and Handoff pe click karo, wahan se on kar sakte ho. |
| 2 | text-editor | is text ko bold kaise karu? | toolbar:Bold | hit, 2 pt | hit, 1 pt | selected text ko bold karne ke liye upar toolbar mein B pe click karo. |
| 2 | text-editor | document mein table kaise daalu? | toolbar:Insert table | hit, 1 pt | hit, 0 pt | step 1: upar toolbar mein table icon pe click karo. |
| 2 | text-editor | photo insert karni hai | toolbar:Insert photo | hit, 1 pt | hit, 0 pt | photo insert karne ke liye upar toolbar mein picture icon pe click karo. |
| 2 | text-editor | ye document share kaise karu? | toolbar:Share | hit, 2 pt | hit, 1 pt | document share karne ke liye upar right corner mein share button pe click karo. |
| 2 | text-editor | numbered list banani hai | toolbar:Numbered list | hit, 1 pt | hit, 1 pt | step 1: upar toolbar mein numbered list icon pe click karo. |
| 2 | login-page | password bhool gaya, ab kya karu? | link:Forgot password? | hit, 2 pt | hit, 2 pt | password recover karne ke liye Sign in ke bagal mein Forgot password? pe click kar do. |
| 2 | login-page | naya account kaise banau? | link:Create an account | hit, 2 pt | hit, 2 pt | create an account karne ke liye niche Create an account pe click karo. |
| 2 | login-page | google se login karna hai | button:Continue with Google | hit, 0 pt | hit, 0 pt | continue with google pe click karo. |
| 2 | login-page | remember me wala tick kahan hai? | checkbox:Remember me | hit, 48 pt | hit, 48 pt | remember me box yahan password ke neeche hai. |
| 2 | login-page | email kahan daalu? | field:Email | hit, 0 pt | hit, 27 pt | email address daalne ke liye upar wale box mein click karo. |
| 2 | finder-file-menu | naya folder kaise banau? | menu:New Folder | hit, 69 pt | hit, 81 pt | naya folder banane ke liye File menu mein New Folder pe click karo. |
| 2 | finder-file-menu | is file ki info kaise dekhu? | menu:Get Info | hit, 85 pt | hit, 93 pt | file ki info dekhne ke liye Get Info pe click karo, ya phir shortcut command i use karo. |
| 2 | finder-file-menu | file ko zip kaise karu? | menu:Compress | hit, 88 pt | hit, 87 pt | file ko zip karne ke liye compress option par click karo. |
| 2 | finder-file-menu | ye file delete karni hai | menu:Move to Trash | miss, 396 pt | miss, 397 pt | step 1: us file ya folder ko select karo jisko delete karna hai. |
| 2 | finder-file-menu | file ki copy banani hai | menu:Duplicate | hit, 76 pt | hit, 81 pt | duplicate karne ke liye Duplicate pe click karo. |
| 2 | save-dialog | bina save kiye band karna hai | button:Don't Save | hit, 11 pt | hit, 8 pt | bina save kiye band karna hai toh don't save pe click kar do. |
| 2 | save-dialog | haan save kar do | button:Save | hit, 2 pt | hit, 2 pt (check too slow) | save karne ke liye blue Save button pe click kar do. |
| 2 | save-dialog | ruko, abhi band nahi karna | button:Cancel | hit, 1 pt | hit, 5 pt | arey cancel button pe click kar do taaki document band na ho. |
| 2 | spreadsheet | nayi sheet kaise add karu? | button:Add sheet | hit, 1 pt | hit, 0 pt | sheet1 ke bagal mein jo plus ka icon hai, wahan click kar do nayi sheet aa jayegi. |
| 2 | spreadsheet | zoom thoda badhana hai | button:Zoom in | miss, 57 pt | miss, 55 pt | neeche right corner pe zoom slider hai, usko drag karke bada kar lo. |
| 2 | spreadsheet | zoom kam karna hai | button:Zoom out | hit, 2 pt | hit, 0 pt | neeche right corner mein jo zoom slider hai, wahan minus button pe click karke zoom kam kar sakte ho. |
| 2 | spreadsheet | column ka total kaise nikalu? | toolbar:AutoSum | miss, 45 pt | miss, 53 pt | column ka total nikalne ke liye formula bar mein equals sum type karke bracket mein cells ki range likh do, jaise yahan B2 se B11 tak ka total karne ke liye formula bar mein likha hai. |
| 2 | spreadsheet | is data ka chart banana hai | toolbar:Insert chart | miss, 128 pt | hit, 2 pt | chart banane ke liye pehle apna sara data select kar lo. |
| 2 | spreadsheet | data filter kaise karu? | toolbar:Filter | hit, 1 pt | hit, 1 pt | arey, data filter karne ke liye toolbar mein filter icon pe click kar sakte ho, yeh columns ke headers ke paas drop-down arrows le aayega. |
