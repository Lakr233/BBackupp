//
//  UpstreamResponsePreProcess.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/1/4.
//

import Foundation
import Network
import NIO

class UpstreamResponsePreProcess: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = ByteBuffer

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var resp: NIOAny = data
        defer { context.fireChannelRead(resp) }
        injectDeviceIfNeeded(byModifyingResponse: &resp, withinContext: context)
    }

    func channelActive(context: ChannelHandlerContext) {
        context.fireChannelActive()
    }

    func channelInactive(context: ChannelHandlerContext) {
        context.fireChannelInactive()
    }
}

extension UpstreamResponsePreProcess {
    //         For muxd headers, we expect the first command to be less than MTU size of 1500 bytes. (usually)
    //         The domain socket is unlikely to be cut off, so we can safely assume that the first command is complete.
    //
    //         This pre-processing is required for insert customized network device to libimobiledevice.
    //         > The usbmuxd relies on Bonjour(mDNS) service but it is not always reliable.
    //         > We have done optimization on this and user is able to configure the device ip themselves.
    //
    //         Thus, for request comes with type 8 plist and MessageType ListDevices:
    //         We are going to take a different approach.
    //
    //         Note: The lack of customization options in libimobiledevice presents significant challenges in these processes.
    //               & I am sure I can NOT maintain the modification/patch that made to the upstream library.

    func injectDeviceIfNeeded(byModifyingResponse response: inout NIOAny, withinContext context: ChannelHandlerContext) {
        guard var muxResponse = try? MuxResponse(data: Data(unwrapInboundIn(response).readableBytesView)),
              muxResponse.message == 8
        else { return }

        guard var dic = try? PropertyListDecoder().decode([String: AnyCodable].self, from: muxResponse.payload),
              var list = dic["DeviceList"]?.value as? [Any]
        else { return }

        var injected = false
        devManager.devices.values.forEach { device in
            guard let networkAddress = device.possibleNetworkAddress.first,
                  !networkAddress.isEmpty
            else { return }
            if self.checkInjectIfNeeded(udid: device.udid, networkAddress: networkAddress, modifyingArray: &list) {
                injected = true
            }
        }

        guard injected else { return }
        dic["DeviceList"] = AnyCodable(list)

        guard let encodeData = try? PropertyListEncoder().encode(dic),
              let object = try? PropertyListSerialization.propertyList(
                  from: encodeData,
                  options: [],
                  format: nil
              ),
              let replacedData = try? PropertyListSerialization.data(
                  fromPropertyList: object,
                  format: .xml,
                  options: .zero
              )
        else { return }

        let newLen = Int(muxResponse.length) + Int(replacedData.count) - Int(muxResponse.payload.count)
        guard newLen > 0 else { return }

        muxResponse.length = UInt32(newLen)
        muxResponse.payload = replacedData
        response = NIOAny(context.channel.allocator.buffer(bytes: muxResponse.serialize()))
    }

    func checkInjectIfNeeded(udid targetIdentifier: String, networkAddress: String, modifyingArray deviceList: inout [Any]) -> Bool {
        // if exists, return nil
        for device in deviceList {
            guard let dic = device as? [String: Any],
                  let deviceProperties = dic["Properties"] as? [String: Any],
                  let udid = deviceProperties["SerialNumber"] as? String
            else { continue }
            if udid == targetIdentifier { return false }
        }

        if let _ = IPv4Address(networkAddress) {
            var sockAddrIn = sockaddr_in()
            sockAddrIn.sin_family = sa_family_t(AF_INET)
            sockAddrIn.sin_port = 0
            sockAddrIn.sin_addr.s_addr = inet_addr(networkAddress)
            sockAddrIn.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            deviceList.append(contentsOf: [
                [
                    "Properties": [
                        "DeviceID": Int.random(in: 50000 ... 65535),
                        "SerialNumber": targetIdentifier,
                        "ConnectionType": "Network",
                        "NetworkAddress": Data(bytes: &sockAddrIn, count: MemoryLayout<sockaddr_in>.size),
                    ],
                ],
            ])
        } else if let _ = IPv6Address(networkAddress) {
            print("[*] ipv6 network address is not supported")
        } else {
            print("[*] invalid network address \(networkAddress)")
            return false
        }

//        print("[*] using \(networkAddress) for device \(targetIdentifier)")

        return true
    }
}
