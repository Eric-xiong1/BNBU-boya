import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation
import UIKit

struct GridBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 42
            let color = BNBUTheme.blue.opacity(0.10)
            var path = Path()

            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }

            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }

            context.stroke(path, with: .color(color), lineWidth: 1)
        }
        .background(BNBUTheme.paper)
        .ignoresSafeArea()
    }
}

struct BrandMark: View {
    var compact = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(BNBUTheme.surface)
                .overlay(Rectangle().stroke(BNBUTheme.line, lineWidth: 2))

            VStack(spacing: compact ? 3 : 6) {
                HStack(spacing: 4) {
                    Rectangle().fill(BNBUTheme.ink).frame(width: compact ? 7 : 10)
                    Rectangle().fill(BNBUTheme.blueLight).frame(width: compact ? 7 : 10)
                    Rectangle().fill(BNBUTheme.ink).frame(width: compact ? 7 : 10)
                }
                .frame(height: compact ? 20 : 28)

                Text("BNBU")
                    .font(.system(size: compact ? 9 : 12, weight: .black, design: .monospaced))
                    .foregroundStyle(BNBUTheme.ink)
            }
        }
        .frame(width: compact ? 44 : 64, height: compact ? 44 : 64)
        .accessibilityLabel("BNBU")
    }
}

struct SwissPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(BNBUTheme.surface)
            .overlay(Rectangle().stroke(BNBUTheme.line, lineWidth: 1.5))
    }
}

struct SectionTitle: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow.uppercased())
                .font(.caption2.weight(.black))
                .foregroundStyle(BNBUTheme.muted)
            Text(title)
                .font(.title2.weight(.black))
                .foregroundStyle(BNBUTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatusBadge: View {
    let text: String
    var filled = false

    var body: some View {
        Text(text)
            .font(.caption.weight(.black))
            .foregroundStyle(filled ? BNBUTheme.surface : BNBUTheme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(filled ? BNBUTheme.ink : BNBUTheme.blueSoft)
            .overlay(Rectangle().stroke(BNBUTheme.line, lineWidth: 1))
    }
}

struct HourProgressBar: View {
    let value: Double
    let total: Double

    var ratio: Double {
        guard total > 0 else { return 0 }
        return min(max(value / total, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(BNBUTheme.surface)
                Rectangle()
                    .fill(BNBUTheme.blue)
                    .frame(width: proxy.size.width * ratio)
                Rectangle().stroke(BNBUTheme.line, lineWidth: 1.5)
            }
        }
        .frame(height: 12)
    }
}

struct MetricCell: View {
    let label: String
    let value: String
    let footnote: String

    var body: some View {
        SwissPanel {
            VStack(alignment: .leading, spacing: 10) {
                Text(label.uppercased())
                    .font(.caption2.weight(.black))
                    .foregroundStyle(BNBUTheme.muted)
                Text(value)
                    .font(.system(size: 34, weight: .black, design: .default))
                    .foregroundStyle(BNBUTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text(footnote)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BNBUTheme.muted)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct PrimaryActionButton: View {
    let title: String
    let systemImage: String
    var accessibilityIdentifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.black))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(BNBUTheme.surface)
                .background(BNBUTheme.ink)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? title)
    }
}

struct DisabledAwareButton: View {
    let title: String
    let systemImage: String
    let isDisabled: Bool
    var accessibilityIdentifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.black))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(isDisabled ? BNBUTheme.muted : BNBUTheme.surface)
                .background(isDisabled ? BNBUTheme.blueSoft : BNBUTheme.ink)
                .overlay(Rectangle().stroke(BNBUTheme.line, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityIdentifier(accessibilityIdentifier ?? title)
    }
}

struct EmptyPlaceholder: View {
    let title: String
    let message: String

    var body: some View {
        SwissPanel {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline.weight(.black))
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BNBUTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ProofAttachmentPanel: View {
    @Environment(\.openURL) private var openURL
    @Binding var attachments: [ProofAttachment]
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var cameraPermission = CameraPermissionState.current
    @State private var activeCameraAlert: CameraAlert?
    @State private var isCameraPresented = false
    @State private var attachmentNotice: String?
    @State private var pendingDeletion: ProofAttachment?
    @State private var isDeletionConfirmationPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("图片 / 视频凭证")
                        .font(.headline.weight(.black))
                    Text("相册仅读取你选中的文件；拍摄会请求摄像头权限。")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BNBUTheme.muted)
                    Text(ProofUploadRule.summaryText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BNBUTheme.muted)
                }
                Spacer()
                Image(systemName: "photo.badge.plus")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(BNBUTheme.blue)
            }

            HStack(spacing: 10) {
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: max(remainingSlots, 1),
                    matching: .any(of: [.images, .videos])
                ) {
                    Label("从相册选择", systemImage: "photo.on.rectangle")
                        .font(.subheadline.weight(.black))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(isAtLimit ? BNBUTheme.muted : BNBUTheme.surface)
                        .background(isAtLimit ? BNBUTheme.surface : BNBUTheme.ink)
                        .overlay(Rectangle().stroke(BNBUTheme.line, lineWidth: isAtLimit ? 1.5 : 0))
                }
                .buttonStyle(.plain)
                .disabled(isAtLimit)

                Button {
                    handleCameraAction()
                } label: {
                    Label("拍摄", systemImage: "camera.fill")
                        .font(.subheadline.weight(.black))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(isAtLimit ? BNBUTheme.muted : BNBUTheme.ink)
                        .background(BNBUTheme.surface)
                        .overlay(Rectangle().stroke(BNBUTheme.line, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .disabled(isAtLimit)
            }

            #if DEBUG
            Button {
                addDemoAttachment()
            } label: {
                Label("添加演示凭证", systemImage: "doc.badge.plus")
                    .font(.caption.weight(.black))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(isAtLimit ? BNBUTheme.muted : BNBUTheme.ink)
                    .background(BNBUTheme.surface)
                    .overlay(Rectangle().stroke(BNBUTheme.line, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .disabled(isAtLimit)
            .accessibilityIdentifier("proof.demo.add")
            #endif

            VStack(spacing: 8) {
                PermissionStatusLine(
                    title: "相册访问",
                    value: "仅所选文件",
                    systemImage: "photo.on.rectangle"
                )
                PermissionStatusLine(
                    title: "摄像头",
                    value: cameraPermission.title,
                    systemImage: cameraPermission.symbolName,
                    filled: cameraPermission == .authorized
                )
            }

            HStack(spacing: 8) {
                StatusBadge(text: "\(imageCount) 张图片")
                StatusBadge(text: "\(videoCount) 个视频")
                StatusBadge(text: "剩余 \(remainingSlots)")
                Spacer()
            }

            if let attachmentNotice {
                Text(attachmentNotice)
                    .font(.caption.weight(.black))
                    .foregroundStyle(BNBUTheme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(BNBUTheme.surface)
                    .overlay(Rectangle().stroke(BNBUTheme.line, lineWidth: 1))
            }

            if attachments.isEmpty {
                Text("尚未添加凭证")
                    .font(.caption.weight(.black))
                    .foregroundStyle(BNBUTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(attachments) { attachment in
                        ProofAttachmentPreviewCard(attachment: attachment) {
                            pendingDeletion = attachment
                            isDeletionConfirmationPresented = true
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(BNBUTheme.blueSoft)
        .overlay(
            Rectangle()
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .foregroundStyle(BNBUTheme.line)
        )
        .onChange(of: selectedItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                await importSelectedItems(newItems)
            }
        }
        .onAppear {
            cameraPermission = CameraPermissionState.current
        }
        .sheet(isPresented: $isCameraPresented) {
            CameraCapturePicker { attachment in
                appendAttachment(attachment)
                cameraPermission = CameraPermissionState.current
            }
        }
        .confirmationDialog(
            "删除凭证",
            isPresented: $isDeletionConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                deletePendingAttachment()
            }
            Button("取消", role: .cancel) {
                pendingDeletion = nil
            }
        } message: {
            Text(pendingDeletion.map { "确认删除 \($0.fileName)？删除后提交前需要重新补充凭证。" } ?? "确认删除这个凭证？")
        }
        .alert(item: $activeCameraAlert) { alert in
            switch alert {
            case .unavailable:
                return Alert(
                    title: Text("当前设备无法拍摄"),
                    message: Text("模拟器或当前设备没有可用摄像头，可先添加占位凭证完成评审流程。"),
                    primaryButton: .default(Text("添加占位凭证")) {
                        addCameraPlaceholder()
                    },
                    secondaryButton: .cancel(Text("取消"))
                )
            case .denied:
                return Alert(
                    title: Text("摄像头权限未开启"),
                    message: Text("需要允许 BNBU Student 使用摄像头，才能直接拍摄打卡凭证。"),
                    primaryButton: .default(Text("去设置")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    },
                    secondaryButton: .cancel(Text("取消"))
                )
            case .restricted:
                return Alert(
                    title: Text("摄像头受系统限制"),
                    message: Text("当前设备策略不允许使用摄像头，请联系设备管理员或改用相册选择。"),
                    dismissButton: .default(Text("好"))
                )
            }
        }
    }

    private var imageCount: Int {
        attachments.filter { $0.type == .image }.count
    }

    private var videoCount: Int {
        attachments.filter { $0.type == .video }.count
    }

    private var remainingSlots: Int {
        max(ProofUploadRule.maxAttachmentCount - attachments.count, 0)
    }

    private var isAtLimit: Bool {
        remainingSlots == 0
    }

    private func addCameraPlaceholder() {
        guard !isAtLimit else {
            attachmentNotice = "已达到 \(ProofUploadRule.maxAttachmentCount) 个凭证上限。"
            return
        }
        attachments.append(
            ProofAttachment(
                id: UUID().uuidString,
                type: .image,
                fileName: "camera-proof-\(attachments.count + 1).jpg",
                byteCount: nil,
                thumbnailData: ProofThumbnailRenderer.demoThumbnailData(type: .image, index: attachments.count + 1),
                source: "拍摄占位"
            )
        )
        attachmentNotice = "已添加 1 个拍摄占位凭证。"
    }

    private func addDemoAttachment() {
        guard !isAtLimit else {
            attachmentNotice = "已达到 \(ProofUploadRule.maxAttachmentCount) 个凭证上限。"
            return
        }
        let nextIndex = attachments.count + 1
        let type: ProofMediaType = nextIndex.isMultiple(of: 3) ? .video : .image
        appendAttachment(
            ProofAttachment(
                id: UUID().uuidString,
                type: type,
                fileName: type == .video ? "demo-running-proof-\(nextIndex).mov" : "demo-running-proof-\(nextIndex).jpg",
                byteCount: type == .video ? 12_400_000 : 1_280_000,
                durationSeconds: type == .video ? 18 : nil,
                thumbnailData: ProofThumbnailRenderer.demoThumbnailData(type: type, index: nextIndex),
                source: "演示"
            )
        )
    }

    private func handleCameraAction() {
        guard !isAtLimit else {
            attachmentNotice = "已达到 \(ProofUploadRule.maxAttachmentCount) 个凭证上限。"
            return
        }

        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            cameraPermission = .unavailable
            activeCameraAlert = .unavailable
            return
        }

        cameraPermission = CameraPermissionState.current
        switch cameraPermission {
        case .authorized:
            isCameraPresented = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    cameraPermission = granted ? .authorized : .denied
                    if granted {
                        isCameraPresented = true
                    } else {
                        activeCameraAlert = .denied
                    }
                }
            }
        case .denied:
            activeCameraAlert = .denied
        case .restricted:
            activeCameraAlert = .restricted
        case .unavailable:
            activeCameraAlert = .unavailable
        }
    }

    @MainActor
    private func importSelectedItems(_ items: [PhotosPickerItem]) async {
        guard !isAtLimit else {
            selectedItems = []
            attachmentNotice = "已达到 \(ProofUploadRule.maxAttachmentCount) 个凭证上限。"
            return
        }

        var importedCount = 0
        var oversizedCount = 0
        let importableItems = Array(items.prefix(remainingSlots))
        let skippedCount = max(items.count - importableItems.count, 0)

        for item in importableItems {
            let type: ProofMediaType = item.supportedContentTypes.contains {
                $0.conforms(to: .movie) || $0.conforms(to: .video)
            } ? .video : .image
            let data = try? await item.loadTransferable(type: Data.self)
            let byteCount = data?.count
            let fileExtension = type == .video ? "mov" : "jpg"
            let prefix = type == .video ? "video" : "image"
            let mediaMetadata = await makeMediaMetadata(type: type, data: data, fileExtension: fileExtension, byteCount: byteCount)
            let attachment = ProofAttachment(
                id: UUID().uuidString,
                type: type,
                fileName: "\(prefix)-\(String(UUID().uuidString.prefix(6))).\(fileExtension)",
                byteCount: byteCount,
                durationSeconds: mediaMetadata.durationSeconds,
                thumbnailData: mediaMetadata.thumbnailData,
                source: "相册"
            )
            attachments.append(attachment)
            importedCount += 1
            if !attachment.isValidForUpload {
                oversizedCount += 1
            }
        }

        var noticeParts: [String] = []
        if importedCount > 0 {
            noticeParts.append("已添加 \(importedCount) 个凭证")
        }
        if skippedCount > 0 {
            noticeParts.append("已忽略 \(skippedCount) 个超出数量上限的文件")
        }
        if oversizedCount > 0 {
            noticeParts.append("\(oversizedCount) 个文件超出大小限制，提交前请删除或替换")
        }
        attachmentNotice = noticeParts.isEmpty ? nil : noticeParts.joined(separator: "；")
        selectedItems = []
    }

    private func appendAttachment(_ attachment: ProofAttachment) {
        guard !isAtLimit else {
            attachmentNotice = "已达到 \(ProofUploadRule.maxAttachmentCount) 个凭证上限。"
            return
        }
        attachments.append(attachment)
        attachmentNotice = attachment.isValidForUpload ? "已添加 1 个\(attachment.type.rawValue)凭证。" : "\(attachment.fileName) 超出大小限制，提交前请删除或替换。"
    }

    private func deletePendingAttachment() {
        guard let pendingDeletion else { return }
        attachments.removeAll { $0.id == pendingDeletion.id }
        attachmentNotice = "已删除 \(pendingDeletion.fileName)。"
        self.pendingDeletion = nil
    }

    private func makeMediaMetadata(
        type: ProofMediaType,
        data: Data?,
        fileExtension: String,
        byteCount: Int?
    ) async -> ProofMediaMetadata {
        guard let data else { return .empty }

        switch type {
        case .image:
            guard (byteCount ?? 0) <= ProofUploadRule.maxImageBytes else {
                return .empty
            }
            return ProofMediaMetadata(
                durationSeconds: nil,
                thumbnailData: ProofThumbnailRenderer.imageThumbnailData(from: data)
            )
        case .video:
            guard (byteCount ?? 0) <= ProofUploadRule.maxVideoBytes else {
                return .empty
            }
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("bnbu-proof-\(UUID().uuidString).\(fileExtension)")
            do {
                try data.write(to: tempURL, options: .atomic)
                defer { try? FileManager.default.removeItem(at: tempURL) }
                return ProofMediaMetadata(
                    durationSeconds: await ProofThumbnailRenderer.videoDurationSeconds(from: tempURL),
                    thumbnailData: ProofThumbnailRenderer.videoThumbnailData(from: tempURL)
                )
            } catch {
                return .empty
            }
        }
    }
}

private struct ProofMediaMetadata {
    let durationSeconds: Double?
    let thumbnailData: Data?

    static let empty = ProofMediaMetadata(durationSeconds: nil, thumbnailData: nil)
}

private enum ProofThumbnailRenderer {
    private static let maxPixel: CGFloat = 420

    static func imageThumbnailData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return imageThumbnailData(from: image)
    }

    static func imageThumbnailData(from image: UIImage) -> Data? {
        let size = fittedSize(for: image.size)
        let renderer = UIGraphicsImageRenderer(size: size)
        let thumbnail = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return thumbnail.jpegData(compressionQuality: 0.72)
    }

    static func videoThumbnailData(from url: URL) -> Data? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixel, height: maxPixel)
        guard let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) else {
            return nil
        }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.72)
    }

    static func videoDurationSeconds(from url: URL) async -> Double? {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return nil }
        let seconds = CMTimeGetSeconds(duration)
        return seconds.isFinite ? seconds : nil
    }

    static func demoThumbnailData(type: ProofMediaType, index: Int) -> Data? {
        let size = CGSize(width: maxPixel, height: maxPixel * 0.78)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            UIColor(red: 126 / 255, green: 190 / 255, blue: 251 / 255, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.32))

            UIColor(red: 11 / 255, green: 11 / 255, blue: 12 / 255, alpha: 1).setFill()
            context.fill(CGRect(x: 28, y: size.height - 58, width: size.width - 56, height: 8))
            context.fill(CGRect(x: 28, y: size.height - 36, width: size.width * 0.55, height: 8))

            let symbol = type == .video ? "VIDEO \(index)" : "PHOTO \(index)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 36, weight: .black),
                .foregroundColor: UIColor(red: 11 / 255, green: 11 / 255, blue: 12 / 255, alpha: 1)
            ]
            symbol.draw(at: CGPoint(x: 28, y: 52), withAttributes: attributes)
        }
        return image.jpegData(compressionQuality: 0.72)
    }

    private static func fittedSize(for originalSize: CGSize) -> CGSize {
        guard originalSize.width > 0, originalSize.height > 0 else {
            return CGSize(width: maxPixel, height: maxPixel)
        }
        let ratio = min(maxPixel / originalSize.width, maxPixel / originalSize.height, 1)
        return CGSize(width: originalSize.width * ratio, height: originalSize.height * ratio)
    }
}

private enum CameraPermissionState: Equatable {
    case unavailable
    case notDetermined
    case authorized
    case denied
    case restricted

    static var current: CameraPermissionState {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            return .unavailable
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .restricted
        }
    }

    var title: String {
        switch self {
        case .unavailable:
            return "设备不可用"
        case .notDetermined:
            return "待授权"
        case .authorized:
            return "已允许"
        case .denied:
            return "已拒绝"
        case .restricted:
            return "系统限制"
        }
    }

    var symbolName: String {
        switch self {
        case .authorized:
            return "camera.fill"
        case .notDetermined:
            return "camera.badge.clock"
        case .denied:
            return "camera.badge.ellipsis"
        case .restricted:
            return "lock.fill"
        case .unavailable:
            return "camera.slash"
        }
    }
}

private enum CameraAlert: Identifiable {
    case unavailable
    case denied
    case restricted

    var id: String {
        switch self {
        case .unavailable:
            return "unavailable"
        case .denied:
            return "denied"
        case .restricted:
            return "restricted"
        }
    }
}

private struct PermissionStatusLine: View {
    let title: String
    let value: String
    let systemImage: String
    var filled = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.black))
                .foregroundStyle(BNBUTheme.blue)
                .frame(width: 20)
            Text(title)
                .font(.caption.weight(.black))
                .foregroundStyle(BNBUTheme.ink)
            Spacer()
            StatusBadge(text: value, filled: filled)
        }
    }
}

private struct CameraCapturePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let completion: (ProofAttachment) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.videoMaximumDuration = 30
        picker.videoQuality = .typeMedium

        let availableTypes = UIImagePickerController.availableMediaTypes(for: .camera) ?? []
        let preferredTypes = [UTType.image.identifier, UTType.movie.identifier].filter { availableTypes.contains($0) }
        picker.mediaTypes = preferredTypes.isEmpty ? availableTypes : preferredTypes
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraCapturePicker

        init(parent: CameraCapturePicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let attachment = makeAttachment(from: info)
            parent.completion(attachment)
            parent.dismiss()
        }

        private func makeAttachment(from info: [UIImagePickerController.InfoKey: Any]) -> ProofAttachment {
            let mediaType = info[.mediaType] as? String
            if mediaType == UTType.movie.identifier, let url = info[.mediaURL] as? URL {
                let byteCount = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? nil
                return ProofAttachment(
                    id: UUID().uuidString,
                    type: .video,
                    fileName: "camera-video-\(String(UUID().uuidString.prefix(6))).mov",
                    byteCount: byteCount,
                    thumbnailData: ProofThumbnailRenderer.videoThumbnailData(from: url),
                    source: "摄像头"
                )
            }

            let image = info[.originalImage] as? UIImage
            let byteCount = image?.jpegData(compressionQuality: 0.82)?.count
            return ProofAttachment(
                id: UUID().uuidString,
                type: .image,
                fileName: "camera-photo-\(String(UUID().uuidString.prefix(6))).jpg",
                byteCount: byteCount,
                thumbnailData: image.flatMap { ProofThumbnailRenderer.imageThumbnailData(from: $0) },
                source: "摄像头"
            )
        }
    }
}

private struct ProofAttachmentPreviewCard: View {
    let attachment: ProofAttachment
    let removeAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .topTrailing) {
                thumbnail
                    .aspectRatio(1.25, contentMode: .fit)
                    .clipped()
                    .overlay(Rectangle().stroke(BNBUTheme.line, lineWidth: 1))

                if attachment.type == .video {
                    Image(systemName: "play.fill")
                        .font(.caption.weight(.black))
                        .foregroundStyle(BNBUTheme.surface)
                        .frame(width: 28, height: 28)
                        .background(BNBUTheme.ink)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }

                Button(action: removeAction) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.black))
                        .foregroundStyle(BNBUTheme.surface)
                        .frame(width: 26, height: 26)
                        .background(BNBUTheme.ink)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("proof.remove.\(attachment.id)")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(attachment.fileName)
                    .font(.caption.weight(.black))
                    .foregroundStyle(BNBUTheme.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(metadataText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BNBUTheme.muted)

                StatusBadge(
                    text: attachment.validationMessage ?? "可提交",
                    filled: attachment.isValidForUpload
                )
            }
        }
        .padding(10)
        .background(BNBUTheme.surface)
        .overlay(
            Rectangle()
                .stroke(attachment.isValidForUpload ? BNBUTheme.line : BNBUTheme.ink, lineWidth: attachment.isValidForUpload ? 1 : 2)
        )
        .accessibilityIdentifier("proof.card.\(attachment.id)")
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let thumbnailData = attachment.thumbnailData,
           let image = UIImage(data: thumbnailData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(BNBUTheme.pale)
                .overlay {
                    Image(systemName: attachment.type == .video ? "video.fill" : "photo.fill")
                        .font(.title3.weight(.black))
                        .foregroundStyle(BNBUTheme.blue)
                }
        }
    }

    private var metadataText: String {
        [
            attachment.type.rawValue,
            attachment.displaySize,
            attachment.displayDuration,
            attachment.source
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}

struct DetailFactRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline.weight(.black))
                .foregroundStyle(BNBUTheme.ink)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BNBUTheme.muted)
                .multilineTextAlignment(.trailing)
        }
    }
}
