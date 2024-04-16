//
//  UpstreamResponseHandler.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/1/4.
//

import Foundation
import NIO

class UpstreamResponseHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    let downstreamContext: ChannelHandlerContext

    init(downstreamContext: ChannelHandlerContext) {
        self.downstreamContext = downstreamContext
    }

    func channelRead(context _: ChannelHandlerContext, data: NIOAny) {
        downstreamContext.writeAndFlush(data, promise: nil)
    }

    func errorCaught(context: ChannelHandlerContext, error _: Error) {
        context.close(promise: nil)
    }
}
