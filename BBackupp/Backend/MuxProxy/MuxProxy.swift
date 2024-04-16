//
//  MuxProxy.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/1/4.
//

import Foundation
import NIO

class MuxProxy {
    let socketPath: URL

    let group: MultiThreadedEventLoopGroup
    let bootstrap: ServerBootstrap
    let channel: Channel

    init() throws {
        socketPath = tempDir.appendingPathComponent("muxd.socket")
        group = .init(numberOfThreads: System.coreCount)
        bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.socket(SOL_SOCKET, SO_REUSEADDR), value: 1)
            .childChannelOption(ChannelOptions.socket(SOL_SOCKET, SO_REUSEADDR), value: 1)
            .childChannelInitializer { $0.pipeline.addHandlers([
                BackPressureHandler(),
                MuxRequestPreProcess(),
                MuxRequestHandler(),
            ]) }

        print("[*] \(socketPath.path)")
        setenv("USBMUXD_SOCKET_ADDRESS", "UNIX:\(socketPath.path)", 1)

        channel = try bootstrap.bind(
            unixDomainSocketPath: socketPath.path,
            cleanupExistingSocketFile: true
        ).wait()
        print("[*] unix socket is now ready to accept connections")
    }

    deinit { try? channel.close().wait() }
}
