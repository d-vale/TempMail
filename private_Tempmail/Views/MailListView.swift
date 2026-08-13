import SwiftUI

/// Mails reçus pour une adresse (ou pour le groupe « Autres »), du plus récent au plus ancien.
struct MailListView: View {
    @Environment(AppModel.self) private var model
    let address: String

    private var isOthers: Bool { address == RootView.othersKey }

    private var mails: [MailSummary] {
        isOthers ? model.otherMails : model.mails(for: address)
    }

    var body: some View {
        Group {
            if mails.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Aucun mail pour l'instant")
                        .foregroundStyle(.secondary)
                    Text("Vérification toutes les 30 secondes")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(mails) { mail in
                    NavigationLink(value: mail) {
                        row(mail)
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(isOthers ? "Autres destinataires" : address)
        .toolbar {
            if !isOthers {
                Button {
                    model.copyToClipboard(address)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .help("Copier l'adresse")
            }
        }
        .onAppear {
            if !isOthers { model.markRead(address) }
        }
    }

    private func row(_ mail: MailSummary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(mail.from)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Spacer()
                Text(mail.date.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(mail.subject)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if isOthers, let recipient = mail.recipient {
                Text("→ \(recipient)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
