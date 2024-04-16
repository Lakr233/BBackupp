//
//  SymbolPickerPanelView.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/1/12.
//

import SwiftUI

private let pickerIconList = [
    "speaker.wave.2",
    "radio",
    "tv.music.note",
    "gamecontroller",
    "keyboard",
    "printer",
    "scanner",
    "faxmachine",
    "camera",
    "video",
    "display.2",
    "display.trianglebadge.exclamationmark",
    "powerplug",
    "wifi",
    "wifi.slash",
    "wifi.exclamationmark",
    "antenna.radiowaves.left.and.right",
    "antenna.radiowaves.left.and.right.slash",
    "cable.connector",
    "cable.connector.horizontal",
    "leaf",
    "leaf.arrow.circlepath",
    "flame",
    "sun.max",
    "moon",
    "star",
    "cloud",
    "cloud.drizzle",
    "cloud.rain",
    "cloud.snow",
    "tornado",
    "hurricane",
    "sparkle",
    "wind",
    "drop",
    "snowflake",
    "umbrella",
    "building",
    "building.2",
    "building.columns",
    "house",
    "map",
    "globe",
    "theatermasks",
    "paintpalette",
    "book",
    "books.vertical",
    "music.note",
    "pianokeys",
    "magnifyingglass",
    "binoculars",
    "hourglass",
    "clock",
    "timer",
    "calendar",
    "alarm",
    "stopwatch",
]

struct SymbolPickerPanelView: View {
    let size: CGFloat = 24
    let spacing: CGFloat = 16

    @Environment(\.dismiss) var dismiss

    @State var chunkSize: Int = 0
    @State var gridSpacing: CGFloat = 0
    @State var chunks: [[String]] = []

    @State var selectedSymbol: String? = nil

    let onComplete: (String?) -> Void
    init(onComplete: @escaping (String?) -> Void) {
        self.onComplete = onComplete
    }

    var columns: [GridItem] { [
        .init(
            .adaptive(minimum: size, maximum: size),
            spacing: spacing
        ),
    ] }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack {
                Text("Symbol Picker").bold()
                Spacer()
            }
            .padding(spacing)
            Divider()
            content
                .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button(selectedSymbol == nil ? "Remove" : "Select") {
                    onComplete(selectedSymbol)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(spacing)
        }
        .frame(width: 450)
    }

    var content: some View {
        GeometryReader { r in
            ScrollView(.vertical) {
                VStack(spacing: spacing) {
                    ForEach(chunks, id: \.self) { chunk in
                        HStack(spacing: 0) {
                            ForEach(chunk, id: \.self) { icon in
                                Image(systemName: icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .padding(4)
                                    .frame(width: size, height: size)
                                    .contentShape(Rectangle())
                                    .foregroundStyle(selectedSymbol == icon ? .white : .primary)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .foregroundStyle(selectedSymbol == icon ? .accent : .clear)
                                    )
                                    .onTapGesture(count: 2) {
                                        onComplete(icon)
                                        dismiss()
                                    }
                                    .onTapGesture {
                                        if selectedSymbol == icon {
                                            selectedSymbol = nil
                                        } else {
                                            selectedSymbol = icon
                                        }
                                    }
                                Spacer()
                                    .frame(width: gridSpacing)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(spacing)
            }
            .onChange(of: r.size) { newValue in
                rebuildLayout(insideWidth: newValue.width - 2 * spacing)
            }
            .onAppear {
                rebuildLayout(insideWidth: r.size.width - 2 * spacing)
            }
        }
        .frame(height: (size + spacing) * 4 + spacing) // - spacing + spacing * 2 as padding
    }

    func rebuildLayout(insideWidth width: CGFloat) {
        chunkSize = Int((width - spacing) / (size + spacing))
        gridSpacing = (width + spacing) / CGFloat(chunkSize) - size
        chunks = pickerIconList.chunked(into: chunkSize)
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        if size == 0 { return [] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
