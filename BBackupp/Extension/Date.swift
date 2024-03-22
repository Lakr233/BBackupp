//
//  Date.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/16.
//

import Foundation

extension Date {
    func years(from date: Date) -> Int {
        Calendar.current.dateComponents([.year], from: date, to: self).year ?? 0
    }

    func months(from date: Date) -> Int {
        Calendar.current.dateComponents([.month], from: date, to: self).month ?? 0
    }

    func weeks(from date: Date) -> Int {
        Calendar.current.dateComponents([.weekOfMonth], from: date, to: self).weekOfMonth ?? 0
    }

    func days(from date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: date, to: self).day ?? 0
    }

    func hours(from date: Date) -> Int {
        Calendar.current.dateComponents([.hour], from: date, to: self).hour ?? 0
    }

    func minutes(from date: Date) -> Int {
        Calendar.current.dateComponents([.minute], from: date, to: self).minute ?? 0
    }

    func seconds(from date: Date) -> Int {
        Calendar.current.dateComponents([.second], from: date, to: self).second ?? 0
    }

    func offset(from date: Date) -> String {
        if years(from: date) > 0 { return "\(years(from: date))y" }
        if months(from: date) > 0 { return "\(months(from: date))M" }
        if weeks(from: date) > 0 { return "\(weeks(from: date))w" }
        if days(from: date) > 0 { return "\(days(from: date))d" }
        if hours(from: date) > 0 { return "\(hours(from: date))h" }
        if minutes(from: date) > 0 { return "\(minutes(from: date))m" }
        if seconds(from: date) > 0 { return "\(seconds(from: date))s" }
        return ""
    }
}
