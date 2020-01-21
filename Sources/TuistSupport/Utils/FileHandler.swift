import Basic
import Foundation

enum FileHandlerError: FatalError {
    case invalidTextEncoding(AbsolutePath)
    case writingError(AbsolutePath)
    case fileNotFound(AbsolutePath)

    var description: String {
        switch self {
        case let .invalidTextEncoding(path):
            return "The file at \(path.pathString) is not a utf8 text file"
        case let .writingError(path):
            return "Couldn't write to the file \(path.pathString)"
        case let .fileNotFound(path):
            return "File not found at \(path.pathString)"
        }
    }

    var type: ErrorType {
        switch self {
        case .invalidTextEncoding:
            return .bug
        case .writingError, .fileNotFound:
            return .abort
        }
    }
}

/// Protocol that defines the interface of an object that provides convenient
/// methods to interact with the system files and folders.
public protocol FileHandling: AnyObject {
    /// true if verbose logging is enabled
    var verbose: Bool { get set }

    /// Returns the current path.
    var currentPath: AbsolutePath { get }

    /// Replaces a file/directory in a given path with another one.
    ///
    /// - Parameters:
    ///   - to: The file/directory to be replaced.
    ///   - with: The replacement file or directory.
    func replace(_ to: AbsolutePath, with: AbsolutePath) throws

    /// Returns true if there's a folder or file at the given path.
    ///
    /// - Parameter path: Path to check.
    /// - Returns: True if there's a folder or file at the given path.
    func exists(_ path: AbsolutePath) -> Bool

    /// Move a file from a location to another location
    ///
    /// - Parameters:
    ///   - from: File/Folder to be moved.
    ///   - to: Path where the file/folder will be moved.
    /// - Throws: An error if from doesn't exist or to does.
    func move(from: AbsolutePath, to: AbsolutePath) throws

    /// It copies a file or folder to another path.
    ///
    /// - Parameters:
    ///   - from: File/Folder to be copied.
    ///   - to: Path where the file/folder will be copied.
    /// - Throws: An error if from doesn't exist or to does.
    func copy(from: AbsolutePath, to: AbsolutePath) throws

    /// Reads a file at the given path and returns its data.
    ///
    /// - Parameter at: Path to the text file.
    /// - Returns: The content of the file.
    /// - Throws: An error if the file doesn't exist
    func readFile(_ at: AbsolutePath) throws -> Data

    /// Reads a text file at the given path and returns it.
    ///
    /// - Parameter at: Path to the text file.
    /// - Returns: The content of the text file.
    /// - Throws: An error if the file doesn't exist or it's not a valid text file.
    func readTextFile(_ at: AbsolutePath) throws -> String

    /// Reads a plist file at the given path and return decoded data
    ///
    /// - Parameter at: Path to the plist file.
    /// - Returns: The content of the plist file in data format
    /// - Throws: An error if the file doesn't exist or it's not a valid plist file.
    func readPlistFile<T: Decodable>(_ at: AbsolutePath) throws -> T

    /// Runs the given closure passing a temporary directory to it. When the closure
    /// finishes its execution, the temporary directory gets destroyed.
    ///
    /// - Parameter closure: Closure to be executed with the temporary directory.
    /// - Throws: An error if the temporary directory cannot be created or the closure throws.
    func inTemporaryDirectory(_ closure: (AbsolutePath) throws -> Void) throws

    /// Writes a string into the given path (using the utf8 encoding)
    ///
    /// - Parameters:
    ///   - content: Content to be written.
    ///   - path: Path where the content will be written into.
    ///   - atomically: Whether the content should be written atomically.
    /// - Throws: An error if the writing fails.
    func write(_ content: String, path: AbsolutePath, atomically: Bool) throws

    /// Traverses the parent directories until the given path is found.
    ///
    /// - Parameters:
    ///   - from: A path to a directory from which search the TuistConfig.swift.
    /// - Returns: The found path.
    func locateDirectoryTraversingParents(from: AbsolutePath, path: String) -> AbsolutePath?

    /// It traverses up the directories hierarchy appending the given path and returning the
    /// resulting path if it exists.
    /// - Parameters:
    ///   - path: Relative path to append to each path in the hierarchy.
    ///   - from: Path to traverse the hierarchy from.
    func locateDirectory(_ path: String, traversingFrom from: AbsolutePath) -> AbsolutePath?

    func glob(_ path: AbsolutePath, glob: String) -> [AbsolutePath]
    func linkFile(atPath: AbsolutePath, toPath: AbsolutePath) throws
    func createFolder(_ path: AbsolutePath) throws
    func delete(_ path: AbsolutePath) throws
    func isFolder(_ path: AbsolutePath) -> Bool
    func touch(_ path: AbsolutePath) throws
}

public class FileHandler: FileHandling {
    // MARK: - Attributes

    @Atomic public var verbose: Bool = false

    public static var shared: FileHandling = FileHandler()
    private let fileManager: FileManager
    private let propertyListDecoder = PropertyListDecoder()

    /// Initializes the file handler with its attributes.
    ///
    /// - Parameter fileManager: File manager instance.
    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public var currentPath: AbsolutePath {
        AbsolutePath(fileManager.currentDirectoryPath)
    }

    public func replace(_ to: AbsolutePath, with: AbsolutePath) throws {
        if verbose {
            Printer.shared.print("Replacing file at path \(to) to \(with)")
        }
        // To support cases where the destination is on a different volume
        // we need to create a temporary directory that is suitable
        // for performing a `replaceItemAt`
        //
        // References:
        // - https://developer.apple.com/documentation/foundation/filemanager/2293212-replaceitemat
        // - https://developer.apple.com/documentation/foundation/filemanager/1407693-url
        // - https://openradar.appspot.com/50553219
        let rootTempDir = try fileManager.url(for: .itemReplacementDirectory,
                                              in: .userDomainMask,
                                              appropriateFor: to.url,
                                              create: true)
        let tempUrl = rootTempDir.appendingPathComponent("temp")
        defer { try? fileManager.removeItem(at: rootTempDir) }
        try fileManager.copyItem(at: with.url, to: tempUrl)
        _ = try fileManager.replaceItemAt(to.url, withItemAt: tempUrl)
    }

    public func inTemporaryDirectory(_ closure: (AbsolutePath) throws -> Void) throws {
        let directory = try TemporaryDirectory(removeTreeOnDeinit: true)
        try closure(directory.path)
    }

    public func exists(_ path: AbsolutePath) -> Bool {
        if verbose {
            Printer.shared.print("Checking if file at path \(path) exists")
        }
        return fileManager.fileExists(atPath: path.pathString)
    }

    public func copy(from: AbsolutePath, to: AbsolutePath) throws {
        if verbose {
            Printer.shared.print("Copying file from path \(from) to \(to)")
        }
        try fileManager.copyItem(atPath: from.pathString, toPath: to.pathString)
    }

    public func move(from: AbsolutePath, to: AbsolutePath) throws {
        if verbose {
            Printer.shared.print("Moving file from path \(from) to \(to)")
        }
        try fileManager.moveItem(atPath: from.pathString, toPath: to.pathString)
    }

    public func readFile(_ at: AbsolutePath) throws -> Data {
        if verbose {
            Printer.shared.print("Reading text file at path \(at)")
        }
        return try Data(contentsOf: at.url)
    }

    public func readTextFile(_ at: AbsolutePath) throws -> String {
        if verbose {
            Printer.shared.print("Reading text file at path \(at)")
        }
        let data = try Data(contentsOf: at.url)
        if let content = String(data: data, encoding: .utf8) {
            return content
        } else {
            throw FileHandlerError.invalidTextEncoding(at)
        }
    }

    public func readPlistFile<T: Decodable>(_ at: AbsolutePath) throws -> T {
        if verbose {
            Printer.shared.print("Reading Plist at path \(at) as type \(String(describing: T.self))")
        }
        guard let data = fileManager.contents(atPath: at.pathString) else {
            throw FileHandlerError.fileNotFound(at)
        }
        return try propertyListDecoder.decode(T.self, from: data)
    }

    public func linkFile(atPath: AbsolutePath, toPath: AbsolutePath) throws {
        if verbose {
            Printer.shared.print("Creating a hard link from \(atPath) to \(toPath)")
        }
        try fileManager.linkItem(atPath: atPath.pathString, toPath: toPath.pathString)
    }

    public func write(_ content: String, path: AbsolutePath, atomically: Bool) throws {
        if verbose {
            Printer.shared.print("Writing contents \(content) at path \(path)")
        }
        do {
            try content.write(to: path.url, atomically: atomically, encoding: .utf8)
        } catch {}
    }

    public func locateDirectory(_ path: String, traversingFrom from: AbsolutePath) -> AbsolutePath? {
        if verbose {
            Printer.shared.print("Traversing the paths from \(from) to find a directory that matches the name \(path)")
        }
        let extendedPath = from.appending(RelativePath(path))
        if exists(extendedPath) {
            return extendedPath
        } else if !from.isRoot {
            return locateDirectory(path, traversingFrom: from.parentDirectory)
        } else {
            return nil
        }
    }

    public func glob(_ path: AbsolutePath, glob: String) -> [AbsolutePath] {
        path.glob(glob)
    }

    public func createFolder(_ path: AbsolutePath) throws {
        if verbose {
            Printer.shared.print("Creating folder at path \(path)")
        }
        try fileManager.createDirectory(at: path.url,
                                        withIntermediateDirectories: true,
                                        attributes: nil)
    }

    public func delete(_ path: AbsolutePath) throws {
        if verbose {
            Printer.shared.print("Deleing file at path \(path)")
        }
        try fileManager.removeItem(atPath: path.pathString)
    }

    public func touch(_ path: AbsolutePath) throws {
        if verbose {
            Printer.shared.print("Touching file at path \(path)")
        }
        try fileManager.createDirectory(at: path.removingLastComponent().url,
                                        withIntermediateDirectories: true,
                                        attributes: nil)
        try Data().write(to: path.url)
    }

    public func isFolder(_ path: AbsolutePath) -> Bool {
        var isDirectory = ObjCBool(true)
        let exists = fileManager.fileExists(atPath: path.pathString, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    public func locateDirectoryTraversingParents(from: AbsolutePath, path: String) -> AbsolutePath? {
        if verbose {
            Printer.shared.print("Traversing the paths from \(from) to find a file that matches the path \(path)")
        }
        let tuistConfigPath = from.appending(component: path)

        if FileHandler.shared.exists(tuistConfigPath) {
            return tuistConfigPath
        } else if from == AbsolutePath("/") {
            return nil
        } else {
            return locateDirectoryTraversingParents(from: from.parentDirectory, path: path)
        }
    }

}
