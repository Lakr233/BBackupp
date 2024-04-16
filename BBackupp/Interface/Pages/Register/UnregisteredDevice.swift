//
//  UnregisteredDevice.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/1/5.
//

import Foundation

struct UnregisteredDevice: Codable, Identifiable, Hashable, Equatable {
    var id: String { udid }

    var udid: String
    var deviceRecord: AppleMobileDeviceManager.DeviceRecord? {
        didSet { assert(deviceRecord?.uniqueDeviceID == udid) }
    }

    var trusted: Bool { deviceRecord?.valueFor("TrustedHostAttached") ?? false }

    var deviceName: String { deviceRecord?.deviceName ?? "Unknown" }
    var productType: String { deviceRecord?.productType ?? "Unknown" }
    var deviceSystemIcon: String {
        deviceRecord?.deviceClass?.lowercased() ?? "questionmark.circle"
    }
}
