//
//  RegisterStepHeaderView.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/1/5.
//

import SwiftUI

struct RegisterStepHeaderView: View {
    let title: String
    let optional: Bool
    let completed: Bool

    var icon: String {
        if completed {
            "checkmark.circle.fill"
        } else if optional {
            "circle.dashed"
        } else {
            "exclamationmark.circle.fill"
        }
    }

    var iconColor: Color {
        if completed {
            .green
        } else if optional {
            .primary.opacity(0.5)
        } else {
            .red
        }
    }

    var body: some View {
        HStack {
            Text(title)
                .lineLimit(1)
                .bold()
            Spacer()
            ZStack {
                ForEach([icon], id: \.self) { _ in
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.interactiveSpring.speed(0.5), value: icon)
        }
    }
}
