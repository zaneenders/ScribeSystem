import Foundation
import NIOCore
import NIOPosix

/**
Create some sort of client server Relation so I can split Scribe into a client
Me and the server Scribe.
Also checkout [Networking](Packages/Networking) for ideas/ starting place
Would Also like to use this to grab standard in and out. Well split those over
a client server connection.
*/

// Temporary to get URL Session working on Linux
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

public enum Network {

    public static func fetchData(webURL: String) async throws -> (
        Data?, URLResponse?, (any Error)?
    ) {
        guard let url = URL(string: webURL) else {
            throw NetworkError.invalidURL
        }
        return await fetchData(from: url)
    }

    static func fetchData(from url: URL) async -> (
        Data?, URLResponse?, (any Error)?
    ) {
        let result = await withCheckedContinuation { continuation in
            URLSession.shared.dataTask(with: url) { data, response, error in
                continuation.resume(returning: (data, response, error))
            }.resume()
        }
        return result
    }
}

public enum NetworkError: Error {
    case invalidURL
}
