import Foundation
import IOKit.pwr_mgt

final class PowerAssertion {
    private var assertionID: IOPMAssertionID = 0
    private var active = false

    func acquire() {
        guard !active else { return }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Baby Mode is running" as CFString,
            &assertionID
        )
        active = result == kIOReturnSuccess
    }

    func release() {
        guard active else { return }
        IOPMAssertionRelease(assertionID)
        active = false
    }
}
