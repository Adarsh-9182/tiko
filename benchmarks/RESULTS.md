# Tiko pointing benchmark

Run 2026-09-15 21:03 · answered by gemini-flash-lite-latest · 29 questions on 6 screens × 2 runs = 58 attempts.

| Method | Hits | Hit rate | Median distance from centre | 90th percentile | Requests per question |
|---|---|---|---|---|---|
| Single guess on the full screenshot (Clicky's approach) | 46/58 | 79% | 20 pt | 164 pt | 1.00 |
| Single guess + close-up check on every question | 45/58 | 78% | 40 pt | 181 pt | 2.00 |
| **Tiko: label read on screen, else close-up check** | **48/58** | **83%** | **23 pt** | **196 pt** | **1.53** |

- The label was read off the screen for 27 of 58 pointed answers, and landed on the target 27 times; the rest fell back to the close-up check.
- Compared with the single guess, Tiko's path turned 3 misses into hits and 1 hits into misses.
- Reading every piece of text off a full-resolution screen took 0.1 s to 0.5 s. Median time to answer: 2.3 s; median close-up check: 2.0 s.

## By screen

| Screen | Attempts | Single guess | Close-up check | Tiko |
|---|---|---|---|---|
| [system-settings](screens/system-settings.png) | 10 | 7 (70%) | 7 (70%) | 10 (100%) |
| [text-editor](screens/text-editor.png) | 10 | 10 (100%) | 10 (100%) | 10 (100%) |
| [login-page](screens/login-page.png) | 10 | 10 (100%) | 10 (100%) | 10 (100%) |
| [finder-file-menu](screens/finder-file-menu.png) | 10 | 9 (90%) | 9 (90%) | 9 (90%) |
| [save-dialog](screens/save-dialog.png) | 6 | 6 (100%) | 6 (100%) | 6 (100%) |
| [spreadsheet](screens/spreadsheet.png) | 12 | 4 (33%) | 3 (25%) | 3 (25%) |

## How it's measured

- Each screen is drawn in code at 1440×900 points and 2 pixels per point, like a Retina MacBook, with macOS's own interface font sizes. The exact rectangle of every button, link, menu item and row is recorded while drawing. The screens are in [`screens/`](screens).
- Each question goes through the app's own path: the same system prompt (`CompanionPrompt`), a screenshot scaled to 1280 pixels wide, a 360-point close-up around a mouse parked mid-screen, and the same reply parser (`PointTag`).
- **Single guess** is where that reply points. The **close-up check** crops 400 points around the guess at full detail and asks again (`PointRefiner`); as in the app, it replaces the guess only if it answers within 5 seconds.
- **Tiko** first reads all the text on the full-resolution screen with Apple's on-device text recognition and snaps to the text matching the element's label (`TextAnchor`, the same code the app runs). Icons, switches and text fields, and labels it can't find, fall back to the close-up check.
- A point is a hit when it lands on the element or within 6 points of its edge. Distance is measured to the element's centre.
- Requests are spaced 4 seconds apart to stay inside the free tier's rate limit. Raw data for every attempt is in [`results/`](results).

## What this does and doesn't show

- "Clicky's approach" means one guess on the full screenshot with **the same Gemini model and Tiko's prompt**. Clicky itself asks Claude, which this free benchmark doesn't call, so this compares methods, not the two products.
- The screens are tidier than real desktops, and their text is crisp — which flatters text recognition. Read the numbers as a comparison between methods, not as the accuracy you'll get on your own Mac.
- Model answers vary from run to run; `--runs` adds repetitions for steadier numbers.

## Every attempt

| Run | Screen | Question | Target | Single guess | Close-up check | Tiko | Reply |
|---|---|---|---|---|---|---|---|
| 1 | system-settings | wallpaper kaise badlu? | sidebar:Wallpaper | miss, 164 pt | miss, 164 pt (check too slow) | hit, 56 pt (label read) | system settings ke sidebar mein Wallpaper pe click karo, wahan se change kar sakte ho. |
| 1 | system-settings | battery ki health kahan dekhu? | sidebar:Battery | miss, 159 pt | miss, 159 pt (check too slow) | hit, 76 pt (label read) | battery health dekhne ke liye sidebar mein Battery pe click karo. |
| 1 | system-settings | mac ki language hindi kaise karu? | row:Language & Region | hit, 196 pt | hit, 196 pt (check too slow) | hit, 196 pt | Language and Region settings mein jaakar mac ki language hindi kar sakte hain. |
| 1 | system-settings | date aur time galat hai, kahan theek karu? | row:Date & Time | hit, 111 pt | hit, 111 pt | hit, 395 pt (label read) | date and time theek karne ke liye General settings mein Date and Time pe click karo. |
| 1 | system-settings | airdrop kahan se on hota hai? | row:AirDrop & Handoff | hit, 332 pt | hit, 310 pt | hit, 310 pt | airdrop on karne ke liye General settings ke andar AirDrop and Handoff pe click karo. |
| 1 | text-editor | is text ko bold kaise karu? | toolbar:Bold | hit, 1 pt | hit, 1 pt | hit, 1 pt | text ko select karne ke baad upar toolbar mein B pe click karo, woh bold ho jayega. |
| 1 | text-editor | document mein table kaise daalu? | toolbar:Insert table | hit, 2 pt | hit, 1 pt | hit, 1 pt | document mein table insert karne ke liye upar toolbar mein table icon pe click karo. |
| 1 | text-editor | photo insert karni hai | toolbar:Insert photo | hit, 1 pt | hit, 0 pt | hit, 0 pt | photo add karne ke liye upar toolbar mein picture icon pe click karo. |
| 1 | text-editor | ye document share kaise karu? | toolbar:Share | hit, 1 pt | hit, 1 pt | hit, 1 pt | document share karne ke liye top right corner mein jo share icon hai, uspe click karo. |
| 1 | text-editor | numbered list banani hai | toolbar:Numbered list | hit, 1 pt | hit, 1 pt | hit, 1 pt | top toolbar mein numbered list wala icon click kar do, wahan se list ban jayegi. |
| 1 | login-page | password bhool gaya, ab kya karu? | link:Forgot password? | hit, 1 pt | hit, 1 pt (check too slow) | hit, 2 pt (label read) | yahan password box ke paas blue color mein Forgot password link hai, uspe click karo. |
| 1 | login-page | naya account kaise banau? | link:Create an account | hit, 2 pt | hit, 2 pt | hit, 2 pt | naya account banane ke liye box ke neeche diye gaye Create an account link pe click karo. |
| 1 | login-page | google se login karna hai | button:Continue with Google | hit, 0 pt | hit, 16 pt | hit, 3 pt (label read) | continue with google pe click karo. |
| 1 | login-page | remember me wala tick kahan hai? | checkbox:Remember me | hit, 48 pt | hit, 49 pt | hit, 2 pt (label read) | Remember me ke bagal mein hai chhota sa box, uspe click kar do. |
| 1 | login-page | email kahan daalu? | field:Email | hit, 1 pt | hit, 1 pt (check too slow) | hit, 1 pt | email address yahan email field mein likh do. |
| 1 | finder-file-menu | naya folder kaise banau? | menu:New Folder | hit, 72 pt | hit, 81 pt | hit, 83 pt (label read) | naya folder banane ke liye menu mein New Folder pe click karo. |
| 1 | finder-file-menu | is file ki info kaise dekhu? | menu:Get Info | hit, 76 pt | hit, 83 pt | hit, 94 pt (label read) | isse info dekhne ke liye file menu mein Get Info pe click karo. |
| 1 | finder-file-menu | file ko zip kaise karu? | menu:Compress | hit, 85 pt | hit, 87 pt | hit, 88 pt (label read) | file ko zip karne ke liye compress pe click karo. |
| 1 | finder-file-menu | ye file delete karni hai | menu:Move to Trash | hit, 40 pt | hit, 68 pt | hit, 75 pt (label read) | file ko delete karne ke liye menu mein move to trash pe click karo. |
| 1 | finder-file-menu | file ki copy banani hai | menu:Duplicate | hit, 131 pt | hit, 106 pt | hit, 90 pt (label read) | duplicate select karne ke liye file menu mein Duplicate pe click karo. |
| 1 | save-dialog | bina save kiye band karna hai | button:Don't Save | hit, 16 pt | hit, 8 pt | hit, 2 pt (label read) | agar changes nahi chahiye toh don't save pe click kar do. |
| 1 | save-dialog | haan save kar do | button:Save | hit, 2 pt | hit, 3 pt | hit, 2 pt (label read) | save karne ke liye blue wale button pe click kar do. |
| 1 | save-dialog | ruko, abhi band nahi karna | button:Cancel | hit, 1 pt | hit, 1 pt | hit, 1 pt (label read) | are arre, cancel pe click kar do taaki file band na ho. |
| 1 | spreadsheet | nayi sheet kaise add karu? | button:Add sheet | hit, 1 pt | hit, 1 pt | hit, 1 pt | sheet1 ke bagal mein jo plus ka icon hai, wahan click kar do nayi sheet aa jayegi. |
| 1 | spreadsheet | zoom thoda badhana hai | button:Zoom in | miss, 61 pt | miss, 55 pt | miss, 55 pt | neeche right corner mein jo zoom slider hai, usko aage badha do. |
| 1 | spreadsheet | zoom kam karna hai | button:Zoom out | miss, 20 pt | miss, 54 pt | miss, 54 pt | neeche right corner mein jo zoom slider hai, usko minus wale icon ki taraf drag kar lo. |
| 1 | spreadsheet | column ka total kaise nikalu? | toolbar:AutoSum | miss, 44 pt | miss, 56 pt | miss, 56 pt | total nikalne ke liye formula bar mein `=SUM(B2:B11)` type karke enter dabao, jaise yahan B2 se B11 tak ka sum ho raha hai. |
| 1 | spreadsheet | is data ka chart banana hai | toolbar:Insert chart | miss, 139 pt | miss, 181 pt | miss, 181 pt | chart banane ke liye pehle apna sara data select kar lo, row 1 se row 11 tak. |
| 1 | spreadsheet | data filter kaise karu? | toolbar:Filter | miss, 30 pt | miss, 40 pt | miss, 40 pt | data filter karne ke liye upar toolbar mein filter icon pe click kar sakte ho, yeh column headers ko sort aur filter karne mein help karega. |
| 2 | system-settings | wallpaper kaise badlu? | sidebar:Wallpaper | miss, 164 pt | miss, 164 pt (check too slow) | hit, 56 pt (label read) | system settings ke sidebar mein Wallpaper pe click karo, wahan se change kar sakte ho. |
| 2 | system-settings | battery ki health kahan dekhu? | sidebar:Battery | hit, 54 pt | hit, 64 pt | hit, 76 pt (label read) | battery ki health dekhne ke liye battery settings mein jana padega. sidebar mein niche Battery pe click karo. |
| 2 | system-settings | mac ki language hindi kaise karu? | row:Language & Region | hit, 6 pt | hit, 6 pt | hit, 6 pt | step 1: General settings mein Language and Region pe click karo. |
| 2 | system-settings | date aur time galat hai, kahan theek karu? | row:Date & Time | hit, 111 pt | hit, 111 pt | hit, 395 pt (label read) | date aur time change karne ke liye General settings mein Date and Time pe click karo. |
| 2 | system-settings | airdrop kahan se on hota hai? | row:AirDrop & Handoff | hit, 356 pt | hit, 356 pt | hit, 356 pt | general settings mein hi AirDrop and Handoff ka option hai, wahan click karo. |
| 2 | text-editor | is text ko bold kaise karu? | toolbar:Bold | hit, 0 pt | hit, 1 pt | hit, 1 pt | text ko select karke upar toolbar mein B pe click kar do. |
| 2 | text-editor | document mein table kaise daalu? | toolbar:Insert table | hit, 1 pt | hit, 0 pt | hit, 0 pt | toolbar mein table insert karne ka icon hai, uspe click karo. |
| 2 | text-editor | photo insert karni hai | toolbar:Insert photo | hit, 2 pt | hit, 0 pt | hit, 0 pt | photo insert karne ke liye top toolbar mein image icon pe click karo. |
| 2 | text-editor | ye document share kaise karu? | toolbar:Share | hit, 1 pt | hit, 1 pt | hit, 1 pt | document share karne ke liye top right corner mein jo share icon hai, uspe click karo. |
| 2 | text-editor | numbered list banani hai | toolbar:Numbered list | hit, 1 pt | hit, 1 pt | hit, 1 pt | toolbar mein jo numbered list ka icon hai, uspe click karo. |
| 2 | login-page | password bhool gaya, ab kya karu? | link:Forgot password? | hit, 1 pt | hit, 4 pt | hit, 2 pt (label read) | koi baat nahi, Sign in button ke paas hi Forgot password? link pe click kar lo. |
| 2 | login-page | naya account kaise banau? | link:Create an account | hit, 2 pt | hit, 2 pt | hit, 2 pt | yahan niche Create an account pe click karke naya account bana sakte ho. |
| 2 | login-page | google se login karna hai | button:Continue with Google | hit, 0 pt | hit, 17 pt | hit, 3 pt (label read) | continue with google pe click kar do. |
| 2 | login-page | remember me wala tick kahan hai? | checkbox:Remember me | hit, 48 pt | hit, 48 pt | hit, 2 pt (label read) | remember me ka checkbox yahan email aur password ke neeche hai. |
| 2 | login-page | email kahan daalu? | field:Email | hit, 1 pt | hit, 23 pt | hit, 23 pt | email field mein click karke apna email type kar do. |
| 2 | finder-file-menu | naya folder kaise banau? | menu:New Folder | hit, 72 pt | hit, 61 pt | hit, 83 pt (label read) | naya folder banane ke liye menu mein New Folder pe click karo. |
| 2 | finder-file-menu | is file ki info kaise dekhu? | menu:Get Info | hit, 83 pt | hit, 68 pt | hit, 94 pt (label read) | file ki info dekhne ke liye Get Info pe click karo, ya phir shortcut command i use karo. |
| 2 | finder-file-menu | file ko zip kaise karu? | menu:Compress | hit, 85 pt | hit, 83 pt | hit, 88 pt (label read) | file ko zip karne ke liye compress pe click karo. |
| 2 | finder-file-menu | ye file delete karni hai | menu:Move to Trash | miss, 396 pt | miss, 396 pt | miss, 396 pt | step 1: us file ya folder ko select karo jisko delete karna hai. |
| 2 | finder-file-menu | file ki copy banani hai | menu:Duplicate | hit, 131 pt | hit, 106 pt | hit, 90 pt (label read) | duplicate karne ke liye file menu mein Duplicate pe click karo. |
| 2 | save-dialog | bina save kiye band karna hai | button:Don't Save | hit, 16 pt | hit, 2 pt | hit, 2 pt (label read) | agar save nahi karna hai, toh don't save pe click kar do. |
| 2 | save-dialog | haan save kar do | button:Save | hit, 2 pt | hit, 2 pt | hit, 2 pt (label read) | save karne ke liye blue Save button pe click kar do. |
| 2 | save-dialog | ruko, abhi band nahi karna | button:Cancel | hit, 1 pt | hit, 5 pt | hit, 1 pt (label read) | arey, cancel pe click kar do taaki document band na ho. |
| 2 | spreadsheet | nayi sheet kaise add karu? | button:Add sheet | hit, 1 pt | hit, 0 pt | hit, 0 pt | sheet1 ke paas jo plus ka icon hai, uspe click karo nayi sheet add karne ke liye. |
| 2 | spreadsheet | zoom thoda badhana hai | button:Zoom in | miss, 57 pt | miss, 55 pt | miss, 55 pt | neeche right corner mein jo zoom slider hai, usko aage badha do. |
| 2 | spreadsheet | zoom kam karna hai | button:Zoom out | hit, 2 pt | hit, 1 pt | hit, 1 pt | neeche right corner mein jo zoom slider hai, wahan minus button pe click karke zoom kam kar sakte ho. |
| 2 | spreadsheet | column ka total kaise nikalu? | toolbar:AutoSum | miss, 314 pt | miss, 362 pt | miss, 362 pt | sum formula use karne ke liye cell B12 mein equals to sign daalkar SUM type karo aur brackets ke andar B2 colon B11 likh do. |
| 2 | spreadsheet | is data ka chart banana hai | toolbar:Insert chart | miss, 183 pt | miss, 183 pt (check too slow) | miss, 183 pt | chart banane ke liye pehle apna sara data select kar lo. |
| 2 | spreadsheet | data filter kaise karu? | toolbar:Filter | hit, 2 pt | miss, 40 pt | miss, 40 pt | toolbar mein jo funnel jaisa filter icon hai, uspe click kar do, fir tum apne data ko easily sort ya filter kar paoge. |
