//
//  SectionBuilder.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/16.
//

import SwiftUI

struct SectionBuilder<V: View>: View {
    let title: String
    @ViewBuilder var content: V

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content
        }
    }
}
