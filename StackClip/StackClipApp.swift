//
//  StackClipApp.swift
//  StackClip
//
//  Created by Shirakawa Mio on 03.06.2025.
//

import SwiftUI

@main
struct ClipboardStackApp: App {
    @StateObject private var clipboardManager = ClipboardManager()

    var body: some Scene {
        MenuBarExtra("Clipboard", systemImage: "doc.on.clipboard") {
            if clipboardManager.clipboardStack.isEmpty {
                Text("剪贴板为空")
            } else {
                ForEach(Array(clipboardManager.clipboardStack.enumerated()), id: \.element) { index, itemArray in
                    Button(action: {
                        clipboardManager.copyToClipboard(itemArray)
                    }) {
                        if let firstItem = itemArray.first,
                           let str = firstItem.displayString {
                            Text(str).lineLimit(1)
                        } else {
                            Text("[多类型项]")
                        }
                    }
                }

                Divider()

                Button("清空栈") {
                    clipboardManager.clearStack()
                }
            }
        }
    }
}

extension ClipboardManager {
    func copyToClipboard(_ content: [PasteboardItemData]) {
        pasteboard.clearContents()
        let copiedItems = content.map { $0.toPasteboardItem() }
        pasteboard.writeObjects(copiedItems)
    }

    func clearStack() {
        clipboardStack.removeAll()
    }
}
