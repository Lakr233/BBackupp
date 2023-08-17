//
//  Backup.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/13.
//

import Foundation

class Backup: Identifiable, Codable {
    var id: UUID = .init()

    let device: Device
    let createdAt: Date
    let archivedAt: Date
    let duration: TimeInterval
    let name: String
    let size: UInt64
    let location: String

    var keep: Bool = false {
        didSet { save() }
    }

    var storeNearLocation: URL {
        URL(fileURLWithPath: location)
            .deletingPathExtension()
            .appendingPathExtension("plist")
    }

    init(session: BackupSession, zipLocation: URL) {
        device = session.device
        createdAt = session.cratedAt
        archivedAt = Date()
        duration = archivedAt.timeIntervalSince(createdAt)
        name = zipLocation.lastPathComponent
        size = zipLocation.fileSize()
        location = zipLocation.path
    }

    func save() {
        backupManager.objectWillChange.send()
        backupManager.save()
        let storeLocation = storeNearLocation
        guard let data = try? PropertyListEncoder().encode(self)
        else { return }
        try? FileManager.default.removeItem(at: storeLocation)
        try? data.write(to: storeLocation)
    }

    static func destroy(backup: Backup) {
        try? FileManager.default.removeItem(atPath: backup.location)
        try? FileManager.default.removeItem(at: backup.storeNearLocation)
    }
}
