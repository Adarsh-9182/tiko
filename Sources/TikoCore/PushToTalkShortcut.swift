import Foundation

/// The modifier keys held down to talk to Tiko.
public enum PushToTalkShortcut: String, CaseIterable, Identifiable, Sendable {
    case controlOption
    case optionCommand
    /// A single key, easier to hold while the other hand is on the mouse —
    /// two held keys was a complaint about Clicky (its issue #35).
    case rightOption

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .controlOption: return "⌃ Control + ⌥ Option"
        case .optionCommand: return "⌥ Option + ⌘ Command"
        case .rightOption: return "Right ⌥ Option"
        }
    }

    /// The short form used in hints, like "⌃⌥".
    public var symbols: String {
        switch self {
        case .controlOption: return "⌃⌥"
        case .optionCommand: return "⌥⌘"
        case .rightOption: return "right ⌥"
        }
    }

    /// The raw bits of macOS's CGEventFlags, spelled out so this logic doesn't
    /// depend on CoreGraphics and can be checked from the command line.
    private enum ModifierBit {
        static let shift: UInt64 = 0x0002_0000
        static let control: UInt64 = 0x0004_0000
        static let option: UInt64 = 0x0008_0000
        static let command: UInt64 = 0x0010_0000
        /// Device-dependent bits that tell the left and right Option keys apart.
        static let leftOption: UInt64 = 0x0000_0020
        static let rightOption: UInt64 = 0x0000_0040
    }

    /// Whether exactly this shortcut is held. Extra modifiers turn it into a
    /// different keyboard shortcut, so they don't count.
    public func isHeld(modifierFlagsRawValue modifierFlags: UInt64) -> Bool {
        let isShiftHeld = (modifierFlags & ModifierBit.shift) != 0
        let isControlHeld = (modifierFlags & ModifierBit.control) != 0
        let isOptionHeld = (modifierFlags & ModifierBit.option) != 0
        let isCommandHeld = (modifierFlags & ModifierBit.command) != 0

        switch self {
        case .controlOption:
            return isControlHeld && isOptionHeld && !isCommandHeld && !isShiftHeld
        case .optionCommand:
            return isOptionHeld && isCommandHeld && !isControlHeld && !isShiftHeld
        case .rightOption:
            let isRightOptionHeld = (modifierFlags & ModifierBit.rightOption) != 0
            let isLeftOptionHeld = (modifierFlags & ModifierBit.leftOption) != 0
            return isOptionHeld && isRightOptionHeld && !isLeftOptionHeld && !isControlHeld && !isCommandHeld && !isShiftHeld
        }
    }
}
