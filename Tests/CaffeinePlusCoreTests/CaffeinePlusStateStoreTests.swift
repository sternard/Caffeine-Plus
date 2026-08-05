import XCTest
@testable import CaffeinePlusCore

final class CaffeinePlusStateStoreTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CaffeinePlusTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
    }

    func testMissingStateUsesSafeDefaults() {
        let store = CaffeinePlusStateStore(baseDirectory: temporaryDirectory)

        XCTAssertEqual(store.load(), .defaults)
    }

    func testRoundTripsEnabledStateAndOptions() throws {
        let store = CaffeinePlusStateStore(baseDirectory: temporaryDirectory)
        let state = CaffeinePlusState(
            isEnabled: true,
            options: CaffeineOptions(
                keepDisplayAwake: true,
                preventIdleSystemSleep: false,
                sendActivityPulses: true
            )
        )

        try store.save(state)

        XCTAssertEqual(store.load(), state)
    }

    func testCorruptStateUsesSafeDefaults() throws {
        let stateURL = temporaryDirectory.appendingPathComponent("state.json")
        try Data("not-json".utf8).write(to: stateURL)
        let store = CaffeinePlusStateStore(baseDirectory: temporaryDirectory)

        XCTAssertEqual(store.load(), .defaults)
    }
}
