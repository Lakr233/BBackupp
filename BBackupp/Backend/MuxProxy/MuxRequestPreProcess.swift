//
//  MuxRequestPreProcess.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/1/4.
//

import Foundation
import NIO

class MuxRequestPreProcess: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = ByteBuffer

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
//        _ = try? MuxRequest(data: Data(unwrapInboundIn(data).readableBytesView))
        context.fireChannelRead(data)
    }

    func channelActive(context: ChannelHandlerContext) {
        context.fireChannelActive()
    }

    func channelInactive(context: ChannelHandlerContext) {
        context.fireChannelInactive()
    }
}

extension MuxRequestPreProcess {
    func shouldProcessToUpstream(data _: Data) {}
}
