import Foundation

public enum UnlockEvent: Equatable {
    case keyDown(code: Int, isRepeat: Bool)
    case modifiersChanged
}

public struct UnlockTracker {
    public static let returnKeyCode = 36
    public static let keypadEnterKeyCode = 76
    public static let requiredPresses = 5

    private var presses = 0

    public init() {}

    public var shouldUnlock: Bool { presses >= Self.requiredPresses }

    public mutating func reset() {
        presses = 0
    }

    public mutating func handle(_ event: UnlockEvent) {
        switch event {
        case let .keyDown(code, isRepeat):
            if code == Self.returnKeyCode || code == Self.keypadEnterKeyCode {
                if !isRepeat { presses += 1 }
            } else {
                presses = 0
            }
        case .modifiersChanged:
            presses = 0
        }
    }
}
