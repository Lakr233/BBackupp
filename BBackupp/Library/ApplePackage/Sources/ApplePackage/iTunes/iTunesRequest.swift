//
//  iTunesRequest.swift
//  IPATool
//
//  Created by Majd Alfhaily on 22.05.21.
//

import Foundation

enum iTunesRequest {
    case search(term: String, limit: Int, region: String)
    case lookup(bundleIdentifier: String, region: String)
}

extension iTunesRequest: HTTPRequest {
    var method: HTTPMethod {
        .get
    }

    var endpoint: HTTPEndpoint {
        switch self {
        case .lookup:
            iTunesEndpoint.lookup
        case .search:
            iTunesEndpoint.search
        }
    }

    var payload: HTTPPayload? {
        switch self {
        case let .lookup(bundleIdentifier, region):
            .urlEncoding(["media": "software", "bundleId": bundleIdentifier, "limit": "1", "country": region])
        case let .search(term, limit, region):
            .urlEncoding(["media": "software", "term": term, "limit": "\(limit)", "country": region])
        }
    }
}
