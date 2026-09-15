import AppKit
import CoreGraphics

/// Screens that look like everyday Mac apps, sized like a 1440×900-point
/// display and using macOS's real interface font sizes, so that shrinking the
/// screenshot makes small labels genuinely hard to read.
public enum SyntheticScreens {
    public static let displaySize = CGSize(width: 1440, height: 900)

    private static let desktopColor = NSColor(calibratedRed: 0.29, green: 0.39, blue: 0.55, alpha: 1)
    private static let windowColor = NSColor(white: 0.97, alpha: 1)
    private static let secondaryTextColor = NSColor(white: 0.45, alpha: 1)
    private static let dividerColor = NSColor(white: 0.85, alpha: 1)

    // MARK: - System Settings

    private static let settingsSidebarItems: [(title: String, symbolName: String, color: NSColor)] = [
        ("Wi-Fi", "wifi", .systemBlue),
        ("Bluetooth", "antenna.radiowaves.left.and.right", .systemBlue),
        ("Network", "globe", .systemBlue),
        ("Notifications", "bell.badge.fill", .systemRed),
        ("Sound", "speaker.wave.3.fill", .systemPink),
        ("Focus", "moon.fill", .systemIndigo),
        ("Screen Time", "hourglass", .systemIndigo),
        ("General", "gearshape.fill", .systemGray),
        ("Appearance", "circle.lefthalf.filled", .black),
        ("Accessibility", "accessibility", .systemBlue),
        ("Control Centre", "switch.2", .systemGray),
        ("Desktop & Dock", "dock.rectangle", .black),
        ("Displays", "sun.max.fill", .systemBlue),
        ("Wallpaper", "photo.fill", .systemTeal),
        ("Battery", "battery.100", .systemGreen),
        ("Privacy & Security", "hand.raised.fill", .systemBlue)
    ]

    public static func systemSettings(
        name: String = "system-settings",
        selectedPane: String = "General",
        paneRows: [String] = ["About", "Software Update", "Storage", "AirDrop & Handoff", "Login Items", "Language & Region", "Date & Time"],
        switchRow: String? = nil,
        scale: CGFloat = 2
    ) -> SyntheticScreen? {
        guard let canvas = SyntheticScreenCanvas(pointSize: displaySize, scale: scale) else { return nil }
        canvas.fill(CGRect(origin: .zero, size: displaySize), color: desktopColor)

        let windowRect = CGRect(x: 120, y: 60, width: 1200, height: 780)
        drawWindowFrame(windowRect, on: canvas)
        canvas.fill(CGRect(x: windowRect.minX, y: windowRect.minY + 12, width: 260, height: windowRect.height - 24), color: NSColor(white: 0.91, alpha: 1))
        drawTrafficLights(atTopLeft: CGPoint(x: windowRect.minX + 18, y: windowRect.minY + 18), on: canvas)

        canvas.fill(CGRect(x: 136, y: 104, width: 228, height: 28), color: NSColor(white: 0.84, alpha: 1), cornerRadius: 7)
        canvas.symbol("magnifyingglass", in: CGRect(x: 145, y: 111, width: 14, height: 14), color: secondaryTextColor)
        canvas.text("Search", at: CGPoint(x: 165, y: 110), fontSize: 13, color: secondaryTextColor)

        for (sidebarIndex, sidebarItem) in settingsSidebarItems.enumerated() {
            let rowRect = CGRect(x: 128, y: 146 + CGFloat(sidebarIndex) * 30, width: 244, height: 26)
            let isSelected = sidebarItem.title == selectedPane
            if isSelected {
                canvas.fill(rowRect, color: .systemBlue, cornerRadius: 6)
            }
            canvas.fill(CGRect(x: rowRect.minX + 8, y: rowRect.minY + 3, width: 20, height: 20), color: sidebarItem.color, cornerRadius: 5)
            canvas.symbol(sidebarItem.symbolName, in: CGRect(x: rowRect.minX + 11, y: rowRect.minY + 6, width: 14, height: 14), color: .white)
            canvas.text(sidebarItem.title, at: CGPoint(x: rowRect.minX + 36, y: rowRect.minY + 5), fontSize: 13, color: isSelected ? .white : .black)
            canvas.markElement("sidebar:\(sidebarItem.title)", rect: rowRect)
        }

        let paneLeft = windowRect.minX + 280
        canvas.text(selectedPane, at: CGPoint(x: paneLeft, y: 80), fontSize: 20, weight: .bold)
        for (rowIndex, rowTitle) in paneRows.enumerated() {
            let rowRect = CGRect(x: paneLeft, y: 128 + CGFloat(rowIndex) * 52, width: 900, height: 44)
            canvas.fill(rowRect, color: .white, cornerRadius: 8)
            canvas.stroke(rowRect, color: dividerColor, cornerRadius: 8)
            canvas.text(rowTitle, at: CGPoint(x: rowRect.minX + 18, y: rowRect.minY + 13), fontSize: 13)
            canvas.markElement("row:\(rowTitle)", rect: rowRect)

            if rowTitle == switchRow {
                let switchRect = CGRect(x: rowRect.maxX - 58, y: rowRect.minY + 11, width: 40, height: 22)
                canvas.fill(switchRect, color: .systemGreen, cornerRadius: 11)
                canvas.fillOval(CGRect(x: switchRect.maxX - 21, y: switchRect.minY + 1, width: 20, height: 20), color: .white)
                canvas.markElement("switch:\(rowTitle)", rect: switchRect)
            } else {
                canvas.symbol("chevron.right", in: CGRect(x: rowRect.maxX - 28, y: rowRect.minY + 15, width: 8, height: 14), color: secondaryTextColor)
            }
        }

        return canvas.finish(name: name)
    }

    // MARK: - Text editor

    public static func textEditor(scale: CGFloat = 2) -> SyntheticScreen? {
        guard let canvas = SyntheticScreenCanvas(pointSize: displaySize, scale: scale) else { return nil }
        canvas.fill(CGRect(origin: .zero, size: displaySize), color: desktopColor)

        let windowRect = CGRect(x: 100, y: 50, width: 1240, height: 800)
        drawWindowFrame(windowRect, on: canvas)
        canvas.fill(CGRect(x: windowRect.minX, y: windowRect.minY, width: windowRect.width, height: 92), color: NSColor(white: 0.93, alpha: 1), cornerRadius: 12)
        drawTrafficLights(atTopLeft: CGPoint(x: windowRect.minX + 18, y: windowRect.minY + 16), on: canvas)
        drawCentredTitle("Quarterly Report.docx", centreX: windowRect.midX, top: windowRect.minY + 12, on: canvas)

        let formattingButtons: [(name: String, symbolName: String)] = [
            ("Bold", "bold"), ("Italic", "italic"), ("Underline", "underline"), ("Strikethrough", "strikethrough"),
            ("Bulleted list", "list.bullet"), ("Numbered list", "list.number"), ("Insert link", "link"),
            ("Insert photo", "photo"), ("Insert table", "tablecells"), ("Font size", "textformat.size")
        ]
        for (buttonIndex, formattingButton) in formattingButtons.enumerated() {
            let buttonRect = CGRect(x: 130 + CGFloat(buttonIndex) * 40, y: windowRect.minY + 50, width: 30, height: 30)
            canvas.symbol(formattingButton.symbolName, in: buttonRect.insetBy(dx: 7, dy: 7), color: NSColor(white: 0.25, alpha: 1))
            canvas.markElement("toolbar:\(formattingButton.name)", rect: buttonRect)
        }

        let trailingButtons: [(name: String, symbolName: String)] = [("Search", "magnifyingglass"), ("Comments", "text.bubble"), ("Share", "square.and.arrow.up")]
        for (buttonIndex, trailingButton) in trailingButtons.enumerated() {
            let buttonRect = CGRect(x: windowRect.maxX - 140 + CGFloat(buttonIndex) * 40, y: windowRect.minY + 50, width: 30, height: 30)
            canvas.symbol(trailingButton.symbolName, in: buttonRect.insetBy(dx: 7, dy: 7), color: NSColor(white: 0.25, alpha: 1))
            canvas.markElement("toolbar:\(trailingButton.name)", rect: buttonRect)
        }

        let pageRect = CGRect(x: 370, y: 170, width: 700, height: 660)
        canvas.fill(pageRect, color: .white)
        canvas.stroke(pageRect, color: dividerColor)
        canvas.text("Quarterly Report", at: CGPoint(x: 430, y: 210), fontSize: 26, weight: .bold)
        drawParagraphLines(left: 430, top: 270, lineCount: 13, on: canvas)
        canvas.text("Revenue", at: CGPoint(x: 430, y: 628), fontSize: 16, weight: .semibold)
        drawParagraphLines(left: 430, top: 662, lineCount: 6, on: canvas)

        return canvas.finish(name: "text-editor")
    }

    // MARK: - Login page

    public static func loginPage(scale: CGFloat = 2) -> SyntheticScreen? {
        guard let canvas = SyntheticScreenCanvas(pointSize: displaySize, scale: scale) else { return nil }
        canvas.fill(CGRect(origin: .zero, size: displaySize), color: NSColor(white: 0.96, alpha: 1))

        // Browser window chrome.
        canvas.fill(CGRect(x: 0, y: 0, width: displaySize.width, height: 84), color: NSColor(white: 0.9, alpha: 1))
        drawTrafficLights(atTopLeft: CGPoint(x: 18, y: 16), on: canvas)
        canvas.fill(CGRect(x: 90, y: 8, width: 220, height: 30), color: .white, cornerRadius: 8)
        canvas.text("Sign in – Example", at: CGPoint(x: 104, y: 15), fontSize: 12)
        canvas.fill(CGRect(x: 160, y: 48, width: 1120, height: 28), color: .white, cornerRadius: 14)
        canvas.symbol("lock.fill", in: CGRect(x: 176, y: 55, width: 12, height: 14), color: secondaryTextColor)
        canvas.text("accounts.example.com/signin", at: CGPoint(x: 196, y: 54), fontSize: 13, color: secondaryTextColor)

        let cardRect = CGRect(x: 520, y: 150, width: 400, height: 560)
        canvas.fill(cardRect, color: .white, cornerRadius: 14)
        canvas.stroke(cardRect, color: dividerColor, cornerRadius: 14)
        canvas.text("Sign in", at: CGPoint(x: 560, y: 190), fontSize: 26, weight: .bold)
        canvas.text("to continue to Example", at: CGPoint(x: 560, y: 228), fontSize: 14, color: secondaryTextColor)

        for (fieldIndex, fieldTitle) in ["Email", "Password"].enumerated() {
            let fieldTop = 280 + CGFloat(fieldIndex) * 76
            canvas.text(fieldTitle, at: CGPoint(x: 560, y: fieldTop), fontSize: 12, weight: .semibold, color: secondaryTextColor)
            let fieldRect = CGRect(x: 560, y: fieldTop + 18, width: 320, height: 38)
            canvas.stroke(fieldRect, color: NSColor(white: 0.72, alpha: 1), cornerRadius: 6)
            canvas.text(fieldIndex == 0 ? "you@example.com" : "••••••••", at: CGPoint(x: 574, y: fieldTop + 29), fontSize: 13, color: NSColor(white: 0.7, alpha: 1))
            canvas.markElement("field:\(fieldTitle)", rect: fieldRect)
        }

        canvas.stroke(CGRect(x: 560, y: 432, width: 16, height: 16), color: NSColor(white: 0.55, alpha: 1), cornerRadius: 3)
        let rememberMeTextRect = canvas.text("Remember me", at: CGPoint(x: 584, y: 431), fontSize: 13)
        canvas.markElement("checkbox:Remember me", rect: CGRect(x: 560, y: 430, width: rememberMeTextRect.maxX - 560, height: 20))

        let forgotPasswordWidth = canvas.textWidth("Forgot password?", fontSize: 13)
        let forgotPasswordRect = canvas.text("Forgot password?", at: CGPoint(x: 880 - forgotPasswordWidth, y: 431), fontSize: 13, color: .systemBlue)
        canvas.markElement("link:Forgot password?", rect: forgotPasswordRect)

        let signInButtonRect = CGRect(x: 560, y: 470, width: 320, height: 42)
        canvas.fill(signInButtonRect, color: .systemBlue, cornerRadius: 8)
        drawCentredText("Sign in", in: signInButtonRect, fontSize: 15, weight: .semibold, color: .white, on: canvas)
        canvas.markElement("button:Sign in", rect: signInButtonRect)

        canvas.line(from: CGPoint(x: 560, y: 540), to: CGPoint(x: 702, y: 540), color: dividerColor)
        canvas.text("or", at: CGPoint(x: 713, y: 532), fontSize: 12, color: secondaryTextColor)
        canvas.line(from: CGPoint(x: 738, y: 540), to: CGPoint(x: 880, y: 540), color: dividerColor)

        let googleButtonRect = CGRect(x: 560, y: 560, width: 320, height: 42)
        canvas.stroke(googleButtonRect, color: NSColor(white: 0.72, alpha: 1), cornerRadius: 8)
        canvas.symbol("g.circle.fill", in: CGRect(x: 580, y: 571, width: 20, height: 20), color: .systemRed)
        drawCentredText("Continue with Google", in: googleButtonRect, fontSize: 14, weight: .medium, color: .black, on: canvas)
        canvas.markElement("button:Continue with Google", rect: googleButtonRect)

        canvas.text("New here?", at: CGPoint(x: 596, y: 640), fontSize: 13, color: secondaryTextColor)
        let createAccountRect = canvas.text("Create an account", at: CGPoint(x: 668, y: 640), fontSize: 13, color: .systemBlue)
        canvas.markElement("link:Create an account", rect: createAccountRect)

        return canvas.finish(name: "login-page")
    }

    // MARK: - Finder with the File menu open

    public static func finderFileMenu(scale: CGFloat = 2) -> SyntheticScreen? {
        guard let canvas = SyntheticScreenCanvas(pointSize: displaySize, scale: scale) else { return nil }
        canvas.fill(CGRect(origin: .zero, size: displaySize), color: desktopColor)

        // A Finder window behind the open menu.
        let windowRect = CGRect(x: 360, y: 180, width: 860, height: 560)
        drawWindowFrame(windowRect, on: canvas)
        canvas.fill(CGRect(x: windowRect.minX, y: windowRect.minY + 12, width: 190, height: windowRect.height - 24), color: NSColor(white: 0.9, alpha: 1))
        drawTrafficLights(atTopLeft: CGPoint(x: windowRect.minX + 18, y: windowRect.minY + 18), on: canvas)
        for (placeIndex, placeName) in ["Favourites", "AirDrop", "Recents", "Applications", "Desktop", "Documents", "Downloads"].enumerated() {
            canvas.text(placeName, at: CGPoint(x: windowRect.minX + 20, y: windowRect.minY + 56 + CGFloat(placeIndex) * 28), fontSize: placeIndex == 0 ? 11 : 13, weight: placeIndex == 0 ? .semibold : .regular, color: placeIndex == 0 ? secondaryTextColor : .black)
        }
        for (folderIndex, folderName) in ["Invoices", "Photos", "Projects", "Taxes 2026", "Notes", "Music", "Archive", "Clients"].enumerated() {
            let folderLeft = 600 + CGFloat(folderIndex % 4) * 150
            let folderTop = 240 + CGFloat(folderIndex / 4) * 140
            canvas.symbol("folder.fill", in: CGRect(x: folderLeft, y: folderTop, width: 64, height: 52), color: NSColor(calibratedRed: 0.35, green: 0.65, blue: 0.95, alpha: 1))
            drawCentredText(folderName, in: CGRect(x: folderLeft - 30, y: folderTop + 60, width: 124, height: 18), fontSize: 12, weight: .regular, color: .black, on: canvas)
        }

        // Menu bar.
        canvas.fill(CGRect(x: 0, y: 0, width: displaySize.width, height: 26), color: NSColor(white: 0.97, alpha: 1))
        canvas.symbol("apple.logo", in: CGRect(x: 16, y: 5, width: 14, height: 16), color: .black)
        var menuTitleLeft: CGFloat = 46
        var fileMenuLeft: CGFloat = 0
        for menuTitle in ["Finder", "File", "Edit", "View", "Go", "Window", "Help"] {
            let titleWeight: NSFont.Weight = menuTitle == "Finder" ? .bold : .regular
            let titleWidth = canvas.textWidth(menuTitle, fontSize: 13, weight: titleWeight)
            let titleRect = CGRect(x: menuTitleLeft - 8, y: 2, width: titleWidth + 16, height: 22)
            let isOpenMenu = menuTitle == "File"
            if isOpenMenu {
                canvas.fill(titleRect, color: .systemBlue, cornerRadius: 4)
                fileMenuLeft = titleRect.minX
            }
            canvas.text(menuTitle, at: CGPoint(x: menuTitleLeft, y: 5), fontSize: 13, weight: titleWeight, color: isOpenMenu ? .white : .black)
            canvas.markElement("menubar:\(menuTitle)", rect: titleRect)
            menuTitleLeft += titleWidth + 22
        }

        // The open File menu. nil marks a separator line.
        let fileMenuItems: [(title: String, shortcut: String)?] = [
            ("New Finder Window", "⌘N"), ("New Folder", "⇧⌘N"), ("New Smart Folder", ""), ("Open", "⌘O"), ("Close Window", "⌘W"),
            nil,
            ("Get Info", "⌘I"), ("Rename", ""), ("Compress", ""), ("Duplicate", "⌘D"), ("Make Alias", "⌃⌘A"),
            nil,
            ("Move to Trash", "⌘⌫")
        ]
        let menuItemHeight: CGFloat = 22
        let separatorHeight: CGFloat = 10
        let menuContentHeight = fileMenuItems.reduce(CGFloat(0)) { runningHeight, menuItem in
            runningHeight + (menuItem == nil ? separatorHeight : menuItemHeight)
        }
        let menuRect = CGRect(x: fileMenuLeft, y: 26, width: 270, height: menuContentHeight + 10)
        canvas.fill(menuRect, color: NSColor(white: 0.98, alpha: 1), cornerRadius: 6)
        canvas.stroke(menuRect, color: NSColor(white: 0.78, alpha: 1), cornerRadius: 6)

        var menuItemTop = menuRect.minY + 5
        for menuItem in fileMenuItems {
            guard let menuItem else {
                canvas.line(from: CGPoint(x: menuRect.minX + 10, y: menuItemTop + 5), to: CGPoint(x: menuRect.maxX - 10, y: menuItemTop + 5), color: dividerColor)
                menuItemTop += separatorHeight
                continue
            }
            let itemRect = CGRect(x: menuRect.minX + 5, y: menuItemTop, width: menuRect.width - 10, height: menuItemHeight)
            canvas.text(menuItem.title, at: CGPoint(x: itemRect.minX + 12, y: itemRect.minY + 3), fontSize: 13)
            if !menuItem.shortcut.isEmpty {
                let shortcutWidth = canvas.textWidth(menuItem.shortcut, fontSize: 13)
                canvas.text(menuItem.shortcut, at: CGPoint(x: itemRect.maxX - 12 - shortcutWidth, y: itemRect.minY + 3), fontSize: 13, color: secondaryTextColor)
            }
            canvas.markElement("menu:\(menuItem.title)", rect: itemRect)
            menuItemTop += menuItemHeight
        }

        return canvas.finish(name: "finder-file-menu")
    }

    // MARK: - Save changes dialog

    public static func saveChangesDialog(scale: CGFloat = 2) -> SyntheticScreen? {
        guard let canvas = SyntheticScreenCanvas(pointSize: displaySize, scale: scale) else { return nil }
        canvas.fill(CGRect(origin: .zero, size: displaySize), color: desktopColor)

        let windowRect = CGRect(x: 100, y: 50, width: 1240, height: 800)
        drawWindowFrame(windowRect, on: canvas)
        canvas.fill(CGRect(x: windowRect.minX, y: windowRect.minY, width: windowRect.width, height: 52), color: NSColor(white: 0.93, alpha: 1), cornerRadius: 12)
        drawTrafficLights(atTopLeft: CGPoint(x: windowRect.minX + 18, y: windowRect.minY + 20), on: canvas)
        drawCentredTitle("Report.docx — Edited", centreX: windowRect.midX, top: windowRect.minY + 17, on: canvas)
        let pageRect = CGRect(x: 370, y: 130, width: 700, height: 700)
        canvas.fill(pageRect, color: .white)
        drawParagraphLines(left: 430, top: 330, lineCount: 16, on: canvas)
        // The sheet dims the document behind it.
        canvas.fill(CGRect(x: windowRect.minX, y: windowRect.minY + 52, width: windowRect.width, height: windowRect.height - 64), color: NSColor(white: 0, alpha: 0.12))

        let sheetRect = CGRect(x: 520, y: 102, width: 400, height: 196)
        canvas.fill(sheetRect, color: NSColor(white: 0.97, alpha: 1), cornerRadius: 10)
        canvas.stroke(sheetRect, color: NSColor(white: 0.78, alpha: 1), cornerRadius: 10)
        canvas.symbol("doc.text.fill", in: CGRect(x: 546, y: 126, width: 38, height: 46), color: .systemBlue)
        canvas.text("Do you want to save the changes you", at: CGPoint(x: 600, y: 124), fontSize: 13, weight: .semibold)
        canvas.text("made to “Report.docx”?", at: CGPoint(x: 600, y: 142), fontSize: 13, weight: .semibold)
        canvas.text("Your changes will be lost if you don’t save them.", at: CGPoint(x: 600, y: 172), fontSize: 11, color: secondaryTextColor)

        let dialogButtons: [(elementName: String, title: String, rect: CGRect, isDefault: Bool)] = [
            ("Don't Save", "Don’t Save", CGRect(x: 600, y: 246, width: 100, height: 30), false),
            ("Cancel", "Cancel", CGRect(x: 716, y: 246, width: 84, height: 30), false),
            ("Save", "Save", CGRect(x: 812, y: 246, width: 84, height: 30), true)
        ]
        for dialogButton in dialogButtons {
            if dialogButton.isDefault {
                canvas.fill(dialogButton.rect, color: .systemBlue, cornerRadius: 7)
            } else {
                canvas.fill(dialogButton.rect, color: .white, cornerRadius: 7)
                canvas.stroke(dialogButton.rect, color: NSColor(white: 0.72, alpha: 1), cornerRadius: 7)
            }
            drawCentredText(dialogButton.title, in: dialogButton.rect, fontSize: 13, weight: .regular, color: dialogButton.isDefault ? .white : .black, on: canvas)
            canvas.markElement("button:\(dialogButton.elementName)", rect: dialogButton.rect)
        }

        return canvas.finish(name: "save-dialog")
    }

    // MARK: - Spreadsheet

    public static func spreadsheet(scale: CGFloat = 2) -> SyntheticScreen? {
        guard let canvas = SyntheticScreenCanvas(pointSize: displaySize, scale: scale) else { return nil }
        canvas.fill(CGRect(origin: .zero, size: displaySize), color: desktopColor)

        let windowRect = CGRect(x: 60, y: 40, width: 1320, height: 820)
        drawWindowFrame(windowRect, on: canvas)
        canvas.fill(CGRect(x: windowRect.minX, y: windowRect.minY, width: windowRect.width, height: 96), color: NSColor(white: 0.93, alpha: 1), cornerRadius: 12)
        drawTrafficLights(atTopLeft: CGPoint(x: windowRect.minX + 18, y: windowRect.minY + 16), on: canvas)
        drawCentredTitle("Budget 2026.xlsx", centreX: windowRect.midX, top: windowRect.minY + 12, on: canvas)

        let toolbarButtons: [(name: String, symbolName: String)] = [
            ("Undo", "arrow.uturn.backward"), ("Redo", "arrow.uturn.forward"), ("AutoSum", "sum"), ("Sort", "arrow.up.arrow.down"),
            ("Filter", "line.3.horizontal.decrease.circle"), ("Insert chart", "chart.bar.xaxis"), ("Merge cells", "rectangle.split.3x1"), ("Borders", "square.dashed")
        ]
        for (buttonIndex, toolbarButton) in toolbarButtons.enumerated() {
            let buttonRect = CGRect(x: 90 + CGFloat(buttonIndex) * 40, y: windowRect.minY + 52, width: 30, height: 30)
            canvas.symbol(toolbarButton.symbolName, in: buttonRect.insetBy(dx: 7, dy: 7), color: NSColor(white: 0.25, alpha: 1))
            canvas.markElement("toolbar:\(toolbarButton.name)", rect: buttonRect)
        }

        // Formula bar.
        canvas.fill(CGRect(x: windowRect.minX, y: 136, width: windowRect.width, height: 30), color: .white)
        canvas.text("fx", at: CGPoint(x: 80, y: 143), fontSize: 13, weight: .semibold, color: secondaryTextColor)
        canvas.text("=SUM(B2:B11)", at: CGPoint(x: 120, y: 143), fontSize: 13)

        // Grid with a column of expenses.
        let gridTop: CGFloat = 166
        let rowHeaderWidth: CGFloat = 44
        let columnWidth: CGFloat = 110
        let rowHeight: CGFloat = 24
        let columnCount = 11
        let rowCount = 26
        canvas.fill(CGRect(x: windowRect.minX, y: gridTop, width: windowRect.width, height: rowHeight), color: NSColor(white: 0.94, alpha: 1))
        for columnIndex in 0..<columnCount {
            let columnLeft = windowRect.minX + rowHeaderWidth + CGFloat(columnIndex) * columnWidth
            drawCentredText(String(UnicodeScalar(UInt8(65 + columnIndex))), in: CGRect(x: columnLeft, y: gridTop, width: columnWidth, height: rowHeight), fontSize: 11, weight: .medium, color: secondaryTextColor, on: canvas)
            canvas.line(from: CGPoint(x: columnLeft, y: gridTop), to: CGPoint(x: columnLeft, y: gridTop + CGFloat(rowCount + 1) * rowHeight), color: dividerColor)
        }
        let expenses = [("Rent", "32,000"), ("Groceries", "9,500"), ("Travel", "4,200"), ("Internet", "1,100"), ("Electricity", "2,300"), ("Phone", "700"), ("Insurance", "3,000"), ("Gym", "1,500"), ("Books", "900"), ("Gifts", "2,000")]
        for rowIndex in 1...rowCount {
            let rowTop = gridTop + CGFloat(rowIndex) * rowHeight
            canvas.line(from: CGPoint(x: windowRect.minX, y: rowTop), to: CGPoint(x: windowRect.maxX, y: rowTop), color: dividerColor)
            drawCentredText("\(rowIndex)", in: CGRect(x: windowRect.minX, y: rowTop, width: rowHeaderWidth, height: rowHeight), fontSize: 11, weight: .regular, color: secondaryTextColor, on: canvas)
            if rowIndex <= expenses.count {
                canvas.text(expenses[rowIndex - 1].0, at: CGPoint(x: windowRect.minX + rowHeaderWidth + 8, y: rowTop + 5), fontSize: 12)
                canvas.text(expenses[rowIndex - 1].1, at: CGPoint(x: windowRect.minX + rowHeaderWidth + columnWidth + 8, y: rowTop + 5), fontSize: 12)
            }
        }

        // Bottom bar: sheet tabs on the left, zoom on the right.
        let bottomBarRect = CGRect(x: windowRect.minX, y: windowRect.maxY - 40, width: windowRect.width, height: 40)
        canvas.fill(bottomBarRect, color: NSColor(white: 0.95, alpha: 1))
        canvas.fill(CGRect(x: 116, y: bottomBarRect.minY + 7, width: 70, height: 26), color: .white, cornerRadius: 5)
        drawCentredText("Sheet1", in: CGRect(x: 116, y: bottomBarRect.minY + 7, width: 70, height: 26), fontSize: 12, weight: .medium, color: .black, on: canvas)
        drawCentredText("Sheet2", in: CGRect(x: 192, y: bottomBarRect.minY + 7, width: 70, height: 26), fontSize: 12, weight: .regular, color: secondaryTextColor, on: canvas)
        let addSheetRect = CGRect(x: 268, y: bottomBarRect.minY + 9, width: 22, height: 22)
        canvas.symbol("plus", in: addSheetRect.insetBy(dx: 4, dy: 4), color: NSColor(white: 0.3, alpha: 1))
        canvas.markElement("button:Add sheet", rect: addSheetRect)

        let zoomOutRect = CGRect(x: 1186, y: bottomBarRect.minY + 9, width: 22, height: 22)
        canvas.symbol("minus", in: zoomOutRect.insetBy(dx: 5, dy: 5), color: NSColor(white: 0.3, alpha: 1))
        canvas.markElement("button:Zoom out", rect: zoomOutRect)
        canvas.line(from: CGPoint(x: 1214, y: bottomBarRect.midY), to: CGPoint(x: 1290, y: bottomBarRect.midY), color: NSColor(white: 0.6, alpha: 1), lineWidth: 2)
        canvas.fillOval(CGRect(x: 1246, y: bottomBarRect.midY - 6, width: 12, height: 12), color: .white)
        let zoomInRect = CGRect(x: 1296, y: bottomBarRect.minY + 9, width: 22, height: 22)
        canvas.symbol("plus", in: zoomInRect.insetBy(dx: 5, dy: 5), color: NSColor(white: 0.3, alpha: 1))
        canvas.markElement("button:Zoom in", rect: zoomInRect)
        canvas.text("100%", at: CGPoint(x: 1326, y: bottomBarRect.minY + 13), fontSize: 12, color: secondaryTextColor)

        return canvas.finish(name: "spreadsheet")
    }

    // MARK: - Shared pieces

    private static func drawWindowFrame(_ windowRect: CGRect, on canvas: SyntheticScreenCanvas) {
        canvas.fill(windowRect.insetBy(dx: -1, dy: -1), color: NSColor(white: 0, alpha: 0.25), cornerRadius: 13)
        canvas.fill(windowRect, color: windowColor, cornerRadius: 12)
    }

    private static func drawTrafficLights(atTopLeft topLeft: CGPoint, on canvas: SyntheticScreenCanvas) {
        for (lightIndex, lightColor) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
            canvas.fillOval(CGRect(x: topLeft.x + CGFloat(lightIndex) * 20, y: topLeft.y, width: 12, height: 12), color: lightColor)
        }
    }

    private static func drawCentredTitle(_ title: String, centreX: CGFloat, top: CGFloat, on canvas: SyntheticScreenCanvas) {
        let titleWidth = canvas.textWidth(title, fontSize: 13, weight: .semibold)
        canvas.text(title, at: CGPoint(x: centreX - titleWidth / 2, y: top), fontSize: 13, weight: .semibold)
    }

    private static func drawCentredText(_ text: String, in rect: CGRect, fontSize: CGFloat, weight: NSFont.Weight, color: NSColor, on canvas: SyntheticScreenCanvas) {
        let textWidth = canvas.textWidth(text, fontSize: fontSize, weight: weight)
        // The system font's line is roughly 1.2× its size; centre that box vertically.
        canvas.text(text, at: CGPoint(x: rect.midX - textWidth / 2, y: rect.midY - fontSize * 0.6), fontSize: fontSize, weight: weight, color: color)
    }

    /// Grey bars standing in for body text, of varying length so they read like a paragraph.
    private static func drawParagraphLines(left: CGFloat, top: CGFloat, lineCount: Int, on canvas: SyntheticScreenCanvas) {
        let lineWidths: [CGFloat] = [560, 540, 575, 520, 390]
        for lineIndex in 0..<lineCount {
            canvas.fill(
                CGRect(x: left, y: top + CGFloat(lineIndex) * 26, width: lineWidths[lineIndex % lineWidths.count], height: 10),
                color: NSColor(white: 0.86, alpha: 1),
                cornerRadius: 3
            )
        }
    }
}
