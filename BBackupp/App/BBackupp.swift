//
//  BBackupp.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/1/4.
//

import AppleMobileDeviceLibrary
import SwiftUI

public func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    NSLog(items.map { "\($0)" }.joined(separator: separator) + terminator)
}

let documentDir: URL = FileManager.default.urls(
    for: .documentDirectory,
    in: .userDomainMask
)
.first!
.appendingPathComponent(Constants.appName)
let tempDir: URL = .init(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent(Constants.appName)
let logDir = documentDir.appendingPathComponent("Logs")

@main
struct BBackuppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        setupApplication()
    }

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .commands { commands }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unifiedCompact)
    }

    @CommandsBuilder
    var commands: some Commands {
        CommandMenu("Muxd") {
            Button("Import Pair Record") {
                let panel = NSOpenPanel()
                panel.title = "Import From Pair Record"
                panel.begin { response in
                    guard response == .OK, let url = panel.url else { return }
                    importPairRecord(from: url)
                }
            }
            Divider()
            Button("Copy Terminal Environment") {
                let string = "export USBMUXD_SOCKET_ADDRESS=UNIX:\(MuxProxy.shared.socketPath.path)"
                NSPasteboard.general.prepareForNewContents()
                NSPasteboard.general.setString(string, forType: .string)
            }
        }
        CommandMenu("Restic") {
            Button("Copy Terminal Environment - Default Password") {
                let string = "export RESTIC_PASSWORD=\(Restic.defaultPassword)"
                NSPasteboard.general.prepareForNewContents()
                NSPasteboard.general.setString(string, forType: .string)
            }
        }
    }
}

func importPairRecord(from url: URL) {
    do {
        try _importPairRecord(from: url)
    } catch {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

private func _importPairRecord(from url: URL) throws {
    let data = try Data(contentsOf: url)
    let pair = try PropertyListDecoder().decode(PairRecord.self, from: data)
    enum ImportError: Error { case deviceNotFound }

    let binaryData = pair.propertyListBinaryData as NSData
    let ret = usbmuxd_save_pair_record_with_device_id(
        pair.udid,
        0,
        binaryData.bytes,
        UInt32(binaryData.length)
    )
    print("[*] usbmuxd_save_pair_record_with_device_id: \(ret)")
    amdManager.sendPairRequest(udid: pair.udid)

    if devManager.devices[pair.udid] == nil {
        let device = Device(
            udid: pair.udid,
            deviceRecord: amdManager.obtainDeviceInfo(udid: pair.udid) ?? .init(),
            pairRecord: pair,
            extra: [:],
            possibleNetworkAddress: []
        )
        devManager.devices[device.udid] = device
    }
}
