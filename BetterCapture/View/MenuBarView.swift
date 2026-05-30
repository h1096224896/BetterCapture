//
//  MenuBarView.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 29.01.26.
//

import SwiftUI
import ScreenCaptureKit

/// The main menu bar interface for BetterCapture
struct MenuBarView: View {
    @Bindable var viewModel: RecorderViewModel
    @Environment(\.openSettings) private var openSettings
    @Environment(\.dismiss) private var dismiss
    @State private var currentPreview: NSImage?

    private var isRecording: Bool { viewModel.isRecording }
    private var language: AppLanguage { viewModel.settings.appLanguage }

    var body: some View {
        VStack(spacing: 0) {
            // Permission status banner (only when idle)
            if !isRecording,
               viewModel.permissionService.screenRecordingState != .granted ||
                (viewModel.settings.captureMicrophone && viewModel.permissionService.microphoneState != .granted) {
                PermissionStatusBanner(
                    permissionService: viewModel.permissionService,
                    showMicrophonePermission: viewModel.settings.captureMicrophone,
                    language: language
                )
                MenuBarDivider()
            }

            // Recording button (stop + timer) or Start button
            if isRecording {
                RecordingButton(
                    duration: viewModel.formattedDuration,
                    language: language
                ) {
                    Task {
                        await viewModel.stopRecording()
                    }
                }
                .padding(.top, 8)
            } else {
                MenuBarActionButton(
                    title: AppText.value("Start Recording", "开始录制", language: language),
                    systemImage: "record.circle",
                    accentColor: .green,
                    isDisabled: !viewModel.canStartRecording
                ) {
                    Task {
                        await viewModel.startRecording()
                        dismiss()
                    }
                }
                .padding(.top, 8)
            }

            MenuBarDivider()

            // Content Selection
            ContentSelectionButton(viewModel: viewModel, language: language) { dismiss() }
                .disabled(isRecording)

            // Preview thumbnail
            if viewModel.hasContentSelected {
                PreviewThumbnailView(
                    previewImage: currentPreview,
                    isLivePreviewActive: viewModel.previewService.isCapturing,
                    language: language,
                    onStartLivePreview: {
                        Task {
                            await viewModel.startPreview()
                        }
                    },
                    onStopLivePreview: {
                        Task {
                            await viewModel.stopPreview()
                        }
                    }
                )
                .onChange(of: viewModel.previewService.previewImage) { _, newImage in
                    currentPreview = newImage
                }
                .onAppear {
                    currentPreview = viewModel.previewService.previewImage
                }

                Button {
                    Task {
                        await viewModel.resetAreaSelection()
                    }
                } label: {
                    Text(AppText.value("Reset Selection", "重置选择", language: language))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(.gray.opacity(0.15), in: .rect(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .disabled(isRecording)
            }

            MenuBarDivider()

            // Settings Sections
            Group {
                VideoSettingsSection(settings: viewModel.settings)

                PresenterOverlaySettingsSection(
                    settings: viewModel.settings,
                    cameraDeviceService: viewModel.cameraDeviceService
                )

                AudioSettingsSection(
                    settings: viewModel.settings,
                    audioDeviceService: viewModel.audioDeviceService
                )
            }
            .disabled(isRecording)

            MenuBarDivider()

            // Bottom Actions
            MenuBarActionButton(
                title: AppText.value("Open Output Folder", "打开输出文件夹", language: language),
                systemImage: "folder"
            ) {
                let settings = viewModel.settings
                let didStart = settings.startAccessingOutputDirectory()
                defer {
                    if didStart {
                        settings.stopAccessingOutputDirectory()
                    }
                }
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: settings.outputDirectory.path)
            }

            MenuBarActionButton(title: AppText.value("Settings...", "设置...", language: language), systemImage: "gear") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openSettings()
            }

            MenuBarActionButton(title: AppText.value("Quit...", "退出...", language: language), systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
            .padding(.bottom, 8)
        }
        .frame(width: 320)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Menu Bar Action Button

/// A styled action button for menu bar window with hover effect
struct MenuBarActionButton: View {
    let title: String
    var systemImage: String?
    var accentColor: Color = .primary
    var isDisabled: Bool = false
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let systemImage {
                    ZStack {
                        Circle()
                            .fill(.gray.opacity(0.2))
                            .frame(width: 24, height: 24)

                        Image(systemName: systemImage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(isDisabled ? Color.gray.opacity(0.3) : accentColor.opacity(0.8))
                    }
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isDisabled ? Color.gray.opacity(0.5) : Color.primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered && !isDisabled ? accentColor.opacity(0.1) : .clear)
                .padding(.horizontal, 4)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Recording Button

/// A combined button that shows recording status and allows stopping
struct RecordingButton: View {
    let duration: String
    var language: AppLanguage = .english
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Pulsing red dot with stop icon
                ZStack {
                    Circle()
                        .fill(.gray.opacity(0.2))
                        .frame(width: 24, height: 24)

                    Image(systemName: "stop.circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.red.opacity(0.8))
                }

                Text(AppText.value("Stop Recording", "停止录制", language: language))
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Text(duration)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? .red.opacity(0.1) : .clear)
                .padding(.horizontal, 4)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Content Selection Button

/// A split button that triggers the active content selection mode, with a dropdown chevron to switch modes.
/// The left portion triggers the action; the right chevron opens a dropdown to change the mode.
/// Styled consistently with other menu bar rows.
struct ContentSelectionButton: View {
    let viewModel: RecorderViewModel
    let language: AppLanguage
    var onDismissPanel: (() -> Void)?
    @AppStorage(ContentSelectionMode.storageKey) private var mode: ContentSelectionMode = .pickContent
    @State private var isDropdownExpanded = false
    @State private var isMainHovered = false
    @State private var isChevronHovered = false

    /// Whether content has been selected via the currently active mode
    private var hasActiveSelection: Bool {
        switch mode {
        case .pickContent:
            viewModel.hasContentSelected && !viewModel.isAreaSelection
        case .selectArea:
            viewModel.isAreaSelection
        }
    }

    private var buttonLabel: String {
        if hasActiveSelection {
            return AppText.value(
                "Change \(mode.label(language: language))...",
                "更改\(mode.label(language: language))...",
                language: language
            )
        }

        return "\(mode.label(language: language))..."
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main button row
            HStack(spacing: 0) {
                // Left: action button
                Button {
                    triggerAction()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(hasActiveSelection ? .blue.opacity(0.8) : .gray.opacity(0.2))
                                .frame(width: 24, height: 24)

                            Image(systemName: mode.icon)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(hasActiveSelection ? .white : .primary)
                        }

                        Text(buttonLabel)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                    .padding(.leading, 12)
                    .padding(.vertical, 4)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isMainHovered = hovering
                }

                // Right: chevron dropdown toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDropdownExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isDropdownExpanded ? 90 : 0))
                        .frame(width: 28, height: 28)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
                .onHover { hovering in
                    isChevronHovered = hovering
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill((isMainHovered || isChevronHovered) ? .gray.opacity(0.1) : .clear)
                    .padding(.horizontal, 4)
            )

            // Dropdown options
            if isDropdownExpanded {
                VStack(spacing: 0) {
                    DeviceRow(
                        name: ContentSelectionMode.pickContent.label(language: language),
                        icon: ContentSelectionMode.pickContent.icon,
                        isSelected: mode == .pickContent
                    ) {
                        mode = .pickContent
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isDropdownExpanded = false
                        }
                    }

                    DeviceRow(
                        name: ContentSelectionMode.selectArea.label(language: language),
                        icon: ContentSelectionMode.selectArea.icon,
                        isSelected: mode == .selectArea
                    ) {
                        mode = .selectArea
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isDropdownExpanded = false
                        }
                    }
                }
                .padding(.leading, 12)
                .background(.quaternary.opacity(0.3))
            }
        }
    }

    private func triggerAction() {
        switch mode {
        case .pickContent:
            viewModel.presentPicker()
        case .selectArea:
            onDismissPanel?()
            Task {
                await viewModel.presentAreaSelection()
            }
        }
    }
}

// MARK: - Permission Status Banner

/// A banner showing missing permissions with buttons to open System Settings
struct PermissionStatusBanner: View {
    let permissionService: PermissionService
    let showMicrophonePermission: Bool
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(AppText.value("Permissions Required", "需要权限", language: language))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            if permissionService.screenRecordingState != .granted {
                PermissionRow(
                    title: AppText.value("Screen Recording", "屏幕录制", language: language),
                    isGranted: false,
                    language: language
                ) {
                    permissionService.openScreenRecordingSettings()
                }
            }

            if showMicrophonePermission && permissionService.microphoneState != .granted {
                PermissionRow(
                    title: AppText.value("Microphone", "麦克风", language: language),
                    isGranted: false,
                    language: language
                ) {
                    permissionService.openMicrophoneSettings()
                }
            }
        }
        .padding(.bottom, 8)
    }
}

/// A single permission row with status and action button
struct PermissionRow: View {
    let title: String
    let isGranted: Bool
    let language: AppLanguage
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(isGranted ? .green : .red)
                    .font(.system(size: 12))

                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)

                Spacer()

                if !isGranted {
                    Text(AppText.value("Open Settings", "打开设置", language: language))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? .gray.opacity(0.1) : .clear)
                .padding(.horizontal, 4)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Preview

#Preview {
    MenuBarView(viewModel: RecorderViewModel())
}
