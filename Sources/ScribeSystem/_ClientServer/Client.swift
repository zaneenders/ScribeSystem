import NIOCore
import NIOPosix

/*
Abstraction for the Client side of the problem
*/
protocol SystemClient {

}

// Maybe actor?
struct TerminalClient: SystemClient {

}

// TODO struct GUIClient: SystemClient {}

private var config: termios = initCStruct()
let stdIN = STDIN_FILENO
// TODO put in raw mode?
let nioPie = NIOPipeBootstrap(group: MultiThreadedEventLoopGroup.singleton)
    .channelInitializer { channel in
        channel.pipeline.addHandler(EchoHandler())
    }
    .takingOwnershipOfDescriptors(input: stdIN, output: STDOUT_FILENO)

public func idk() {
    // This works
    // enableRawMode()
    let v = try! nioPie.wait()
    try! v.closeFuture.wait()
    // restore()
}

public func enableRawMode() {
    // see https://stackoverflow.com/a/24335355/669586
    // init raw: termios variable
    var raw: termios = initCStruct()
    // sets raw to a copy of the file handlers attributes
    tcgetattr(stdIN, &raw)
    // saves a copy of the original standard output file descriptor to revert back to
    config = raw
    // sets magical bits to enable "raw mode" 🤷‍♂️
    #if os(Linux)
        // TODO: update linux flags to match MacOS
        raw.c_lflag &= UInt32(~(UInt32(ECHO | ICANON | IEXTEN | ISIG)))
    #else  // MacOS
        /// [Entering Raw Mode](https://viewsourcecode.org/snaptoken/kilo/02.enteringRawMode.html)
        raw.c_iflag &= UInt(
            ~(UInt32(BRKINT | ICRNL | INPCK | ISTRIP | IXON)))
        raw.c_oflag &= UInt(~(UInt32(OPOST)))
        raw.c_cflag |= UInt((CS8))
        raw.c_lflag &= UInt(~(UInt32(ECHO | ICANON | IEXTEN | ISIG)))
    // not sure how to do this in swift
    // raw.c_cc[VMIN] = 0
    // raw.c_cc[VTIME] = 1
    #endif
    // changes the file descriptor to raw mode
    tcsetattr(stdIN, TCSAFLUSH, &raw)
}

public func restore() {
    var term: termios = config
    // restores the original terminal state
    tcsetattr(stdIN, TCSAFLUSH, &term)
}

func initCStruct<S>() -> S {
    let structPointer: UnsafeMutablePointer<S> = UnsafeMutablePointer<S>
        .allocate(capacity: 1)
    let structMemory: S = structPointer.pointee
    structPointer.deallocate()
    return structMemory
}

final class EchoHandler: ChannelInboundHandler {
    init() {}
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    func channelActive(context: ChannelHandlerContext) {
        // Allocate message to ByteBuffer
        let message = ByteBuffer(string: "Hello\n")
        let buffer = context.channel.allocator.buffer(buffer: message)
        // Keep track of the size of bytes sent
        context.writeAndFlush(self.wrapOutboundOut(buffer), promise: nil)
    }

    func channelRead(
        context: ChannelHandlerContext, data: NIOAny
    ) {
        let unwrappedInboundData = self.unwrapInboundIn(data)
        let string = String(buffer: unwrappedInboundData)
        let message = ByteBuffer(string: "Received: \(string)\n")
        let buffer = context.channel.allocator.buffer(buffer: message)
        // Keep track of the size of bytes sent
        context.writeAndFlush(self.wrapOutboundOut(buffer), promise: nil)
    }
}
