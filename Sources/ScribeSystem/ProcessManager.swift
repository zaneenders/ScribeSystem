import Foundation

@available(*, deprecated, message: "Refactor for concurrency")
private var processState = ProcessManager()

/*
This will ideally live in the server part. But for now keep it together so I
can focus on getting things working as well as handling the isolation correctly.
*/
private struct ProcessManager {

    fileprivate init() {
        signal(
            SIGINT,
            { sig in
                processState.interrupt()
            })
        signal(
            SIGTERM,
            { sig in
                processState.interrupt()
            })
        // Maybe to keep process alive from parent
        // signal(SIGHUP,{_ in ()})
    }

    private var functions: [() -> Void] = []
    private var state: ManagerState = .accepting

    enum ManagerState {
        case accepting
        case locked
    }

    private mutating func interrupt() {
        lock()
        // this is bad but I don't wanna figure out a better way right now
        // maybe custom executor can help with this?
        // also might not need this after I get away from the host shell
        print("\nshuting down...")
        for f in functions {
            f()
        }
    }

    mutating func lock() {
        state = .locked
    }

    mutating func add(_ f: @escaping () -> Void) async throws {
        switch state {
        case .accepting:
            functions.append(f)
        case .locked:
            throw ProcessManagerError.noLongerAccepting
        }
    }

    enum ProcessManagerError: Error {
        case noLongerAccepting
    }
}

enum ProcessError: Error {
    case invalidPath(String)
}

extension System {
    @available(
        *, deprecated, message: "potential data race from SIGTERM, SIGINT"
    )
    public static func runProcess(binary path: String, arguments: [String])
        async throws
    {
        let str = "file://\(path)"
        guard let url = URL(string: str) else {
            throw ProcessError.invalidPath(str)
        }
        let process = Process()
        process.executableURL = url
        process.arguments = arguments
        let start = {
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                print("\(error.localizedDescription)")
            }
        }
        let stop = {
            process.terminate()
            process.interrupt()
        }
        try await processState.add(stop)
        // Maybe we capture std out and stream or return that one day
        await Task(priority: .userInitiated) {
            start()
        }.value
    }
}

extension System {
    public enum SystemShell: String {
        case zsh = "zsh"
        case bash = "bash"
    }

    public static var defaultShell: SystemShell = .zsh

    public static func shell(
        _ command: String, _ shell: SystemShell = defaultShell,
        _ info: Bool = true
    )
        async throws
    {
        let shellPath = "/bin/\(shell.rawValue)"
        if info {
            print("\(shellPath), Running(\(command))")
        }
        try await System.runProcess(
            binary: shellPath, arguments: ["-c", command])
    }

    public static func which(program name: String) async throws -> String? {
        return try await Task {
            let task = Process()
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            task.arguments = [name]
            // Does this break on Windows or MacOS?
            task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            task.standardInput = nil

            try task.run()
            task.waitUntilExit()

            let data: Data = pipe.fileHandleForReading.readDataToEndOfFile()
            var path = String(data: data, encoding: .utf8)
            path?.removeLast()  // Removes extra newline character
            return path
        }.value
    }
}
