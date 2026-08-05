import XCTest
@testable import CaffeinePlusCore

final class CaffeinePlusEngineTests: XCTestCase {
    func testDefaultActivityPulseIdleThresholdIs120Seconds() {
        XCTAssertEqual(CaffeineOptions.all.activityPulseIdleSeconds, 120)
    }

    func testStartCreatesBothAssertionsAndInitialActivityPulse() throws {
        let provider = RecordingProvider()
        let engine = CaffeinePlusEngine(provider: provider)
        let now = Date(timeIntervalSince1970: 1_000)

        try engine.start(at: now)

        XCTAssertTrue(engine.isActive)
        XCTAssertEqual(engine.activeOptions, .all)
        XCTAssertEqual(engine.lastPulseDate, now)
        XCTAssertEqual(provider.createdKinds, [.displaySleep, .systemSleep])
        XCTAssertEqual(provider.activityPreviousIDs, [nil])
        XCTAssertTrue(provider.releasedIDs.isEmpty)
    }

    func testStartUsesOnlySelectedSafeguards() throws {
        let provider = RecordingProvider()
        let engine = CaffeinePlusEngine(provider: provider)
        let options = CaffeineOptions(
            keepDisplayAwake: false,
            preventIdleSystemSleep: true,
            sendActivityPulses: false
        )

        try engine.start(options: options)

        XCTAssertTrue(engine.isActive)
        XCTAssertEqual(engine.activeOptions, options)
        XCTAssertEqual(provider.createdKinds, [.systemSleep])
        XCTAssertTrue(provider.activityPreviousIDs.isEmpty)
        XCTAssertNil(engine.lastPulseDate)
    }

    func testStartRejectsConfigurationWithoutSafeguards() {
        let engine = CaffeinePlusEngine(provider: RecordingProvider())
        let options = CaffeineOptions(
            keepDisplayAwake: false,
            preventIdleSystemSleep: false,
            sendActivityPulses: false
        )

        XCTAssertThrowsError(try engine.start(options: options)) { error in
            XCTAssertEqual(error as? CaffeinePlusConfigurationError, .noSafeguardsEnabled)
        }
        XCTAssertFalse(engine.isActive)
    }

    func testPulseUsesConfiguredIdleThresholdAndFixedRenewalInterval() throws {
        let provider = RecordingProvider()
        let engine = CaffeinePlusEngine(
            provider: provider,
            pulseInterval: 60
        )
        let start = Date(timeIntervalSince1970: 1_000)
        let options = CaffeineOptions(activityPulseIdleSeconds: 37)
        try engine.start(options: options, at: start)

        XCTAssertFalse(try engine.pulseIfNeeded(
            inputIdleDuration: 36,
            at: start.addingTimeInterval(120)
        ))
        XCTAssertTrue(try engine.pulseIfNeeded(
            inputIdleDuration: 37,
            at: start.addingTimeInterval(120)
        ))
        XCTAssertFalse(try engine.pulseIfNeeded(
            inputIdleDuration: 180,
            at: start.addingTimeInterval(150)
        ))
        XCTAssertTrue(try engine.pulseIfNeeded(
            inputIdleDuration: 180,
            at: start.addingTimeInterval(180)
        ))

        XCTAssertEqual(provider.activityPreviousIDs.count, 3)
        XCTAssertEqual(provider.activityPreviousIDs[1]!, 3)
        XCTAssertEqual(provider.activityPreviousIDs[2]!, 4)
    }

    func testPulseDoesNothingWhenOptionIsDisabled() throws {
        let provider = RecordingProvider()
        let engine = CaffeinePlusEngine(provider: provider, pulseInterval: 0)
        let options = CaffeineOptions(sendActivityPulses: false)
        try engine.start(options: options)

        XCTAssertFalse(try engine.pulseIfNeeded(inputIdleDuration: 1_000))
        XCTAssertTrue(provider.activityPreviousIDs.isEmpty)
    }

    func testStopReleasesLatestActivityAndPersistentAssertions() throws {
        let provider = RecordingProvider()
        let engine = CaffeinePlusEngine(provider: provider, pulseInterval: 0)
        let start = Date(timeIntervalSince1970: 1_000)
        try engine.start(at: start)
        _ = try engine.pulseIfNeeded(inputIdleDuration: 1_000, at: start.addingTimeInterval(1))

        engine.stop()

        XCTAssertFalse(engine.isActive)
        XCTAssertNil(engine.activeOptions)
        XCTAssertNil(engine.lastPulseDate)
        XCTAssertEqual(provider.releasedIDs, [4, 2, 1])
    }

    func testPartialStartFailureReleasesCreatedAssertion() {
        let provider = RecordingProvider()
        provider.failCreateCall = 2
        let engine = CaffeinePlusEngine(provider: provider)

        XCTAssertThrowsError(try engine.start())

        XCTAssertFalse(engine.isActive)
        XCTAssertEqual(provider.createdKinds, [.displaySleep, .systemSleep])
        XCTAssertEqual(provider.releasedIDs, [1])
    }

    func testActivityFailureDuringStartReleasesBothPersistentAssertions() {
        let provider = RecordingProvider()
        provider.failActivityCall = 1
        let engine = CaffeinePlusEngine(provider: provider)

        XCTAssertThrowsError(try engine.start())

        XCTAssertFalse(engine.isActive)
        XCTAssertEqual(provider.releasedIDs, [2, 1])
    }
}

private final class RecordingProvider: PowerAssertionProviding {
    var createdKinds: [PowerAssertionKind] = []
    var activityPreviousIDs: [UInt32?] = []
    var releasedIDs: [UInt32] = []
    var failCreateCall: Int?
    var failActivityCall: Int?

    private var nextID: UInt32 = 1

    func createAssertion(_ kind: PowerAssertionKind, reason: String) throws -> UInt32 {
        createdKinds.append(kind)
        if createdKinds.count == failCreateCall {
            throw RecordingError.requestedFailure
        }
        return takeID()
    }

    func declareUserActivity(previousID: UInt32?, reason: String) throws -> UInt32 {
        activityPreviousIDs.append(previousID)
        if activityPreviousIDs.count == failActivityCall {
            throw RecordingError.requestedFailure
        }
        return takeID()
    }

    func releaseAssertion(_ identifier: UInt32) {
        releasedIDs.append(identifier)
    }

    private func takeID() -> UInt32 {
        defer { nextID += 1 }
        return nextID
    }
}

private enum RecordingError: Error {
    case requestedFailure
}
