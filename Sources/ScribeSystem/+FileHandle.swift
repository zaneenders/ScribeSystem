//
//  +FileHandle.swift
//
//
//  Created by Zane Enders on 7/20/22.
//

import Foundation

/// Hoping I won't need this extension with later versions of Foundation that
/// support for API's on linux
extension FileHandle {

    /// Return an iterator over the bytes in the file.
    ///
    /// - returns: An iterator for UInt8 elements.
    public func asyncBytes() -> FileHandleAsyncByteIterator {
        return FileHandleAsyncByteIterator(fileHandle: self)
    }

    public struct FileHandleAsyncByteIterator: AsyncSequence {

        public typealias Element = UInt8

        let fileHandle: FileHandle

        init(fileHandle: FileHandle) {
            self.fileHandle = fileHandle
        }

        public struct AsyncIterator: AsyncIteratorProtocol {
            public typealias Element = UInt8
            let fileHandle: FileHandle

            @available(*, deprecated, message: "Really bad, but works for now")
            public mutating func next() async throws -> UInt8? {
                guard let data: Data = try fileHandle.read(upToCount: 1) else {
                    throw AsyncIteratorError.readError
                }
                return data.first
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            return AsyncIterator(fileHandle: fileHandle)
        }
    }
}

enum AsyncIteratorError: Error {
    case readError
}
