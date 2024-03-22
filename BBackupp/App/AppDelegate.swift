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
            selector: #selector(activityChecker),
            userInfo: nil,
            repeats: true
        )
        CFRunLoopAddTimer(CFRunLoopGetMain(), timer, .commonModes)
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

    var assertionID: IOPMAssertionID = 0
    @objc func activityChecker() {
        if bakManager.runningTaskCount <= 0 {
            if assertionID != 0 {
                IOPMAssertionRelease(assertionID)
                assertionID = 0
            }
        } else {
            if assertionID == 0 {
                let reasonForActivity = "\(Constants.appName) is backing up your devices"
                IOPMAssertionCreateWithName(
                    kIOPMAssertionTypeNoDisplaySleep as CFString,
                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                    reasonForActivity as CFString,
                    &assertionID
                )
            }
        }
    }

    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        guard bakManager.runningTaskCount <= 0 else {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Are you sure to quit?"
            alert.informativeText = "You have running backup tasks."
            alert.addButton(withTitle: "Quit")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            return response == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
        }
        guard bakManager.automationEnabledPlans.isEmpty else {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Are you sure to quit?"
            alert.informativeText = "You have backup plans in schedule."
            alert.addButton(withTitle: "Quit")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            return response == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
        }
        return .terminateNow
    }

    func applicationWillTerminate(_: Notification) {
        bakManager.saveAll()
        killAllChildren()
    }
}

@discardableResult
func terminateSubprocess(_ pid: pid_t) -> Int32 {
    var signal = SIGKILL
    var buf = [CChar](repeating: 0, count: Int(PROC_PIDPATHINFO_SIZE))
    proc_pidpath(pid, &buf, UInt32(PROC_PIDPATHINFO_SIZE))
    let path = String(cString: buf)
    let url = URL(fileURLWithPath: path)
    if url.path == Restic.executable { signal = SIGINT }
    print("[*] terminating \(pid) with signal \(signal)")
    return kill(pid, signal)
}

private func killAllChildren() {
    var mib = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
    var size = 0
    if sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) < 0 { return }
    let entryCount = size / MemoryLayout<kinfo_proc>.stride

    var ps: UnsafeMutablePointer<kinfo_proc>?
    ps = UnsafeMutablePointer.allocate(capacity: size)
    defer { ps?.deallocate() }

    if sysctl(&mib, UInt32(mib.count), ps, &size, nil, 0) < 0 { return }

    for index in 0 ... entryCount {
        guard let pid = ps?[index].kp_proc.p_pid,
              pid != 0,
              pid != getpid()
        else { continue }
        var buf = [CChar](repeating: 0, count: Int(PROC_PIDPATHINFO_SIZE))
        proc_pidpath(pid, &buf, UInt32(PROC_PIDPATHINFO_SIZE))

        let path = String(cString: buf)
        if path.hasPrefix(Bundle.main.bundlePath) {
            terminateSubprocess(pid)
        }
    }
}
