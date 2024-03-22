//
//  MacAddress.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/17.
//

import Foundation

enum MacAddress {
    static func FindEthernetInterfaces() -> io_iterator_t? {
        let matchingDictUM = IOServiceMatching("IOEthernetInterface")
        // Note that another option here would be:
        // matchingDict = IOBSDMatching("en0");
        // but en0: isn't necessarily the primary interface, especially on systems with multiple Ethernet ports.

        if matchingDictUM == nil {
            return nil
        }

        let matchingDict = matchingDictUM! as NSMutableDictionary
        matchingDict["IOPropertyMatch"] = ["IOPrimaryInterface": true]

        var matchingServices: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &matchingServices) != KERN_SUCCESS {
            return nil
        }

        return matchingServices
    }

    // Given an iterator across a set of Ethernet interfaces, return the MAC address of the last one.
    // If no interfaces are found the MAC address is set to an empty string.
    // In this sample the iterator should contain just the primary interface.
    static func GetMACAddress(_ intfIterator: io_iterator_t) -> [UInt8]? {
        var macAddress: [UInt8]?

        var intfService = IOIteratorNext(intfIterator)
        while intfService != 0 {
            var controllerService: io_object_t = 0
            if IORegistryEntryGetParentEntry(intfService, kIOServicePlane, &controllerService) == KERN_SUCCESS {
                let dataUM = IORegistryEntryCreateCFProperty(controllerService, "IOMACAddress" as CFString, kCFAllocatorDefault, 0)
                if dataUM != nil {
                    let data = (dataUM!.takeRetainedValue() as! CFData) as Data
                    macAddress = [0, 0, 0, 0, 0, 0]
                    data.copyBytes(to: &macAddress!, count: macAddress!.count)
                }
                IOObjectRelease(controllerService)
            }

            IOObjectRelease(intfService)
            intfService = IOIteratorNext(intfIterator)
        }

        return macAddress
    }

    static func getMacAddress() -> String? {
        var macAddressAsString: String?
        if let intfIterator = FindEthernetInterfaces() {
            if let macAddress = GetMACAddress(intfIterator) {
                macAddressAsString = macAddress.map { String(format: "%02x", $0) }.joined(separator: ":")
            }

            IOObjectRelease(intfIterator)
        }
        return macAddressAsString
    }
}
