import Foundation

public enum KeyEvent: Equatable {
    case keyDown(code: Int, isRepeat: Bool)
    case modifiersChanged
}

public enum KeyCode {
    public static let returnKey = 36
    public static let keypadEnter = 76
    public static let v = 9

    public static func normalize(_ code: Int) -> Int {
        code == keypadEnter ? returnKey : code
    }
}

public struct KeySequenceMatcher {
    public let sequence: [Int]
    public let maxGap: TimeInterval?
    public let otherKeyRepeatResets: Bool

    private var buffer: [Int] = []
    private var lastPress: TimeInterval = -.infinity

    public init(sequence: [Int], maxGap: TimeInterval? = nil, otherKeyRepeatResets: Bool = false) {
        self.sequence = sequence.map(KeyCode.normalize)
        self.maxGap = maxGap
        self.otherKeyRepeatResets = otherKeyRepeatResets
    }

    public mutating func reset() {
        buffer.removeAll()
    }

    public mutating func handle(_ event: KeyEvent, at now: TimeInterval = 0) -> Bool {
        guard !sequence.isEmpty else { return false }
        switch event {
        case .modifiersChanged:
            buffer.removeAll()
            return false
        case let .keyDown(rawCode, isRepeat):
            let code = KeyCode.normalize(rawCode)
            if isRepeat {
                if otherKeyRepeatResets && code != buffer.last { buffer.removeAll() }
                return false
            }
            if let gap = maxGap, now - lastPress > gap { buffer.removeAll() }
            lastPress = now
            buffer.append(code)
            if buffer.count > sequence.count { buffer.removeFirst(buffer.count - sequence.count) }
            guard buffer == sequence else { return false }
            buffer.removeAll()
            return true
        }
    }
}
