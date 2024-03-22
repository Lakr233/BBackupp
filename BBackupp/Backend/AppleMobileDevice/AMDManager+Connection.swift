//
//  AMDManager+Connection.swift
//
//
//  Created by QAQ on 2023/8/11.
//

import AppleMobileDeviceLibrary
import Foundation

public extension AppleMobileDeviceManager {
    enum ConnectionMethod: String {
        case usb
        case net
        case usbPreferred
        case netPreferred
        case any // -> usbPreferred
    }

    func requireDevice(
        udid: String,
        connection: ConnectionMethod = configuration.connectionMethod,
        task: (idevice_t?) -> Void
    ) {
        var device: idevice_t?
        var ret: idevice_error_t = .init(0)
        switch connection {
        case .usb:
            ret = idevice_new_with_options(&device, udid, IDEVICE_LOOKUP_USBMUX)
        case .net:
            ret = idevice_new_with_options(&device, udid, IDEVICE_LOOKUP_NETWORK)
        case .usbPreferred, .any:
            ret = idevice_new_with_options(&device, udid, IDEVICE_LOOKUP_USBMUX)
            if ret != IDEVICE_E_SUCCESS || device == nil {
                ret = idevice_new_with_options(&device, udid, IDEVICE_LOOKUP_NETWORK)
            }
        case .netPreferred:
            ret = idevice_new_with_options(&device, udid, IDEVICE_LOOKUP_NETWORK)
            if ret != IDEVICE_E_SUCCESS || device == nil {
                ret = idevice_new_with_options(&device, udid, IDEVICE_LOOKUP_USBMUX)
            }
        }
        guard ret == IDEVICE_E_SUCCESS, let device else {
            task(nil)
            return
        }
        task(device)
        idevice_free(device)
    }

    func requireLockdownClient(
        device: idevice_t,
        name: String = UUID().uuidString,
        handshake: Bool = true,
        task: (lockdownd_client_t?) -> Void
    ) {
        var client: lockdownd_client_t?
        if handshake {
            guard lockdownd_client_new_with_handshake(device, &client, name) == LOCKDOWN_E_SUCCESS else {
                task(nil)
                return
            }
        } else {
            guard lockdownd_client_new(device, &client, name) == LOCKDOWN_E_SUCCESS else {
                task(nil)
                return
            }
        }
        guard let client else {
            task(nil)
            return
        }
        task(client)
        lockdownd_client_free(client)
    }

    func requireLockdownService(
        client: lockdownd_client_t,
        serviceName: String,
        requiresEscrowBag: Bool = false,
        task: (lockdownd_service_descriptor_t?) -> Void
    ) {
        var service: lockdownd_service_descriptor_t?
        if requiresEscrowBag {
            guard lockdownd_start_service_with_escrow_bag(client, serviceName, &service) == LOCKDOWN_E_SUCCESS,
                  let service
            else {
                task(nil)
                return
            }
            task(service)
            lockdownd_service_descriptor_free(service)
        } else {
            guard lockdownd_start_service(client, serviceName, &service) == LOCKDOWN_E_SUCCESS,
                  let service
            else {
                task(nil)
                return
            }
            task(service)
            lockdownd_service_descriptor_free(service)
        }
    }

    func requireAppleFileConduitService(
        device: idevice_t,
        appleFileConduitService: lockdownd_service_descriptor_t,
        task: (afc_client_t?) -> Void
    ) {
        var client: afc_client_t?
        guard afc_client_new(device, appleFileConduitService, &client) == AFC_E_SUCCESS,
              let client
        else {
            task(nil)
            return
        }
        task(client)
        afc_client_free(client)
    }
}
