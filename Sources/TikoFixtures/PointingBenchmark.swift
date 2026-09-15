import CoreGraphics

/// One question asked about one screen, with the element a correct answer points at.
public struct PointingBenchmarkCase: Sendable {
    public let screenName: String
    public let question: String
    public let targetElementKey: String
}

/// The screens and questions the pointing benchmark runs through.
public enum PointingBenchmark {
    public static let screenNames = ["system-settings", "text-editor", "login-page", "finder-file-menu", "save-dialog", "spreadsheet"]

    public static func renderScreens(scale: CGFloat) -> [String: SyntheticScreen] {
        let renderedScreens = [
            SyntheticScreens.systemSettings(scale: scale),
            SyntheticScreens.textEditor(scale: scale),
            SyntheticScreens.loginPage(scale: scale),
            SyntheticScreens.finderFileMenu(scale: scale),
            SyntheticScreens.saveChangesDialog(scale: scale),
            SyntheticScreens.spreadsheet(scale: scale)
        ].compactMap { $0 }
        return Dictionary(uniqueKeysWithValues: renderedScreens.map { screen in (screen.name, screen) })
    }

    /// Everyday questions, asked the way someone would say them out loud in
    /// Hinglish — they name what they want to do, not the button's label.
    public static let cases: [PointingBenchmarkCase] = [
        PointingBenchmarkCase(screenName: "system-settings", question: "wallpaper kaise badlu?", targetElementKey: "sidebar:Wallpaper"),
        PointingBenchmarkCase(screenName: "system-settings", question: "battery ki health kahan dekhu?", targetElementKey: "sidebar:Battery"),
        PointingBenchmarkCase(screenName: "system-settings", question: "mac ki language hindi kaise karu?", targetElementKey: "row:Language & Region"),
        PointingBenchmarkCase(screenName: "system-settings", question: "date aur time galat hai, kahan theek karu?", targetElementKey: "row:Date & Time"),
        PointingBenchmarkCase(screenName: "system-settings", question: "airdrop kahan se on hota hai?", targetElementKey: "row:AirDrop & Handoff"),

        PointingBenchmarkCase(screenName: "text-editor", question: "is text ko bold kaise karu?", targetElementKey: "toolbar:Bold"),
        PointingBenchmarkCase(screenName: "text-editor", question: "document mein table kaise daalu?", targetElementKey: "toolbar:Insert table"),
        PointingBenchmarkCase(screenName: "text-editor", question: "photo insert karni hai", targetElementKey: "toolbar:Insert photo"),
        PointingBenchmarkCase(screenName: "text-editor", question: "ye document share kaise karu?", targetElementKey: "toolbar:Share"),
        PointingBenchmarkCase(screenName: "text-editor", question: "numbered list banani hai", targetElementKey: "toolbar:Numbered list"),

        PointingBenchmarkCase(screenName: "login-page", question: "password bhool gaya, ab kya karu?", targetElementKey: "link:Forgot password?"),
        PointingBenchmarkCase(screenName: "login-page", question: "naya account kaise banau?", targetElementKey: "link:Create an account"),
        PointingBenchmarkCase(screenName: "login-page", question: "google se login karna hai", targetElementKey: "button:Continue with Google"),
        PointingBenchmarkCase(screenName: "login-page", question: "remember me wala tick kahan hai?", targetElementKey: "checkbox:Remember me"),
        PointingBenchmarkCase(screenName: "login-page", question: "email kahan daalu?", targetElementKey: "field:Email"),

        PointingBenchmarkCase(screenName: "finder-file-menu", question: "naya folder kaise banau?", targetElementKey: "menu:New Folder"),
        PointingBenchmarkCase(screenName: "finder-file-menu", question: "is file ki info kaise dekhu?", targetElementKey: "menu:Get Info"),
        PointingBenchmarkCase(screenName: "finder-file-menu", question: "file ko zip kaise karu?", targetElementKey: "menu:Compress"),
        PointingBenchmarkCase(screenName: "finder-file-menu", question: "ye file delete karni hai", targetElementKey: "menu:Move to Trash"),
        PointingBenchmarkCase(screenName: "finder-file-menu", question: "file ki copy banani hai", targetElementKey: "menu:Duplicate"),

        PointingBenchmarkCase(screenName: "save-dialog", question: "bina save kiye band karna hai", targetElementKey: "button:Don't Save"),
        PointingBenchmarkCase(screenName: "save-dialog", question: "haan save kar do", targetElementKey: "button:Save"),
        PointingBenchmarkCase(screenName: "save-dialog", question: "ruko, abhi band nahi karna", targetElementKey: "button:Cancel"),

        PointingBenchmarkCase(screenName: "spreadsheet", question: "nayi sheet kaise add karu?", targetElementKey: "button:Add sheet"),
        PointingBenchmarkCase(screenName: "spreadsheet", question: "zoom thoda badhana hai", targetElementKey: "button:Zoom in"),
        PointingBenchmarkCase(screenName: "spreadsheet", question: "zoom kam karna hai", targetElementKey: "button:Zoom out"),
        PointingBenchmarkCase(screenName: "spreadsheet", question: "column ka total kaise nikalu?", targetElementKey: "toolbar:AutoSum"),
        PointingBenchmarkCase(screenName: "spreadsheet", question: "is data ka chart banana hai", targetElementKey: "toolbar:Insert chart"),
        PointingBenchmarkCase(screenName: "spreadsheet", question: "data filter kaise karu?", targetElementKey: "toolbar:Filter")
    ]
}
