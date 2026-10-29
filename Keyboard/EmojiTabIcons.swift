import UIKit

/// Hand-drawn template icons for the emoji tabs that SF Symbols has no good symbol for:
/// an apple (food) and a puppy head (animals). Each comes as an outline (inactive tab) and a filled
/// (active tab) version, drawn on an 18 x 18pt canvas to match the 14.4pt SF Symbols next to them.
enum EmojiTabIcons {
    private static let canvas = CGSize(width: 18, height: 18)
    private static let lineWidth: CGFloat = 1.4

    private static func render(_ draw: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: canvas, format: format).image { context in
            context.cgContext.setFillColor(UIColor.black.cgColor)
            context.cgContext.setStrokeColor(UIColor.black.cgColor)
            context.cgContext.setLineWidth(lineWidth)
            context.cgContext.setLineJoin(.round)
            context.cgContext.setLineCap(.round)
            draw(context.cgContext)
        }
        return image.withRenderingMode(.alwaysTemplate)
    }

    // MARK: Apple

    static func apple(filled: Bool) -> UIImage {
        return render { ctx in
            let body = UIBezierPath()
            body.move(to: CGPoint(x: 9, y: 6.0))
            body.addCurve(to: CGPoint(x: 15, y: 9.4), controlPoint1: CGPoint(x: 10.3, y: 4.9), controlPoint2: CGPoint(x: 14.8, y: 5.0))
            body.addCurve(to: CGPoint(x: 10.8, y: 16.2), controlPoint1: CGPoint(x: 15.3, y: 12.8), controlPoint2: CGPoint(x: 12.9, y: 16.2))
            body.addCurve(to: CGPoint(x: 9, y: 15.7), controlPoint1: CGPoint(x: 10.0, y: 16.2), controlPoint2: CGPoint(x: 9.7, y: 15.7))
            body.addCurve(to: CGPoint(x: 7.2, y: 16.2), controlPoint1: CGPoint(x: 8.3, y: 15.7), controlPoint2: CGPoint(x: 8.0, y: 16.2))
            body.addCurve(to: CGPoint(x: 3, y: 9.4), controlPoint1: CGPoint(x: 5.1, y: 16.2), controlPoint2: CGPoint(x: 2.7, y: 12.8))
            body.addCurve(to: CGPoint(x: 9, y: 6.0), controlPoint1: CGPoint(x: 3.2, y: 5.0), controlPoint2: CGPoint(x: 7.7, y: 4.9))
            body.close()

            let stem = UIBezierPath()
            stem.move(to: CGPoint(x: 9, y: 6.0))
            stem.addCurve(to: CGPoint(x: 10.2, y: 2.6), controlPoint1: CGPoint(x: 9, y: 4.6), controlPoint2: CGPoint(x: 9.4, y: 3.4))

            let leaf = UIBezierPath()
            leaf.move(to: CGPoint(x: 10.6, y: 4.4))
            leaf.addCurve(to: CGPoint(x: 14.2, y: 1.6), controlPoint1: CGPoint(x: 10.6, y: 2.8), controlPoint2: CGPoint(x: 12.2, y: 1.6))
            leaf.addCurve(to: CGPoint(x: 10.6, y: 4.4), controlPoint1: CGPoint(x: 14.2, y: 3.4), controlPoint2: CGPoint(x: 12.6, y: 4.4))
            leaf.close()

            if filled {
                body.fill()
                leaf.fill()
                stem.stroke()
            } else {
                body.stroke()
                leaf.stroke()
                stem.stroke()
            }
        }
    }

    // MARK: Puppy

    static func puppy(filled: Bool) -> UIImage {
        return render { ctx in
            let head = UIBezierPath(ovalIn: CGRect(x: 4.0, y: 4.2, width: 10.0, height: 10.4))

            func ear(mirrored: Bool) -> UIBezierPath {
                let path = UIBezierPath()
                func x(_ value: CGFloat) -> CGFloat { return mirrored ? 18 - value : value }
                path.move(to: CGPoint(x: x(5.4), y: 5.0))
                path.addCurve(to: CGPoint(x: x(2.6), y: 12.2), controlPoint1: CGPoint(x: x(2.4), y: 3.8), controlPoint2: CGPoint(x: x(1.4), y: 9.6))
                path.addCurve(to: CGPoint(x: x(5.0), y: 11.4), controlPoint1: CGPoint(x: x(3.6), y: 13.2), controlPoint2: CGPoint(x: x(4.6), y: 12.6))
                path.close()
                return path
            }
            let leftEar = ear(mirrored: false)
            let rightEar = ear(mirrored: true)

            let leftEye = UIBezierPath(ovalIn: CGRect(x: 6.3, y: 8.1, width: 1.6, height: 1.6))
            let rightEye = UIBezierPath(ovalIn: CGRect(x: 10.1, y: 8.1, width: 1.6, height: 1.6))
            let nose = UIBezierPath(ovalIn: CGRect(x: 7.7, y: 10.5, width: 2.6, height: 1.8))
            let mouth = UIBezierPath()
            mouth.move(to: CGPoint(x: 9, y: 12.3))
            mouth.addLine(to: CGPoint(x: 9, y: 13.0))
            mouth.addCurve(to: CGPoint(x: 7.6, y: 13.4), controlPoint1: CGPoint(x: 9, y: 13.6), controlPoint2: CGPoint(x: 8.2, y: 13.8))
            mouth.move(to: CGPoint(x: 9, y: 13.0))
            mouth.addCurve(to: CGPoint(x: 10.4, y: 13.4), controlPoint1: CGPoint(x: 9, y: 13.6), controlPoint2: CGPoint(x: 9.8, y: 13.8))

            if filled {
                head.fill()
                leftEar.fill()
                rightEar.fill()
                // Features are knocked out of the solid shape.
                ctx.setBlendMode(.clear)
                leftEye.fill()
                rightEye.fill()
                nose.fill()
                mouth.lineWidth = 1.0
                mouth.stroke()
                ctx.setBlendMode(.normal)
            } else {
                head.stroke()
                leftEar.stroke()
                rightEar.stroke()
                leftEye.fill()
                rightEye.fill()
                nose.fill()
                mouth.lineWidth = 1.0
                mouth.stroke()
            }
        }
    }

    /// (outline, filled) icons for a tab key, or nil when an SF Symbol should be used.
    static func icons(forKey key: String) -> (outline: UIImage, filled: UIImage)? {
        switch key {
        case "animals": return (puppy(filled: false), puppy(filled: true))
        case "food": return (apple(filled: false), apple(filled: true))
        default: return nil
        }
    }
}
