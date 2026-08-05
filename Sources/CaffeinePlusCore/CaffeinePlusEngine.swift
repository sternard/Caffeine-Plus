import Foundation
import IOKit.pwr_mgt

public enum PowerAssertionKind: CaseIterable, Equatable, Sendable {
    case displaySleep
    case systemSleep
}

public struct PowerAssertionError: Error, Equatable, LocalizedError, Sendable {
    public let operation: String
    public let code: Int32

    public init(operation: String, code: Int32) {
        self.operation = operation
        self.code = code
    }

    public var errorDescription: String? {
        "\(operation) failed with IOKit error \(code)."
    }
}

public protocol PowerAssertionProviding: AnyObject {
    func createAssertion(_ kind: PowerAssertionKind, reason: String) throws -> UInt32
    func declareUserActivity(previousID: UInt32?, reason: String) throws -> UInt32
    func releaseAssertion(_ identifier: UInt32)
}

public struct CaffeineOptions: Codable, Equatable, Sendable {
    public var keepDisplayAwake: Bool
    public var preventIdleSystemSleep: Bool
    public var sendActivityPulses: Bool

    public init(
        keepDisplayAwake: Bool = true,
        preventIdleSystemSleep: Bool = true,
        sendActivityPulses: Bool = true
    ) {
        self.keepDisplayAwake = keepDisplayAwake
        self.preventIdleSystemSleep = preventIdleSystemSleep
        self.sendActivityPulses = sendActivityPulses
    }

    public static let all = CaffeineOptions()

    public var hasEnabledSafeguard: Bool {
        keepDisplayAwake || preventIdleSystemSleep || sendActivityPulses
    }

    public var enabledSafeguardCount: Int {
        [keepDisplayAwake, preventIdleSystemSleep, sendActivityPulses]
            .filter { $0 }
            .count
    }
}

public enum CaffeinePlusConfigurationError: Error, LocalizedError, Equatable, Sendable {
    case noSafeguardsEnabled

    public var errorDescription: String? {
        "Select at least one safeguard before enabling Caffeine Plus."
    }
}

public final class IOKitPowerAssertionProvider: PowerAssertionProviding {
    public init() {}

    public func createAssertion(_ kind: PowerAssertionKind, reason: String) throws -> UInt32 {
        let assertionType: CFString
        switch kind {
        case .displaySleep:
            assertionType = kIOPMAssertPreventUserIdleDisplaySleep as CFString
        case .systemSleep:
            assertionType = kIOPMAssertPreventUserIdleSystemSleep as CFString
        }

        var identifier = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            assertionType,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &identifier
        )

        guard result == kIOReturnSuccess else {
            throw PowerAssertionError(
                operation: "Creating the \(kind.description) assertion",
                code: result
            )
        }
        return identifier
    }

    public func declareUserActivity(previousID: UInt32?, reason: String) throws -> UInt32 {
        var identifier = IOPMAssertionID(previousID ?? 0)
        let result = IOPMAssertionDeclareUserActivity(
            reason as CFString,
            kIOPMUserActiveLocal,
            &identifier
        )

        guard result == kIOReturnSuccess else {
            throw PowerAssertionError(
                operation: "Declaring user activity",
                code: result
            )
        }
        return identifier
    }

    public func releaseAssertion(_ identifier: UInt32) {
        IOPMAssertionRelease(IOPMAssertionID(identifier))
    }
}

public final class CaffeinePlusEngine {
    public static let defaultIdleThreshold: TimeInterval = 2 * 60
    public static let defaultPulseInterval: TimeInterval = 60

    public private(set) var isActive = false
    public private(set) var lastPulseDate: Date?
    public private(set) var activeOptions: CaffeineOptions?

    private let provider: PowerAssertionProviding
    private let idleThreshold: TimeInterval
    private let pulseInterval: TimeInterval
    private let reason = "Caffeine Plus is enabled"

    private var assertionIDs: [UInt32] = []
    private var userActivityAssertionID: UInt32?

    public init(
        provider: PowerAssertionProviding = IOKitPowerAssertionProvider(),
        idleThreshold: TimeInterval = CaffeinePlusEngine.defaultIdleThreshold,
        pulseInterval: TimeInterval = CaffeinePlusEngine.defaultPulseInterval
    ) {
        self.provider = provider
        self.idleThreshold = max(0, idleThreshold)
        self.pulseInterval = max(0, pulseInterval)
    }

    deinit {
        stop()
    }

    public func start(
        options: CaffeineOptions = .all,
        at date: Date = Date()
    ) throws {
        guard !isActive else {
            return
        }
        guard options.hasEnabledSafeguard else {
            throw CaffeinePlusConfigurationError.noSafeguardsEnabled
        }

        var createdIDs: [UInt32] = []
        do {
            let assertionKinds = PowerAssertionKind.allCases.filter { kind in
                switch kind {
                case .displaySleep:
                    return options.keepDisplayAwake
                case .systemSleep:
                    return options.preventIdleSystemSleep
                }
            }

            for kind in assertionKinds {
                createdIDs.append(try provider.createAssertion(kind, reason: reason))
            }

            let activityID: UInt32?
            if options.sendActivityPulses {
                activityID = try provider.declareUserActivity(
                    previousID: nil,
                    reason: reason
                )
            } else {
                activityID = nil
            }

            assertionIDs = createdIDs
            userActivityAssertionID = activityID
            lastPulseDate = activityID == nil ? nil : date
            activeOptions = options
            isActive = true
        } catch {
            for identifier in createdIDs.reversed() {
                provider.releaseAssertion(identifier)
            }
            throw error
        }
    }

    @discardableResult
    public func pulseIfNeeded(
        inputIdleDuration: TimeInterval,
        at date: Date = Date()
    ) throws -> Bool {
        guard isActive,
              activeOptions?.sendActivityPulses == true,
              inputIdleDuration >= idleThreshold else {
            return false
        }

        if let lastPulseDate,
           date.timeIntervalSince(lastPulseDate) < pulseInterval {
            return false
        }

        userActivityAssertionID = try provider.declareUserActivity(
            previousID: userActivityAssertionID,
            reason: reason
        )
        lastPulseDate = date
        return true
    }

    public func restart(
        options: CaffeineOptions? = nil,
        at date: Date = Date()
    ) throws {
        let optionsToRestore = options ?? activeOptions ?? .all
        stop()
        try start(options: optionsToRestore, at: date)
    }

    public func stop() {
        if let userActivityAssertionID {
            provider.releaseAssertion(userActivityAssertionID)
        }
        for identifier in assertionIDs.reversed() {
            provider.releaseAssertion(identifier)
        }

        assertionIDs = []
        userActivityAssertionID = nil
        lastPulseDate = nil
        activeOptions = nil
        isActive = false
    }
}

private extension PowerAssertionKind {
    var description: String {
        switch self {
        case .displaySleep:
            return "display-sleep"
        case .systemSleep:
            return "system-sleep"
        }
    }
}
