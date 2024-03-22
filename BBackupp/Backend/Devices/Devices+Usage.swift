//
//  Devices+Usage.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/1/4.
//

import Combine
import Foundation

let devManager = Devices.manager

class Devices: ObservableObject {
    fileprivate static let manager = Devices()
    private init() {}

    @PublishedStorage(key: "devices", defaultValue: [:])
    var devices: [Device.ID: Device]

    var deviceList: [Device] {
        Array(devices.values).sorted { $0.udid < $1.udid }
    }

    func register(device: Device) {
        assert(Thread.isMainThread)
        print("[*] registering \(device.udid)")
        devices[device.id] = device
    }
}

struct Device: Codable, Identifiable, Hashable, Equatable {
    typealias ID = String

    var id: String { udid }

    var udid: String
    var deviceRecord: AppleMobileDeviceManager.DeviceRecord
    var pairRecord: PairRecord

    enum ExtraKey: String, Codable {
        case preferredIcon
    }

    var extra: [ExtraKey: String] = .init()

    var possibleNetworkAddress: [String] = []

    var deviceName: String { deviceRecord.deviceName ?? "Unknown" }
    var deviceSystemIcon: String {
        if let icon = extra[.preferredIcon], !icon.isEmpty {
            return icon
        }
        if let icon = deviceRecord.deviceClass?.lowercased() {
            return icon
        }
        return "questionmark.circle"
    }

    init(
        udid: String = "",
        deviceRecord: AppleMobileDeviceManager.DeviceRecord = .init(),
        pairRecord: PairRecord = .init(),
        extra: [ExtraKey: String] = .init(),
        possibleNetworkAddress: [String] = []
    ) {
        self.udid = udid.uppercased()
        self.deviceRecord = deviceRecord
        self.pairRecord = pairRecord
        self.extra = extra
        self.possibleNetworkAddress = possibleNetworkAddress
    }
}
