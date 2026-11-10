import Foundation

var failures = 0
var total = 0

func check(_ name: String, _ condition: Bool) {
    total += 1
    if condition {
        print("PASS  \(name)")
    } else {
        failures += 1
        print("FAIL  \(name)")
    }
}

let enter = KeyCode.returnKey
let keypadEnter = KeyCode.keypadEnter
let vKey = KeyCode.v
let otherKey = 0
let bKey = 11

func press(_ t: inout KeySequenceMatcher, _ code: Int, times: Int) -> Bool {
    var fired = false
    for _ in 0..<times {
        fired = t.handle(.keyDown(code: code, isRepeat: false))
    }
    return fired
}

func unlock() -> KeySequenceMatcher { KeyBindings.defaults.unlockMatcher() }

do {
    var t = unlock()
    check("4 enters does not unlock", !press(&t, enter, times: 4))
    check("5 enters unlocks", press(&t, enter, times: 1))
}

do {
    var t = unlock()
    _ = press(&t, enter, times: 2)
    check("keypad enter counts", press(&t, keypadEnter, times: 3))
}

do {
    var t = unlock()
    _ = press(&t, enter, times: 4)
    _ = press(&t, otherKey, times: 1)
    check("other key resets the count", !press(&t, enter, times: 1))
    check("still locked at 4 after reset", !press(&t, enter, times: 3))
    check("5 enters after reset unlocks", press(&t, enter, times: 1))
}

do {
    var t = unlock()
    _ = press(&t, enter, times: 4)
    _ = t.handle(.modifiersChanged)
    check("modifier key resets the count", !press(&t, enter, times: 1))
}

do {
    var t = unlock()
    _ = press(&t, enter, times: 1)
    var fired = false
    for _ in 0..<50 {
        fired = fired || t.handle(.keyDown(code: enter, isRepeat: true))
    }
    check("holding enter does not count", !fired)
    check("repeats do not break the run", press(&t, enter, times: 4))
}

do {
    var t = unlock()
    _ = press(&t, enter, times: 4)
    _ = t.handle(.keyDown(code: otherKey, isRepeat: true))
    check("other key auto-repeat resets the count", !press(&t, enter, times: 1))
}

do {
    var t = unlock()
    _ = press(&t, enter, times: 4)
    t.reset()
    check("reset clears the count", !press(&t, enter, times: 1))
}

do {
    var t = KeyBindings(activation: KeyBindings.defaultActivation, unlock: [bKey, otherKey, bKey]).unlockMatcher()
    check("custom unlock fires", press(&t, bKey, times: 1) || press(&t, otherKey, times: 1) || press(&t, bKey, times: 1))
    _ = press(&t, bKey, times: 1)
    _ = press(&t, bKey, times: 1)
    _ = press(&t, otherKey, times: 1)
    check("custom unlock fires after a false start", press(&t, bKey, times: 1))
}

func sequence(_ t: inout KeySequenceMatcher, _ codes: [Int], gap: TimeInterval = 0.2, from start: TimeInterval = 100) -> Bool {
    var time = start
    var fired = false
    for code in codes {
        fired = t.handle(.keyDown(code: code, isRepeat: false), at: time)
        time += gap
    }
    return fired
}

func activation() -> KeySequenceMatcher { KeyBindings.defaults.activationMatcher() }

do {
    var t = activation()
    check("enter v enter activates", sequence(&t, [enter, vKey, enter]))
}

do {
    var t = activation()
    check("keypad enter activates", sequence(&t, [keypadEnter, vKey, keypadEnter]))
}

do {
    var t = activation()
    check("extra leading enter still activates", sequence(&t, [enter, enter, vKey, enter]))
}

do {
    var t = activation()
    check("other key between blocks", !sequence(&t, [enter, otherKey, vKey, enter]))
}

do {
    var t = activation()
    check("double v blocks", !sequence(&t, [enter, vKey, vKey, enter]))
}

do {
    var t = activation()
    check("v enter alone does not activate", !sequence(&t, [vKey, enter]))
}

do {
    var t = activation()
    check("slow presses do not activate", !sequence(&t, [enter, vKey, enter], gap: 2))
}

do {
    var t = activation()
    check("presses at the time limit activate", sequence(&t, [enter, vKey, enter], gap: 1.5))
}

do {
    var t = activation()
    _ = sequence(&t, [enter, vKey])
    _ = t.handle(.modifiersChanged, at: 100.4)
    check("modifier blocks", !t.handle(.keyDown(code: enter, isRepeat: false), at: 100.5))
}

do {
    var t = activation()
    _ = sequence(&t, [enter, vKey])
    check("holding enter into repeat does not fire", !t.handle(.keyDown(code: enter, isRepeat: true), at: 100.4))
    check("fresh press after repeat fires", t.handle(.keyDown(code: enter, isRepeat: false), at: 100.5))
}

do {
    var t = activation()
    check("first run fires", sequence(&t, [enter, vKey, enter]))
    check("does not fire again without the full sequence", !t.handle(.keyDown(code: enter, isRepeat: false), at: 101))
}

do {
    var t = KeyBindings(activation: [bKey, bKey], unlock: KeyBindings.defaultUnlock).activationMatcher()
    check("custom activation fires", sequence(&t, [otherKey, bKey, bKey]))
    check("custom activation needs the full run again", !sequence(&t, [bKey], from: 101))
}

check("one-key start is rejected", KeyBindings.validateActivation([bKey]) != nil)
check("two-key start is accepted", KeyBindings.validateActivation([bKey, vKey]) == nil)
check("two-key stop is rejected", KeyBindings.validateUnlock([enter, enter]) != nil)
check("three-key stop is accepted", KeyBindings.validateUnlock([enter, enter, enter]) == nil)

do {
    let suite = "babymode.tests.\(UUID().uuidString)"
    let store = UserDefaults(suiteName: suite)!
    check("defaults load when nothing saved", KeyBindings.load(from: store) == KeyBindings.defaults)
    let custom = KeyBindings(activation: [bKey, vKey], unlock: [otherKey, otherKey, otherKey])
    custom.save(to: store)
    check("saved bindings load back", KeyBindings.load(from: store) == custom)
    store.set([bKey], forKey: "activationKeys")
    check("invalid saved start falls back to default", KeyBindings.load(from: store).activation == KeyBindings.defaultActivation)
    store.removePersistentDomain(forName: suite)
}

print("\n\(total - failures)/\(total) passed")
exit(failures == 0 ? 0 : 1)
