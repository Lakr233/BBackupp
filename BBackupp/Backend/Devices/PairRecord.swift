//
//  PairRecord.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/1/5.
//

import CommonCrypto
import Foundation

struct PairRecord: Codable, Identifiable, Hashable, Equatable {
    var id: String { udid }

    var udid: String
    var hostID: String
    var systemBUID: String

    var deviceCertificate: Data

    var hostPrivateKey: Data
    var hostCertificate: Data

    var rootPrivateKey: Data
    var rootCertificate: Data

    var wifiMACAddress: String

    var escrowBag: Data

    enum CodingKeys: String, CodingKey {
        case udid = "UDID"
        case hostID = "HostID"
        case systemBUID = "SystemBUID"
        case deviceCertificate = "DeviceCertificate"
        case hostPrivateKey = "HostCertificate"
        case hostCertificate = "HostPrivateKey"
        case rootPrivateKey = "RootPrivateKey"
        case rootCertificate = "RootCertificate"
        case wifiMACAddress = "WiFiMACAddress"
        case escrowBag = "EscrowBag"
    }

    init(
        udid: String = "",
        hostID: String = "",
        systemBUID: String = "",
        deviceCertificate: Data = .init(),
        hostPrivateKey: Data = .init(),
        hostCertificate: Data = .init(),
        rootPrivateKey: Data = .init(),
        rootCertificate: Data = .init(),
        wifiMACAddress: String = "",
        escrowBag: Data = .init()
    ) {
        self.udid = udid
        self.hostID = hostID
        self.systemBUID = systemBUID
        self.deviceCertificate = deviceCertificate
        self.hostPrivateKey = hostPrivateKey
        self.hostCertificate = hostCertificate
        self.rootPrivateKey = rootPrivateKey
        self.rootCertificate = rootCertificate
        self.wifiMACAddress = wifiMACAddress
        self.escrowBag = escrowBag
    }

    init?(_ rawRecord: AppleMobileDeviceManager.PairRecord, udid: String) {
        let udid = rawRecord.udid ?? udid
        guard let hostID = rawRecord.hostID,
              let systemBUID = rawRecord.systemBUID,
              let deviceCertificate = rawRecord.deviceCertificate,
              let hostPrivateKey = rawRecord.hostPrivateKey,
              let hostCertificate = rawRecord.hostCertificate,
              let rootPrivateKey = rawRecord.rootPrivateKey,
              let rootCertificate = rawRecord.rootCertificate,
              let wifiMACAddress = rawRecord.wifiMACAddress,
              let escrowBag = rawRecord.escrowBag
        else { return nil }
        self.init(
            udid: udid,
            hostID: hostID,
            systemBUID: systemBUID,
            deviceCertificate: deviceCertificate,
            hostPrivateKey: hostPrivateKey,
            hostCertificate: hostCertificate,
            rootPrivateKey: rootPrivateKey,
            rootCertificate: rootCertificate,
            wifiMACAddress: wifiMACAddress,
            escrowBag: escrowBag
        )
    }
}

extension PairRecord {
    var fingerprint: String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        deviceCertificate.withUnsafeBytes { ptr in
            _ = CC_SHA1(ptr.baseAddress, CC_LONG(deviceCertificate.count), &digest)
        }
        return Data(digest).map { String(format: "%02x", $0) }.joined(separator: ":")
    }

    var propertyListBinaryData: Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        guard let data = try? encoder.encode(self) else { return .init() }
        return data
    }
}
