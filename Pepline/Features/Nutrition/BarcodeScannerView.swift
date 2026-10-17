import SwiftUI
import VisionKit

/// Live barcode scanner (VisionKit). Calls `onCode` once with the first
/// EAN/UPC it recognises.
struct BarcodeScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    @MainActor static var isAvailable: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128])],
            qualityLevel: .balanced,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        private var done = false

        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !done else { return }
            for case let .barcode(code) in addedItems {
                guard let value = code.payloadStringValue, !value.isEmpty else { continue }
                done = true
                dataScanner.stopScanning()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onCode(value)
                return
            }
        }
    }
}
