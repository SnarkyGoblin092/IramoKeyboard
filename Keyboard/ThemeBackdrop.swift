import UIKit

/// A designed theme's backdrop behind the whole keyboard (suggestion bar, keys and panels): its vertical gradient
/// and its texture (dots, grid, ruled lines or scanlines) in the line colour. Mirrors ThemeLook.backdrop in the
/// app (App/ThemePreview.swift).
final class ThemeBackdropView: UIView {
    override class var layerClass: AnyClass { return CAGradientLayer.self }

    init(style: ThemeStyle) {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        if let gradient = layer as? CAGradientLayer {
            gradient.colors = [style.background.uiColor.cgColor, style.backgroundEnd.uiColor.cgColor]
            gradient.startPoint = CGPoint(x: 0.5, y: 0)
            gradient.endPoint = CGPoint(x: 0.5, y: 1)
        }
        if style.textureMetrics != nil {
            let texture = TextureView(style: style)
            texture.frame = bounds
            texture.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(texture)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}

/// The texture, drawn again whenever the keyboard changes size.
private final class TextureView: UIView {
    private let style: ThemeStyle

    init(style: ThemeStyle) {
        self.style = style
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isOpaque = false
        backgroundColor = UIColor.clear
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func draw(_ rect: CGRect) {
        guard let texture = style.textureMetrics, let context = UIGraphicsGetCurrentContext() else { return }
        let spacing = CGFloat(texture.spacing)
        let size = CGFloat(texture.size)
        context.setFillColor(texture.color.uiColor.cgColor)
        switch style.texture {
        case .none:
            break
        case .dots:
            var row = 0
            var y = spacing / 2
            while y < bounds.height {
                // Every other row shifted half a step, so the dots sit in a diamond pattern.
                var x = row % 2 == 0 ? spacing / 2 : spacing
                while x < bounds.width {
                    context.fillEllipse(in: CGRect(x: x - size, y: y - size, width: size * 2, height: size * 2))
                    x += spacing
                }
                y += spacing
                row += 1
            }
        case .grid:
            var x = spacing / 2
            while x < bounds.width {
                context.fill(CGRect(x: x, y: 0, width: size, height: bounds.height))
                x += spacing
            }
            var y = spacing / 2
            while y < bounds.height {
                context.fill(CGRect(x: 0, y: y, width: bounds.width, height: size))
                y += spacing
            }
        case .lines, .scanlines:
            var y = spacing - size
            while y < bounds.height {
                context.fill(CGRect(x: 0, y: y, width: bounds.width, height: size))
                y += spacing
            }
        }
    }
}
