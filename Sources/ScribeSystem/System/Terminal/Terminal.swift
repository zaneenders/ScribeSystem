//
//  Terminal.swift
//
//
//  Created by Zane Enders on 2/19/22.
//

import Foundation

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

/// Sets up the Terminal to be in raw mode so we receive the key commands as
/// they are pressed.
/// This is definitely a hack on top of the terminal as It seemed easier then
/// learning how MacOS and other operating systems send key commands to
/// programs.
//???: rename to MacOSTerminal, UnixTerminal or POSIXTerminal?
extension System {

    public enum Terminal {

        private static var config: termios = initCStruct()

        public static func enableRawMode() {
            // see https://stackoverflow.com/a/24335355/669586
            // init raw: termios variable
            var raw: termios = initCStruct()
            // sets raw to a copy of the file handlers attributes
            tcgetattr(FileHandle.standardInput.fileDescriptor, &raw)
            // saves a copy of the original standard output file descriptor to revert back to
            config = raw
            // sets magical bits to enable "raw mode" 🤷‍♂️
            // Understand how this works
            #if os(Linux)
                // TODO: update linux flags to match MacOS
                raw.c_lflag &= UInt32(~(UInt32(ECHO | ICANON | IEXTEN | ISIG)))
            #else  // MacOS
                //     /// [Entering Raw Mode](https://viewsourcecode.org/snaptoken/kilo/02.enteringRawMode.html)
                //     raw.c_iflag &= UInt(
                //         ~(UInt32(BRKINT | ICRNL | INPCK | ISTRIP | IXON)))
                //     raw.c_oflag &= UInt(~(UInt32(OPOST)))
                //     raw.c_cflag |= UInt((CS8))
                //     raw.c_lflag &= UInt(~(UInt32(ECHO | ICANON | IEXTEN | ISIG)))
                // // not sure how to do this in swift
                // // raw.c_cc[VMIN] = 0
                // // raw.c_cc[VTIME] = 1
            #endif
            // changes the file descriptor to raw mode
            tcsetattr(FileHandle.standardInput.fileDescriptor, TCSAFLUSH, &raw)
        }

        public static func restore() {
            var term: termios = config
            // restores the original terminal state
            tcsetattr(FileHandle.standardInput.fileDescriptor, TCSAFLUSH, &term)
        }

        static func initCStruct<S>() -> S {
            let structPointer: UnsafeMutablePointer<S> = UnsafeMutablePointer<S>
                .allocate(capacity: 1)
            let structMemory: S = structPointer.pointee
            structPointer.deallocate()
            return structMemory
        }

        enum TerminalSizeError: Error {
            case hight
            case width
        }
    }
}

extension System.Terminal {

    static var clearString: String {
        //FIXME: Think these commands are out of order and could be simplified
        AnsiCode.goTo(0, 0) + AnsiCode.reset.rawValue
            + AnsiCode.eraseScreen.rawValue
            + AnsiCode.eraseSaved.rawValue
            + AnsiCode.home.rawValue
            + AnsiCode.Cursor.Style.Block.blinking.rawValue
    }

    public static func clearOutput() {
        FileHandle.standardOutput.write(Data(clearString.utf8))
    }

    public static func writeToStandardOut(_ string: String) {
        let output: String = clearString + string
        FileHandle.standardOutput.write(Data(output.utf8))
    }

    /// Returns the max dimensions of the current Terminal
    public static func size() -> System.TerminalSize {
        // TODO look into the SIGWINCH signal maybe replace this function or
        // its call sites.
        var newWindow: System.TerminalSize = System.TerminalSize()
        var w: winsize = initCStruct()
        //???: Is it possible to get a call back or notification of when the window is resized
        _ = ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &w)
        // Check that we have a valid window size
        // ???: Should this throw instead?
        if w.ws_row == 0 || w.ws_col == 0 {
            return newWindow
        } else {
            newWindow.y = Int(w.ws_row.magnitude)
            newWindow.x = Int(w.ws_col.magnitude)
            return newWindow
        }
    }
}

extension System {

    public struct TerminalSize {
        // Minus 1 because terminal starts at 1 not 0
        public var x: Int = 80
        public var y: Int = 24

        init() {}
    }
}
