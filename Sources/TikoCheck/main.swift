import AppKit
import AVFoundation
import Foundation
import TikoCore
import TikoFixtures

// Checks Tiko's logic without its UI or any macOS permissions.
//   swift run TikoCheck          offline checks only
//   swift run TikoCheck --live   also asks Gemini real questions: pointing on a
//                                rendered screen and a two-step guided tour
//                                (needs a key: GEMINI_API_KEY, or one saved in Tiko's panel)
// For accuracy numbers across many screens, run `swift run TikoBenchmark`.

var failedCheckCount = 0

func check(_ condition: Bool, _ description: String) {
    if condition {
        print("  ok    \(description)")
    } else {
        failedCheckCount += 1
        print("  FAIL  \(description)")
    }
}

func element<Element>(_ array: [Element], at index: Int) -> Element? {
    array.indices.contains(index) ? array[index] : nil
}

// MARK: - Request body

print("Gemini request body")
let requestBody = GeminiClient.makeRequestBody(
    systemInstruction: "be tiko",
    history: [ConversationExchange(userText: "hi", tikoReply: "hello")],
    images: [GeminiImage(jpegData: Data([0xFF, 0xD8]), label: "screen 1 of 1, cursor is here:")],
    userText: "save button kahan hai?"
)
let requestContents = requestBody["contents"] as? [[String: Any]] ?? []
check(requestContents.count == 3, "earlier question and reply, then the new question")
check(element(requestContents, at: 1)?["role"] as? String == "model", "Tiko's earlier reply uses the model role")
let questionParts = requestContents.last?["parts"] as? [[String: Any]] ?? []
check(questionParts.count == 3, "image label, image, question")
check((element(questionParts, at: 1)?["inline_data"] as? [String: Any])?["mime_type"] as? String == "image/jpeg", "screenshot is sent inline as JPEG")
check(questionParts.last?["text"] as? String == "save button kahan hai?", "question comes after the images")
let systemInstructionParts = (requestBody["system_instruction"] as? [String: Any])?["parts"] as? [[String: Any]]
check(systemInstructionParts?.first?["text"] as? String == "be tiko", "system instruction is set")

// MARK: - Responses

print("Gemini responses")
let thinkingModelResponse = Data(#"{"candidates":[{"content":{"parts":[{"text":"let me look","thought":true},{"text":"Appearance pe click karo."}]},"finishReason":"STOP"}]}"#.utf8)
check((try? GeminiClient.extractReplyText(from: thinkingModelResponse)) == "Appearance pe click karo.", "skips a thinking model's reasoning")

let blockedPromptResponse = Data(#"{"promptFeedback":{"blockReason":"SAFETY"}}"#.utf8)
do {
    _ = try GeminiClient.extractReplyText(from: blockedPromptResponse)
    check(false, "reports a blocked prompt")
} catch {
    check(error as? GeminiClientError == .noReplyText(reason: "SAFETY"), "reports a blocked prompt")
}

let invalidKeyResponse = Data(#"{"error":{"code":400,"message":"API key not valid. Please pass a valid API key.","status":"INVALID_ARGUMENT"}}"#.utf8)
check(GeminiClient.classifyResponse(statusCode: 200, responseData: Data()) == .success, "200 is a success")
check(GeminiClient.classifyResponse(statusCode: 429, responseData: Data()) == .tryNextModel(isBusy: true), "rate limit moves on to the next model")
check(GeminiClient.classifyResponse(statusCode: 404, responseData: Data()) == .tryNextModel(isBusy: false), "unavailable model moves on to the next model")
check(GeminiClient.classifyResponse(statusCode: 400, responseData: invalidKeyResponse) == .fail(.invalidAPIKey), "bad key is reported as a bad key")

let modelListResponse = Data(#"{"models":[{"name":"models/gemini-flash-lite-latest","supportedGenerationMethods":["generateContent","countTokens"]},{"name":"models/text-embedding-004","supportedGenerationMethods":["embedContent"]}]}"#.utf8)
check((try? GeminiClient.parseGenerateContentModelNames(from: modelListResponse)) == ["gemini-flash-lite-latest"], "model list keeps only models that can answer, without the models/ prefix")

// MARK: - Model choice

print("Model choice")
let pickedModelNames = GeminiModelPicker.preferredModelNames(from: [
    "gemini-3.8-flash",
    "gemini-flash-latest",
    "gemini-flash-lite-latest",
    "gemini-3.7-flash-lite",
    "gemini-3.8-flash-image",
    "gemini-3.9-flash-preview",
    "text-embedding-004"
])
check(pickedModelNames == ["gemini-flash-lite-latest", "gemini-flash-latest", "gemini-3.7-flash-lite"], "lite first, then flash; image, preview and embedding models skipped")

// MARK: - Point tags

print("Point tags")
let appearanceReply = PointTag.parse("left sidebar mein Appearance pe click karo. [POINT:88,309:Appearance]")
check(appearanceReply.displayText == "left sidebar mein Appearance pe click karo.", "the tag is removed from the text the user sees")
check(appearanceReply.normalizedPoint == CGPoint(x: 88, y: 309), "coordinates are read")
check(appearanceReply.elementLabel == "Appearance" && appearanceReply.screenNumber == nil, "label is read; no screen number means the cursor's screen")

let otherScreenReply = PointTag.parse("wo terminal dusri screen pe hai. [POINT:400,300:terminal:screen2]")
check(otherScreenReply.elementLabel == "terminal" && otherScreenReply.screenNumber == 2, "label and screen number are both read")

let noPointReply = PointTag.parse("html web page ka dhaancha hai. [POINT:none]")
check(noPointReply.normalizedPoint == nil && noPointReply.displayText == "html web page ka dhaancha hai.", "[POINT:none] means no pointing")

let untaggedReply = PointTag.parse("bas itna hi")
check(untaggedReply.normalizedPoint == nil && untaggedReply.displayText == "bas itna hi", "a reply without a tag is left as it is")

let spacedReply = PointTag.parse("yahan dabao [POINT: 120 , 880 : save button ]")
check(spacedReply.normalizedPoint == CGPoint(x: 120, y: 880) && spacedReply.elementLabel == "save button", "tolerates spaces the model adds")

let offScreenReply = PointTag.parse("upar menu bar mein. [POINT:-4,1003:menu bar]")
check(offScreenReply.normalizedPoint == CGPoint(x: -4, y: 1003), "slightly off-screen coordinates are kept, not dropped")

// Formats the benchmark caught Gemini sending instead of the requested colons.
let commaLabelReply = PointTag.parse("upar toolbar mein filter button pe click karo. [POINT:185,119,filter button]")
check(
    commaLabelReply.normalizedPoint == CGPoint(x: 185, y: 119) && commaLabelReply.elementLabel == "filter button"
        && commaLabelReply.displayText == "upar toolbar mein filter button pe click karo.",
    "a comma before the label still counts as a point"
)
let commaScreenReply = PointTag.parse("wo doosri screen pe hai. [POINT:400,300,terminal,screen2]")
check(commaScreenReply.elementLabel == "terminal" && commaScreenReply.screenNumber == 2, "commas before the label and screen number both work")
let screenWithoutLabelReply = PointTag.parse("yahan dekho [POINT:400,300:screen2]")
check(screenWithoutLabelReply.screenNumber == 2 && screenWithoutLabelReply.elementLabel == nil, "a screen number without a label isn't mistaken for a label")

// MARK: - Guided tours

print("Guided tours")
let stepWithMore = TourTag.strip("step 1: Bluetooth pe click karo. [POINT:40,200:Bluetooth] [MORE]")
check(stepWithMore.hasMoreSteps && stepWithMore.text == "step 1: Bluetooth pe click karo. [POINT:40,200:Bluetooth]", "[MORE] marks more steps and is removed")
check(PointTag.parse(stepWithMore.text).normalizedPoint == CGPoint(x: 40, y: 200), "the point tag still reads once [MORE] is removed")
check(!TourTag.strip("bas, ho gaya. [POINT:none]").hasMoreSteps, "a reply without [MORE] ends the tour")
check(TourTag.removingLeadingStepNumber("step 1: Appearance pe click karo.") == "Appearance pe click karo.", "a lone \"step 1:\" is dropped outside a tour")
check(TourTag.removingLeadingStepNumber("Appearance ke step 2 mein dekho") == "Appearance ke step 2 mein dekho", "\"step\" in the middle of a reply is left alone")

check(TourCommand.isNextStepRequest("Next."), "\"Next.\" asks for the next step")
check(TourCommand.isNextStepRequest("ho gaya"), "\"ho gaya\" asks for the next step")
check(TourCommand.isNextStepRequest("Aage bolo"), "\"Aage bolo\" asks for the next step")
check(!TourCommand.isNextStepRequest("next time ye kaise karu"), "a real question isn't mistaken for \"next\"")

let bluetoothTour = GuidedTour(goal: "bluetooth band kaise karu", shownSteps: ["step 1: sidebar mein Bluetooth pe click karo."])
let nextStepRequest = CompanionPrompt.nextTourStepRequest(for: bluetoothTour)
check(
    bluetoothTour.nextStepNumber == 2
        && nextStepRequest.contains("bluetooth band kaise karu")
        && nextStepRequest.contains("1. step 1: sidebar mein Bluetooth pe click karo.")
        && nextStepRequest.contains("give only step 2"),
    "the next-step request carries the goal, the steps so far and the step number"
)

// MARK: - Screen coordinates

print("Screen coordinates")
let laptopDisplayFrame = CGRect(x: 0, y: 0, width: 1470, height: 956)
let laptopDisplayBounds = CGRect(origin: .zero, size: laptopDisplayFrame.size)
check(ScreenCoordinates.point(fromNormalized: CGPoint(x: 500, y: 500), in: laptopDisplayBounds) == CGPoint(x: 735, y: 478), "the grid's centre is the display's centre")
check(ScreenCoordinates.point(fromNormalized: CGPoint(x: -4, y: 1003), in: laptopDisplayBounds) == CGPoint(x: 0, y: 956), "off-grid coordinates are clamped onto the display")
check(ScreenCoordinates.point(fromNormalized: CGPoint(x: 500, y: 250), in: CGRect(x: 100, y: 200, width: 400, height: 400)) == CGPoint(x: 300, y: 300), "a point on a close-up maps back to display points")
check(ScreenCoordinates.appKitGlobalPoint(fromDisplayPoint: .zero, displayFrame: laptopDisplayFrame) == CGPoint(x: 0, y: 956), "a display's top-left is at the top in AppKit space")
let externalDisplayFrame = CGRect(x: 1470, y: -124, width: 1920, height: 1080)
check(ScreenCoordinates.appKitGlobalPoint(fromDisplayPoint: CGPoint(x: 1920, y: 1080), displayFrame: externalDisplayFrame) == CGPoint(x: 3390, y: -124), "a second display's corner lands in the right global place")

// MARK: - Close-up regions

print("Close-up regions")
check(
    CloseUpRegion.captureRect(centeredOn: CGPoint(x: 700, y: 400), displaySize: laptopDisplayFrame.size, regionSize: 360)
        == CGRect(x: 520, y: 220, width: 360, height: 360),
    "centred on the given point"
)
check(
    CloseUpRegion.captureRect(centeredOn: CGPoint(x: 10, y: 950), displaySize: laptopDisplayFrame.size, regionSize: 360)
        == CGRect(x: 0, y: 596, width: 360, height: 360),
    "slides back inside the display at a corner"
)
let cursorCloseUpLabel = CompanionPrompt.cursorCloseUpLabel(
    screenNumber: 1,
    regionInDisplay: CGRect(x: 540, y: 270, width: 360, height: 360),
    displaySize: CGSize(width: 1440, height: 900)
)
check(
    cursorCloseUpLabel.contains("x 375 to 625") && cursorCloseUpLabel.contains("y 300 to 700"),
    "the cursor close-up says which part of the screen it shows, on the 0–1000 grid"
)

// MARK: - Buddy flight

print("Buddy flight")
let rightwardFlight = BuddyFlight(from: CGPoint(x: 100, y: 500), to: CGPoint(x: 900, y: 500))
check(rightwardFlight.duration == 1.0, "an 800-point flight takes one second")
check(rightwardFlight.pose(afterSeconds: 0).position == CGPoint(x: 100, y: 500), "starts where the buddy is")
check(rightwardFlight.pose(afterSeconds: rightwardFlight.duration).position == CGPoint(x: 900, y: 500), "lands exactly on the target")
check(rightwardFlight.pose(afterSeconds: 0.5).position.y < 500, "arcs upward on the way")
check(rightwardFlight.pose(afterSeconds: 0.5).scale > 1.25, "swells mid-flight")
check(abs(rightwardFlight.pose(afterSeconds: 0).rotationDegrees - 90) < 30, "faces its direction of travel")

// MARK: - Speech

/// Lets exactly one of two racing callbacks resume a continuation.
final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var hasResumed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !hasResumed else { return false }
        hasResumed = true
        return true
    }
}

/// Renders speech into memory instead of through the speakers, so the check is silent.
/// Returns 0 if no audio arrives within 15 seconds.
func synthesizedAudioFrameCount(of text: String, voice: AVSpeechSynthesisVoice) async -> Int {
    let speechSynthesizer = AVSpeechSynthesizer()
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = voice
    let resumeOnce = ResumeOnce()

    let audioFrameCount = await withCheckedContinuation { continuation in
        var totalFrameCount = 0
        speechSynthesizer.write(utterance) { audioBuffer in
            guard let pcmBuffer = audioBuffer as? AVAudioPCMBuffer else { return }
            if pcmBuffer.frameLength == 0 {
                // An empty buffer marks the end of the utterance.
                if resumeOnce.claim() {
                    continuation.resume(returning: totalFrameCount)
                }
            } else {
                totalFrameCount += Int(pcmBuffer.frameLength)
            }
        }
        Task {
            try? await Task.sleep(for: .seconds(15))
            if resumeOnce.claim() {
                continuation.resume(returning: 0)
            }
        }
    }
    // Keep the synthesizer alive until rendering has finished.
    withExtendedLifetime(speechSynthesizer) {}
    return audioFrameCount
}

print("Speech")
check(
    SpokenText.prepare("**Appearance** pe click karo, `file_name.txt` kholo") == "Appearance pe click karo, file name.txt kholo",
    "formatting symbols aren't read aloud"
)
check(
    SpokenText.prepare("docs yahan hain: https://example.com/docs dekh lo") == "docs yahan hain: link dekh lo",
    "a web address is said as \"link\""
)
if let chosenVoice = SpeechVoicePicker.bestVoice() {
    print("  voice on this Mac: \(chosenVoice.name), \(chosenVoice.language), \(SpeechVoicePicker.qualityName(of: chosenVoice)) quality")
    check(!chosenVoice.voiceTraits.contains(.isNoveltyVoice), "never picks a novelty voice")
    let audioFrameCount = await synthesizedAudioFrameCount(of: "Appearance pe click karo, wahan dark mode mil jayega.", voice: chosenVoice)
    check(audioFrameCount > 0, "the voice turns a Hinglish reply into audio (\(audioFrameCount) frames, rendered silently)")
} else {
    check(false, "the Mac has a speech voice installed")
}

// MARK: - Push-to-talk shortcuts

print("Push-to-talk shortcuts")
// Raw CGEventFlags bits: shift 0x20000, control 0x40000, option 0x80000,
// command 0x100000; 0x20 and 0x40 mark the left and right Option keys.
check(PushToTalkShortcut.controlOption.isHeld(modifierFlagsRawValue: 0x40000 | 0x80000 | 0x20), "⌃⌥ is recognised")
check(!PushToTalkShortcut.controlOption.isHeld(modifierFlagsRawValue: 0x40000 | 0x80000 | 0x100000), "⌃⌥ with ⌘ added is a different shortcut")
check(!PushToTalkShortcut.controlOption.isHeld(modifierFlagsRawValue: 0x40000), "⌃ alone isn't ⌃⌥")
check(PushToTalkShortcut.optionCommand.isHeld(modifierFlagsRawValue: 0x80000 | 0x100000 | 0x20), "⌥⌘ is recognised")
check(!PushToTalkShortcut.optionCommand.isHeld(modifierFlagsRawValue: 0x80000 | 0x100000 | 0x20000), "⌥⌘ with ⇧ added is a different shortcut")
check(PushToTalkShortcut.rightOption.isHeld(modifierFlagsRawValue: 0x80000 | 0x40), "right ⌥ alone is recognised")
check(!PushToTalkShortcut.rightOption.isHeld(modifierFlagsRawValue: 0x80000 | 0x20), "left ⌥ doesn't count as right ⌥")
check(!PushToTalkShortcut.rightOption.isHeld(modifierFlagsRawValue: 0x80000 | 0x40 | 0x20), "both ⌥ keys together don't count")

// MARK: - Languages and voices

print("Languages and voices")
check(SpeechLanguage.allCases.map(\.localeIdentifier) == ["en-IN", "en-US", "hi-IN"], "Hinglish first, then US English and Hindi")
let voiceOptions = SpeechVoicePicker.voiceOptions()
print("  voices offered on this Mac: \(voiceOptions.count)")
check(!voiceOptions.isEmpty, "Settings has voices to offer")
check(voiceOptions.first?.language == "en-IN", "Indian English voices are listed first")
check(SpeechVoicePicker.voice(withIdentifier: "no.such.voice")?.identifier == SpeechVoicePicker.bestVoice()?.identifier, "a voice that's gone from the Mac falls back to the best installed one")

// MARK: - History

print("History")
var conversationLog = ConversationLog()
for questionIndex in 1...(ConversationLog.maximumEntryCount + 5) {
    conversationLog.append(ConversationLogEntry(question: "sawaal \(questionIndex)", reply: "jawab \(questionIndex)"))
}
check(conversationLog.entries.count == ConversationLog.maximumEntryCount, "history keeps at most \(ConversationLog.maximumEntryCount) answers")
check(conversationLog.entries.first?.question == "sawaal 6", "the oldest answers are the ones dropped")

let temporaryHistoryFolderURL = FileManager.default.temporaryDirectory.appendingPathComponent("tiko-history-check-\(UUID().uuidString)")
let temporaryHistoryFileURL = temporaryHistoryFolderURL.appendingPathComponent("history.json")
do {
    try conversationLog.save(to: temporaryHistoryFileURL)
    check(ConversationLog.load(from: temporaryHistoryFileURL) == conversationLog, "history survives a save and load")
    let historyFileAttributes = try FileManager.default.attributesOfItem(atPath: temporaryHistoryFileURL.path)
    check((historyFileAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o600, "history file is readable only by this user")
} catch {
    check(false, "saving history failed: \(error)")
}
try? FileManager.default.removeItem(at: temporaryHistoryFolderURL)
conversationLog.removeAll()
check(conversationLog.entries.isEmpty, "clearing history removes every answer")

// MARK: - Benchmark screens

print("Benchmark screens")
let benchmarkScreens = PointingBenchmark.renderScreens(scale: 1)
check(benchmarkScreens.count == PointingBenchmark.screenNames.count, "every benchmark screen renders")
let casesWithMissingTargets = PointingBenchmark.cases.filter { benchmarkCase in
    benchmarkScreens[benchmarkCase.screenName]?.elementRects[benchmarkCase.targetElementKey] == nil
}
check(
    casesWithMissingTargets.isEmpty,
    "every benchmark question's target is drawn on its screen\(casesWithMissingTargets.isEmpty ? "" : " (missing: \(casesWithMissingTargets.map(\.targetElementKey).joined(separator: ", ")))")"
)
let offScreenTargets = PointingBenchmark.cases.filter { benchmarkCase in
    guard let screen = benchmarkScreens[benchmarkCase.screenName],
          let targetRect = screen.elementRects[benchmarkCase.targetElementKey] else { return false }
    return !CGRect(origin: .zero, size: screen.pointSize).contains(targetRect)
}
check(offScreenTargets.isEmpty, "every benchmark target lies fully on its screen")

// MARK: - Settings

print("Settings file")
let temporarySettingsFolderURL = FileManager.default.temporaryDirectory.appendingPathComponent("tiko-check-\(UUID().uuidString)")
let temporarySettingsFileURL = temporarySettingsFolderURL.appendingPathComponent("settings.json")
let settingsToSave = TikoSettings(geminiAPIKey: "test-key", geminiModelNames: ["gemini-flash-lite-latest"])
do {
    try settingsToSave.save(to: temporarySettingsFileURL)
    check(TikoSettings.load(from: temporarySettingsFileURL) == settingsToSave, "settings survive a save and load")
    let fileAttributes = try FileManager.default.attributesOfItem(atPath: temporarySettingsFileURL.path)
    let filePermissions = (fileAttributes[.posixPermissions] as? NSNumber)?.intValue
    check(filePermissions == 0o600, "settings file is readable only by this user")
} catch {
    check(false, "saving settings failed: \(error)")
}
try? FileManager.default.removeItem(at: temporarySettingsFolderURL)
check(TikoSettings.load(from: temporarySettingsFileURL) == TikoSettings(), "a missing settings file loads as empty settings")

// MARK: - Live

/// A point on the element's row, not only on its letters or knob, counts as a hit.
func hitArea(of elementRect: CGRect) -> CGRect {
    elementRect.insetBy(dx: -16, dy: -12)
}

func describe(_ point: CGPoint, against targetRect: CGRect) -> String {
    let distanceFromCentre = Int(hypot(point.x - targetRect.midX, point.y - targetRect.midY))
    return "(\(Int(point.x)), \(Int(point.y))), \(distanceFromCentre)pt from centre"
}

func fullScreenImage(of screen: SyntheticScreen) -> GeminiImage {
    GeminiImage(
        jpegData: screen.screenshotJPEG(longestSide: 1280) ?? Data(),
        label: CompanionPrompt.screenLabel(screenNumber: 1, screenCount: 1, isCursorScreen: true)
    )
}

if CommandLine.arguments.contains("--live") {
    print("Live Gemini")
    let apiKey = TikoSettings.load().resolvedGeminiAPIKey
    if apiKey.isEmpty {
        print("  FAIL  no key: set GEMINI_API_KEY or save a key in Tiko's panel")
        failedCheckCount += 1
    } else if let generalScreen = SyntheticScreens.systemSettings(name: "general", selectedPane: "General", paneRows: ["About", "Software Update", "Storage", "Login Items"]) {
        do {
            let availableModelNames = try await GeminiClient(apiKey: apiKey, modelNames: []).fetchAvailableModelNames()
            let preferredModelNames = GeminiModelPicker.preferredModelNames(from: availableModelNames)
            print("  models to use, best first: \(preferredModelNames.joined(separator: ", "))")
            check(!preferredModelNames.isEmpty, "the key can reach at least one suitable model")

            let geminiClient = GeminiClient(apiKey: apiKey, modelNames: preferredModelNames)
            let generalScreenBounds = CGRect(origin: .zero, size: generalScreen.pointSize)

            // Pointing: one-action questions, first guess vs zoom check.
            let pointingQuestions: [(question: String, expectedElementKey: String)] = [
                ("bhai dark mode kaise on karu?", "sidebar:Appearance"),
                ("bluetooth ki settings kahan hai?", "sidebar:Bluetooth"),
                ("storage kitna bacha hai kaise dekhu?", "row:Storage"),
                ("login items kahan milenge?", "row:Login Items")
            ]

            var pointedAnswerCount = 0
            var firstGuessHitCount = 0
            var zoomCheckedHitCount = 0

            print("  pointing on the fake screen:")
            for pointingQuestion in pointingQuestions {
                guard let expectedRect = generalScreen.elementRects[pointingQuestion.expectedElementKey] else { continue }

                let reply = try await geminiClient.generateReply(
                    systemInstruction: CompanionPrompt.systemInstruction(canSeeScreen: true),
                    history: [],
                    images: [fullScreenImage(of: generalScreen)],
                    userText: pointingQuestion.question
                )
                let parsedReply = PointTag.parse(TourTag.strip(reply.text).text)
                print("    \"\(pointingQuestion.question)\" → \(parsedReply.displayText)")

                guard let normalizedPoint = parsedReply.normalizedPoint else {
                    print("      no point given")
                    continue
                }
                pointedAnswerCount += 1

                let firstGuess = ScreenCoordinates.point(fromNormalized: normalizedPoint, in: generalScreenBounds)
                let regionRect = CloseUpRegion.captureRect(centeredOn: firstGuess, displaySize: generalScreen.pointSize, regionSize: 400)
                var zoomCheckedPoint: CGPoint?
                if let regionJPEG = generalScreen.regionJPEG(rectInPoints: regionRect) {
                    zoomCheckedPoint = await PointRefiner.refinePoint(
                        elementLabel: parsedReply.elementLabel ?? "the element",
                        userQuestion: pointingQuestion.question,
                        regionRect: regionRect,
                        regionJPEG: regionJPEG,
                        geminiClient: geminiClient
                    )
                }
                let finalPoint = zoomCheckedPoint ?? firstGuess

                let firstGuessHit = hitArea(of: expectedRect).contains(firstGuess)
                let finalPointHit = hitArea(of: expectedRect).contains(finalPoint)
                if firstGuessHit { firstGuessHitCount += 1 }
                if finalPointHit { zoomCheckedHitCount += 1 }

                print("      label \"\(parsedReply.elementLabel ?? "none")\", target \(pointingQuestion.expectedElementKey)")
                print("      first guess  \(describe(firstGuess, against: expectedRect)) \(firstGuessHit ? "HIT" : "miss")")
                if let zoomCheckedPoint {
                    print("      zoom-checked \(describe(zoomCheckedPoint, against: expectedRect)) \(finalPointHit ? "HIT" : "miss")")
                } else {
                    print("      zoom check found nothing; kept the first guess")
                }
            }

            print("  result: first guess \(firstGuessHitCount)/\(pointingQuestions.count) hits, with zoom check \(zoomCheckedHitCount)/\(pointingQuestions.count) hits")
            check(pointedAnswerCount > 0, "Gemini points when asked where something is")

            // Guided tour: step 1 on the General pane, step 2 on the Bluetooth pane
            // the user would see after doing step 1.
            print("  guided tour across two fake screens:")
            let tourGoal = "mujhe step by step batao bluetooth kaise band karu"

            let firstStepReply = try await geminiClient.generateReply(
                systemInstruction: CompanionPrompt.systemInstruction(canSeeScreen: true),
                history: [],
                images: [fullScreenImage(of: generalScreen)],
                userText: tourGoal
            )
            let firstStepTourTag = TourTag.strip(firstStepReply.text)
            let firstStep = PointTag.parse(firstStepTourTag.text)
            let firstStepHit = firstStep.normalizedPoint.map { normalizedPoint in
                generalScreen.elementRects["sidebar:Bluetooth"].map { hitArea(of: $0).contains(ScreenCoordinates.point(fromNormalized: normalizedPoint, in: generalScreenBounds)) } ?? false
            } ?? false
            print("    step 1 → \(firstStep.displayText)")
            print("      [MORE]: \(firstStepTourTag.hasMoreSteps ? "yes" : "no"), points at Bluetooth in the sidebar: \(firstStepHit ? "HIT" : "miss")")
            check(!firstStep.displayText.isEmpty, "the tour's first step comes back")

            if firstStepTourTag.hasMoreSteps,
               let bluetoothScreen = SyntheticScreens.systemSettings(name: "bluetooth", selectedPane: "Bluetooth", paneRows: ["Bluetooth", "My Devices", "Nearby Devices"], switchRow: "Bluetooth") {
                let tourAfterFirstStep = GuidedTour(goal: tourGoal, shownSteps: [firstStep.displayText])
                let secondStepReply = try await geminiClient.generateReply(
                    systemInstruction: CompanionPrompt.systemInstruction(canSeeScreen: true),
                    history: [ConversationExchange(userText: tourGoal, tikoReply: firstStep.displayText)],
                    images: [fullScreenImage(of: bluetoothScreen)],
                    userText: CompanionPrompt.nextTourStepRequest(for: tourAfterFirstStep)
                )
                let secondStepTourTag = TourTag.strip(secondStepReply.text)
                let secondStep = PointTag.parse(secondStepTourTag.text)
                let bluetoothScreenBounds = CGRect(origin: .zero, size: bluetoothScreen.pointSize)
                let secondStepHit = secondStep.normalizedPoint.map { normalizedPoint in
                    bluetoothScreen.elementRects["switch:Bluetooth"].map { hitArea(of: $0).contains(ScreenCoordinates.point(fromNormalized: normalizedPoint, in: bluetoothScreenBounds)) } ?? false
                } ?? false
                print("    step 2 → \(secondStep.displayText)")
                print("      [MORE]: \(secondStepTourTag.hasMoreSteps ? "yes" : "no"), points at the Bluetooth switch: \(secondStepHit ? "HIT" : "miss")")
                check(!secondStep.displayText.isEmpty, "the tour's next step comes back from a fresh screen")
            } else {
                print("    step 1 had no [MORE], so there was no second step to ask for")
            }
        } catch {
            print("  FAIL  \(error.localizedDescription)")
            failedCheckCount += 1
        }
    }
}

print(failedCheckCount == 0 ? "\nAll checks passed." : "\n\(failedCheckCount) check(s) failed.")
exit(failedCheckCount == 0 ? 0 : 1)
