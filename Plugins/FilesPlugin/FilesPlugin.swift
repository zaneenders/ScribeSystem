import Foundation
import PackagePlugin

// swift package --allow-writing-to-package-directory files
@main
public struct FilesPlugin: CommandPlugin {

    public init() {}

    public func performCommand(
        context: PluginContext,
        arguments: [String]
    ) async throws {
        print("FilesPlugin starting")
        let swiftFormatTool = try context.tool(named: "Files")
        let swiftFormatExec = URL(fileURLWithPath: swiftFormatTool.path.string)
        let process = try Process.run(swiftFormatExec, arguments: arguments)
        process.waitUntilExit()
    }
}
