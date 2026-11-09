import UIKit

/// The emoji key's smiley, on an 80 x 80 grid and rendered as a template image, so it takes the text colour. The
/// icon is from Iconify (`vectorIcons`, credited in the app).
enum EmojiTabIcons {
    private static var cache: [String: UIImage] = [:]

    /// The icon from Iconify, converted to path data on the 80 x 80 grid (absolute M, L, C and Z) and scaled
    /// so every icon has the same drawn size. `stroked`: a line icon; otherwise filled, its lines `band` grid units
    /// thick.
    private struct VectorIcon {
        let stroked: Bool
        let evenOdd: Bool
        let band: CGFloat
        let path: String
    }

    /// The icons (Iconify; the set and licence of each above it).
    private static let vectorIcons: [String: VectorIcon] = [
        // codicon:smiley (CC BY 4.0, Microsoft)
        "smileys": VectorIcon(stroked: false, evenOdd: false, band: 4, path: [
                "M33 39 C34.66 39 36 37.66 36 36 C36 34.34 34.66 33 33 33 C31.34 33 30 34.34 30 36 C30 37.66 31.34 39 ",
                "33 39 M32.54 46.67 C32.07 46.13 31.34 45.88 30.64 46.03 C29.93 46.17 29.36 46.69 29.14 47.37 C28.92 ",
                "48.05 29.08 48.8 29.56 49.34 C32.22 52.3 36.02 54 40 54 C43.98 54 47.78 52.3 50.44 49.34 C51.16 ",
                "48.51 51.09 47.26 50.27 46.53 C49.45 45.79 48.2 45.86 47.46 46.67 C45.56 48.79 42.85 50 40 50 C37.04 ",
                "50 34.38 48.72 32.54 46.67 M50 36 C50 37.66 48.66 39 47 39 C45.34 39 44 37.66 44 36 C44 34.34 45.34 ",
                "33 47 33 C48.66 33 50 34.34 50 36 M64 40 C64 26.75 53.25 16 40 16 C26.75 16 16 26.75 16 40 C16 53.25 ",
                "26.75 64 40 64 C53.25 64 64 53.25 64 40 M20 40 C20 28.95 28.95 20 40 20 C51.05 20 60 28.95 60 40 C60 ",
                "51.05 51.05 60 40 60 C28.95 60 20 51.05 20 40",
            ].joined())
    ]

    /// A path from the M / L / C / Z commands above.
    private static func vectorPath(_ data: String) -> UIBezierPath {
        let path = UIBezierPath()
        var command: Character = "M"
        var numbers: [CGFloat] = []
        func flush() {
            switch command {
            case "M" where numbers.count >= 2:
                path.move(to: CGPoint(x: numbers[0], y: numbers[1]))
            case "L" where numbers.count >= 2:
                path.addLine(to: CGPoint(x: numbers[0], y: numbers[1]))
            case "C" where numbers.count >= 6:
                path.addCurve(to: CGPoint(x: numbers[4], y: numbers[5]),
                              controlPoint1: CGPoint(x: numbers[0], y: numbers[1]),
                              controlPoint2: CGPoint(x: numbers[2], y: numbers[3]))
            default:
                break
            }
            numbers = []
        }
        for token in data.split(separator: " ") {
            guard let first = token.first else { continue }
            if first.isLetter {
                flush()
                command = first
                if command == "Z" { path.close() }
                if token.count > 1, let value = Double(token.dropFirst()) { numbers.append(CGFloat(value)) }
            } else if let value = Double(token) {
                numbers.append(CGFloat(value))
            }
        }
        flush()
        return path
    }

    /// `weight`: line thickness in points.
    static func icon(forKey rawKey: String, side: CGFloat = 80.0 / 3.0, weight: CGFloat) -> UIImage? {
        let key = rawKey
        let cacheKey = key + "@\(side)/\(weight)"
        if let cached = cache[cacheKey] { return cached }
        guard let vector = vectorIcons[key] else { return nil }
        let path = vectorPath(vector.path)
        let size = CGSize(width: side, height: side)
        path.apply(CGAffineTransform(scaleX: side / 80, y: side / 80))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 3
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            path.lineJoinStyle = .round
            path.lineCapStyle = .round
            if vector.stroked {
                UIColor.black.setStroke()
                path.lineWidth = weight
                path.stroke()
            } else {
                // A filled icon's lines are brought to the same weight: grown by outlining them, or thinned by
                // erasing along both edges.
                path.usesEvenOddFillRule = vector.evenOdd
                UIColor.black.setFill()
                UIColor.black.setStroke()
                path.fill()
                let difference = weight - vector.band * side / 80
                if abs(difference) > 0.05 {
                    path.lineWidth = abs(difference)
                    path.stroke(with: difference > 0 ? .normal : .clear, alpha: 1)
                }
            }
        }.withRenderingMode(.alwaysTemplate)
        cache[cacheKey] = image
        return image
    }
}
