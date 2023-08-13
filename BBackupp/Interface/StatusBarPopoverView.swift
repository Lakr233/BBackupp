//
//  StatusBarPopover.swift
//  Rainbow Fart
//
//  Created by QAQ on 2023/7/11.
//

import Cocoa
import SwiftUI

struct StatusBarPopoverView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                Button("Exit") {
                    NSApplication.shared.terminate(self)
                }
            }
            Image("Avatar")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64, alignment: .center)
            Text("BBackupp is Running")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
            Text(Constants.copyrightNotice)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
        }
        .frame(width: 400, alignment: .center)
        .padding()
    }
}

class StatusBarPopover: NSPopover {
    var eventMonitor: EventMonitor!

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
