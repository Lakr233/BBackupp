//
//  ResticBackup.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/17.
//

import AuxiliaryExecute
import Combine
import Foundation

class ResticBackup {
    let repo: ResticRepo
    let dir: URL
    init(repo: ResticRepo, dir: URL) {
        self.repo = repo
        self.dir = dir
    }

    var pid: pid_t?
    var onProgress: ((Progress) -> Void)?
    var onCompletion: (() -> Void)?
    var errorList: [String] = []
    var receipt: AuxiliaryExecute.ExecuteReceipt?

    func start() {
        if let pid { terminateSubprocess(pid) }
        receipt = nil

        let queue = DispatchQueue(label: "wiki.qaq.restic.backup")
        queue.async { self.exec() }
    }

    func terminate() {
        if let pid { terminateSubprocess(pid) }
    }

    private func exec() {
        // restic -r /srv/restic-repo --verbose backup ~/work
        var parameters = [
            "--json",
            "--retry-lock", "5h",
            "--tag", String(Int(Date().timeIntervalSince1970)),
            "--exclude", ".DS_Store",
            "--exclude", "._*",
            "backup",
        ]
        if let content = try? FileManager.default.contentsOfDirectory(atPath: dir.path) {
            parameters.append(contentsOf: content)
        }
        let recp = AuxiliaryExecute.spawn(
            command: Restic.executable,
            args: parameters,
            environment: repo.prepareEnv(),
            workingDirectory: dir.path
        ) { self.pid = $0 } output: { self.decodeOutput($0) }
        pid = nil
        receipt = recp
        onCompletion?()
    }

    var buffer = String()
    private func decodeOutput(_ input: String) {
        buffer += input
        while let index = buffer.firstIndex(of: "\n") {
            let line = String(buffer.prefix(upTo: index))
            buffer.removeSubrange(buffer.startIndex ... index)
            decodeLine(line)
        }
    }

    private func decodeLine(_ line: String) {
        let line = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let message_type = object["message_type"] as? String
        else { return }

        switch message_type {
        case "error": decodeErrorFrom(object)
        case "status": decodeStatusFrom(object)
        case "summary": decodeSummaryFrom(object)
        default: break
        }
    }

    private func decodeErrorFrom(_ dic: [String: Any]) {
        /*
         message_type Always “error”
         error Error message
         during What restic was trying to do
         item Usually, the path of the problematic file
         */
        guard let error = dic["error"] as? String, !error.isEmpty else {
            return
        }
        errorList.append(error)
    }

    private func decodeStatusFrom(_ dic: [String: Any]) {
        /*
         message_type Always “status”
         seconds_elapsed Time since backup started
         seconds_remaining Estimated time remaining
         percent_done Percentage of data backed up (bytes_done/total_bytes)
         total_files Total number of files detected
         files_done Files completed (backed up to repo)
         total_bytes Total number of bytes in backup set
         bytes_done Number of bytes completed (backed up to repo)
         error_count Number of errors
         current_files List of files currently being backed up
         */
        // {"message_type":"status","percent_done":0.016352636412683117,"total_files":677,"files_done":17,"total_bytes":1214055,"bytes_done":19853}
        let progress = Progress()
        progress.totalUnitCount = Int64(dic["total_bytes"] as? Int ?? 0)
        progress.completedUnitCount = Int64(dic["bytes_done"] as? Int ?? 0)
        onProgress?(progress)
    }

    private func decodeSummaryFrom(_: [String: Any]) {
        /*
         message_type Always “summary”
         files_new Number of new files
         files_changed Number of files that changed
         files_unmodified Number of files that did not change
         dirs_new Number of new directories
         dirs_changed Number of directories that changed
         dirs_unmodified Number of directories that did not change
         data_blobs Number of data blobs
         tree_blobs Number of tree blobs
         data_added Amount of data added, in bytes
         total_files_processed Total number of files processed
         total_bytes_processed Total number of bytes processed
         total_duration Total time it took for the operation to complete
         snapshot_id ID of the new snapshot
         */
        // {"message_type":"summary","files_new":0,"files_changed":1,"files_unmodified":6526,"dirs_new":0,"dirs_changed":2,"dirs_unmodified":2014,"data_blobs":1,"tree_blobs":3,"data_added":71017,"total_files_processed":6527,"total_bytes_processed":721364953,"total_duration":0.918486206,"snapshot_id":"bcc5c5b1"}
    }
}
