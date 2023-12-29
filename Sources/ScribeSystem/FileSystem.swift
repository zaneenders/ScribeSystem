import Foundation

/// Defines an abstraction lay over Foundations FileManager and other
/// FileSystem Needs
public enum FileSystem {

    private static func wrapFilePath(_ path: String) -> String {
        "file://" + path
    }

    public static func fileExists(
        atPath filePath: String, isDirectory: Bool = false
    ) -> Bool {
        FileManager.default.fileExists(atPath: filePath)
    }

    public static func removeItem(atPath path: String) throws {
        try FileManager.default.removeItem(atPath: path)
    }

    public static func write(string contents: String, to path: String)
        throws
    {
        guard let url = URL(string: wrapFilePath(path)) else {
            throw FileSystemError.invalidFilePath(path)
        }
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    public static func copyContents(of path: String) throws -> String {
        guard let url = URL(string: wrapFilePath(path)) else {
            throw FileSystemError.invalidFilePath(path)
        }
        return try String(contentsOf: url)
    }

    public static func createDirectory(at path: String) throws {
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: path),
            withIntermediateDirectories: true)
    }

    public static func subpathsOfDirectory(atPath: String) throws
        -> [String]
    {
        return try FileManager.default.subpathsOfDirectory(atPath: atPath)
    }

    public static func subpaths(atPath: String) throws -> [String]? {
        return FileManager.default.subpaths(atPath: atPath)
    }
}

public enum FileSystemError: Error {
    case invalidFilePath(String)
}
