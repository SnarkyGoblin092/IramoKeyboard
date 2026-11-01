import UIKit

/// The native-style balloon that shows the pressed letter above the finger: a wide rounded top that
/// narrows into the shape of the key underneath it.
final class KeyPreviewView: UIView {
    private let shape = CAShapeLayer()
    private let label = UILabel()
    /// Liquid Glass theme: the preview is a floating glass pill instead of the opaque balloon.
    private let glassView: UIVisualEffectView? = Theme.usesRealGlass ? GlassSupport.makeEffectView(clear: false) : nil

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = UIColor.clear
        if let glassView = glassView {
            glassView.isUserInteractionEnabled = false
            addSubview(glassView)
        }

        shape.shadowOpacity = 0.35
        shape.shadowRadius = 2
        shape.shadowOffset = CGSize(width: 0, height: 1)
        shape.shadowColor = UIColor.black.cgColor
        layer.addSublayer(shape)

        label.textAlignment = .center
        label.font = Theme.keyFont(ofSize: 38, weight: .light)
        label.textColor = Theme.keyText
        if let glassView = glassView {
            glassView.contentView.addSubview(label)
        } else {
            addSubview(label)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// `keyFrame` and `hostBounds` are both in the coordinate space of the view this preview lives in.
    func show(text: String, keyFrame: CGRect, hostBounds: CGRect) {
        label.text = text

        if let glassView = glassView {
            let width = keyFrame.width + 24
            let room = keyFrame.minY - hostBounds.minY - 6 - 1
            let height = max(keyFrame.height * 0.7, min(keyFrame.height * 1.1, room))
            var x = keyFrame.midX - width / 2
            x = max(2, min(x, hostBounds.width - width - 2))
            frame = CGRect(x: x, y: max(hostBounds.minY, keyFrame.minY - height - 6), width: width, height: height)
            glassView.frame = bounds
            GlassSupport.applyShape(glassView, radius: Theme.keyCornerRadius(for: bounds.size), size: bounds.size)
            label.font = Theme.keyFont(ofSize: min(38, height * 0.75), weight: .light)
            label.frame = glassView.bounds
            return
        }

        let balloonWidth = keyFrame.width + 28
        let neck: CGFloat = 8
        // The keyboard clips anything above its top edge, so on the first row the balloon gets shorter.
        let room = keyFrame.minY - hostBounds.minY - neck - 1
        let topHeight = max(keyFrame.height * 0.7, min(keyFrame.height * 1.2, room))
        let totalHeight = topHeight + neck + keyFrame.height

        var x = keyFrame.midX - balloonWidth / 2
        x = max(2, min(x, hostBounds.width - balloonWidth - 2))
        let keyX = keyFrame.minX - x
        let y = keyFrame.maxY - totalHeight
        frame = CGRect(x: x, y: y, width: balloonWidth, height: totalHeight)

        // One continuous outline (wide rounded top, smooth neck, key-shaped foot), so no corners poke out
        // where separate shapes would overlap.
        let keyRadius = min(Theme.keyCornerRadius(for: keyFrame.size), keyFrame.width / 2, keyFrame.height / 2)
        // Same roundness as the keys.
        let topRadius = Theme.keyCornerRadius(for: CGSize(width: balloonWidth, height: topHeight))
        let keyLeft = keyX
        let keyRight = keyX + keyFrame.width
        let footTop = topHeight + neck
        let bottom = totalHeight

        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: topRadius))
        path.addArc(withCenter: CGPoint(x: topRadius, y: topRadius), radius: topRadius,
                    startAngle: .pi, endAngle: .pi * 1.5, clockwise: true)
        path.addLine(to: CGPoint(x: balloonWidth - topRadius, y: 0))
        path.addArc(withCenter: CGPoint(x: balloonWidth - topRadius, y: topRadius), radius: topRadius,
                    startAngle: .pi * 1.5, endAngle: 0, clockwise: true)
        path.addLine(to: CGPoint(x: balloonWidth, y: topHeight - topRadius))
        path.addCurve(to: CGPoint(x: keyRight, y: footTop),
                      controlPoint1: CGPoint(x: balloonWidth, y: topHeight),
                      controlPoint2: CGPoint(x: keyRight, y: topHeight))
        path.addLine(to: CGPoint(x: keyRight, y: bottom - keyRadius))
        path.addArc(withCenter: CGPoint(x: keyRight - keyRadius, y: bottom - keyRadius), radius: keyRadius,
                    startAngle: 0, endAngle: .pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: keyLeft + keyRadius, y: bottom))
        path.addArc(withCenter: CGPoint(x: keyLeft + keyRadius, y: bottom - keyRadius), radius: keyRadius,
                    startAngle: .pi / 2, endAngle: .pi, clockwise: true)
        path.addLine(to: CGPoint(x: keyLeft, y: footTop))
        path.addCurve(to: CGPoint(x: 0, y: topHeight - topRadius),
                      controlPoint1: CGPoint(x: keyLeft, y: topHeight),
                      controlPoint2: CGPoint(x: 0, y: topHeight))
        path.close()

        shape.path = path.cgPath
        shape.shadowPath = path.cgPath
        shape.fillColor = balloonFill
        label.font = Theme.keyFont(ofSize: min(38, topHeight * 0.75), weight: .light)
        label.frame = CGRect(x: 0, y: 2, width: balloonWidth, height: topHeight - 4)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        shape.fillColor = balloonFill
    }

    /// Always opaque: a see-through balloon lets the pressed key and its letter show through it.
    private var balloonFill: CGColor {
        return Theme.popupFill.resolvedColor(with: traitCollection).withAlphaComponent(1).cgColor
    }
}

/// The strip of alternative characters (accents, punctuation) shown while a key is held.
final class AlternatesPopupView: UIView {
    private let highlight = UIView()
    private let glassView: UIVisualEffectView? = Theme.usesRealGlass ? GlassSupport.makeEffectView(clear: false) : nil
    private var labels: [UILabel] = []
    private let displayItems: [String]
    private let itemWidth: CGFloat
    private let inset: CGFloat = 5
    private(set) var highlightedIndex = 0
    private var popupRadius: CGFloat = 8
    private var cellRadius: CGFloat = 4

    /// The character that will be inserted if the finger lifts now.
    var selectedItem: String { return displayItems[highlightedIndex] }

    init(alternates: [String], keyFrame: CGRect, hostBounds: CGRect) {
        let startsAtKey = keyFrame.midX <= hostBounds.midX
        // On the right half of the keyboard the strip grows to the left and is reversed, so the
        // first alternate is always the one closest to the key.
        self.displayItems = startsAtKey ? alternates : Array(alternates.reversed())

        // Long lists (the comma key) shrink the cells so everything fits on one row.
        let available = hostBounds.width - 4 - 10
        let wanted = max(keyFrame.width, 38)
        self.itemWidth = min(wanted, max(24, available / CGFloat(max(alternates.count, 1))))
        super.init(frame: .zero)

        isUserInteractionEnabled = false
        let count = CGFloat(displayItems.count)
        let width = itemWidth * count + inset * 2
        let height = keyFrame.height + 12
        // Cells are shaped like keys; the strip's corners follow them, so it never pinches into a lemon.
        cellRadius = Theme.keyCornerRadius(for: CGSize(width: itemWidth, height: height - inset * 2))
        popupRadius = min(cellRadius + inset, min(width, height) / 2)
        if glassView == nil {
            backgroundColor = Theme.popupFill
            layer.cornerRadius = popupRadius
            layer.cornerCurve = .continuous
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.35
            layer.shadowRadius = 2
            layer.shadowOffset = CGSize(width: 0, height: 1)
        }

        var x = startsAtKey ? keyFrame.minX - inset : keyFrame.maxX - width + inset
        x = max(2, min(x, hostBounds.width - width - 2))
        let y = max(0, keyFrame.minY - height - 4)
        frame = CGRect(x: x, y: y, width: width, height: height)

        highlight.layer.cornerCurve = .continuous
        let host: UIView
        if let glassView = glassView {
            glassView.isUserInteractionEnabled = false
            glassView.frame = bounds
            addSubview(glassView)
            GlassSupport.applyShape(glassView, radius: popupRadius, size: bounds.size)
            host = glassView.contentView
        } else {
            host = self
        }
        host.addSubview(highlight)

        for (index, item) in displayItems.enumerated() {
            let label = UILabel(frame: CGRect(x: inset + CGFloat(index) * itemWidth,
                                              y: inset,
                                              width: itemWidth,
                                              height: height - inset * 2))
            label.text = item
            label.textAlignment = .center
            label.font = Theme.keyFont(ofSize: 24)
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.6
            host.addSubview(label)
            labels.append(label)
        }

        highlightedIndex = startsAtKey ? 0 : max(displayItems.count - 1, 0)
        refreshHighlight()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// `hostX` is the finger's x position in the same coordinate space as this view's frame.
    func updateHighlight(hostX: CGFloat) {
        guard !displayItems.isEmpty else { return }
        let raw = Int(((hostX - frame.minX - inset) / itemWidth).rounded(.down))
        let index = max(0, min(raw, displayItems.count - 1))
        if index != highlightedIndex {
            highlightedIndex = index
            refreshHighlight()
        }
    }

    private func refreshHighlight() {
        guard highlightedIndex < labels.count else { return }
        let frame = labels[highlightedIndex].frame
        highlight.frame = frame
        highlight.layer.cornerRadius = cellRadius
        highlight.backgroundColor = Theme.accent
        for (index, label) in labels.enumerated() {
            label.textColor = (index == highlightedIndex) ? Theme.onAccent : Theme.keyText
        }
    }
}
