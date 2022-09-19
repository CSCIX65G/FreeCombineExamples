//
//  Result+Async.swift
//  
//
//  Created by Van Simmons on 9/14/22.
//

extension Result {
    init(catching: () async throws -> Success) async where Failure == Swift.Error {
        do { self = try await .success(catching()) }
        catch { self = .failure(error) }
    }
}
