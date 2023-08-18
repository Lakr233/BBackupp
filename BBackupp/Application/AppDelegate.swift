//
//  AppDelegate.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/13.
//

import AppKit
import IOKit
import IOKit.pwr_mgt

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let popover = StatusBarPopover()

    override private init() {
        super.init()
        let timer = Timer(
            timeInterval: 1,
            target: self,
            selector: #selector(windowStatusWatcher),
            userInfo: nil,
            repeats: true
        )
        CFRunLoopAddTimer(CFRunLoopGetMain(), timer, .commonModes)
        let aliveChecker = Timer(
            timeInterval: 60,
            target: self,
            selector: #selector(postAliveHeartBeatIfNeeded),
            userInfo: nil,
            repeats: true
        )
        CFRunLoopAddTimer(CFRunLoopGetMain(), aliveChecker, .commonModes)

        let reasonForActivity = "\(Constants.appName) is viewing your backup schedule list" as CFString
        var assertionID: IOPMAssertionID = 0
        var success = IOPMAssertionCreateWithName(kIOPMAssertionTypeNoDisplaySleep as CFString,
                                                  IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                  reasonForActivity,
                                                  &assertionID)
        if success == kIOReturnSuccess { success = IOPMAssertionRelease(assertionID) }
    }

    func applicationDidFinishLaunching(_: Notification) {
        let robotImage = NSImage(named: "Robot")!
        robotImage.size = .init(width: 18, height: 18)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = robotImage
        statusItem.button?.target = self
        statusItem.button?.action = #selector(activateStatusMenu(_:))
    }

    @objc
    func activateStatusMenu(_: Any) {
        popover.showPopover(statusItem: statusItem)
    }

    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Quit the app will cancel all backup and disable scheduled backup"
        alert.addButton(withTitle: "Exit")
        alert.addButton(withTitle: "Cancel")
        let resp = alert.runModal()
        return resp == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }

    @objc
    func windowStatusWatcher() {
        let windows = NSApp.windows
            .filter { window in
                guard let readClass = NSClassFromString("NSStatusBarWindow") else {
                    return true
                }
                return !window.isKind(of: readClass.self)
            }
            .filter(\.isVisible)
        if windows.isEmpty, !popover.isShown {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
        }
    }

    @objc
    func postAliveHeartBeatIfNeeded() {
        let aliveUrl = Configuration.shared.aliveCheck
        guard !aliveUrl.isEmpty, let url = URL(string: aliveUrl) else { return }
        DispatchQueue.global().async {
            URLSession.shared.dataTask(with: URLRequest(url: url)).resume()
        }
    }
}
