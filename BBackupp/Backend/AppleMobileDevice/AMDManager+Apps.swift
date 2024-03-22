//
//  AMDManager+Apps.swift
//
//
//  Created by QAQ on 2023/8/15.
//

import AppleMobileDeviceLibrary
import Foundation

public extension AppleMobileDeviceManager {
    func requireInstallProxyService(
        device: idevice_t,
        name: String = UUID().uuidString,
        task: (instproxy_client_t?) -> Void
    ) {
        var client: instproxy_client_t?
        guard instproxy_client_start_service(device, &client, name) == INSTPROXY_E_SUCCESS,
              let client
        else {
            task(nil)
            return
        }
        task(client)
        instproxy_client_free(client)
    }

    func listApplications(device: idevice_t) -> AnyCodableDictionary? {
        var applicationDic: AnyCodableDictionary = [:]
        var fullyDecoded = false
        requireInstallProxyService(device: device) { inst_client in
            guard let inst_client else { return }
            let options: [String: Any] = [
                "ApplicationType": "User",
                "ReturnAttributes": [
                    "CFBundleIdentifier",
                    "ApplicationSINF",
                    "iTunesMetadata",
                ], // looks like that's all, really is?
            ]
            let data = try! PropertyListEncoder().encode(AnyCodable(options))
            var query: plist_t?
            defer { plist_free(query) }
            _ = data.withUnsafeBytes { byte in
                plist_from_memory(byte.baseAddress, UInt32(byte.count), &query, nil)
            }
            guard let query else { return }

            var apps: plist_t?
            defer { plist_free(apps) }

            instproxy_browse(inst_client, query, &apps)
            guard let apps, plist_get_node_type(apps) == PLIST_ARRAY else { return }

            var sb_client: sbservices_client_t?
            defer { if let sb_client { sbservices_client_free(sb_client) } }
            sbservices_client_start_service(device, &sb_client, UUID().uuidString)

            let appCount = plist_array_get_size(apps) // later just free apps, frees all
            for idx in 0 ..< appCount {
                // if any error, break entirely, none-fully-working backup is not acceptable
                guard let app_entry = plist_array_get_item(apps, idx),
                      plist_get_node_type(app_entry) == PLIST_DICT
                else { return }

                guard let bundleHandler = plist_dict_get_item(app_entry, "CFBundleIdentifier"),
                      plist_get_node_type(bundleHandler) == PLIST_STRING
                else { return }
                var buf: UnsafeMutablePointer<CChar>?
                defer { free(buf) }
                plist_get_string_val(bundleHandler, &buf)
                guard let buf else { return }
                let bundleIdentifier = String(cString: buf)

                guard let data = read_plist_to_binary_data(plist: app_entry),
                      var appElement = try? PropertyListDecoder().decode([String: AnyCodable].self, from: data)
                else { return }

                if let sb_client {
                    var buf: UnsafeMutablePointer<CChar>?
                    defer { free(buf) }
                    var len: UInt64 = 0
                    if sbservices_get_icon_pngdata(sb_client, bundleIdentifier, &buf, &len) == SBSERVICES_E_SUCCESS,
                       let buf,
                       len > 0
                    {
                        let pngData = Data(bytes: buf, count: Int(len))
                        appElement["PlaceholderIcon"] = .init(pngData)
                    }
                }

                applicationDic[bundleIdentifier] = .init(appElement)
            }

            fullyDecoded = true
        }
        guard fullyDecoded else { return nil }
        return applicationDic
    }

    func listApplications(
        udid: String,
        connection: ConnectionMethod = configuration.connectionMethod
    ) -> AnyCodableDictionary? {
        var result: AnyCodableDictionary?
        requireDevice(udid: udid, connection: connection) { device in
            guard let device else { return }
            result = listApplications(device: device)
        }
        return result
    }
}

private func read_plist_to_binary_data(plist: plist_t?) -> Data? {
    guard let plist else { return nil }
    var buf: UnsafeMutablePointer<CChar>?
    defer { free(buf) }
    var len: UInt32 = 0
    guard plist_to_bin(plist, &buf, &len) == PLIST_ERR_SUCCESS,
          let buf,
          len > 0
    else { return nil }
    return Data(bytes: buf, count: Int(len))
}
