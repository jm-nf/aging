import AVFoundation
import UIKit

struct ReelsTextOptions {
    var spotName:  String = ""
    var catchText: String = ""
    var tideText:  String = ""
    var dateText:  String = ""
    var showSpot:  Bool = true
    var showCatch: Bool = true
    var showTide:  Bool = true
    var showDate:  Bool = true
}

actor ReelsExporter {
    static let shared = ReelsExporter()

    private let width        = 1080
    private let height       = 1920
    private let fps          = 30
    private let secPerPhoto  = 3

    func export(photos: [UIImage], textOptions: ReelsTextOptions) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("reels_\(Int(Date().timeIntervalSince1970)).mp4")
        try? FileManager.default.removeItem(at: outputURL)

        let size = CGSize(width: width, height: height)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let buffers: [CVPixelBuffer] = try await MainActor.run {
            try photos.map { photo -> CVPixelBuffer in
                let overlaid = renderOverlay(on: photo, size: size, options: textOptions)
                return try makePixelBuffer(from: overlaid, size: size)
            }
        }

        let framesPerPhoto = fps * secPerPhoto
        let totalFrames    = buffers.count * framesPerPhoto
        let queue          = DispatchQueue(label: "reels.writer")

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var frameIndex = 0
            input.requestMediaDataWhenReady(on: queue) {
                while input.isReadyForMoreMediaData && frameIndex < totalFrames {
                    let pb   = buffers[frameIndex / framesPerPhoto]
                    let time = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(self.fps))
                    adaptor.append(pb, withPresentationTime: time)
                    frameIndex += 1
                }
                if frameIndex >= totalFrames {
                    input.markAsFinished()
                    writer.finishWriting { continuation.resume() }
                }
            }
        }

        guard writer.status == .completed else {
            throw writer.error ?? NSError(domain: "ReelsExporter", code: -1)
        }
        return outputURL
    }

    @MainActor
    private func renderOverlay(on image: UIImage, size: CGSize, options: ReelsTextOptions) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let scale = max(size.width / image.size.width, size.height / image.size.height)
            let sw = image.size.width  * scale
            let sh = image.size.height * scale
            image.draw(in: CGRect(x: (size.width - sw) / 2, y: (size.height - sh) / 2, width: sw, height: sh))

            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.65).cgColor] as CFArray,
                locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(gradient,
                start: CGPoint(x: 0, y: size.height * 0.6),
                end:   CGPoint(x: 0, y: size.height),
                options: [])

            var lines: [String] = []
            if options.showSpot,  !options.spotName.isEmpty  { lines.append("📍 \(options.spotName)") }
            if options.showDate,  !options.dateText.isEmpty  { lines.append("📅 \(options.dateText)") }
            if options.showCatch, !options.catchText.isEmpty { lines.append("🐟 \(options.catchText)") }
            if options.showTide,  !options.tideText.isEmpty  { lines.append("🌊 \(options.tideText)") }

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 52),
                .foregroundColor: UIColor.white,
                .strokeColor: UIColor.black,
                .strokeWidth: -4,
            ]
            let lineHeight: CGFloat = 70
            let startY = size.height - CGFloat(lines.count) * lineHeight - 80
            for (i, line) in lines.enumerated() {
                NSAttributedString(string: line, attributes: attrs)
                    .draw(at: CGPoint(x: 40, y: startY + CGFloat(i) * lineHeight))
            }
        }
    }

    private nonisolated func makePixelBuffer(from image: UIImage, size: CGSize) throws -> CVPixelBuffer {
        var pb: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        ] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height),
                            kCVPixelFormatType_32BGRA, attrs, &pb)
        guard let buf = pb else { throw NSError(domain: "ReelsExporter", code: -2) }
        CVPixelBufferLockBaseAddress(buf, [])
        defer { CVPixelBufferUnlockBaseAddress(buf, []) }
        let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(buf),
            width: Int(size.width), height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buf),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
        if let cg = image.cgImage {
            ctx.draw(cg, in: CGRect(origin: .zero, size: size))
        }
        return buf
    }
}
