//
//  ProgressPanelView.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/15.
//

import SwiftUI

struct ProgressPanelView: View {
    var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .frame(width: 300, height: 200, alignment: .center)
    }
}

/*

 struct ProgressPanelView: View {
     @Binding var progress: Progress
     init(progress: Binding<Progress>? = nil) {
         if let progress {
             _progress = .init(projectedValue: progress)
         } else {
             _progress = .init(get: { Progress() }, set: { _ in })
         }
     }

     var body: some View {
         content
             .frame(width: 333, height: 180, alignment: .center)
     }

     @ViewBuilder
     var content: some View {
         if progress.totalUnitCount > 0 {
             VStack(spacing: 16) {
                 ProgressView()
                     .progressViewStyle(.circular)
                 ProgressView(
                     value: Double(progress.completedUnitCount),
                     total: Double(progress.totalUnitCount)
                 )
                 .progressViewStyle(.linear)
             }
         } else {
             ProgressView()
                 .progressViewStyle(.circular)
         }
     }
 }

 */
