import SwiftUI
import UIKit

struct HandoffSharePayload: Identifiable {
    let id = UUID()
    let content: HandoffShareContent
}

struct HandoffShareContent {
    let url: URL
    let records: [PickupRecord]

    var activityItems: [Any] {
        [url]
    }

    func recordsToHandOff(completed: Bool, error: Error?) -> [PickupRecord] {
        guard completed, error == nil else {
            return []
        }
        return records
    }
}

struct HandoffActivityView: UIViewControllerRepresentable {
    let content: HandoffShareContent
    let completion: (Bool, Error?) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: content.activityItems,
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, completed, _, error in
            completion(completed, error)
        }
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}
