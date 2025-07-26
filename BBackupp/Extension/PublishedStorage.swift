//
//  PublishedStorage.swift
//  App
//
//  Created by Lakr Aream on 2023/6/5.
//  Copyright © 2023 Lakr Aream. All rights reserved.
//

// Remove SwiftUI stuff, use Combine & Foundation only.

import Combine
import Foundation

private let encoder = JSONEncoder()
private let decoder = JSONDecoder()

@propertyWrapper
public struct PublishedStorage<ValueA: Codable> {
    @CodableDefault private var storedValue: ValueA

    public let subject: CurrentValueSubject<ValueA, Never>
    public var defaultValue: ValueA {
        _storedValue.defaultValue
    }

    @available(*, unavailable, message: "accessing wrappedValue will result undefined behavior")
    // PublishedStorage only accept to work inside class, which class confirms to ObservableObject
    public var wrappedValue: ValueA {
        get { subject.value }
        set { storedValue = newValue }
    }

    public static subscript<EnclosingSelf: ObservableObject>(
        _enclosingInstance object: EnclosingSelf,
        wrapped _: ReferenceWritableKeyPath<EnclosingSelf, ValueA>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, PublishedStorage<ValueA>>
    ) -> ValueA {
        get {
            object[keyPath: storageKeyPath].subject.value
        }
        set {
            (object.objectWillChange as? ObservableObjectPublisher)?.send()
            object[keyPath: storageKeyPath].subject.send(newValue)
            object[keyPath: storageKeyPath].storedValue = newValue
        }
    }

    init(key: String, defaultValue: ValueA, storage: UserDefaults = .standard) {
        let storageCore = CodableDefault(key: key, defaultValue: defaultValue, storage: storage)
        _storedValue = storageCore
        subject = .init(storageCore.wrappedValue)
    }

    public func saveFromSubjectValueImmediately() {
        _storedValue.save(value: subject.value)
    }
}

private extension PublishedStorage {
    @propertyWrapper
    struct CodableDefault<ValueB: Codable> {
        let key: String
        let defaultValue: ValueB
        var storage: UserDefaults = .standard

        init(key: String, defaultValue: ValueB, storage: UserDefaults = .standard) {
            self.key = key
            self.defaultValue = defaultValue
            self.storage = storage
        }

        var wrappedValue: ValueB {
            get {
                if let read = storage.value(forKey: key) as? Data,
                   let object = try? decoder.decode(ValueB.self, from: read)
                {
                    return object
                }
                return defaultValue
            }
            set {
                save(value: newValue)
            }
        }

        func save(value: ValueB) {
            do {
                let data = try encoder.encode(value)
                storage.setValue(data, forKey: key)
                return
            } catch {}
            storage.setValue(nil, forKey: key)
        }
    }
}
