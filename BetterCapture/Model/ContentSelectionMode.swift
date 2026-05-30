//
//  ContentSelectionMode.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 28.03.26.
//

import Foundation

/// The mode for content selection: picking content via the system picker, or drawing a screen area
enum ContentSelectionMode: String {
    /// The `UserDefaults` / `@AppStorage` key used to persist the selected mode.
    static let storageKey = "contentSelectionMode"

    /// The mode currently stored in `UserDefaults`, falling back to `.pickContent`.
    static var current: ContentSelectionMode {
        guard let raw = UserDefaults.standard.string(forKey: storageKey) else { return .pickContent }
        return ContentSelectionMode(rawValue: raw) ?? .pickContent
    }

    case pickContent
    case selectArea

    var label: String {
        label(language: .english)
    }

    func label(language: AppLanguage) -> String {
        switch self {
        case .pickContent:
            AppText.value("Pick Content", "选择内容", language: language)
        case .selectArea:
            AppText.value("Select Area", "选择区域", language: language)
        }
    }

    var icon: String {
        switch self {
        case .pickContent: "macwindow"
        case .selectArea: "rectangle.dashed"
        }
    }
}
