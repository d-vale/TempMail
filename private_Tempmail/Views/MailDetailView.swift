import SwiftUI

/// Détail d'un mail : rendu HTML (WKWebView) si disponible, sinon texte brut.
struct MailDetailView: View {
    @Environment(AppModel.self) private var model
    let summary: MailSummary

    @State private var content: MailContent?
    @State private var loadError: String?
    @State private var allowRemote = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            body_
        }
        .navigationTitle(summary.subject)
        .task(id: summary.uid) {
            content = nil
            loadError = nil
            do {
                content = try await model.fetchContent(of: summary)
            } catch {
                loadError = error.localizedDescription
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(summary.subject)
                .font(.headline)
                .lineLimit(2)
            Text("De : \(summary.from)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack {
                if let recipient = summary.recipient {
                    Text("À : \(recipient)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(summary.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let content {
                HStack {
                    if content.attachmentCount > 0 {
                        Label("\(content.attachmentCount) pièce(s) jointe(s) (ignorées)", systemImage: "paperclip")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    if content.html != nil && !allowRemote {
                        Button("Charger les images distantes") {
                            allowRemote = true
                        }
                        .font(.caption)
                        .buttonStyle(.link)
                    }
                }
            }
        }
        .padding(10)
    }

    @ViewBuilder
    private var body_: some View {
        if let content {
            if let html = content.html {
                HTMLView(html: html, allowRemote: allowRemote)
            } else if let text = content.text {
                ScrollView {
                    Text(text)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
            } else {
                Text("(message vide)")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else if let loadError {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text(loadError)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
