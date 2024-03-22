//
//  DownloadSeed.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/17.
//

import AuxiliaryExecute
import Foundation

class DownloadSeed {
    static let executable = Bundle.main.url(forAuxiliaryExecutable: "pget")!.path

    let url: URL
    let toFile: URL

    init(url: URL, toFile: URL) {
        self.url = url
        self.toFile = toFile
    }

    var pid: pid_t?
    var onProgress: ((Progress) -> Void)?
    var onCompletion: (() -> Void)?
    var receipt: AuxiliaryExecute.ExecuteReceipt?

    func start() {
        if let pid { terminateSubprocess(pid) }
        receipt = nil

        let queue = DispatchQueue(label: "wiki.qaq.pget")
        queue.async { self.exec() }
    }

    func terminate() {
        if let pid { terminateSubprocess(pid) }
    }

    private func exec() {
        let recp = AuxiliaryExecute.spawn(
            command: Self.executable,
            args: ["-p4", "-o", toFile.path, url.absoluteString]
        ) { self.pid = $0 } output: { self.decodeOutput($0) }
        pid = nil
        receipt = recp
        onCompletion?()
    }

    var buffer = String()
    private func decodeOutput(_ input: String) {
        buffer += input
        buffer = buffer.replacingOccurrences(of: "\r", with: "\n")
        buffer = buffer.replacingOccurrences(of: "p/s", with: "\n")
        while let index = buffer.firstIndex(of: "\n") {
            let line = String(buffer.prefix(upTo: index))
            buffer.removeSubrange(buffer.startIndex ... index)
            decodeLine(line)
        }
    }

    private func decodeLine(_ line: String) {
        decodeProgressFrom(line)
    }

    private func decodeProgressFrom(_ line: String) {
        guard let cutA = line.components(separatedBy: "[")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        else { return }
        let comps = cutA.components(separatedBy: "/").map { $0.trimmingCharacters(in: .whitespaces) }
        guard comps.count == 2 else { return }
        guard let current = SizeDecoder.decode(comps[0]),
              let total = SizeDecoder.decode(comps[1])
        else { return }
        let progress = Progress(totalUnitCount: Int64(total))
        progress.completedUnitCount = Int64(current)
        onProgress?(progress)
    }
}
