//
//  SettingsView.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 29.01.26.
//

import AppKit
import KeyboardShortcuts
import SwiftUI

/// The settings window for BetterCapture
struct SettingsView: View {
    @Bindable var settings: SettingsStore
    var updaterService: UpdaterService
    private var language: AppLanguage { settings.appLanguage }

    var body: some View {
        TabView {
            Tab(AppText.value("General", "通用", language: language), systemImage: "gearshape") {
                GeneralSettingsView(settings: settings, updaterService: updaterService)
            }

            Tab(AppText.value("Video", "视频", language: language), systemImage: "video") {
                VideoSettingsView(settings: settings)
            }

            Tab(AppText.value("Audio", "音频", language: language), systemImage: "waveform") {
                AudioSettingsView(settings: settings)
            }

            Tab(AppText.value("Shortcuts", "快捷键", language: language), systemImage: "keyboard") {
                ShortcutsSettingsView(settings: settings)
            }
        }
        .frame(width: 500, height: 420)
    }
}

// MARK: - Shortcuts Settings

struct ShortcutsSettingsView: View {
    @Bindable var settings: SettingsStore
    private var language: AppLanguage { settings.appLanguage }

    var body: some View {
        Form {
            Section(AppText.value("Recording", "录制", language: language)) {
                KeyboardShortcuts.Recorder(
                    AppText.value("Toggle Recording", "切换录制", language: language),
                    name: .toggleRecording
                )
            }

            Section(AppText.value("Content Selection", "内容选择", language: language)) {
                KeyboardShortcuts.Recorder(AppText.value("Select Content", "选择内容", language: language), name: .selectContent)
                KeyboardShortcuts.Recorder(AppText.value("Select Area", "选择区域", language: language), name: .selectArea)
            }

            Section {
                Text(AppText.value(
                    "Shortcuts work globally, even when BetterCapture is not focused.",
                    "快捷键全局生效，即使 BetterCapture 当前未获得焦点。",
                    language: language
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Video Settings

struct VideoSettingsView: View {
    @Bindable var settings: SettingsStore
    private var language: AppLanguage { settings.appLanguage }

    private var alphaChannelHelpText: String {
        switch settings.videoCodec {
        case .proRes4444:
            return AppText.value("ProRes 4444 always includes alpha channel support", "ProRes 4444 始终支持 Alpha 通道", language: language)
        case .hevc:
            return AppText.value("Enable transparency support for HEVC", "为 HEVC 启用透明度支持", language: language)
        case .h264, .proRes422:
            return AppText.value("Alpha channel not supported by this codec", "此编码器不支持 Alpha 通道", language: language)
        }
    }

    private var hdrHelpText: String {
        if settings.videoCodec.supportsHDR {
            return AppText.value(
                "Enable 10-bit HDR capture for high dynamic range content",
                "为高动态范围内容启用 10-bit HDR 录制",
                language: language
            )
        } else {
            return AppText.value(
                "HDR is only supported with ProRes 422 and ProRes 4444 codecs",
                "HDR 仅支持 ProRes 422 和 ProRes 4444 编码器",
                language: language
            )
        }
    }

    private var qualityHelpText: String {
        if settings.videoCodec.supportsQualitySetting {
            return AppText.value(
                "Controls the video bitrate. Higher quality produces sharper output with larger files",
                "控制视频码率。质量越高，画面越清晰，文件也越大",
                language: language
            )
        } else {
            return AppText.value("ProRes codecs use fixed-quality encoding", "ProRes 编码器使用固定质量编码", language: language)
        }
    }

    private var captureNativeResHelpText: String {
        AppText.value(
            """
            When enabled, captures at the display's native pixel resolution. \
            When disabled, captures at the logical (1x) resolution. Has no effect on non-Retina displays
            """,
            """
            启用后按显示器原生像素分辨率录制。\
            关闭后按逻辑（1x）分辨率录制。对非 Retina 显示器无影响
            """,
            language: language
        )
    }

    var body: some View {
        Form {
            Section(AppText.value("Recording", "录制", language: language)) {
                Picker(AppText.value("Frame Rate", "帧率", language: language), selection: $settings.frameRate) {
                    ForEach(FrameRate.allCases) { rate in
                        Text(rate.displayName(language: language)).tag(rate)
                    }
                }

                Picker(AppText.value("Codec", "编码器", language: language), selection: $settings.videoCodec) {
                    ForEach(VideoCodec.allCases) { codec in
                        let isSupported = settings.containerFormat.supportedVideoCodecs.contains(codec)
                        if isSupported {
                            Text(codec.rawValue).tag(codec)
                        } else {
                            Text(AppText.value(
                                "\(codec.rawValue) (not supported for \(settings.containerFormat.rawValue.uppercased()))",
                                "\(codec.rawValue)（\(settings.containerFormat.rawValue.uppercased()) 不支持）",
                                language: language
                            ))
                                .foregroundStyle(.secondary)
                                .tag(codec)
                        }
                    }
                }

                Picker(AppText.value("Container", "封装格式", language: language), selection: $settings.containerFormat) {
                    ForEach(ContainerFormat.allCases) { format in
                        Text(".\(format.rawValue)").tag(format)
                    }
                }

                Picker(AppText.value("Quality", "质量", language: language), selection: $settings.videoQuality) {
                    ForEach(VideoQuality.allCases) { quality in
                        Text(quality.displayName(language: language)).tag(quality)
                    }
                }
                .disabled(!settings.videoCodec.supportsQualitySetting)
                .help(qualityHelpText)
            }

            Section(AppText.value("Advanced", "高级", language: language)) {
                Toggle(AppText.value("Capture Alpha Channel", "录制 Alpha 通道", language: language), isOn: $settings.captureAlphaChannel)
                    .disabled(!settings.videoCodec.canToggleAlpha || !settings.containerFormat.supportsAlphaChannel)
                    .help(alphaChannelHelpText)

                Toggle(AppText.value("HDR Recording", "HDR 录制", language: language), isOn: $settings.captureHDR)
                    .disabled(!settings.videoCodec.supportsHDR)
                    .help(hdrHelpText)

                Toggle(AppText.value("Native Resolution", "原生分辨率", language: language), isOn: $settings.captureNativeResolution)
                    .help(captureNativeResHelpText)
            }

            Section(AppText.value("Display Elements", "显示元素", language: language)) {
                Toggle(AppText.value("Show Cursor", "显示光标", language: language), isOn: $settings.showCursor)
                Toggle(AppText.value("Show Wallpaper", "显示壁纸", language: language), isOn: $settings.showWallpaper)
                Toggle(AppText.value("Show Menu Bar", "显示菜单栏", language: language), isOn: $settings.showMenuBar)
                Toggle(AppText.value("Show Dock", "显示 Dock", language: language), isOn: $settings.showDock)
                Toggle(AppText.value("Show BetterCapture", "显示 BetterCapture", language: language), isOn: $settings.showBetterCapture)
            }

            Section(AppText.value("Window Capture", "窗口录制", language: language)) {
                Toggle(AppText.value("Show Window Shadows", "显示窗口阴影", language: language), isOn: $settings.showWindowShadows)
                    .help(AppText.value(
                        "Include window shadows when capturing individual windows",
                        "录制单个窗口时包含窗口阴影",
                        language: language
                    ))
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Audio Settings

struct AudioSettingsView: View {
    @Bindable var settings: SettingsStore
    private var language: AppLanguage { settings.appLanguage }

    var body: some View {
        Form {
            Section(AppText.value("Sources", "来源", language: language)) {
                Toggle(AppText.value("Capture System Audio", "录制系统音频", language: language), isOn: $settings.captureSystemAudio)
                    .help(AppText.value("Record audio from applications and system sounds", "录制应用程序和系统声音", language: language))

                Toggle(AppText.value("Capture Microphone", "录制麦克风", language: language), isOn: $settings.captureMicrophone)
                    .help(AppText.value("Record audio from the default microphone input", "录制默认麦克风输入", language: language))
            }

            Section(AppText.value("Format", "格式", language: language)) {
                Picker(AppText.value("Codec", "编码器", language: language), selection: $settings.audioCodec) {
                    ForEach(AudioCodec.allCases) { codec in
                        let isSupported = settings.containerFormat.supportedAudioCodecs.contains(codec)
                        if isSupported {
                            Text(codec.rawValue).tag(codec)
                        } else {
                            Text(AppText.value(
                                "\(codec.rawValue) (not supported for \(settings.containerFormat.rawValue.uppercased()))",
                                "\(codec.rawValue)（\(settings.containerFormat.rawValue.uppercased()) 不支持）",
                                language: language
                            ))
                                .foregroundStyle(.secondary)
                                .tag(codec)
                        }
                    }
                }
                .help(AppText.value(
                    "AAC is compressed, PCM is uncompressed lossless (MOV only)",
                    "AAC 为压缩格式，PCM 为未压缩无损格式（仅 MOV）",
                    language: language
                ))
            }

            Section {
                Text(AppText.value(
                    "Audio tracks are recorded separately for post-processing flexibility.",
                    "音轨会被单独录制，便于后期处理。",
                    language: language
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @Bindable var settings: SettingsStore
    var updaterService: UpdaterService

    @State private var automaticallyChecksForUpdates: Bool
    private var language: AppLanguage { settings.appLanguage }

    init(settings: SettingsStore, updaterService: UpdaterService) {
        self.settings = settings
        self.updaterService = updaterService
        self._automaticallyChecksForUpdates = State(initialValue: updaterService.automaticallyChecksForUpdates)
    }

    /// Formats the output directory path for display
    private var displayPath: String {
        let path = settings.outputDirectory.path(percentEncoded: false)
        // Replace home directory with ~ for cleaner display
        let home = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    var body: some View {
        Form {
            Section(AppText.value("Language", "语言", language: language)) {
                Picker(AppText.value("Language", "语言", language: language), selection: $settings.appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
            }

            Section(AppText.value("Output Location", "输出位置", language: language)) {
                LabeledContent {
                    HStack {
                        Button(AppText.value("Change...", "更改...", language: language)) {
                            selectOutputDirectory()
                        }

                        if settings.hasCustomOutputDirectory {
                            Button(AppText.value("Reset", "重置", language: language), role: .destructive) {
                                settings.resetOutputDirectory()
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "folder")
                        Text(displayPath)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }

            Section(AppText.value("Software Updates", "软件更新", language: language)) {
                Toggle(AppText.value("Automatically check for updates", "自动检查更新", language: language), isOn: $automaticallyChecksForUpdates)
                    .onChange(of: automaticallyChecksForUpdates) { _, newValue in
                        updaterService.automaticallyChecksForUpdates = newValue
                    }

                LabeledContent(AppText.value("Updates", "更新", language: language)) {
                    Button(AppText.value("Check for Update", "检查更新", language: language)) {
                        updaterService.checkForUpdates()
                    }
                    .disabled(!updaterService.canCheckForUpdates)
                }
            }

            AboutSection(language: language)
        }
        .formStyle(.grouped)
        .padding()
    }

    /// Opens an NSOpenPanel to select a custom output directory
    private func selectOutputDirectory() {
        let panel = NSOpenPanel()
        panel.title = AppText.value("Select Output Directory", "选择输出目录", language: language)
        panel.message = AppText.value("Choose where recordings will be saved", "选择录制文件的保存位置", language: language)
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = settings.outputDirectory

        if panel.runModal() == .OK, let url = panel.url {
            settings.setCustomOutputDirectory(url)
        }
    }
}

// MARK: - About Section

struct AboutSection: View {
    let language: AppLanguage

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? AppText.value("Unknown", "未知", language: language)
    }

    private var gitSHA: String {
        Bundle.main.infoDictionary?["GitSHA"] as? String ?? "dev"
    }

    var body: some View {
        Section(AppText.value("About", "关于", language: language)) {
            LabeledContent(AppText.value("Version", "版本", language: language), value: "v\(appVersion) (\(gitSHA))")

            LabeledContent(AppText.value("Website", "网站", language: language)) {
                Link("jsattler.github.io/BetterCapture", destination: URL(string: "https://jsattler.github.io/BetterCapture")!)
            }

            LabeledContent(AppText.value("Source Code", "源代码", language: language)) {
                Link("github.com/jsattler/BetterCapture", destination: URL(string: "https://github.com/jsattler/BetterCapture")!)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView(settings: SettingsStore(), updaterService: UpdaterService())
}
