//
//  AMDManager.swift
//
//
//  Created by QAQ on 2023/8/10.
//

import AppleMobileDeviceLibrary
import Foundation

let amdManager = AppleMobileDeviceManager.shared

public class AppleMobileDeviceManager {
    fileprivate static let shared = AppleMobileDeviceManager()

    private init() {}

    public struct Configuration {
        public var connectionMethod: ConnectionMethod = .usbPreferred
    }

    public static var configuration: Configuration = .init()

    public class CodableRecord: Codable, Equatable, Hashable, Identifiable {
        public var id: UUID = .init()

        public var store: AnyCodable
        public init() { store = .init([String: String]()) }
        public init(store: AnyCodable) { self.store = store }

        var dictionary: [String: Any] { store.value as? [String: Any] ?? [:] }

        public var plistData: Data? {
            guard !dictionary.keys.isEmpty,
                  let data = try? PropertyListEncoder().encode(AnyCodable(dictionary))
            else {
                return nil
            }
            return data
        }

        public var xml: String? {
            guard !dictionary.keys.isEmpty,
                  let data = try? PropertyListSerialization.data(
                      fromPropertyList: dictionary,
                      format: .xml,
                      options: .zero
                  ),
                  let text = String(data: data, encoding: .utf8),
                  !text.isEmpty
            else {
                return nil
            }
            return text
        }

        public func valueFor<T: Codable>(_ key: String) -> T? {
            (store.value as? [String: Any])?[key] as? T
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(store)
        }

        public static func == (lhs: CodableRecord, rhs: CodableRecord) -> Bool {
            lhs.store == rhs.store
        }
    }
}

#if DEBUG

    func generateDictionaryGetter(_ input: AnyCodable?) {
        var gen = [String]()
        (input?.value as? [String: Any])?.forEach { pair in
            let key = pair.key
            guard !key.isEmpty else { return }
            let keyName = key.first!.lowercased() + String(key.dropFirst())
            let value = pair.value
            let valueType = type(of: value)
            gen.append("public var \(keyName): \(valueType)? { decode(\"\(key)\") }")
        }
        gen.sort()
        gen.forEach { print($0) }
    }

#endif
