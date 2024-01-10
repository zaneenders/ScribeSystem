//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

// TODO wriet with out Apple starting NIO code so I can delete the license
import NIOCore
import NIOHTTP1
import NIOPosix

/// A simple HTTP server intended to just be used for local host testing but not be
/// so overweleming you can jump in and tweak how the server works if you need different
/// behavour.
public func httpServer(_ httpDocsDir: String = "/dev/null/") throws {
    var allowHalfClosure = true
    let defaultHost = "::1"
    let defaultPort = 8080
    print(httpDocsDir)
    print(defaultHost)
    print(defaultPort)

    // TODO do I need this?
    func childChannelInitializer(channel: (any Channel)) -> EventLoopFuture<
        Void
    > {
        return channel.pipeline.configureHTTPServerPipeline(
            withErrorHandling: true
        ).flatMap {
            channel.pipeline.addHandler(
                HTTPHandler(fileIO: fileIO, htdocsPath: httpDocsDir))
        }
    }

    let fileIO = NonBlockingFileIO(threadPool: .singleton)
    let socketBootstrap = ServerBootstrap(
        group: MultiThreadedEventLoopGroup.singleton
    )
    .serverChannelOption(ChannelOptions.backlog, value: 256)
    .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
    .childChannelInitializer(childChannelInitializer(channel:))
    .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
    .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
    .childChannelOption(
        ChannelOptions.allowRemoteHalfClosure, value: allowHalfClosure)
    let pipeBootstrap = NIOPipeBootstrap(
        group: MultiThreadedEventLoopGroup.singleton
    )
    .channelInitializer(childChannelInitializer(channel:))
    .channelOption(ChannelOptions.maxMessagesPerRead, value: 1)
    .channelOption(
        ChannelOptions.allowRemoteHalfClosure, value: allowHalfClosure)
    let channel = try socketBootstrap.bind(host: defaultHost, port: defaultPort)
        .wait()
    try channel.closeFuture.wait()
}

private func httpResponseHead(
    request: HTTPRequestHead, status: HTTPResponseStatus,
    headers: HTTPHeaders = HTTPHeaders()
) -> HTTPResponseHead {
    var head = HTTPResponseHead(
        version: request.version, status: status, headers: headers)
    let connectionHeaders: [String] = head.headers[canonicalForm: "connection"]
        .map { $0.lowercased() }

    if !connectionHeaders.contains("keep-alive")
        && !connectionHeaders.contains("close")
    {
        // the user hasn't pre-set either 'keep-alive' or 'close', so we might need to add headers

        switch (
            request.isKeepAlive, request.version.major, request.version.minor
        ) {
        case (true, 1, 0):
            // HTTP/1.0 and the request has 'Connection: keep-alive', we should mirror that
            head.headers.add(name: "Connection", value: "keep-alive")
        case (false, 1, let n) where n >= 1:
            // HTTP/1.1 (or treated as such) and the request has 'Connection: close', we should mirror that
            head.headers.add(name: "Connection", value: "close")
        default:
            // we should match the default or are dealing with some HTTP that we don't support, let's leave as is
            ()
        }
    }
    return head
}

private final class HTTPHandler: ChannelInboundHandler {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias OutboundOut = HTTPServerResponsePart

    private enum State {
        case idle
        case waitingForRequestBody
        case sendingResponse

        mutating func requestReceived() {
            precondition(
                self == .idle, "Invalid state for request received: \(self)")
            self = .waitingForRequestBody
        }

        mutating func requestComplete() {
            precondition(
                self == .waitingForRequestBody,
                "Invalid state for request complete: \(self)")
            self = .sendingResponse
        }

        mutating func responseComplete() {
            precondition(
                self == .sendingResponse,
                "Invalid state for response complete: \(self)")
            self = .idle
        }
    }
    private var keepAlive = false
    private var buffer: ByteBuffer! = nil
    private var state = State.idle
    private let htdocsPath: String

    private var infoSavedRequestHead: HTTPRequestHead?
    private var infoSavedBodyBytes: Int = 0

    private var continuousCount: Int = 0

    private var handler:
        ((ChannelHandlerContext, HTTPServerRequestPart) -> Void)?
    private var handlerFuture: EventLoopFuture<Void>?
    private let fileIO: NonBlockingFileIO

    public init(fileIO: NonBlockingFileIO, htdocsPath: String) {
        self.htdocsPath = htdocsPath
        self.fileIO = fileIO
    }

    private func handleFile(
        context: ChannelHandlerContext, request: HTTPServerRequestPart,
        path: String
    ) {
        self.buffer.clear()

        func sendErrorResponse(request: HTTPRequestHead, _ error: (any Error)) {
            var body = context.channel.allocator.buffer(capacity: 128)
            let response = { () -> HTTPResponseHead in
                switch error {
                case let e as IOError where e.errnoCode == ENOENT:
                    body.writeStaticString("IOError (not found)\r\n")
                    return httpResponseHead(request: request, status: .notFound)
                case let e as IOError:
                    body.writeStaticString("IOError (other)\r\n")
                    body.writeString(e.description)
                    body.writeStaticString("\r\n")
                    return httpResponseHead(request: request, status: .notFound)
                default:
                    body.writeString("\(type(of: error)) error\r\n")
                    return httpResponseHead(
                        request: request, status: .internalServerError)
                }
            }()
            body.writeString("\(error)")
            body.writeStaticString("\r\n")
            context.write(self.wrapOutboundOut(.head(response)), promise: nil)
            context.write(
                self.wrapOutboundOut(.body(.byteBuffer(body))), promise: nil)
            context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
            context.channel.close(promise: nil)
        }

        enum FileType {
            case html
            case js
            case css
            case plain
        }

        switch request {
        case .head(let request):
            self.keepAlive = request.isKeepAlive
            self.state.requestReceived()
            let path = self.htdocsPath + "/" + path
            let fileHandleAndRegion = self.fileIO.openFile(
                path: path, eventLoop: context.eventLoop)
            fileHandleAndRegion.whenFailure {
                sendErrorResponse(request: request, $0)
            }
            fileHandleAndRegion.whenSuccess { (file, region) in
                var fileType: FileType = .plain
                // this is a bad hack
                if request.uri.contains(".html") {
                    fileType = .html
                } else if request.uri.contains(".css") {
                    fileType = .css
                } else if request.uri.contains(".js") {
                    fileType = .js
                }
                var response = httpResponseHead(request: request, status: .ok)
                response.headers.add(
                    name: "Content-Length", value: "\(region.endIndex)")
                switch fileType {
                case .html:
                    response.headers.add(
                        name: "Content-Type", value: "text/html; charset=utf-8")
                case .css:
                    response.headers.add(
                        name: "Content-Type", value: "text/css; charset=utf-8")

                case .js:
                    response.headers.add(
                        name: "Content-Type",
                        value: "text/javascript; charset=utf-8")
                case .plain:
                    response.headers.add(
                        name: "Content-Type", value: "text/plain; charset=utf-8"
                    )
                }
                context.write(
                    self.wrapOutboundOut(.head(response)), promise: nil)
                context.writeAndFlush(
                    self.wrapOutboundOut(.body(.fileRegion(region)))
                ).flatMap {
                    let p = context.eventLoop.makePromise(of: Void.self)
                    self.completeResponse(
                        context, trailers: nil, promise: p)
                    return p.futureResult
                }.flatMapError { (_: Error) in
                    context.close()
                }.whenComplete { (_: Result<Void, Error>) in
                    _ = try? file.close()
                }
            }
        case .end:
            self.state.requestComplete()
        default:
            fatalError("oh noes: \(request)")
        }
    }

    private func completeResponse(
        _ context: ChannelHandlerContext, trailers: HTTPHeaders?,
        promise: EventLoopPromise<Void>?
    ) {
        self.state.responseComplete()

        let promise =
            self.keepAlive
            ? promise : (promise ?? context.eventLoop.makePromise())
        if !self.keepAlive {
            promise!.futureResult.whenComplete { (_: Result<Void, Error>) in
                context.close(promise: nil)
            }
        }
        self.handler = nil
        context.writeAndFlush(
            self.wrapOutboundOut(.end(trailers)), promise: promise)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = self.unwrapInboundIn(data)
        if let handler = self.handler {
            handler(context, reqPart)
            return
        }
        switch reqPart {
        case .head(let request):
            self.handler = {
                self.handleFile(
                    context: $0, request: $1,
                    path: request.uri)
            }
            self.handler!(context, reqPart)
            return
        case .body:
            break
        case .end:
            self.state.requestComplete()
            let content = HTTPServerResponsePart.body(
                .byteBuffer(buffer!.slice()))
            context.write(self.wrapOutboundOut(content), promise: nil)
            self.completeResponse(context, trailers: nil, promise: nil)
            self.state.responseComplete()
            self.handler = nil
            context.writeAndFlush(
                self.wrapOutboundOut(.end(nil)), promise: nil)
        }
    }

    func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }

    func handlerAdded(context: ChannelHandlerContext) {
        self.buffer = context.channel.allocator.buffer(capacity: 0)
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        switch event {
        case let evt as ChannelEvent where evt == ChannelEvent.inputClosed:
            // The remote peer half-closed the channel. At this time, any
            // outstanding response will now get the channel closed, and
            // if we are idle or waiting for a request body to finish we
            // will close the channel immediately.
            switch self.state {
            case .idle, .waitingForRequestBody:
                context.close(promise: nil)
            case .sendingResponse:
                self.keepAlive = false
            }
        default:
            context.fireUserInboundEventTriggered(event)
        }
    }
}
