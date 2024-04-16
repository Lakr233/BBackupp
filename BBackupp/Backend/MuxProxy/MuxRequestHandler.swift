//
//  MuxRequestHandler.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/1/4.
//

import Foundation
import NIO

private let upstreamSocket = try! SocketAddress(unixDomainSocketPath: "/var/run/usbmuxd")

class MuxRequestHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer

    var upstreamChannel: Channel?
    var pendingBuffer: [NIOAny] = []

    func channelActive(context: ChannelHandlerContext) {
        let bootstrap = ClientBootstrap(group: context.channel.eventLoop)
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHandlers([
                    BackPressureHandler(),
                    UpstreamResponsePreProcess(),
                    UpstreamResponseHandler(downstreamContext: context),
                ])
            }

        let future = bootstrap.connect(to: upstreamSocket)
        future.whenSuccess { channel in
            self.upstreamChannel = channel
            self.flushPendingRequests()
        }
        future.whenFailure { _ in
            context.close(promise: nil)
        }
    }

    func channelRead(context _: ChannelHandlerContext, data: NIOAny) {
        pendingBuffer.append(data)
        flushPendingRequests()
    }

    func flushPendingRequests() {
        guard let upstreamChannel else { return }
        pendingBuffer.forEach { upstreamChannel.write($0, promise: nil) }
        pendingBuffer.removeAll()
        upstreamChannel.flush()
    }

    func channelInactive(context _: ChannelHandlerContext) {
        upstreamChannel?.close(promise: nil)
    }

    func errorCaught(context: ChannelHandlerContext, error _: Error) {
        context.close(promise: nil)
    }
}
