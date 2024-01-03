import Foundation
import PackagePlugin

@main
public struct FilesPlugin: CommandPlugin {

    public init() {}

    public func performCommand(
        context: PluginContext,
        arguments: [String]
    ) async throws {
        let swiftFormatTool = try context.tool(named: "Files")
        let swiftFormatExec = URL(fileURLWithPath: swiftFormatTool.path.string)
        print("zane was here")
        let process = try Process.run(swiftFormatExec, arguments: arguments)
        print(process)
        process.waitUntilExit()
    }
}
