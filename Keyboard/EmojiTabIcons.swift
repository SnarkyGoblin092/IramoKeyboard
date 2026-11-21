import UIKit

/// Tab icons for the emoji picker, on an 80 x 80 grid and rendered as template images, so they take the text
/// colour. The icons are from Iconify (`vectorIcons`, credited in the app). They look the same whether or not their
/// tab is selected; the selection is shown by a circle behind the tab.
enum EmojiTabIcons {
    private static var cache: [String: UIImage] = [:]

    /// One tab icon from Iconify, converted to path data on the 80 x 80 grid (absolute M, L, C and Z) and scaled
    /// so every icon has the same drawn size. `stroked`: a line icon; otherwise filled, its lines `band` grid units
    /// thick.
    private struct VectorIcon {
        let stroked: Bool
        let evenOdd: Bool
        let band: CGFloat
        let path: String
    }

    /// Line thickness of every tab icon, in points: the delete icon's (SF Symbol "delete.left", 20pt, light).
    static let lineWeight: CGFloat = 1.15

    /// The tab icons (Iconify; the set and licence of each above it).
    private static let vectorIcons: [String: VectorIcon] = [
        // akar-icons:clock (MIT)
        "recents": VectorIcon(stroked: true, evenOdd: false, band: 0, path: [
                "M46.76 49.02 L41.32 43.58 C40.47 42.73 40 41.58 40 40.39 L40 26.48 M17.46 40 C17.46 27.55 27.55 ",
                "17.46 40 17.46 C52.45 17.46 62.54 27.55 62.54 40 C62.54 52.45 52.45 62.54 40 62.54 C27.55 62.54 ",
                "17.46 52.45 17.46 40 Z",
            ].joined()),
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
            ].joined()),
        // famicons:paw-outline (MIT)
        "animals": VectorIcon(stroked: true, evenOdd: false, band: 0, path: [
                "M61.12 31.01 C60.74 30.86 60.35 30.79 59.95 30.79 L59.9 30.79 C57.79 30.82 55.42 32.8 54.19 35.79 ",
                "C52.69 39.36 53.38 43.02 55.73 43.97 C56.1 44.11 56.5 44.19 56.9 44.19 C59.02 44.19 61.42 42.19 ",
                "62.67 39.19 C64.15 35.61 63.46 31.95 61.12 31.01 Z M47.49 44.97 C44.59 40.14 43.33 38.33 40 38.33 ",
                "C36.67 38.33 35.4 40.15 32.5 44.97 C30 49.09 24.97 49.44 23.71 52.93 C23.46 53.57 23.33 54.26 23.34 ",
                "54.95 C23.34 57.79 25.51 60.1 28.19 60.1 C31.53 60.1 36.06 57.44 40.01 57.44 C43.97 57.44 48.47 60.1 ",
                "51.81 60.1 C54.49 60.1 56.66 57.79 56.66 54.95 C56.66 54.26 56.52 53.57 56.27 52.93 C55.01 49.42 ",
                "49.99 49.09 47.49 44.97 Z M33.35 33.72 C33.49 33.72 33.64 33.71 33.77 33.69 C36.21 33.33 37.72 29.97 ",
                "37.17 26.17 C36.65 22.58 34.47 19.9 32.2 19.9 C32.06 19.9 31.92 19.91 31.79 19.94 C29.36 20.29 27.83 ",
                "23.65 28.39 27.46 C28.91 31.03 31.08 33.72 33.35 33.72 Z M51.61 27.46 C52.16 23.65 50.64 20.29 48.21 ",
                "19.94 C48.07 19.91 47.94 19.9 47.8 19.9 C45.52 19.9 43.35 22.58 42.83 26.17 C42.28 29.97 43.79 33.33 ",
                "46.23 33.69 C46.36 33.71 46.51 33.72 46.65 33.72 C48.92 33.72 51.1 31.03 51.61 27.46 Z M24.27 43.97 ",
                "C26.62 43.02 27.31 39.36 25.82 35.79 C24.57 32.78 22.16 30.79 20.05 30.79 C19.65 30.79 19.25 30.86 ",
                "18.88 31.01 C16.54 31.95 15.85 35.61 17.34 39.19 C18.59 42.19 20.99 44.19 23.11 44.19 C23.5 44.19 ",
                "23.91 44.11 24.27 43.97 Z",
            ].joined()),
        // flowbite:apple-full-outline (MIT)
        "food": VectorIcon(stroked: true, evenOdd: false, band: 0, path: [
                "M40 34.82 C36.33 34.82 36.33 31.85 28.9 32.08 C24.34 32.23 20.58 37.97 21.75 46.09 C22.48 51.16 ",
                "26.77 63.73 32.07 63.73 C37.36 63.73 37.54 61.48 40 61.48 C42.46 61.48 42.26 63.73 47.93 63.73 ",
                "C53.61 63.73 57.52 51.16 58.25 46.09 C59.42 37.97 55.66 32.23 51.1 32.08 C43.67 31.85 43.67 34.82 40 ",
                "34.82 M46.22 23.7 C43.91 25.68 41.32 25.6 39.04 25.6 C39.04 23.95 39.26 20.49 41.32 18.3 C43.37 ",
                "16.12 46.92 16.27 48.29 16.27 C48.29 17.85 48.54 21.73 46.22 23.7",
            ].joined()),
        // fa:futbol-o (OFL 1.1, Font Awesome 4.7)
        "activity": VectorIcon(stroked: false, evenOdd: false, band: 3.43, path: [
                "M32.31 37.86 L40 32.29 L47.69 37.86 L44.77 46.86 L35.26 46.86 Z M40 16 C43.25 16 46.36 16.63 49.32 ",
                "17.9 C52.29 19.17 54.84 20.87 56.98 23.02 C59.12 25.16 60.83 27.71 62.1 30.68 C63.37 33.64 64 36.75 ",
                "64 40 C64 43.25 63.37 46.36 62.1 49.32 C60.83 52.29 59.12 54.84 56.98 56.98 C54.84 59.12 52.29 60.83 ",
                "49.32 62.1 C46.36 63.37 43.25 64 40 64 C36.75 64 33.64 63.37 30.68 62.1 C27.71 60.83 25.16 59.12 ",
                "23.02 56.98 C20.87 54.84 19.17 52.29 17.9 49.32 C16.63 46.36 16 43.25 16 40 C16 36.75 16.63 33.64 ",
                "17.9 30.68 C19.17 27.71 20.87 25.16 23.02 23.02 C25.16 20.87 27.71 19.17 30.68 17.9 C33.64 16.63 ",
                "36.75 16 40 16 M56.58 52.16 C59.24 48.54 60.57 44.48 60.57 40 L60.57 39.92 L57.84 42.3 L51.41 36.3 ",
                "L53.1 27.65 L56.69 27.97 C54.01 24.29 50.54 21.78 46.27 20.42 L47.69 23.74 L40 28 L32.31 23.74 ",
                "L33.73 20.42 C29.46 21.78 25.99 24.29 23.31 27.97 L26.93 27.65 L28.59 36.3 L22.16 42.3 L19.43 39.92 ",
                "L19.43 40 C19.43 44.48 20.76 48.54 23.42 52.16 L24.22 48.62 L32.96 49.7 L36.68 57.68 L33.57 59.53 ",
                "C35.66 60.22 37.8 60.57 40 60.57 C42.2 60.57 44.34 60.22 46.43 59.53 L43.32 57.68 L47.04 49.7 L55.78 ",
                "48.62 Z",
            ].joined()),
        // fluent:vehicle-car-profile-16-regular (MIT, Microsoft)
        "travel": VectorIcon(stroked: false, evenOdd: false, band: 3.73, path: [
                "M54.08 34.41 L53.58 34.23 L49.34 26.29 C47.73 23.25 44.56 21.35 41.12 21.35 L30.46 21.35 C26.44 ",
                "21.35 22.88 23.93 21.61 27.73 L19.6 33.78 C16.14 35.24 13.89 38.63 13.89 42.38 L13.89 46.53 C13.89 ",
                "49.17 15.47 51.45 17.74 52.48 C18.34 55.93 21.28 58.51 24.78 58.65 C28.3 58.79 31.43 56.46 32.31 ",
                "53.05 L47.69 53.05 C48.57 56.46 51.7 58.79 55.22 58.65 C58.72 58.51 61.66 55.93 62.26 52.48 C64.61 ",
                "51.42 66.11 49.09 66.11 46.53 L66.11 45.26 C66.11 41.31 63.63 37.8 59.91 36.48 L54.27 34.48 L54.27 ",
                "34.41 Z M30.46 25.08 L34.41 25.08 L34.41 34.41 L23.32 34.41 L25.15 28.9 C25.91 26.62 28.05 25.08 ",
                "30.46 25.08 M38.14 25.08 L41.12 25.08 C43.19 25.08 45.08 26.22 46.06 28.05 L49.45 34.41 L38.14 34.41 ",
                "Z M53.44 38.14 L58.66 39.99 C60.88 40.78 62.38 42.9 62.38 45.26 L62.38 46.53 C62.38 47.18 62.15 ",
                "47.78 61.78 48.26 C60.53 45.31 57.54 43.51 54.36 43.74 C51.17 43.98 48.49 46.23 47.69 49.32 L32.31 ",
                "49.32 C31.51 46.23 28.83 43.98 25.64 43.74 C22.46 43.51 19.47 45.31 18.22 48.26 C17.83 47.77 17.62 ",
                "47.15 17.62 46.53 L17.62 42.38 C17.62 40.7 18.37 39.17 19.56 38.14 Z M21.35 51.19 C21.35 49.13 23.02 ",
                "47.46 25.08 47.46 C27.14 47.46 28.81 49.13 28.81 51.19 C28.81 53.25 27.14 54.92 25.08 54.92 C23.02 ",
                "54.92 21.35 53.25 21.35 51.19 M54.92 47.46 C56.98 47.46 58.65 49.13 58.65 51.19 C58.65 53.25 56.98 ",
                "54.92 54.92 54.92 C52.86 54.92 51.19 53.25 51.19 51.19 C51.19 49.13 52.86 47.46 54.92 47.46",
            ].joined()),
        // basil:lightbulb-outline (CC BY 4.0, Craftwork)
        "objects": VectorIcon(stroked: false, evenOdd: true, band: 3.77, path: [
                "M40 18.03 C31.27 18.03 24.3 24.86 24.3 33.13 C24.3 38.17 26.37 42.51 30.05 45.21 C30.86 45.81 31.55 ",
                "46.7 31.82 47.82 C32.03 48.75 32.28 49.87 32.52 51.07 L47.48 51.07 C47.72 49.87 47.97 48.75 48.18 ",
                "47.82 C48.46 46.7 49.14 45.81 49.95 45.21 C53.63 42.51 55.7 38.17 55.7 33.13 C55.7 24.86 48.73 18.03 ",
                "40 18.03 M46.75 54.84 L33.25 54.84 C33.52 56.44 33.74 57.95 33.8 59.04 C33.88 60.19 34.74 61.22 36 ",
                "61.48 L36.49 61.6 C38.79 62.1 41.2 62.1 43.51 61.6 L44 61.48 C45.26 61.22 46.12 60.19 46.19 59.04 ",
                "C46.25 57.95 46.47 56.44 46.75 54.84 M20.54 33.13 C20.54 22.65 29.31 14.26 40 14.26 C50.69 14.26 ",
                "59.46 22.65 59.46 33.13 C59.46 39.22 56.94 44.75 52.18 48.24 C52.02 48.35 51.91 48.51 51.85 48.69 ",
                "C51.5 50.22 51.17 51.77 50.87 53.31 C50.4 55.67 50.03 57.95 49.95 59.27 C49.77 62.18 47.64 64.55 ",
                "44.8 65.17 L44.3 65.28 C41.47 65.89 38.53 65.89 35.7 65.28 L35.2 65.17 C32.36 64.56 30.23 62.18 ",
                "30.05 59.27 C29.97 57.95 29.6 55.67 29.13 53.31 C28.83 51.77 28.5 50.22 28.15 48.69 C28.09 48.51 ",
                "27.98 48.35 27.82 48.24 C23.06 44.75 20.54 39.22 20.54 33.14",
            ].joined()),
        // akar-icons:heart (MIT)
        "symbols": VectorIcon(stroked: true, evenOdd: false, band: 0, path: [
                "M28.43 19.36 C22.03 19.36 16.84 24.49 16.84 30.82 C16.84 35.93 18.88 48.05 38.81 60.31 C39.54 60.75 ",
                "40.46 60.75 41.19 60.31 C61.13 48.05 63.16 35.93 63.16 30.82 C63.16 24.49 57.97 19.36 51.57 19.36 ",
                "C45.18 19.36 40 26.3 40 26.3 C40 26.3 34.82 19.36 28.43 19.36",
            ].joined()),
        // boxicons:flag-alt (MIT)
        "flags": VectorIcon(stroked: false, evenOdd: false, band: 4.94, path: [
                "M22.69 48.94 C27.63 46.79 33.27 47.05 37.96 49.75 C41.35 51.68 45.1 52.66 48.88 52.66 C51.65 52.66 ",
                "54.41 52.14 57.08 51.09 L60.67 49.65 C61.61 49.28 62.22 48.36 62.22 47.35 L62.22 20.17 C62.22 19.35 ",
                "61.82 18.58 61.14 18.13 C60.46 17.66 59.6 17.57 58.84 17.88 L55.26 19.3 C50.39 21.26 44.98 20.86 ",
                "40.43 18.27 C34.04 14.61 26.24 14.4 19.65 17.7 L19.13 17.95 C18.3 18.37 17.78 19.22 17.78 20.15 ",
                "L17.78 64.62 L22.71 64.62 L22.71 48.91 Z M22.69 21.73 C27.63 19.58 33.27 19.88 37.96 22.57 C43.81 ",
                "25.93 50.78 26.4 57.08 23.9 L57.29 23.83 L57.29 45.69 L55.26 46.51 C50.42 48.47 44.95 48.08 40.43 ",
                "45.47 C37.1 43.57 33.34 42.57 29.51 42.56 C27.21 42.56 24.91 42.93 22.71 43.64 L22.71 21.73 Z",
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

    /// `weight`: line thickness in points (the tabs use the delete icon's; the keyboard's emoji key a bolder one).
    static func icon(forKey rawKey: String, side: CGFloat = 80.0 / 3.0, weight: CGFloat = lineWeight) -> UIImage? {
        let key = (rawKey == "recent") ? "recents" : rawKey
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

    /// Kept for the panel: the same image is used for the normal and the selected state.
    static func icons(forKey key: String, side: CGFloat = 80.0 / 3.0) -> (outline: UIImage, filled: UIImage)? {
        guard let image = icon(forKey: key, side: side) else { return nil }
        return (image, image)
    }
}
