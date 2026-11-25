import AVFoundation
import SwiftUI
import VisionKit

struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss

    let onScanned: (_ keyword: String, _ isBookTitle: Bool) -> Void

    @State private var authorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var isProcessingCode = false
    @State private var detectedCodePreview: String?
    @State private var scannerErrorMessage: String?

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            scannerContent

            headerOverlay

            if isProcessingCode {
                processingOverlay
            } else {
                scanGuideOverlay
            }
        }
        .task {
            await requestCameraAccessIfNeeded()
        }
    }

    @ViewBuilder
    private var scannerContent: some View {
        switch authorizationStatus {
        case .authorized:
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                VisionKitScannerRepresentable(
                    onCodeDetected: handleDetectedCode,
                    onError: { message in
                        scannerErrorMessage = message
                    }
                )
                .ignoresSafeArea()
            } else {
                AVCaptureScannerRepresentable(
                    onCodeDetected: handleDetectedCode,
                    onError: { message in
                        scannerErrorMessage = message
                    }
                )
                .ignoresSafeArea()
            }
        case .notDetermined:
            ProgressView("カメラを準備中...")
                .tint(.white)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .denied, .restricted:
            permissionDeniedView
        @unknown default:
            permissionDeniedView
        }
    }

    private var headerOverlay: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("バーコードスキャン")
                    .font(.headline)
                Text("JAN / ISBN（EAN-13・EAN-8）に対応")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("閉じる")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var scanGuideOverlay: some View {
        VStack {
            Spacer()

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.75), lineWidth: 1.5)
                .frame(width: 260, height: 140)
                .background(Color.clear)

            Spacer()

            VStack(spacing: 6) {
                if let scannerErrorMessage {
                    Text(scannerErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                } else {
                    Text("商品のバーコードを枠内に合わせてください")
                        .font(.subheadline.weight(.medium))
                    Text("978 / 979始まりの書籍は書名を自動取得します")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, 28)
        }
        .allowsHitTesting(false)
    }

    private var processingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text(detectedCodePreview.map { "書籍情報を照会中...\n\($0)" } ?? "読み取り中...")
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("カメラへのアクセスが必要です")
                .font(.headline)
                .foregroundStyle(.white)

            Text("設定アプリからカメラのアクセスを許可すると、JANコードや書籍ISBNを読み取って検索できます。")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                Button("設定を開く") {
                    UIApplication.shared.open(settingsURL)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func requestCameraAccessIfNeeded() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            authorizationStatus = granted ? .authorized : .denied
        } else {
            authorizationStatus = status
        }
    }

    private func handleDetectedCode(_ rawCode: String) {
        let cleaned = rawCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, !isProcessingCode else { return }

        isProcessingCode = true
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)

        if cleaned.hasPrefix("978") || cleaned.hasPrefix("979") {
            detectedCodePreview = cleaned
            Task {
                let title = await OpenBDClient.fetchBookTitle(isbn: cleaned)
                await MainActor.run {
                    if let title, !title.isEmpty {
                        onScanned(title, true)
                    } else {
                        onScanned(cleaned, false)
                    }
                    dismiss()
                }
            }
        } else {
            onScanned(cleaned, false)
            dismiss()
        }
    }
}

private enum BarcodeFilter {
    /// 日本の書籍の裏表紙にある2段目のバーコード（書籍JANコード2段目：分類・価格。191/192 始まり）か。
    /// 商品のコードではないので読み取っても無視し、1段目の ISBN（978/979）を読ませる。
    static func isBookPriceCode(_ code: String) -> Bool {
        code.count == 13 && (code.hasPrefix("191") || code.hasPrefix("192"))
    }
}

private enum OpenBDClient {
    private struct BookEntry: Decodable {
        struct Summary: Decodable {
            let title: String?
        }
        let summary: Summary?
    }

    static func fetchBookTitle(isbn: String) async -> String? {
        guard let encoded = isbn.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.openbd.jp/v1/get?isbn=\(encoded)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 6.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }
            let entries = try JSONDecoder().decode([BookEntry?].self, from: data)
            let rawTitle = entries.first??.summary?.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (rawTitle?.isEmpty == false) ? rawTitle : nil
        } catch {
            return nil
        }
    }
}

private struct VisionKitScannerRepresentable: UIViewControllerRepresentable {
    let onCodeDetected: (String) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeDetected: onCodeDetected, onError: onError)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        do {
            try controller.startScanning()
        } catch {
            // 画面の更新中に @State を変えないよう、次のタイミングで知らせる
            DispatchQueue.main.async {
                onError("バーコードスキャナの起動に失敗しました")
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onCodeDetected: (String) -> Void
        private let onError: (String) -> Void
        private var didEmit = false

        init(onCodeDetected: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
            self.onCodeDetected = onCodeDetected
            self.onError = onError
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            emitFirstBarcode(from: addedItems, scanner: dataScanner)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            emitFirstBarcode(from: [item], scanner: dataScanner)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            onError("スキャナを利用できませんでした")
        }

        private func emitFirstBarcode(from items: [RecognizedItem], scanner: DataScannerViewController) {
            guard !didEmit else { return }
            for item in items {
                if case let .barcode(barcode) = item,
                   let payload = barcode.payloadStringValue,
                   !payload.isEmpty,
                   !BarcodeFilter.isBookPriceCode(payload) {
                    didEmit = true
                    scanner.stopScanning()
                    onCodeDetected(payload)
                    return
                }
            }
        }
    }
}

private struct AVCaptureScannerRepresentable: UIViewControllerRepresentable {
    let onCodeDetected: (String) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeDetected: onCodeDetected, onError: onError)
    }

    func makeUIViewController(context: Context) -> ScannerFallbackViewController {
        let controller = ScannerFallbackViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerFallbackViewController, context: Context) {}

    final class Coordinator: NSObject, ScannerFallbackViewControllerDelegate {
        private let onCodeDetected: (String) -> Void
        private let onError: (String) -> Void

        init(onCodeDetected: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
            self.onCodeDetected = onCodeDetected
            self.onError = onError
        }

        func scannerDidDetectCode(_ code: String) {
            onCodeDetected(code)
        }

        func scannerDidFail(_ message: String) {
            // カメラの準備は画面の作成中（viewDidLoad）に行われるため、@State の変更は次のタイミングにする
            DispatchQueue.main.async { [onError] in
                onError(message)
            }
        }
    }
}

private protocol ScannerFallbackViewControllerDelegate: AnyObject {
    func scannerDidDetectCode(_ code: String)
    func scannerDidFail(_ message: String)
}

private final class ScannerFallbackViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: ScannerFallbackViewControllerDelegate?

    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.example.FurimaKakakuCheck.scanner")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didEmit = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureCaptureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sessionQueue.async { [weak self] in
            guard let self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [weak self] in
            guard let self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
        }
    }

    private func configureCaptureSession() {
        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            delegate?.scannerDidFail("カメラデバイスが見つかりません")
            return
        }

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            guard captureSession.canAddInput(videoInput) else {
                delegate?.scannerDidFail("カメラ入力を設定できませんでした")
                return
            }
            captureSession.addInput(videoInput)

            let metadataOutput = AVCaptureMetadataOutput()
            guard captureSession.canAddOutput(metadataOutput) else {
                delegate?.scannerDidFail("バーコード出力を設定できませんでした")
                return
            }
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            metadataOutput.metadataObjectTypes = [.ean13, .ean8]

            let layer = AVCaptureVideoPreviewLayer(session: captureSession)
            layer.videoGravity = .resizeAspectFill
            layer.frame = view.bounds
            view.layer.addSublayer(layer)
            previewLayer = layer
        } catch {
            delegate?.scannerDidFail("カメラの初期化に失敗しました")
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didEmit,
              let value = metadataObjects
                .compactMap({ ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue })
                .first(where: { !$0.isEmpty && !BarcodeFilter.isBookPriceCode($0) }) else {
            return
        }
        didEmit = true
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
        delegate?.scannerDidDetectCode(value)
    }
}
