import SwiftUI

struct SettingsView: View {
    @State private var apiKeyInput: String = ""
    @State private var hasStoredKey: Bool = KeychainService.loadAPIKey() != nil
    @State private var isTesting: Bool = false
    @State private var testResult: TestResult?
    @State private var showRemoveConfirm: Bool = false

    enum TestResult {
        case success
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if hasStoredKey {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                            Text("API key saved in Keychain")
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("No API key set")
                        }
                    }

                    SecureField("sk-ant-…", text: $apiKeyInput)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button("Save Key") { saveKey() }
                        .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)

                    if hasStoredKey {
                        Button("Remove Key", role: .destructive) {
                            showRemoveConfirm = true
                        }
                    }
                } header: {
                    Text("Anthropic API Key")
                } footer: {
                    Text("Required for Phase 2 AI features. Stored in the iOS Keychain, never leaves this device except to call api.anthropic.com.")
                }

                Section {
                    Button {
                        Task { await runTest() }
                    } label: {
                        HStack {
                            Text("Test Connection")
                            Spacer()
                            if isTesting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(!hasStoredKey || isTesting)

                    if let testResult {
                        switch testResult {
                        case .success:
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case .failure(let message):
                            Label(message, systemImage: "xmark.octagon.fill")
                                .foregroundStyle(.red)
                        }
                    }
                } header: {
                    Text("Diagnostics")
                } footer: {
                    Text("Sends a tiny ping to Anthropic using the saved key and model \(AIService.defaultModel).")
                }
            }
            .navigationTitle("Settings")
            .alert("Remove API key?", isPresented: $showRemoveConfirm) {
                Button("Remove", role: .destructive) { removeKey() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("AI features will stop working until a new key is saved.")
            }
        }
    }

    private func saveKey() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        do {
            try KeychainService.saveAPIKey(trimmed)
            hasStoredKey = true
            apiKeyInput = ""
            testResult = nil
        } catch {
            testResult = .failure("Keychain save failed: \(error.localizedDescription)")
        }
    }

    private func removeKey() {
        KeychainService.deleteAPIKey()
        hasStoredKey = false
        testResult = nil
    }

    private func runTest() async {
        isTesting = true
        testResult = nil
        defer { isTesting = false }
        do {
            try await AIService().testConnection()
            testResult = .success
        } catch {
            testResult = .failure(error.localizedDescription)
        }
    }
}

#Preview {
    SettingsView()
}
