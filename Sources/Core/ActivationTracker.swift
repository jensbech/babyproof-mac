import Foundation

public enum ActivationEvent: Equatable {
    case keyDown(code: Int, isRepeat: Bool)
    case modifiersChanged
}

public struct ActivationTracker {
    public static let vKeyCode = 9
    public static let stepWindow: TimeInterval = 1.5

    private var step = 0
    private var lastPress: TimeInterval = 0

    public init() {}

    public mutating func reset() {
        step = 0
    }

    public mutating func handle(_ event: ActivationEvent, at now: TimeInterval) -> Bool {
        switch event {
        case .modifiersChanged:
            step = 0
            return false
        case let .keyDown(code, isRepeat):
            if isRepeat { return false }
            if now - lastPress > Self.stepWindow { step = 0 }
            lastPress = now
            let isEnter = code == UnlockTracker.returnKeyCode || code == UnlockTracker.keypadEnterKeyCode
            switch step {
            case 1 where code == Self.vKeyCode:
                step = 2
            case 2 where isEnter:
                step = 0
                return true
            default:
                step = isEnter ? 1 : 0
            }
            return false
        }
    }
}
