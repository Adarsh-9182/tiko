# Tiko pointing benchmark

Run 2026-09-15 17:08 · answered by gemini-flash-lite-latest · 29 questions on 6 screens × 2 runs = 58 attempts.

| Method | Hits | Hit rate | Median distance from centre | 90th percentile |
|---|---|---|---|---|
| Single guess on the full screenshot (Clicky's approach) | 32/58 | 55% | 39 pt | 369 pt |
| **Tiko: single guess + close-up check** | **49/58** | **84%** | **4 pt** | **339 pt** |

- The close-up check turned 17 misses into hits and 0 hits into misses.
- No point given: 0. Close-up check found nothing: 6 (first guess kept). Over the 5 s limit: 2 (first guess kept, as the app does).
- Median time to answer: 2.0 s. Median close-up check: 1.9 s.

## By screen

| Screen | Attempts | Single guess | With close-up check |
|---|---|---|---|
| [system-settings](screens/system-settings.png) | 10 | 5 (50%) | 5 (50%) |
| [text-editor](screens/text-editor.png) | 10 | 8 (80%) | 10 (100%) |
| [login-page](screens/login-page.png) | 10 | 6 (60%) | 10 (100%) |
| [finder-file-menu](screens/finder-file-menu.png) | 10 | 7 (70%) | 9 (90%) |
| [save-dialog](screens/save-dialog.png) | 6 | 0 (0%) | 5 (83%) |
| [spreadsheet](screens/spreadsheet.png) | 12 | 6 (50%) | 10 (83%) |

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
| 1 | system-settings | wallpaper kaise badlu? | sidebar:Wallpaper | miss, 628 pt | miss, 628 pt | step 1: sidebar mein Wallpaper pe click karo. |
| 1 | system-settings | battery ki health kahan dekhu? | sidebar:Battery | miss, 680 pt | miss, 680 pt | step 1: sidebar mein Battery pe click karo. |
| 1 | system-settings | mac ki language hindi kaise karu? | row:Language & Region | hit, 196 pt | hit, 335 pt | step 1: General settings mein Language and Region pe click karo. |
| 1 | system-settings | date aur time galat hai, kahan theek karu? | row:Date & Time | hit, 108 pt | hit, 108 pt | date aur time theek karne ke liye, general settings mein Date and Time par click karo. |
| 1 | system-settings | airdrop kahan se on hota hai? | row:AirDrop & Handoff | miss, 285 pt | miss, 285 pt (check too slow) | airdrop on karne ke liye General settings mein AirDrop and Handoff pe click karo. |
| 1 | text-editor | is text ko bold kaise karu? | toolbar:Bold | hit, 6 pt | hit, 1 pt | is text ko bold karne ke liye pehle isko select karo, phir upar toolbar mein B pe click kar dena. |
| 1 | text-editor | document mein table kaise daalu? | toolbar:Insert table | hit, 3 pt | hit, 1 pt | table add karne ke liye upar toolbar mein table icon pe click karo. |
| 1 | text-editor | photo insert karni hai | toolbar:Insert photo | hit, 8 pt | hit, 0 pt | photo add karne ke liye upar toolbar mein image icon pe click karo. |
| 1 | text-editor | ye document share kaise karu? | toolbar:Share | hit, 19 pt | hit, 1 pt | yeh document share karne ke liye top right corner mein share button pe click karo. |
| 1 | text-editor | numbered list banani hai | toolbar:Numbered list | miss, 46 pt | hit, 0 pt | step 1: upar toolbar mein numbered list icon pe click karo. |
| 1 | login-page | password bhool gaya, ab kya karu? | link:Forgot password? | hit, 6 pt | hit, 1 pt | forgot password link pe click karo, wahan se reset kar paoge. |
| 1 | login-page | naya account kaise banau? | link:Create an account | miss, 35 pt | hit, 1 pt | niche create an account pe click karo, wahan se naya account ban jayega. |
| 1 | login-page | google se login karna hai | button:Continue with Google | hit, 2 pt | hit, 15 pt | google se sign in karne ke liye niche Continue with Google pe click karo. |
| 1 | login-page | remember me wala tick kahan hai? | checkbox:Remember me | miss, 86 pt | hit, 48 pt | yeh raha remember me box, ispe click karke tick kar sakte ho. |
| 1 | login-page | email kahan daalu? | field:Email | miss, 195 pt | hit, 47 pt | email field mein click karke apni email type kar do. |
| 1 | finder-file-menu | naya folder kaise banau? | menu:New Folder | miss, 74 pt | hit, 81 pt | new folder banane ke liye File menu mein jaakar New Folder pe click karo, ya phir command shift aur N dabao. |
| 1 | finder-file-menu | is file ki info kaise dekhu? | menu:Get Info | hit, 66 pt | hit, 73 pt | is folder ki info dekhne ke liye isko select karke Get Info pe click karo, ya phir command i daba do. |
| 1 | finder-file-menu | file ko zip kaise karu? | menu:Compress | hit, 59 pt | hit, 59 pt (check too slow) | file ko zip karne ke liye usko select karo aur fir menu mein Compress pe click karo. |
| 1 | finder-file-menu | ye file delete karni hai | menu:Move to Trash | miss, 429 pt | miss, 417 pt | file delete karne ke liye usko trash mein daalna padega. pehle file pe click karke select karo. |
| 1 | finder-file-menu | file ki copy banani hai | menu:Duplicate | hit, 125 pt | hit, 100 pt | file ki duplicate copy banane ke liye, is menu mein Duplicate pe click karo. |
| 1 | save-dialog | bina save kiye band karna hai | button:Don't Save | miss, 26 pt | hit, 4 pt | agar save nahi karna hai toh Don't Save pe click kar do. |
| 1 | save-dialog | haan save kar do | button:Save | miss, 27 pt | hit, 1 pt | agar changes rakhne hain toh Save pe click kar do. |
| 1 | save-dialog | ruko, abhi band nahi karna | button:Cancel | miss, 30 pt | hit, 1 pt | achha theek hai, cancel pe click kar do taaki document band na ho. |
| 1 | spreadsheet | nayi sheet kaise add karu? | button:Add sheet | miss, 1062 pt | miss, 1062 pt | nayi sheet add karne ke liye sheet one ke paas plus button pe click karo. |
| 1 | spreadsheet | zoom thoda badhana hai | button:Zoom in | miss, 32 pt | hit, 1 pt | bottom right corner mein zoom slider hai, wahan plus icon pe click karo. |
| 1 | spreadsheet | zoom kam karna hai | button:Zoom out | hit, 2 pt | hit, 1 pt | zoom kam karne ke liye bottom right corner mein minus icon pe click karo. |
| 1 | spreadsheet | column ka total kaise nikalu? | toolbar:AutoSum | miss, 35 pt | hit, 1 pt | column ka total nikalne ke liye top toolbar mein sum icon pe click karo, ya phir type karo equal sum bracket mein cells ke naam. |
| 1 | spreadsheet | is data ka chart banana hai | toolbar:Insert chart | hit, 1 pt | hit, 1 pt | yeh dekho, upar toolbar mein chart ka icon hai, uspe click karo. |
| 1 | spreadsheet | data filter kaise karu? | toolbar:Filter | miss, 39 pt | hit, 1 pt | column headers select karke top toolbar mein filter icon pe click karo, fir data sort aur filter ho jayega. |
| 2 | system-settings | wallpaper kaise badlu? | sidebar:Wallpaper | miss, 640 pt | miss, 640 pt | step 1: sidebar mein Wallpaper par click karo. |
| 2 | system-settings | battery ki health kahan dekhu? | sidebar:Battery | miss, 673 pt | miss, 673 pt | step 1: sidebar mein Battery pe click karo. |
| 2 | system-settings | mac ki language hindi kaise karu? | row:Language & Region | hit, 196 pt | hit, 335 pt | step 1: General mein Language and Region par click karo. |
| 2 | system-settings | date aur time galat hai, kahan theek karu? | row:Date & Time | hit, 314 pt | hit, 339 pt | general settings mein niche Date and Time pe click karo. |
| 2 | system-settings | airdrop kahan se on hota hai? | row:AirDrop & Handoff | hit, 369 pt | hit, 303 pt | step 1: General settings mein AirDrop and Handoff pe click karo. |
| 2 | text-editor | is text ko bold kaise karu? | toolbar:Bold | hit, 21 pt | hit, 1 pt | ise bold karne ke liye pehle text ko select karo, phir upar toolbar mein B icon pe click kar dena. |
| 2 | text-editor | document mein table kaise daalu? | toolbar:Insert table | hit, 18 pt | hit, 0 pt | table add karne ke liye upar toolbar mein table icon pe click karo. |
| 2 | text-editor | photo insert karni hai | toolbar:Insert photo | hit, 3 pt | hit, 1 pt | upar toolbar mein photo wale icon pe click karo, wahan se image insert kar sakte ho. |
| 2 | text-editor | ye document share kaise karu? | toolbar:Share | hit, 3 pt | hit, 1 pt | yeh document share karne ke liye upar right corner mein jo share icon hai, uspe click karo. |
| 2 | text-editor | numbered list banani hai | toolbar:Numbered list | miss, 46 pt | hit, 0 pt | step 1: upar toolbar mein numbered list icon pe click karo. |
| 2 | login-page | password bhool gaya, ab kya karu? | link:Forgot password? | hit, 7 pt | hit, 1 pt | arey, koi baat nahi, yahan blue color mein forgot password ka option hai us pe click kar lo. |
| 2 | login-page | naya account kaise banau? | link:Create an account | hit, 8 pt | hit, 4 pt | naye account ke liye niche diye hue create an account pe click karo. |
| 2 | login-page | google se login karna hai | button:Continue with Google | hit, 1 pt | hit, 0 pt | google se sign in karne ke liye niche wale button pe click karo. |
| 2 | login-page | remember me wala tick kahan hai? | checkbox:Remember me | miss, 88 pt | hit, 47 pt | yeh raha remember me box, ispe click karke tick kar sakte ho. |
| 2 | login-page | email kahan daalu? | field:Email | hit, 0 pt | hit, 45 pt | email address dalne ke liye upar wale box mein click karo. |
| 2 | finder-file-menu | naya folder kaise banau? | menu:New Folder | miss, 79 pt | hit, 82 pt | naya folder banane ke liye File menu mein jaakar New Folder pe click karo, ya phir command, shift aur n keys ek saath dabao. |
| 2 | finder-file-menu | is file ki info kaise dekhu? | menu:Get Info | hit, 75 pt | hit, 68 pt | isse select karke File menu mein Get Info pe click karo. |
| 2 | finder-file-menu | file ko zip kaise karu? | menu:Compress | hit, 75 pt | hit, 87 pt | file ko zip karne ke liye, pehle usko select karo aur phir dropdown menu se Compress pe click karo. |
| 2 | finder-file-menu | ye file delete karni hai | menu:Move to Trash | hit, 72 pt | hit, 69 pt | agar isko delete karna hai toh isko select karke menu mein Move to Trash pe click kar do. |
| 2 | finder-file-menu | file ki copy banani hai | menu:Duplicate | hit, 130 pt | hit, 63 pt | file ki duplicate copy banane ke liye is menu mein Duplicate pe click kar do. |
| 2 | save-dialog | bina save kiye band karna hai | button:Don't Save | miss, 26 pt | hit, 2 pt | ager save nahi karna hai toh Don't Save pe click kar do. |
| 2 | save-dialog | haan save kar do | button:Save | miss, 30 pt | hit, 1 pt | save button pe click kar do. |
| 2 | save-dialog | ruko, abhi band nahi karna | button:Cancel | miss, 95 pt | miss, 95 pt | theek hai, changes bachane ke liye save pe click kar do. |
| 2 | spreadsheet | nayi sheet kaise add karu? | button:Add sheet | hit, 2 pt | hit, 1 pt | nayi sheet add karne ke liye sheet one ke paas wale plus button par click karo. |
| 2 | spreadsheet | zoom thoda badhana hai | button:Zoom in | miss, 39 pt | hit, 1 pt | bottom right corner mein zoom slider hai, wahan plus icon pe click karo. |
| 2 | spreadsheet | zoom kam karna hai | button:Zoom out | hit, 2 pt | hit, 0 pt | bottom right corner mein minus icon pe click karo zoom kam karne ke liye. |
| 2 | spreadsheet | column ka total kaise nikalu? | toolbar:AutoSum | hit, 11 pt | hit, 1 pt | toolbar mein jo sum ka icon hai, usko click karke enter daba do. |
| 2 | spreadsheet | is data ka chart banana hai | toolbar:Insert chart | hit, 1 pt | hit, 1 pt | is data ka chart banane ke liye pehle poore table ko select karo, fir upar toolbar mein chart icon pe click karo. |
| 2 | spreadsheet | data filter kaise karu? | toolbar:Filter | miss, 34 pt | miss, 40 pt | data filter karne ke liye upar toolbar mein filter button pe click karo. |
