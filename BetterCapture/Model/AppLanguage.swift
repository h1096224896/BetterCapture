//
//  AppLanguage.swift
//  BetterCapture
//
//  Created by Codex on 30.05.26.
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english
    case simplifiedChinese

    var id: String { rawValue }

    static var current: AppLanguage {
        let rawValue = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.english.rawValue
        return AppLanguage(rawValue: rawValue) ?? .english
    }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }
}

enum AppText {
    static func value(_ english: String, _ simplifiedChinese: String, language: AppLanguage) -> String {
        switch language {
        case .english:
            return english
        case .simplifiedChinese:
            return simplifiedChinese
        }
    }
}
