import SwiftUI

struct OnboardingStepView: View {
    let step: Int
    let onNext: () -> Void
    let onComplete: () -> Void

    @EnvironmentObject var permissions: PermissionsManager
    @StateObject private var downloader = ModelDownloader.shared
    @State private var abMode: Bool? = nil
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            switch step {
            case 0: welcomeStep
            case 1: microphoneStep
            case 2: accessibilityStep
            case 3: speechStep
            case 4: modelStep
            case 5: backendStep
            default: EmptyView()
            }

            Spacer()
        }
        .padding(32)
    }

    // MARK: Step views

    var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 56))
                .foregroundStyle(.blue)
            Text("Welcome to Murmur")
                .font(.title.bold())
            Text("A system-wide voice dictation tool for macOS.\nPress ⌥Space anywhere to start dictating.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            nextButton("Get Started")
        }
    }

    var microphoneStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.fill").font(.system(size: 48)).foregroundStyle(.red)
            Text("Microphone Access").font(.title2.bold())
            Text("Murmur needs microphone access to record your voice.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            if permissions.microphoneGranted {
                Label("Granted", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                nextButton("Continue")
            } else {
                Button("Grant Microphone Access") {
                    isProcessing = true
                    Task {
                        await permissions.requestMicrophone()
                        isProcessing = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)
            }
        }
    }

    var accessibilityStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "accessibility").font(.system(size: 48)).foregroundStyle(.purple)
            Text("Accessibility Access").font(.title2.bold())
            Text("Required to inject text into apps.\nYou'll be taken to System Settings.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            if permissions.accessibilityGranted {
                Label("Granted", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                nextButton("Continue")
            } else {
                Button("Open System Settings") {
                    permissions.openAccessibilitySettings()
                }
                .buttonStyle(.borderedProminent)
                Text("Waiting for access…").foregroundStyle(.secondary).font(.caption)
                    .onAppear { permissions.startPollingAccessibility() }
                    .onChange(of: permissions.accessibilityGranted) { _, granted in
                        if granted { onNext() }
                    }
            }
        }
    }

    var speechStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.bubble.fill").font(.system(size: 48)).foregroundStyle(.blue)
            Text("Speech Recognition").font(.title2.bold())
            Text("Required for Apple's on-device speech engine.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            if permissions.speechGranted {
                Label("Granted", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                nextButton("Continue")
            } else {
                Button("Grant Speech Recognition") {
                    isProcessing = true
                    Task {
                        await permissions.requestSpeech()
                        isProcessing = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)
            }
        }
    }

    var modelStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle.fill").font(.system(size: 48)).foregroundStyle(.green)
            Text("Whisper Model").font(.title2.bold())
            Text("Download the Whisper base.en-v2 model via WhisperKit (first use downloads automatically).")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)

            if downloader.isReady {
                Label("Model Ready", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                nextButton("Continue")
            } else if downloader.isDownloading {
                ProgressView(value: downloader.downloadProgress)
                    .frame(width: 200)
                Text("\(Int(downloader.downloadProgress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 12) {
                    Button("Download Model") {
                        Task { await downloader.downloadModel() }
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Skip (Apple-only mode)") { onNext() }
                        .buttonStyle(.bordered)
                }
                if let err = downloader.errorMessage {
                    Text(err).foregroundStyle(.red).font(.caption)
                }
            }
        }
        .onChange(of: downloader.isReady) { _, ready in
            if ready { /* auto-advance not needed, user clicks */ }
        }
    }

    var backendStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.fill").font(.system(size: 48)).foregroundStyle(.orange)
            Text("Choose Your Mode").font(.title2.bold())
            VStack(alignment: .leading, spacing: 12) {
                ModeCard(
                    icon: "shuffle",
                    title: "Blind A/B Test Mode",
                    subtitle: "Randomly compare backends and rate results to find what works best for your voice.",
                    selected: abMode == true
                ) { abMode = true }

                ModeCard(
                    icon: "star.fill",
                    title: "Single Backend",
                    subtitle: "Use one transcription engine (Apple, Whisper, or Hybrid).",
                    selected: abMode == false
                ) { abMode = false }
            }

            if abMode != nil {
                Button("Done") {
                    UserDefaults.standard.set(abMode!, forKey: "abTestMode")
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func nextButton(_ title: String) -> some View {
        Button(title, action: onNext).buttonStyle(.borderedProminent)
    }
}

struct ModeCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
