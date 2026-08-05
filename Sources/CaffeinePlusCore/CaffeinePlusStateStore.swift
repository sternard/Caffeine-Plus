import Foundation

public struct CaffeinePlusState: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var options: CaffeineOptions

    public init(isEnabled: Bool, options: CaffeineOptions) {
        self.isEnabled = isEnabled
        self.options = options
    }

    public static let defaults = CaffeinePlusState(
        isEnabled: false,
        options: .all
    )
}

public final class CaffeinePlusStateStore {
    private let fileManager: FileManager
    private let stateURL: URL

    public init(
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil
    ) {
        self.fileManager = fileManager

        let supportDirectory = baseDirectory ?? fileManager
            .homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/Caffeine Plus",
                isDirectory: true
            )
        self.stateURL = supportDirectory.appendingPathComponent("state.json")
    }

    public func load() -> CaffeinePlusState {
        guard let data = try? Data(contentsOf: stateURL),
              let state = try? JSONDecoder().decode(CaffeinePlusState.self, from: data) else {
            return .defaults
        }
        return state
    }

    public func save(_ state: CaffeinePlusState) throws {
        try fileManager.createDirectory(
            at: stateURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: stateURL, options: [.atomic])
    }
}
