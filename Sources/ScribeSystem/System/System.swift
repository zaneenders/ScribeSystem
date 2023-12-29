//
//  System.swift
//
//
//  Created by Zane Enders on 12/19/22.
//

import Foundation

// TODO fix Hack for Debian
extension ScribeSystem.System.OS: CustomStringConvertible {
    public var description: String {
        if ProcessInfo.processInfo.operatingSystemVersionString.contains(
            "Debian")
        {
            return "Debian"
        }
        switch self {
        case .macOS:
            return "macOS"
        case .linux(let l):
            switch l {
            case .ubuntu(let u):
                return "ubuntu \(u)"
            case .redhat(let r):
                return "redhat \(r)"
            case .fedora(let f):
                return "fedora \(f)"
            case .centos(let c):
                return "centos \(c)"
            }
        }
    }
}

extension System {
    public static var configPath: String {
        homePath + "/.config"
    }
    public static var scribePath: String {
        homePath + "/.scribe"
    }
}

public enum System {
    public enum Path {
        case home
        case path(String)
        case up
    }

    public static var coreCount: Int {
        ProcessInfo.processInfo.activeProcessorCount
    }

    /// username for filesystem stuff
    public static var username: String {
        ProcessInfo.processInfo.userName
    }

    /// The username when addressing the user
    public static var formalUsername: String {
        ProcessInfo.processInfo.fullUserName
    }

    // TODO return an enum or a more concrete type with a string description
    @available(*, deprecated, message: "beta: not finished")
    public static var memory: String {
        "\(ProcessInfo.processInfo.physicalMemory)"
    }

    // Maybe think of this supported Operating Systems?
    public enum OS {
        case macOS
        case linux(Linux)
        public enum Linux {
            case ubuntu(String)
            case redhat(String)
            case fedora(String)
            case centos(String)
        }
    }

    @available(*, deprecated, message: "beta: defaults to macOS")
    public static var os: OS {
        let str = ProcessInfo.processInfo.operatingSystemVersionString
        /*
        TODO check for other Operating systems.
        This should be finite and easy ish to check
        idk how I want to do versions yet
        */
        if str.contains("Ubuntu") {
            return .linux(.ubuntu(str))
        } else if str.contains("Red Hat") {
            return .linux(.redhat(str))
        } else if str.contains("Fedora Linux") {
            return .linux(.fedora(str))
        } else {
            return .macOS
        }
    }

    @available(
        *, deprecated, message: "beta: May change to a better name or location"
    )
    public static var processArguments: [String] {
        ProcessInfo.processInfo.arguments
    }

    /// Maybe we could use this for making daemons, reboot system, updates or other automate task?
    @available(*, deprecated, message: "beta: might not keep this")
    public static var uptime: Double {
        ProcessInfo.processInfo.systemUptime
    }

    /// Output a string description of the Process info
    /// - Parameter showEnv: weather to show the env variables
    public static func info(_ showEnv: Bool = false) -> String {
        func env() -> String {
            func envVarsToString() -> String {
                var output = ""
                for e in ProcessInfo.processInfo.environment {
                    output += "    \(e.key): \(e.value)\n"
                }
                output.removeFirst(4)
                output.removeLast()
                return output
            }
            return """
                \n  Environment: {
                    \(envVarsToString())
                  }
                """
        }
        // Not sure what do do with this string yet
        // ProcessInfo.processInfo.globallyUniqueString
        return """
            Username": \(ProcessInfo.processInfo.userName)
            Full Username: \(ProcessInfo.processInfo.fullUserName)
            Hostname : \(ProcessInfo.processInfo.hostName)
            Number of Cores: \(ProcessInfo.processInfo.activeProcessorCount)
            OS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)
            Memory: \(ProcessInfo.processInfo.physicalMemory)
            System uptime: \(ProcessInfo.processInfo.systemUptime)
            Process Info {
              name: \(ProcessInfo.processInfo.processName)
              PID: \(ProcessInfo.processInfo.processIdentifier)
              Arguments: \(ProcessInfo.processInfo.arguments)\(showEnv ? env() : "")
            }
            """
    }

    public static let homePath = FileManager.default
        .homeDirectoryForCurrentUser
        .path

    public static func moveCurrentPath(to newPath: Path) {
        switch newPath {
        case .home:
            FileManager.default.changeCurrentDirectoryPath(homePath)
        case .path(let path):
            FileManager.default.changeCurrentDirectoryPath(path)
        case .up:
            let current = FileManager.default.currentDirectoryPath
            var url = URL(string: current)!
            url.deleteLastPathComponent()
            FileManager.default.changeCurrentDirectoryPath(url.absoluteString)
        }
    }

    public static var currentWorkingDirectory: String {
        FileManager.default.currentDirectoryPath
    }

    public static var currentDirectory: String {
        guard
            let dirName = URL(string: FileManager.default.currentDirectoryPath)?
                .lastPathComponent
        else {
            fatalError("Unable to get currentDirectory name.")
        }
        return dirName
    }
}
