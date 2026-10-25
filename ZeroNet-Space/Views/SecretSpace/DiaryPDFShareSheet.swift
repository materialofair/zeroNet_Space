import SwiftUI
import UniformTypeIdentifiers

/// After the final gate, UIKit owns this immutable user-authorized snapshot.
/// Keeping its provider alive lets an already chosen activity finish after the vault locks.
/// No app-owned plaintext file is created, logged, or prematurely removed.
struct DiaryPDFShareSheet: UIViewControllerRepresentable {
    let item: DiaryPDFShareItem
    let isAllowed: () -> Bool
    let finished: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        guard isAllowed() else {
            DispatchQueue.main.async { finished() }
            return UIViewController()
        }
        let provider = Self.provider(for: item)
        let configuration = UIActivityItemsConfiguration(itemProviders: [provider])
        let controller = UIActivityViewController(activityItemsConfiguration: configuration)
        controller.completionWithItemsHandler = { _, _, _, _ in
            Task { @MainActor in finished() }
        }
        return controller
    }
    func updateUIViewController(_ controller: UIViewController, context: Context) {}

    static func provider(for item: DiaryPDFShareItem) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.suggestedName = item.fileName
        let data = item.data
        provider.registerDataRepresentation(forTypeIdentifier: UTType.pdf.identifier, visibility: .all) { completion in
            completion(data, nil)
            return nil
        }
        return provider
    }
}

struct DiaryPDFVIPView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authentication: AuthenticationViewModel
    @EnvironmentObject private var guest: GuestModeManager
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var purchases = PurchaseManager.shared
    private var authorized: Bool { authentication.isAuthenticated && guest.isOwnerMode }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "crown.fill").font(.largeTitle).foregroundStyle(.orange)
                Text(String(localized: "diary.pdf.vip.title")).font(.title2.bold())
                Text(String(localized: "diary.pdf.vip.message")).multilineTextAlignment(.center)
                Button {
                    guard authorized else { return }
                    Task { _ = await purchases.purchase() }
                } label: {
                    Text(String(localized: "iap.unlockUnlimited.title") + " · " + purchases.getPriceString())
                }.buttonStyle(.borderedProminent).accessibilityIdentifier("diary.pdf.purchase")
                Button(String(localized: "iap.restorePurchases")) {
                    guard authorized else { return }
                    Task { await purchases.restorePurchases() }
                }.accessibilityIdentifier("diary.pdf.restore")
                if purchases.isLoading { ProgressView() }
                if let error = purchases.purchaseError { Text(error).font(.footnote).foregroundStyle(.red) }
            }.padding(24).frame(maxWidth: 500).disabled(purchases.isLoading || !authorized)
                .navigationTitle(String(localized: "diary.pdf.export"))
                .toolbar { ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done")) { dismiss() }.accessibilityIdentifier("diary.pdf.vipDone")
                } }
        }
        .task { if authorized { await purchases.loadProducts() } }
        .onChange(of: settings.hasUnlockedUnlimited) { _, value in if value { dismiss() } }
        .onReceive(NotificationCenter.default.publisher(for: .vaultWillLock)) { _ in dismiss() }
        .onChange(of: guest.currentMode) { _, mode in if mode != .owner { dismiss() } }
    }
}
