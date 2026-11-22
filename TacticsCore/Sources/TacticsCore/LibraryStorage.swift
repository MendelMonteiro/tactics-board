import Foundation

/// What loading found, and whether it is safe to save afterwards.
public struct LoadResult: Sendable {
    public var library: Library
    /// False when the file exists but could not be read, or a damaged file could not be set
    /// aside. Saving then would overwrite the coach's data, so it must be blocked.
    public var savingAllowed: Bool
    /// A message for the coach, if something went wrong.
    public var notice: String?
    /// Where a damaged file was moved to.
    public var movedAsideTo: URL?

    public init(library: Library, savingAllowed: Bool, notice: String? = nil,
                movedAsideTo: URL? = nil) {
        self.library = library
        self.savingAllowed = savingAllowed
        self.notice = notice
        self.movedAsideTo = movedAsideTo
    }
}

/// One JSON file, library.json, in a given folder.
public struct LibraryStorage: Sendable {
    public static let fileName = "library.json"

    public let directory: URL
    private let moveItem: @Sendable (URL, URL) throws -> Void
    private let now: @Sendable () -> Date

    public init(
        directory: URL,
        moveItem: @escaping @Sendable (URL, URL) throws -> Void = {
            try FileManager.default.moveItem(at: $0, to: $1)
        },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.directory = directory
        self.moveItem = moveItem
        self.now = now
    }

    public var fileURL: URL {
        directory.appendingPathComponent(LibraryStorage.fileName)
    }

    /// - A missing file is an empty library.
    /// - A file that exists but can't be read blocks saving.
    /// - A file that can't be decoded is moved aside (".corrupt-<timestamp>") and the library
    ///   starts empty. If the move fails, saving is blocked instead.
    /// A failed move must never lead to the original file being overwritten.
    public func load() -> LoadResult {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return LoadResult(library: Library(), savingAllowed: true)
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            return LoadResult(
                library: Library(),
                savingAllowed: false,
                notice: "Your saved squad and sequences couldn't be read, so changes won't be saved until this is fixed."
            )
        }

        do {
            let library = try JSONDecoder().decode(Library.self, from: data)
            return LoadResult(library: library, savingAllowed: true)
        } catch {
            let backup = corruptURL(for: url)
            do {
                try moveItem(url, backup)
                return LoadResult(
                    library: Library(),
                    savingAllowed: true,
                    notice: "Your saved data was damaged, so the app started empty. A copy was kept as \(backup.lastPathComponent).",
                    movedAsideTo: backup
                )
            } catch {
                return LoadResult(
                    library: Library(),
                    savingAllowed: false,
                    notice: "Your saved data was damaged and couldn't be set aside, so changes won't be saved."
                )
            }
        }
    }

    /// Writes the whole file in one atomic step, creating the folder if needed.
    public func save(_ library: Library) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(library)
        try data.write(to: fileURL, options: .atomic)
    }

    private func corruptURL(for url: URL) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let base = url.lastPathComponent + ".corrupt-" + formatter.string(from: now())

        var candidate = directory.appendingPathComponent(base)
        var counter = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(base)-\(counter)")
            counter += 1
        }
        return candidate
    }
}
