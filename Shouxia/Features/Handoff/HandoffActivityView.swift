import SwiftUI
import UIKit

struct HandoffSharePayload: Identifiable {
    let packageID: UUID
    let records: [PickupRecord]
    let url: URL

    var id: UUID { packageID }
}

struct HandoffActivityView: UIViewControllerRepresentable {
    let url: URL
    let completion: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, completed, _, _ in
            completion(completed)
        }
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}
