import AppKit
import Foundation
import TikoCore

// Checks Tiko's logic without its UI or any macOS permissions.
//   swift run TikoCheck          offline checks only
//   swift run TikoCheck --live   also asks Gemini a real question (needs a key:
//                                GEMINI_API_KEY, or one saved in Tiko's panel)

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

// MARK: - Cursor close-up

print("Cursor close-up")
let displaySize = CGSize(width: 1470, height: 956)
check(
    CursorCloseUp.captureRect(mouseLocationInDisplay: CGPoint(x: 700, y: 400), displaySize: displaySize, closeUpSize: 360)
        == CGRect(x: 520, y: 220, width: 360, height: 360),
    "centred on the cursor"
)
check(
    CursorCloseUp.captureRect(mouseLocationInDisplay: CGPoint(x: 10, y: 950), displaySize: displaySize, closeUpSize: 360)
        == CGRect(x: 0, y: 596, width: 360, height: 360),
    "slides back inside the display at a corner"
)

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

/// A made-up System Settings window, so the live check has a screen with known contents.
func renderFakeSettingsScreen() -> Data? {
    let pixelWidth = 1280
    let pixelHeight = 800
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixelWidth, pixelsHigh: pixelHeight,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
        return nil
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext

    NSColor(white: 0.97, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight).fill()
    NSColor(white: 0.89, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: 280, height: pixelHeight).fill()

    // AppKit draws from the bottom-left, so convert "distance from the top".
    func drawText(_ text: String, x: CGFloat, distanceFromTop: CGFloat, fontSize: CGFloat, weight: NSFont.Weight = .regular) {
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
            .foregroundColor: NSColor.black
        ]
        (text as NSString).draw(at: NSPoint(x: x, y: CGFloat(pixelHeight) - distanceFromTop - fontSize), withAttributes: textAttributes)
    }

    drawText("System Settings", x: 24, distanceFromTop: 28, fontSize: 22, weight: .semibold)
    for (sidebarIndex, sidebarItem) in ["Wi-Fi", "Bluetooth", "General", "Appearance", "Notifications", "Privacy & Security"].enumerated() {
        drawText(sidebarItem, x: 32, distanceFromTop: 100 + CGFloat(sidebarIndex) * 46, fontSize: 18)
    }
    drawText("General", x: 320, distanceFromTop: 28, fontSize: 26, weight: .bold)
    for (rowIndex, rowTitle) in ["About", "Software Update", "Storage", "Login Items"].enumerated() {
        drawText(rowTitle, x: 320, distanceFromTop: 110 + CGFloat(rowIndex) * 54, fontSize: 18)
    }

    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
}

if CommandLine.arguments.contains("--live") {
    print("Live Gemini question")
    let apiKey = TikoSettings.load().resolvedGeminiAPIKey
    if apiKey.isEmpty {
        print("  FAIL  no key: set GEMINI_API_KEY or save a key in Tiko's panel")
        failedCheckCount += 1
    } else if let fakeScreenJPEG = renderFakeSettingsScreen() {
        do {
            let availableModelNames = try await GeminiClient(apiKey: apiKey, modelNames: []).fetchAvailableModelNames()
            let preferredModelNames = GeminiModelPicker.preferredModelNames(from: availableModelNames)
            print("  models to use, best first: \(preferredModelNames.joined(separator: ", "))")
            check(!preferredModelNames.isEmpty, "the key can reach at least one suitable model")

            let questionStartTime = ContinuousClock.now
            let reply = try await GeminiClient(apiKey: apiKey, modelNames: preferredModelNames).generateReply(
                systemInstruction: CompanionPrompt.systemInstruction(canSeeScreen: true),
                history: [],
                images: [GeminiImage(jpegData: fakeScreenJPEG, label: CompanionPrompt.screenLabel(screenNumber: 1, screenCount: 1, isCursorScreen: true))],
                userText: "bhai dark mode kaise on karu?"
            )
            let secondsTaken = (ContinuousClock.now - questionStartTime).components.seconds
            print("  \(reply.modelName) answered in about \(secondsTaken)s: \(reply.text)")
            check(reply.text.localizedCaseInsensitiveContains("appearance"), "the reply points to Appearance, which is on the fake screen")
        } catch {
            print("  FAIL  \(error.localizedDescription)")
            failedCheckCount += 1
        }
    }
}

print(failedCheckCount == 0 ? "\nAll checks passed." : "\n\(failedCheckCount) check(s) failed.")
exit(failedCheckCount == 0 ? 0 : 1)
