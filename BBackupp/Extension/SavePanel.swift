//
//  SavePanel.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/7.
//

import AppKit

extension NSApplication {
    func beginSavePanel(_ adjust: (inout NSSavePanel) -> Void, completion: @escaping (URL) -> Void) {
        guard let window = keyWindow else { return }
        var panel = NSSavePanel()
        adjust(&panel)
        panel.beginSheetModal(for: window) { resp in
            guard resp == .OK else { return }
            guard let url = panel.url else { return }
            completion(url)
        }
    }
}

extension NSSavePanel {
    func setup(
        title: String? = nil,
        nameFieldStringValue: String? = nil,
        directoryURL: URL? = nil,
        canCreateDirectories: Bool? = true,
        showsHiddenFiles: Bool? = false
    ) {
        if let title { self.title = title }
        if let nameFieldStringValue { self.nameFieldStringValue = nameFieldStringValue }
        if let directoryURL { self.directoryURL = directoryURL }
        if let canCreateDirectories { self.canCreateDirectories = canCreateDirectories }
        if let showsHiddenFiles { self.showsHiddenFiles = showsHiddenFiles }
    }
}
