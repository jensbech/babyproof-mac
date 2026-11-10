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

let enter = UnlockTracker.returnKeyCode
let keypadEnter = UnlockTracker.keypadEnterKeyCode
let otherKey = 0

func press(_ t: inout UnlockTracker, _ code: Int, times: Int) {
    for _ in 0..<times {
        t.handle(.keyDown(code: code, isRepeat: false))
    }
}

do {
    var t = UnlockTracker()
    press(&t, enter, times: 4)
    check("4 enters does not unlock", !t.shouldUnlock)
    press(&t, enter, times: 1)
    check("5 enters unlocks", t.shouldUnlock)
}

do {
    var t = UnlockTracker()
    press(&t, enter, times: 2)
    press(&t, keypadEnter, times: 3)
    check("keypad enter counts", t.shouldUnlock)
}

do {
    var t = UnlockTracker()
    press(&t, enter, times: 4)
    press(&t, otherKey, times: 1)
    press(&t, enter, times: 1)
    check("other key resets the count", !t.shouldUnlock)
    press(&t, enter, times: 3)
    check("still locked at 4 after reset", !t.shouldUnlock)
    press(&t, enter, times: 1)
    check("5 enters after reset unlocks", t.shouldUnlock)
}

do {
    var t = UnlockTracker()
    press(&t, enter, times: 4)
    t.handle(.modifiersChanged)
    press(&t, enter, times: 1)
    check("modifier key resets the count", !t.shouldUnlock)
}

do {
    var t = UnlockTracker()
    press(&t, enter, times: 1)
    for _ in 0..<50 {
        t.handle(.keyDown(code: enter, isRepeat: true))
    }
    check("holding enter does not count", !t.shouldUnlock)
    press(&t, enter, times: 4)
    check("repeats do not break the run", t.shouldUnlock)
}

do {
    var t = UnlockTracker()
    press(&t, enter, times: 4)
    t.handle(.keyDown(code: otherKey, isRepeat: true))
    press(&t, enter, times: 1)
    check("other key auto-repeat resets the count", !t.shouldUnlock)
}

do {
    var t = UnlockTracker()
    press(&t, enter, times: 5)
    t.reset()
    check("reset clears the count", !t.shouldUnlock)
}

let vKey = ActivationTracker.vKeyCode

func sequence(_ t: inout ActivationTracker, _ codes: [Int], gap: TimeInterval = 0.2, from start: TimeInterval = 100) -> Bool {
    var time = start
    var fired = false
    for code in codes {
        fired = t.handle(.keyDown(code: code, isRepeat: false), at: time)
        time += gap
    }
    return fired
}

do {
    var t = ActivationTracker()
    check("enter v enter activates", sequence(&t, [enter, vKey, enter]))
}

do {
    var t = ActivationTracker()
    check("keypad enter activates", sequence(&t, [keypadEnter, vKey, keypadEnter]))
}

do {
    var t = ActivationTracker()
    check("extra leading enter still activates", sequence(&t, [enter, enter, vKey, enter]))
}

do {
    var t = ActivationTracker()
    check("other key between blocks", !sequence(&t, [enter, otherKey, vKey, enter]))
}

do {
    var t = ActivationTracker()
    check("double v blocks", !sequence(&t, [enter, vKey, vKey, enter]))
}

do {
    var t = ActivationTracker()
    check("v enter alone does not activate", !sequence(&t, [vKey, enter]))
}

do {
    var t = ActivationTracker()
    check("slow presses do not activate", !sequence(&t, [enter, vKey, enter], gap: 2))
}

do {
    var t = ActivationTracker()
    check("presses at the time limit activate", sequence(&t, [enter, vKey, enter], gap: 1.5))
}

do {
    var t = ActivationTracker()
    _ = sequence(&t, [enter, vKey])
    _ = t.handle(.modifiersChanged, at: 100.4)
    check("modifier blocks", !t.handle(.keyDown(code: enter, isRepeat: false), at: 100.5))
}

do {
    var t = ActivationTracker()
    _ = sequence(&t, [enter, vKey])
    check("holding enter into repeat does not fire", !t.handle(.keyDown(code: enter, isRepeat: true), at: 100.4))
    check("fresh press after repeat fires", t.handle(.keyDown(code: enter, isRepeat: false), at: 100.5))
}

do {
    var t = ActivationTracker()
    check("first run fires", sequence(&t, [enter, vKey, enter]))
    check("does not fire again without the full sequence", !t.handle(.keyDown(code: enter, isRepeat: false), at: 101))
}

print("\n\(total - failures)/\(total) passed")
exit(failures == 0 ? 0 : 1)
