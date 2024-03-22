//
//  AMDManager+Pair.swift
//
//
//  Created by QAQ on 2023/8/11.
//

import AppleMobileDeviceLibrary
import Foundation

public extension AppleMobileDeviceManager {
    class PairRecord: CodableRecord {
        public var deviceCertificate: Data? { valueFor("DeviceCertificate") }
        public var hostPrivateKey: Data? { valueFor("HostPrivateKey") }
        public var hostCertificate: Data? { valueFor("HostCertificate") }
        public var rootPrivateKey: Data? { valueFor("RootPrivateKey") }
        public var rootCertificate: Data? { valueFor("RootCertificate") }
        public var systemBUID: String? { valueFor("SystemBUID") }
        public var hostID: String? { valueFor("HostID") }
        public var escrowBag: Data? { valueFor("EscrowBag") }
        public var wifiMACAddress: String? { valueFor("WiFiMACAddress") }
        public var udid: String? { valueFor("UDID") }
    }

    func obtainSystemBUID() -> String? {
        var buf: UnsafeMutablePointer<CChar>?
        defer { if let buf { free(buf) } }
        guard usbmuxd_read_buid(&buf) == 0, let buf else { return nil }
        let ret = String(cString: buf)
        return ret.isEmpty ? nil : ret
    }

    func obtainPairRecord(udid: String) -> PairRecord? {
        var result: AnyCodable?
        var buf: UnsafeMutablePointer<CChar>?
        defer { if let buf { free(buf) } }
        var len: Int32 = 0
        usbmuxd_read_pair_record(udid, &buf, &len)
        if let buf, len > 0 {
            let data = Data(bytes: buf, count: Int(len))
            result = try? PropertyListDecoder().decode(AnyCodable.self, from: data)
        }
        guard let result else { return nil }
        return .init(store: result)
    }

    func isDevicePaired(udid: String, connection: ConnectionMethod = configuration.connectionMethod) -> Bool? {
        var result: Bool?
        requireDevice(udid: udid, connection: connection) { device in
            guard let device else { return }
            result = false
            requireLockdownClient(device: device, handshake: true) { client in
                guard client != nil else { return }
                result = true
            }
        }
        return result
    }

    func sendPairRequest(udid: String, connection: ConnectionMethod = configuration.connectionMethod) {
        requireDevice(udid: udid, connection: connection) { device in
            guard let device else { return }
            requireLockdownClient(device: device, handshake: false) { client in
                guard let client else { return }
                lockdownd_pair(client, nil)
            }
        }
    }

    func unpaireDevice(udid: String, connection: ConnectionMethod = configuration.connectionMethod) {
        requireDevice(udid: udid, connection: connection) { device in
            guard let device else { return }
            requireLockdownClient(device: device, handshake: true) { client in
                guard let client else { return }
                lockdownd_unpair(client, nil)
            }
        }
    }

    func isDeviceWirelessConnectionEnabled(udid: String, connection: ConnectionMethod = configuration.connectionMethod) -> Bool? {
        let deviceInfo = obtainDeviceInfo(
            udid: udid,
            domain: "com.apple.mobile.wireless_lockdown",
            key: nil,
            connection: connection
        )
        return deviceInfo?.valueFor("EnableWifiConnections")
    }

    func setDeviceWirelessConnectionEnabled(udid: String, enabled: Bool, connection: ConnectionMethod = configuration.connectionMethod) {
        requireDevice(udid: udid, connection: connection) { device in
            guard let device else { return }
            requireLockdownClient(device: device, handshake: true) { client in
                guard let client else { return }
                let bool = plist_new_bool(enabled ? 1 : 0)
                lockdownd_set_value(
                    client,
                    "com.apple.mobile.wireless_lockdown",
                    "EnableWifiConnections",
                    bool
                )
            }
        }
    }

    func requireMobileBackup2Service(
        device: idevice_t,
        mobileBackup2Service: lockdownd_service_descriptor_t,
        task: (mobilebackup2_client_t?) -> Void
    ) {
        var client: mobilebackup2_client_t?
        guard mobilebackup2_client_new(device, mobileBackup2Service, &client) == MOBILEBACKUP2_E_SUCCESS,
              let client
        else {
            task(nil)
            return
        }
        task(client)
        mobilebackup2_client_free(client)
    }

    func enableBackupPassword(
        udid: String,
        password: String,
        connection: ConnectionMethod = configuration.connectionMethod
    ) {
        requireDevice(udid: udid, connection: connection) { device in
            guard let device else { return }
            requireLockdownClient(device: device, handshake: true) { lkd_client in
                guard let lkd_client else { return }
                requireLockdownService(client: lkd_client, serviceName: MOBILEBACKUP2_SERVICE_NAME, requiresEscrowBag: true) { mb2_service in
                    guard let mb2_service else { return }
                    requireMobileBackup2Service(device: device, mobileBackup2Service: mb2_service) { mb2_client in
                        guard let mb2_client else { return }
                        let options: [String: Codable] = [
                            "NewPassword": password,
                            "TargetIdentifier": udid,
                        ]
                        let data = try! PropertyListEncoder().encode(AnyCodable(options))
                        var query: plist_t?
                        defer { plist_free(query) }
                        _ = data.withUnsafeBytes { byte in
                            plist_from_memory(byte.baseAddress, UInt32(byte.count), &query, nil)
                        }
                        guard let query else { return }
                        mobilebackup2_send_message(mb2_client, "ChangePassword", query)
                    }
                }
            }
        }
    }

    func disableBackupPassword(
        udid: String,
        currentPassword: String,
        connection: ConnectionMethod = configuration.connectionMethod
    ) {
        requireDevice(udid: udid, connection: connection) { device in
            guard let device else { return }
            requireLockdownClient(device: device, handshake: true) { lkd_client in
                guard let lkd_client else { return }
                requireLockdownService(client: lkd_client, serviceName: MOBILEBACKUP2_SERVICE_NAME, requiresEscrowBag: true) { mb2_service in
                    guard let mb2_service else { return }
                    requireMobileBackup2Service(device: device, mobileBackup2Service: mb2_service) { mb2_client in
                        guard let mb2_client else { return }
                        let options: [String: Codable] = [
                            "OldPassword": currentPassword,
                            "TargetIdentifier": udid,
                        ]
                        let data = try! PropertyListEncoder().encode(AnyCodable(options))
                        var query: plist_t?
                        defer { plist_free(query) }
                        _ = data.withUnsafeBytes { byte in
                            plist_from_memory(byte.baseAddress, UInt32(byte.count), &query, nil)
                        }
                        guard let query else { return }
                        mobilebackup2_send_message(mb2_client, "ChangePassword", query)
                    }
                }
            }
        }
    }
}
