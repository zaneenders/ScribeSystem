import Foundation
import RegexBuilder
import ScribeSystem

let publicPath = System.scribePath + "/Packages/Public"
print(publicPath)
guard let sub = try FileSystem.subpaths(atPath: publicPath) else {
    fatalError("idk")
}
let filteredPaths = sub.filter {
    // TODO filter out Package.Swift
    $0.contains(".swift") && !$0.contains(".build") && !$0.contains(".git")
}
async let group = await withTaskGroup(of: Void.self) {
    taskGroup in
    for path in filteredPaths {
        taskGroup.addTask {
            do {
                try processFile(publicPath + "/" + path)
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}
let pattern = Regex {
    One("_WebsiteBuilder")
}

@Sendable
func processFile(_ path: String) throws {
    let contents = try FileSystem.copyContents(of: path)
    let matches = contents.matches(of: pattern)
    let modifed = contents.replacing(pattern, with: "WebsiteBuilder")
    // DANGER ZONE!!!
    /*
    try FileSystem.removeItem(atPath: path)
    try FileSystem.write(string: modifed, to: path)
    */
    print("Done: \(path), \(matches.count)")
}

/*
for _ in 0...x {
    async let _ = await withTaskGroup(of: Void.self) {
        taskGroup in
        // Iterate over the targets in the package.
        for _ in 0...x {
            taskGroup.addTask {
                do {
                    try await Task {
                        try await Task.sleep(
                            nanoseconds: 10)
                        let result =
                            try await Network.fetchData(
                                webURL: url)
                        if let count = result.0?.count {
                            print(count)
                        } else {
                            print(
                                "\(String(describing: result.1)),\(String(describing: result.2))"
                            )
                        }
                    }.value
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
    }
}
*/
