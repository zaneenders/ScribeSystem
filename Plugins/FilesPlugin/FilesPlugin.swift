import Foundation
import PackagePlugin

// import Files

@main
public struct FilesPlugin: CommandPlugin {

    public init() {}

    public func performCommand(
        context: PluginContext,
        arguments: [String]
    ) async throws {
        print("zane was here")
    }
}
