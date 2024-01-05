import RegexBuilder
import ScribeSystem

let publicPath = System.scribePath  // + "/Packages/Public"
print(publicPath)

guard let sub = try FileSystem.subpaths(atPath: publicPath) else {
    fatalError("FileSystem failed")
}

// Filter files
let filteredPaths = sub.filter {
    $0.contains(".swift") && !$0.contains(".build") && !$0.contains(".git")
}
// exclude Package.swift
let f = filteredPaths.filter {
    !$0.contains("Package.swift")
}

let pattern = Regex {
    One("markup:")
}

@Sendable
func processFile(_ path: String) throws {
    let contents = try FileSystem.copyContents(of: path)
    let matches = contents.matches(of: pattern)
    let modifed = contents.replacing(pattern, with: "themedContent:")
    // DANGER ZONE!!!
    /*
    try FileSystem.removeItem(atPath: path)
    try FileSystem.write(string: modifed, to: path)
    */
    print("Done: \(path), \(matches.count)")
}

async let group = await withTaskGroup(of: Void.self) {
    taskGroup in
    for path in f {
        taskGroup.addTask {
            do {
                try processFile(publicPath + "/" + path)
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}

await group

print("Files processed: \(f.count)")
