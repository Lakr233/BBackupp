//
//  Devices.swift
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

    func refreshDevice(_ udid: String) {
        DispatchQueue.global().async {
            guard let deviceInfo = amdManager.obtainDeviceInfo(udid: udid),
                  // offline or in backup progress may result nil that we need to skip
                  deviceInfo.uniqueDeviceID == udid
            else { return }
            DispatchQueue.main.async {
                self.devices[udid]?.deviceRecord = deviceInfo
            }
        }
        DispatchQueue.global().async {
            guard let pairRecord = amdManager.obtainPairRecord(udid: udid),
                  let reocrd = PairRecord(pairRecord, udid: udid)
            else { return }
            DispatchQueue.main.async {
                self.devices[udid]?.pairRecord = reocrd
            }
        }
    }
}

struct Device: Codable, Identifiable, Hashable, Equatable, CopyableCodable {
    typealias ID = String

    var id: String { udid }

    var udid: String
    var deviceRecord: AppleMobileDeviceManager.DeviceRecord {
        didSet { deviceRecordLastUpdate = Date() }
    }

    var deviceRecordLastUpdate: Date?
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
