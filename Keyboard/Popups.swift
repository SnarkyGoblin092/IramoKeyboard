import UIKit

/// The native-style balloon that shows the pressed letter above the finger: a wide rounded top that
/// narrows into the shape of the key underneath it.
final class KeyPreviewView: UIView {
    private let shape = CAShapeLayer()
    private let label = UILabel()

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = UIColor.clear

        shape.shadowOpacity = 0.35
        shape.shadowRadius = 2
        shape.shadowOffset = CGSize(width: 0, height: 1)
        shape.shadowColor = UIColor.black.cgColor
        layer.addSublayer(shape)

        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 38, weight: .light)
        label.textColor = Theme.text
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// `keyFrame` and `hostBounds` are both in the coordinate space of the view this preview lives in.
    func show(text: String, keyFrame: CGRect, hostBounds: CGRect) {
        label.text = text

        let balloonWidth = keyFrame.width + 28
        let topHeight = keyFrame.height * 1.2
        let neck: CGFloat = 8
        let totalHeight = topHeight + neck + keyFrame.height

        var x = keyFrame.midX - balloonWidth / 2
        x = max(2, min(x, hostBounds.width - balloonWidth - 2))
        let keyX = keyFrame.minX - x
        let y = keyFrame.maxY - totalHeight
        frame = CGRect(x: x, y: y, width: balloonWidth, height: totalHeight)

        let topRect = CGRect(x: 0, y: 0, width: balloonWidth, height: topHeight)
        let keyRect = CGRect(x: keyX, y: topHeight + neck, width: keyFrame.width, height: keyFrame.height)

        let path = UIBezierPath(roundedRect: topRect, cornerRadius: 10)
        path.append(UIBezierPath(roundedRect: keyRect, cornerRadius: 6))
        let neckPath = UIBezierPath()
        neckPath.move(to: CGPoint(x: 2, y: topHeight - 8))
        neckPath.addLine(to: CGPoint(x: balloonWidth - 2, y: topHeight - 8))
        neckPath.addLine(to: CGPoint(x: keyRect.maxX, y: keyRect.minY + 8))
        neckPath.addLine(to: CGPoint(x: keyRect.minX, y: keyRect.minY + 8))
        neckPath.close()
        path.append(neckPath)

        shape.path = path.cgPath
        shape.shadowPath = path.cgPath
        shape.fillColor = Theme.popupFill.resolvedColor(with: traitCollection).cgColor
        label.frame = CGRect(x: 0, y: 2, width: balloonWidth, height: topHeight - 4)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        shape.fillColor = Theme.popupFill.resolvedColor(with: traitCollection).cgColor
    }
}

/// The strip of alternative characters (accents, punctuation) shown while a key is held.
final class AlternatesPopupView: UIView {
    private let highlight = UIView()
    private var labels: [UILabel] = []
    private let displayItems: [String]
    private let itemWidth: CGFloat
    private let inset: CGFloat = 5
    private(set) var highlightedIndex = 0

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
        backgroundColor = Theme.popupFill
        layer.cornerRadius = 8
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 2
        layer.shadowOffset = CGSize(width: 0, height: 1)

        let count = CGFloat(displayItems.count)
        let width = itemWidth * count + inset * 2
        let height = keyFrame.height + 12
        var x = startsAtKey ? keyFrame.minX - inset : keyFrame.maxX - width + inset
        x = max(2, min(x, hostBounds.width - width - 2))
        let y = max(0, keyFrame.minY - height - 4)
        frame = CGRect(x: x, y: y, width: width, height: height)

        highlight.layer.cornerCurve = .continuous
        addSubview(highlight)

        for (index, item) in displayItems.enumerated() {
            let label = UILabel(frame: CGRect(x: inset + CGFloat(index) * itemWidth,
                                              y: inset,
                                              width: itemWidth,
                                              height: height - inset * 2))
            label.text = item
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: 24, weight: .regular)
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.6
            addSubview(label)
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
        highlight.layer.cornerRadius = 6
        highlight.backgroundColor = Theme.accent
        for (index, label) in labels.enumerated() {
            label.textColor = (index == highlightedIndex) ? Theme.onAccent : Theme.text
        }
    }
}
