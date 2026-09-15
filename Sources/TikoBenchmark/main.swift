import AppKit
import Foundation
import TikoCore
import TikoFixtures

// Measures how often Tiko points at the right element, on app screens drawn in
// code where the position of every element is known exactly.
//
//   swift run TikoBenchmark [--runs 2] [--pause-seconds 4] [--output benchmarks]
//   swift run TikoBenchmark --screens-only    just draw the screens, no requests
//
// Every question is answered the way the app answers it, then scored three ways:
//   - single guess: where Gemini first points on the full screenshot, the
//     one-shot approach Clicky uses;
//   - close-up check: that guess double-checked on a sharp crop (PointRefiner),
//     within the app's 5-second limit — every question costs a second request;
//   - Tiko now: the element's label found as text on screen (TextAnchor), and
//     only when that finds nothing, the close-up check.
// Needs a Gemini key: GEMINI_API_KEY, or one saved in Tiko's panel.

func argumentValue(after flag: String) -> String? {
    guard let flagIndex = CommandLine.arguments.firstIndex(of: flag),
          CommandLine.arguments.indices.contains(flagIndex + 1) else {
        return nil
    }
    return CommandLine.arguments[flagIndex + 1]
}

let runCount = max(argumentValue(after: "--runs").flatMap(Int.init) ?? 2, 1)
let pauseSeconds = max(argumentValue(after: "--pause-seconds").flatMap(Double.init) ?? 4, 0)
let outputFolderURL = URL(fileURLWithPath: argumentValue(after: "--output") ?? "benchmarks", isDirectory: true)

/// The app gives the close-up check this long before pointing at the first guess instead.
let zoomCheckTimeLimitSeconds = 5.0
/// A point this close to an element's edge still counts as a hit — about the slack of a real click.
let hitMargin: CGFloat = 6
/// Sizes the app uses, in points.
let cursorCloseUpSize: CGFloat = 360
let zoomCheckRegionSize: CGFloat = 400
/// The app's screenshots are scaled to this many pixels on their longest side.
let screenshotLongestSide: CGFloat = 1280

// MARK: - Measuring

enum PointingMethod: CaseIterable {
    case singleGuess
    case closeUpCheck
    case textAnchorThenCloseUpCheck
}

struct PointingAttempt: Codable {
    let screenName: String
    let question: String
    let targetElementKey: String
    let runNumber: Int
    var modelName: String?
    var replyText: String?
    var elementLabel: String?
    /// Points from the screen's top-left.
    var firstGuess: CGPoint?
    var zoomCheckedPoint: CGPoint?
    var finalPoint: CGPoint?
    var zoomCheckTimedOut = false
    var textAnchorPoint: CGPoint?
    var firstGuessDistance: Double?
    var finalDistance: Double?
    var textAnchoredFinalDistance: Double?
    var isFirstGuessHit = false
    var isFinalHit = false
    var isTextAnchoredFinalHit = false
    var answerSeconds: Double?
    var zoomCheckSeconds: Double?
    var errorMessage: String?
}

struct BenchmarkRun: Codable {
    let date: Date
    let runCount: Int
    let hitMargin: Double
    let zoomCheckTimeLimitSeconds: Double
    let pauseSeconds: Double
    let modelNames: [String]
    /// How long reading all the text off each screen took, in seconds.
    let textRecognitionSeconds: [String: Double]
    let attempts: [PointingAttempt]
}

enum BenchmarkError: LocalizedError {
    case renderingFailed(screenName: String)

    var errorDescription: String? {
        switch self {
        case .renderingFailed(let screenName):
            return "couldn't render the \(screenName) screen"
        }
    }
}

func secondsElapsed(since startTime: ContinuousClock.Instant) -> Double {
    let elapsed = ContinuousClock.now - startTime
    return Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
}

func distance(from point: CGPoint, toCentreOf rect: CGRect) -> Double {
    Double(hypot(point.x - rect.midX, point.y - rect.midY))
}

func isHit(_ point: CGPoint, on targetRect: CGRect) -> Bool {
    targetRect.insetBy(dx: -hitMargin, dy: -hitMargin).contains(point)
}

/// Spaces requests out so the free tier's per-minute limit isn't hit.
func pauseBetweenRequests() async {
    guard pauseSeconds > 0 else { return }
    try? await Task.sleep(for: .seconds(pauseSeconds))
}

func measure(
    _ benchmarkCase: PointingBenchmarkCase,
    runNumber: Int,
    on screen: SyntheticScreen,
    recognizedTexts: [RecognizedText],
    targetRect: CGRect,
    geminiClient: GeminiClient
) async -> PointingAttempt {
    var attempt = PointingAttempt(
        screenName: benchmarkCase.screenName,
        question: benchmarkCase.question,
        targetElementKey: benchmarkCase.targetElementKey,
        runNumber: runNumber
    )

    do {
        guard let screenshotJPEG = screen.screenshotJPEG(longestSide: screenshotLongestSide) else {
            throw BenchmarkError.renderingFailed(screenName: screen.name)
        }
        // The app also sends a close-up around the mouse; here the mouse is parked mid-screen.
        let screenCentre = CGPoint(x: screen.pointSize.width / 2, y: screen.pointSize.height / 2)
        let cursorCloseUpRect = CloseUpRegion.captureRect(centeredOn: screenCentre, displaySize: screen.pointSize, regionSize: cursorCloseUpSize)
        guard let cursorCloseUpJPEG = screen.regionJPEG(rectInPoints: cursorCloseUpRect) else {
            throw BenchmarkError.renderingFailed(screenName: screen.name)
        }

        let answerStartTime = ContinuousClock.now
        let reply = try await geminiClient.generateReply(
            systemInstruction: CompanionPrompt.systemInstruction(canSeeScreen: true),
            history: [],
            // Same order and labels as the app: the close-up first, the full screenshot right before the question.
            images: [
                GeminiImage(
                    jpegData: cursorCloseUpJPEG,
                    label: CompanionPrompt.cursorCloseUpLabel(screenNumber: 1, regionInDisplay: cursorCloseUpRect, displaySize: screen.pointSize)
                ),
                GeminiImage(jpegData: screenshotJPEG, label: CompanionPrompt.screenLabel(screenNumber: 1, screenCount: 1, isCursorScreen: true))
            ],
            userText: benchmarkCase.question
        )
        attempt.answerSeconds = secondsElapsed(since: answerStartTime)
        attempt.modelName = reply.modelName

        let parsedReply = PointTag.parse(TourTag.strip(reply.text).text)
        attempt.replyText = parsedReply.displayText
        attempt.elementLabel = parsedReply.elementLabel
        // A reply without a point is a miss for every method.
        guard let normalizedPoint = parsedReply.normalizedPoint else { return attempt }

        let firstGuess = ScreenCoordinates.point(fromNormalized: normalizedPoint, in: CGRect(origin: .zero, size: screen.pointSize))
        attempt.firstGuess = firstGuess
        attempt.firstGuessDistance = distance(from: firstGuess, toCentreOf: targetRect)
        attempt.isFirstGuessHit = isHit(firstGuess, on: targetRect)

        await pauseBetweenRequests()

        // The close-up check runs on every question, so that method can be scored on its own.
        var finalPoint = firstGuess
        let zoomCheckRect = CloseUpRegion.captureRect(centeredOn: firstGuess, displaySize: screen.pointSize, regionSize: zoomCheckRegionSize)
        if let zoomCheckJPEG = screen.regionJPEG(rectInPoints: zoomCheckRect) {
            let zoomCheckStartTime = ContinuousClock.now
            let zoomCheckedPoint = await PointRefiner.refinePoint(
                elementLabel: parsedReply.elementLabel ?? "the element",
                userQuestion: benchmarkCase.question,
                regionRect: zoomCheckRect,
                regionJPEG: zoomCheckJPEG,
                geminiClient: geminiClient
            )
            let zoomCheckSeconds = secondsElapsed(since: zoomCheckStartTime)
            attempt.zoomCheckSeconds = zoomCheckSeconds
            attempt.zoomCheckedPoint = zoomCheckedPoint

            if let zoomCheckedPoint {
                if zoomCheckSeconds <= zoomCheckTimeLimitSeconds {
                    finalPoint = zoomCheckedPoint
                } else {
                    // By this time the app would already have pointed at the first guess.
                    attempt.zoomCheckTimedOut = true
                }
            }
        }
        attempt.finalPoint = finalPoint
        attempt.finalDistance = distance(from: finalPoint, toCentreOf: targetRect)
        attempt.isFinalHit = isHit(finalPoint, on: targetRect)

        // Tiko's current path: the label read off the screen; only when that
        // finds nothing does the close-up check's answer count.
        let textAnchorPoint = TextAnchor.anchorPoint(forLabel: parsedReply.elementLabel ?? "", among: recognizedTexts, nearGuess: firstGuess)
        attempt.textAnchorPoint = textAnchorPoint
        let textAnchoredFinalPoint = textAnchorPoint ?? finalPoint
        attempt.textAnchoredFinalDistance = distance(from: textAnchoredFinalPoint, toCentreOf: targetRect)
        attempt.isTextAnchoredFinalHit = isHit(textAnchoredFinalPoint, on: targetRect)
    } catch {
        attempt.errorMessage = error.localizedDescription
    }

    return attempt
}

// MARK: - Scoring

struct MethodScore {
    let hitCount: Int
    let attemptCount: Int
    let medianDistance: Double?
    let ninetiethPercentileDistance: Double?

    var hitRateText: String {
        guard attemptCount > 0 else { return "–" }
        return String(format: "%.0f%%", Double(hitCount) / Double(attemptCount) * 100)
    }
}

func percentile(_ values: [Double], _ fraction: Double) -> Double? {
    guard !values.isEmpty else { return nil }
    let sortedValues = values.sorted()
    let index = Int((Double(sortedValues.count - 1) * fraction).rounded())
    return sortedValues[index]
}

func isHit(_ attempt: PointingAttempt, using pointingMethod: PointingMethod) -> Bool {
    switch pointingMethod {
    case .singleGuess: return attempt.isFirstGuessHit
    case .closeUpCheck: return attempt.isFinalHit
    case .textAnchorThenCloseUpCheck: return attempt.isTextAnchoredFinalHit
    }
}

func finalDistance(of attempt: PointingAttempt, using pointingMethod: PointingMethod) -> Double? {
    switch pointingMethod {
    case .singleGuess: return attempt.firstGuessDistance
    case .closeUpCheck: return attempt.finalDistance
    case .textAnchorThenCloseUpCheck: return attempt.textAnchoredFinalDistance
    }
}

func score(_ attempts: [PointingAttempt], using pointingMethod: PointingMethod) -> MethodScore {
    let distances = attempts.compactMap { attempt in finalDistance(of: attempt, using: pointingMethod) }
    return MethodScore(
        hitCount: attempts.filter { attempt in isHit(attempt, using: pointingMethod) }.count,
        attemptCount: attempts.count,
        medianDistance: percentile(distances, 0.5),
        ninetiethPercentileDistance: percentile(distances, 0.9)
    )
}

/// Requests to Gemini per question: the answer, plus a close-up check whenever the method uses one.
func requestsPerQuestion(_ attempts: [PointingAttempt], using pointingMethod: PointingMethod) -> Double {
    guard !attempts.isEmpty else { return 0 }
    let closeUpCheckCount: Int
    switch pointingMethod {
    case .singleGuess:
        closeUpCheckCount = 0
    case .closeUpCheck:
        closeUpCheckCount = attempts.filter { $0.firstGuess != nil }.count
    case .textAnchorThenCloseUpCheck:
        closeUpCheckCount = attempts.filter { $0.firstGuess != nil && $0.textAnchorPoint == nil }.count
    }
    return Double(attempts.count + closeUpCheckCount) / Double(attempts.count)
}

func formatPoints(_ value: Double?) -> String {
    value.map { String(format: "%.0f pt", $0) } ?? "–"
}

func formatSeconds(_ value: Double?) -> String {
    value.map { String(format: "%.1f s", $0) } ?? "–"
}

func tableCell(_ text: String) -> String {
    text.replacingOccurrences(of: "|", with: "\\|").replacingOccurrences(of: "\n", with: " ")
}

func outcomeText(isHit: Bool, distance: Double?) -> String {
    guard let distance else { return "no point" }
    return "\(isHit ? "hit" : "miss"), \(formatPoints(distance))"
}

func progressLine(for attempt: PointingAttempt, number attemptNumber: Int, of totalAttemptCount: Int) -> String {
    let prefix = "[\(attemptNumber)/\(totalAttemptCount)] run \(attempt.runNumber) · \(attempt.screenName) · \"\(attempt.question)\""
    if let errorMessage = attempt.errorMessage {
        return "\(prefix) → error: \(errorMessage)"
    }
    return "\(prefix) → single \(outcomeText(isHit: attempt.isFirstGuessHit, distance: attempt.firstGuessDistance)); close-up \(outcomeText(isHit: attempt.isFinalHit, distance: attempt.finalDistance)); text anchor \(attempt.textAnchorPoint == nil ? "–" : "used") → \(outcomeText(isHit: attempt.isTextAnchoredFinalHit, distance: attempt.textAnchoredFinalDistance))"
}

func makeReport(for benchmarkRun: BenchmarkRun) -> String {
    let scoredAttempts = benchmarkRun.attempts.filter { $0.errorMessage == nil }
    let failedAttempts = benchmarkRun.attempts.filter { $0.errorMessage != nil }
    let singleGuessScore = score(scoredAttempts, using: .singleGuess)
    let closeUpCheckScore = score(scoredAttempts, using: .closeUpCheck)
    let textAnchorScore = score(scoredAttempts, using: .textAnchorThenCloseUpCheck)

    let pointedAttempts = scoredAttempts.filter { $0.firstGuess != nil }
    let textAnchorUsedCount = pointedAttempts.filter { $0.textAnchorPoint != nil }.count
    let missesFixedByTextAnchorPath = scoredAttempts.filter { !$0.isFirstGuessHit && $0.isTextAnchoredFinalHit }.count
    let hitsBrokenByTextAnchorPath = scoredAttempts.filter { $0.isFirstGuessHit && !$0.isTextAnchoredFinalHit }.count
    let textAnchorHitsWhenUsed = pointedAttempts.filter { $0.textAnchorPoint != nil && $0.isTextAnchoredFinalHit }.count
    let answeringModelNames = Set(scoredAttempts.compactMap(\.modelName)).sorted()

    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

    var reportLines: [String] = []
    reportLines.append("# Tiko pointing benchmark")
    reportLines.append("")
    reportLines.append("Run \(dateFormatter.string(from: benchmarkRun.date)) · answered by \(answeringModelNames.joined(separator: ", ")) · \(PointingBenchmark.cases.count) questions on \(PointingBenchmark.screenNames.count) screens × \(benchmarkRun.runCount) runs = \(benchmarkRun.attempts.count) attempts\(failedAttempts.isEmpty ? "" : " (\(failedAttempts.count) failed and are left out of the scores; listed at the end)").")
    reportLines.append("")
    reportLines.append("| Method | Hits | Hit rate | Median distance from centre | 90th percentile | Requests per question |")
    reportLines.append("|---|---|---|---|---|---|")
    reportLines.append("| Single guess on the full screenshot (Clicky's approach) | \(singleGuessScore.hitCount)/\(singleGuessScore.attemptCount) | \(singleGuessScore.hitRateText) | \(formatPoints(singleGuessScore.medianDistance)) | \(formatPoints(singleGuessScore.ninetiethPercentileDistance)) | \(String(format: "%.2f", requestsPerQuestion(scoredAttempts, using: .singleGuess))) |")
    reportLines.append("| Single guess + close-up check on every question | \(closeUpCheckScore.hitCount)/\(closeUpCheckScore.attemptCount) | \(closeUpCheckScore.hitRateText) | \(formatPoints(closeUpCheckScore.medianDistance)) | \(formatPoints(closeUpCheckScore.ninetiethPercentileDistance)) | \(String(format: "%.2f", requestsPerQuestion(scoredAttempts, using: .closeUpCheck))) |")
    reportLines.append("| **Tiko: label read on screen, else close-up check** | **\(textAnchorScore.hitCount)/\(textAnchorScore.attemptCount)** | **\(textAnchorScore.hitRateText)** | **\(formatPoints(textAnchorScore.medianDistance))** | **\(formatPoints(textAnchorScore.ninetiethPercentileDistance))** | **\(String(format: "%.2f", requestsPerQuestion(scoredAttempts, using: .textAnchorThenCloseUpCheck)))** |")
    reportLines.append("")
    reportLines.append("- The label was read off the screen for \(textAnchorUsedCount) of \(pointedAttempts.count) pointed answers, and landed on the target \(textAnchorHitsWhenUsed) times; the rest fell back to the close-up check.")
    reportLines.append("- Compared with the single guess, Tiko's path turned \(missesFixedByTextAnchorPath) misses into hits and \(hitsBrokenByTextAnchorPath) hits into misses.")
    let recognitionTimes = benchmarkRun.textRecognitionSeconds.values.sorted()
    reportLines.append("- Reading every piece of text off a full-resolution screen took \(formatSeconds(recognitionTimes.first)) to \(formatSeconds(recognitionTimes.last)). Median time to answer: \(formatSeconds(percentile(scoredAttempts.compactMap(\.answerSeconds), 0.5))); median close-up check: \(formatSeconds(percentile(scoredAttempts.compactMap(\.zoomCheckSeconds), 0.5))).")
    reportLines.append("")
    reportLines.append("## By screen")
    reportLines.append("")
    reportLines.append("| Screen | Attempts | Single guess | Close-up check | Tiko |")
    reportLines.append("|---|---|---|---|---|")
    for screenName in PointingBenchmark.screenNames {
        let screenAttempts = scoredAttempts.filter { $0.screenName == screenName }
        let screenScores = PointingMethod.allCases.map { pointingMethod in score(screenAttempts, using: pointingMethod) }
        reportLines.append("| [\(screenName)](screens/\(screenName).png) | \(screenAttempts.count) | " + screenScores.map { "\($0.hitCount) (\($0.hitRateText))" }.joined(separator: " | ") + " |")
    }
    reportLines.append("")
    reportLines.append("## How it's measured")
    reportLines.append("")
    reportLines.append("- Each screen is drawn in code at 1440×900 points and 2 pixels per point, like a Retina MacBook, with macOS's own interface font sizes. The exact rectangle of every button, link, menu item and row is recorded while drawing. The screens are in [`screens/`](screens).")
    reportLines.append("- Each question goes through the app's own path: the same system prompt (`CompanionPrompt`), a screenshot scaled to \(Int(screenshotLongestSide)) pixels wide, a \(Int(cursorCloseUpSize))-point close-up around a mouse parked mid-screen, and the same reply parser (`PointTag`).")
    reportLines.append("- **Single guess** is where that reply points. The **close-up check** crops \(Int(zoomCheckRegionSize)) points around the guess at full detail and asks again (`PointRefiner`); as in the app, it replaces the guess only if it answers within \(Int(benchmarkRun.zoomCheckTimeLimitSeconds)) seconds.")
    reportLines.append("- **Tiko** first reads all the text on the full-resolution screen with Apple's on-device text recognition and snaps to the text matching the element's label (`TextAnchor`, the same code the app runs). Icons, switches and text fields, and labels it can't find, fall back to the close-up check.")
    reportLines.append("- A point is a hit when it lands on the element or within \(Int(benchmarkRun.hitMargin)) points of its edge. Distance is measured to the element's centre.")
    reportLines.append("- Requests are spaced \(Int(benchmarkRun.pauseSeconds)) seconds apart to stay inside the free tier's rate limit. Raw data for every attempt is in [`results/`](results).")
    reportLines.append("")
    reportLines.append("## What this does and doesn't show")
    reportLines.append("")
    reportLines.append("- \"Clicky's approach\" means one guess on the full screenshot with **the same Gemini model and Tiko's prompt**. Clicky itself asks Claude, which this free benchmark doesn't call, so this compares methods, not the two products.")
    reportLines.append("- The screens are tidier than real desktops, and their text is crisp — which flatters text recognition. Read the numbers as a comparison between methods, not as the accuracy you'll get on your own Mac.")
    reportLines.append("- Model answers vary from run to run; `--runs` adds repetitions for steadier numbers.")
    reportLines.append("")
    reportLines.append("## Every attempt")
    reportLines.append("")
    reportLines.append("| Run | Screen | Question | Target | Single guess | Close-up check | Tiko | Reply |")
    reportLines.append("|---|---|---|---|---|---|---|---|")
    for attempt in scoredAttempts {
        let tikoOutcome = outcomeText(isHit: attempt.isTextAnchoredFinalHit, distance: attempt.textAnchoredFinalDistance) + (attempt.textAnchorPoint != nil ? " (label read)" : "")
        reportLines.append("| \(attempt.runNumber) | \(attempt.screenName) | \(tableCell(attempt.question)) | \(tableCell(attempt.targetElementKey)) | \(outcomeText(isHit: attempt.isFirstGuessHit, distance: attempt.firstGuessDistance)) | \(outcomeText(isHit: attempt.isFinalHit, distance: attempt.finalDistance))\(attempt.zoomCheckTimedOut ? " (check too slow)" : "") | \(tikoOutcome) | \(tableCell(attempt.replyText ?? "")) |")
    }
    if !failedAttempts.isEmpty {
        reportLines.append("")
        reportLines.append("## Failed attempts")
        reportLines.append("")
        for attempt in failedAttempts {
            reportLines.append("- Run \(attempt.runNumber), \(attempt.screenName), \"\(attempt.question)\": \(attempt.errorMessage ?? "")")
        }
    }
    reportLines.append("")
    return reportLines.joined(separator: "\n")
}

// MARK: - Run

print("Rendering \(PointingBenchmark.screenNames.count) screens…")
let screensByName = PointingBenchmark.renderScreens(scale: 2)
guard screensByName.count == PointingBenchmark.screenNames.count else {
    print("Some screens failed to render.")
    exit(1)
}

// Save what Gemini is shown, so the results can be checked by eye.
let screensFolderURL = outputFolderURL.appendingPathComponent("screens", isDirectory: true)
do {
    try FileManager.default.createDirectory(at: screensFolderURL, withIntermediateDirectories: true)
    for screenName in PointingBenchmark.screenNames {
        try screensByName[screenName]?.screenshotPNG(longestSide: 1440)?.write(to: screensFolderURL.appendingPathComponent("\(screenName).png"))
    }
} catch {
    print("Couldn't save the screens: \(error.localizedDescription)")
    exit(1)
}

// `--screens-only` stops here, to look at the screens without spending any requests.
if CommandLine.arguments.contains("--screens-only") {
    print("Screens saved to \(screensFolderURL.path)")
    exit(0)
}

// Reading a screen's text doesn't depend on the question, so each screen is read once.
print("Reading the text on each screen…")
var recognizedTextsByScreen: [String: [RecognizedText]] = [:]
var textRecognitionSecondsByScreen: [String: Double] = [:]
for screenName in PointingBenchmark.screenNames {
    guard let screen = screensByName[screenName] else { continue }
    let recognitionStartTime = ContinuousClock.now
    recognizedTextsByScreen[screenName] = TextAnchor.recognizeText(in: screen.fullResolutionImage, imageAreaSize: screen.pointSize)
    textRecognitionSecondsByScreen[screenName] = secondsElapsed(since: recognitionStartTime)
}

let apiKey = TikoSettings.load().resolvedGeminiAPIKey
guard !apiKey.isEmpty else {
    // Tiko keeps its key in the keychain, which a command-line tool can't read without macOS asking.
    print("No Gemini key: run with GEMINI_API_KEY=your-key (Tiko's own key is in the keychain).")
    exit(1)
}

do {
    let availableModelNames = try await GeminiClient(apiKey: apiKey, modelNames: []).fetchAvailableModelNames()
    let modelNames = GeminiModelPicker.preferredModelNames(from: availableModelNames)
    print("Models, best first: \(modelNames.joined(separator: ", "))")
    let geminiClient = GeminiClient(apiKey: apiKey, modelNames: modelNames)

    var attempts: [PointingAttempt] = []
    let totalAttemptCount = runCount * PointingBenchmark.cases.count
    for runNumber in 1...runCount {
        for benchmarkCase in PointingBenchmark.cases {
            guard let screen = screensByName[benchmarkCase.screenName],
                  let targetRect = screen.elementRects[benchmarkCase.targetElementKey] else {
                print("Skipping \"\(benchmarkCase.question)\": \(benchmarkCase.targetElementKey) isn't on \(benchmarkCase.screenName)")
                continue
            }
            let attempt = await measure(
                benchmarkCase,
                runNumber: runNumber,
                on: screen,
                recognizedTexts: recognizedTextsByScreen[benchmarkCase.screenName] ?? [],
                targetRect: targetRect,
                geminiClient: geminiClient
            )
            attempts.append(attempt)
            print(progressLine(for: attempt, number: attempts.count, of: totalAttemptCount))
            await pauseBetweenRequests()
        }
    }

    let benchmarkRun = BenchmarkRun(
        date: Date(),
        runCount: runCount,
        hitMargin: Double(hitMargin),
        zoomCheckTimeLimitSeconds: zoomCheckTimeLimitSeconds,
        pauseSeconds: pauseSeconds,
        modelNames: modelNames,
        textRecognitionSeconds: textRecognitionSecondsByScreen,
        attempts: attempts
    )

    let resultsFolderURL = outputFolderURL.appendingPathComponent("results", isDirectory: true)
    try FileManager.default.createDirectory(at: resultsFolderURL, withIntermediateDirectories: true)
    let jsonEncoder = JSONEncoder()
    jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    jsonEncoder.dateEncodingStrategy = .iso8601
    let fileNameFormatter = DateFormatter()
    fileNameFormatter.dateFormat = "yyyy-MM-dd-HHmm"
    let resultsFileURL = resultsFolderURL.appendingPathComponent("\(fileNameFormatter.string(from: benchmarkRun.date)).json")
    try jsonEncoder.encode(benchmarkRun).write(to: resultsFileURL)

    let reportFileURL = outputFolderURL.appendingPathComponent("RESULTS.md")
    try Data(makeReport(for: benchmarkRun).utf8).write(to: reportFileURL)

    let scoredAttempts = attempts.filter { $0.errorMessage == nil }
    print("")
    for (methodName, pointingMethod) in [("Single guess", PointingMethod.singleGuess), ("Close-up check", .closeUpCheck), ("Tiko (text anchor)", .textAnchorThenCloseUpCheck)] {
        let methodScore = score(scoredAttempts, using: pointingMethod)
        print("\(methodName.padding(toLength: 20, withPad: " ", startingAt: 0)) \(methodScore.hitCount)/\(methodScore.attemptCount) (\(methodScore.hitRateText)), median \(formatPoints(methodScore.medianDistance)), \(String(format: "%.2f", requestsPerQuestion(scoredAttempts, using: pointingMethod))) requests per question")
    }
    print("Failed attempts:     \(attempts.count - scoredAttempts.count)")
    print("Report: \(reportFileURL.path)")
    print("Raw results: \(resultsFileURL.path)")
} catch {
    print("Benchmark stopped: \(error.localizedDescription)")
    exit(1)
}
