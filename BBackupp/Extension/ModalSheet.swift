//
//  ModalSheet.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/18.
//

import Cocoa

extension NSAlert {
    func runSheetModal(for sheetWindow: NSWindow) -> NSApplication.ModalResponse {
        beginSheetModal(for: sheetWindow, completionHandler: NSApp.stopModal(withCode:))
        return NSApp.runModal(for: sheetWindow)
    }
}

extension NSSavePanel {
    @discardableResult
    func runSheetModal(for sheetWindow: NSWindow) -> NSApplication.ModalResponse {
        beginSheetModal(for: sheetWindow, completionHandler: NSApp.stopModal(withCode:))
        return NSApp.runModal(for: sheetWindow)
    }
}
