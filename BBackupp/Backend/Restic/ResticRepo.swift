//
//  ResticRepo.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/15.
//

import AuxiliaryExecute
import Foundation

private let iso8601fmt = {
    let fmt = ISO8601DateFormatter()
    fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return fmt
}()

struct ResticRepo: Codable, Identifiable {
    var id: String = ""
    var location: String = ""

    struct EnvValue: Identifiable, Codable {
        var id: UUID
        var key: String
        var value: String

        init(id: UUID = .init(), key: String, value: String) {
            self.id = id
            self.key = key
            self.value = value
        }
    }

    var metadata: [EnvValue] = []

    init(location: String, metadata: [EnvValue] = []) {
        self.location = location
        self.metadata = metadata
    }
}

extension ResticRepo {
    struct CreateResponse: Codable {
        var message_type: String
        var id: String
        var repository: String
    }

    struct Snapshot: Codable, Identifiable {
        var time: String
        var date: Date { iso8601fmt.date(from: time) ?? .init(timeIntervalSince1970: 0) }
        var program_version: String
        var id: String
        var short_id: String
    }
}

extension ResticRepo {
    func prepareEnv() -> [String: String] {
        var ans = [String: String]()
        for item in metadata {
            ans[item.key] = item.value
        }
        ans["RESTIC_REPOSITORY"] = location
        ans["RESTIC_PASSWORD"] = Restic.defaultPassword
        return ans
    }

    enum InitError: Error {
        case unkown
        case error(message: String)
    }

    mutating func initializeRepository() -> Result<Void, InitError> {
        let recp = AuxiliaryExecute.spawn(
            command: Restic.executable,
            args: ["--json", "--retry-lock", "5h", "init", "--repo", location],
            environment: prepareEnv(),
            setPid: nil,
            output: nil
        )
        let stdout = recp.stdout
        guard let data = stdout.data(using: .utf8),
              let response = try? JSONDecoder().decode(CreateResponse.self, from: data),
              !response.id.isEmpty,
              response.message_type == "initialized"
        else {
            let err = recp.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if err.isEmpty {
                return .failure(.unkown)
            } else {
                return .failure(.error(message: err))
            }
        }
        id = response.id
        return .success()
    }

    func listSnapshots() -> [Snapshot] {
        let recp = AuxiliaryExecute.spawn(
            command: Restic.executable,
            args: ["--json", "--retry-lock", "5h", "snapshots"],
            environment: prepareEnv(),
            setPid: nil,
            output: nil
        )
        let stdout = recp.stdout
        guard let data = stdout.data(using: .utf8),
              let response = try? JSONDecoder().decode([Snapshot].self, from: data)
        else {
            return []
        }
        return response
    }

    func unlock() {
        let recp = AuxiliaryExecute.spawn(
            command: Restic.executable,
            args: ["--json", "--retry-lock", "5h", "unlock"],
            environment: prepareEnv(),
            setPid: nil,
            output: nil
        )
        print("[*] unlocking repo at \(location) retuned \(recp.exitCode)")
    }
}
