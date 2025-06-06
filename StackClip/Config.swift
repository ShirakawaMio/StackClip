//
//  Config.swift
//  StackClip
//
//  Created by Shirakawa Mio on 04.06.2025.
//

import Foundation

class AppConfig: ObservableObject {
    static let shared = AppConfig() // 单例
    
    @Published var basePasteDelay: TimeInterval = 0.25
    @Published var maxStackDepth: Int = 20
    @Published var showDockIcon: Bool = false
    @Published var maxTextLength: Int = 32

    private init() {}
}
