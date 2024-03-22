//
//  AppStoreBackend.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/16.
//

import ApplePackage
import AuxiliaryExecute
import Combine
import Foundation

class AppStoreBackend: ObservableObject {
    struct Account: Codable, Identifiable, CopyableCodable {
        var id: UUID = .init()

        var email: String
        var password: String
        var countryCode: String
        var storeResponse: StoreResponse.Account
    }

    @PublishedStorage(key: "accounts", defaultValue: [])
    var accounts: [Account]

    static let shared = AppStoreBackend()
    private init() {}

    func save(email: String, password: String, account: StoreResponse.Account) {
        accounts = accounts
            .filter { $0.email.lowercased() != email.lowercased() }
            + [.init(email: email, password: password, countryCode: account.countryCode, storeResponse: account)]
    }

    func delete(id: Account.ID) {
        accounts = accounts.filter { $0.id != id }
    }
}
