import Foundation

public struct KeyBindings: Equatable {
    public static let activationGap: TimeInterval = 1.5
    public static let activationLength = 2...8
    public static let unlockLength = 3...12

    public static let defaultActivation = [KeyCode.returnKey, KeyCode.v, KeyCode.returnKey]
    public static let defaultUnlock = Array(repeating: KeyCode.returnKey, count: 5)
    public static let defaults = KeyBindings(activation: defaultActivation, unlock: defaultUnlock)

    private static let activationKey = "activationKeys"
    private static let unlockKey = "unlockKeys"

    public var activation: [Int]
    public var unlock: [Int]

    public init(activation: [Int], unlock: [Int]) {
        self.activation = activation.map(KeyCode.normalize)
        self.unlock = unlock.map(KeyCode.normalize)
    }

    public static func validateActivation(_ keys: [Int]) -> String? {
        guard activationLength.contains(keys.count) else {
            return "The start sequence needs \(activationLength.lowerBound) to \(activationLength.upperBound) keys."
        }
        return nil
    }

    public static func validateUnlock(_ keys: [Int]) -> String? {
        guard unlockLength.contains(keys.count) else {
            return "The stop sequence needs \(unlockLength.lowerBound) to \(unlockLength.upperBound) keys, so a baby can't hit it by accident."
        }
        return nil
    }

    public func activationMatcher() -> KeySequenceMatcher {
        KeySequenceMatcher(sequence: activation, maxGap: KeyBindings.activationGap)
    }

    public func unlockMatcher() -> KeySequenceMatcher {
        KeySequenceMatcher(sequence: unlock, otherKeyRepeatResets: true)
    }

    public static func load(from defaults: UserDefaults = .standard) -> KeyBindings {
        var activation = defaults.array(forKey: activationKey) as? [Int] ?? defaultActivation
        var unlock = defaults.array(forKey: unlockKey) as? [Int] ?? defaultUnlock
        if validateActivation(activation) != nil { activation = defaultActivation }
        if validateUnlock(unlock) != nil { unlock = defaultUnlock }
        return KeyBindings(activation: activation, unlock: unlock)
    }

    public func save(to defaults: UserDefaults = .standard) {
        defaults.set(activation, forKey: KeyBindings.activationKey)
        defaults.set(unlock, forKey: KeyBindings.unlockKey)
    }
}
