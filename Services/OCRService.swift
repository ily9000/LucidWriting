import Vision
import AppKit

class OCRService {

    /// Extracts text from an image using Vision framework
    func extractText(from image: NSImage) async -> String {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return ""
        }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                // Sort observations by position (top to bottom, left to right)
                let sortedObservations = observations.sorted { first, second in
                    // Vision coordinates have origin at bottom-left, so we invert Y
                    let firstY = 1.0 - first.boundingBox.midY
                    let secondY = 1.0 - second.boundingBox.midY

                    // Group by rough rows (within 5% of each other vertically)
                    if abs(firstY - secondY) < 0.05 {
                        return first.boundingBox.minX < second.boundingBox.minX
                    }
                    return firstY < secondY
                }

                // Extract text with line breaks for readability
                var lines: [String] = []
                var currentLineY: CGFloat = -1
                var currentLine: [String] = []

                for observation in sortedObservations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }

                    let y = 1.0 - observation.boundingBox.midY

                    // New line if Y position differs significantly
                    if currentLineY >= 0 && abs(y - currentLineY) > 0.03 {
                        if !currentLine.isEmpty {
                            lines.append(currentLine.joined(separator: " "))
                            currentLine = []
                        }
                    }

                    currentLineY = y
                    currentLine.append(topCandidate.string)
                }

                // Don't forget the last line
                if !currentLine.isEmpty {
                    lines.append(currentLine.joined(separator: " "))
                }

                continuation.resume(returning: lines.joined(separator: "\n"))
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                print("OCR failed: \(error)")
                continuation.resume(returning: "")
            }
        }
    }

    /// Extracts text with bounding boxes (useful for identifying UI elements)
    func extractTextWithPositions(from image: NSImage) async -> [(text: String, bounds: CGRect)] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let results = observations.compactMap { observation -> (text: String, bounds: CGRect)? in
                    guard let topCandidate = observation.topCandidates(1).first else { return nil }
                    return (text: topCandidate.string, bounds: observation.boundingBox)
                }

                continuation.resume(returning: results)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                print("OCR failed: \(error)")
                continuation.resume(returning: [])
            }
        }
    }
}
