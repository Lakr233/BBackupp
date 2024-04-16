//
//  StatusBarPopoverView.swift
//  Rainbow Fart
//
//  Created by QAQ on 2023/7/11.
//

import Cocoa
import ColorfulX
import SwiftUI

struct StatusBarPopoverView: View {
    @StateObject var backupManager = bakManager

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Spacer()
                Text("Exit")
                    .font(.footnote)
                    .underline()
                    .foregroundStyle(.accent)
                    .onTapGesture {
                        NSApplication.shared.terminate(self)
                    }
            }
            Image("Avatar")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64, alignment: .center)
                .padding(.vertical, 8)
            Text("BBackupp")
                .bold()
            Text("Automation scheduler is running for \(backupManager.automationEnabledPlans.count) plan(s).")
                .font(.footnote)
        }
        .frame(width: 400, alignment: .center)
        .padding()
        .background(background.ignoresSafeArea().padding(-64))
    }

    @ViewBuilder
    var background: some View {
        ColorfulView(color: .constant([
            .init("WelcomeColorMain"),
            .init("WelcomeColorSecondary"),
            .background,
            .background,
            .background,
            .background,
            .background,
            .background,
            .background,
            .background,
        ]), speed: .constant(0))
            .opacity(0.25)
    }
}

#Preview {
    StatusBarPopoverView()
}

class StatusBarPopover: NSPopover {
    private var eventMonitor: EventMonitor!

    override init() {
        super.init()
        contentViewController = NSHostingController(rootView: StatusBarPopoverView())
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown], handler: mouseEventHandler)
    }

    func mouseEventHandler(_: NSEvent?) {
        if isShown { hidePopover() }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    func showPopover(statusItem: NSStatusItem) {
        if let statusBarButton = statusItem.button {
            show(relativeTo: statusBarButton.bounds, of: statusBarButton, preferredEdge: NSRectEdge.maxY)
            eventMonitor.start()
        }
    }

    func hidePopover() {
        performClose(nil)
        eventMonitor.stop()
    }
}

private class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void

    public init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    deinit {
        stop()
    }

    public func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler) as! NSObject
    }

    public func stop() {
        if monitor != nil {
            NSEvent.removeMonitor(monitor!)
            monitor = nil
        }
    }
}
