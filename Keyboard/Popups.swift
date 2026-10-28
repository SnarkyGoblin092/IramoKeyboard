import UIKit

/// The bubble that shows the pressed letter above the finger.
final class KeyPreviewView: UIView {
    private let label = UILabel()

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = Theme.letterKey
        layer.cornerRadius = 8
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 3
        layer.shadowOffset = CGSize(width: 0, height: 1)

        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 34)
        label.textColor = UIColor.label
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// `keyFrame` and `hostBounds` are both in the coordinate space of the view this preview lives in.
    func show(text: String, keyFrame: CGRect, hostBounds: CGRect) {
        label.text = text
        let width = keyFrame.width + 22
        let height = keyFrame.height * 1.3
        var x = keyFrame.midX - width / 2
        x = max(2, min(x, hostBounds.width - width - 2))
        let y = max(0, keyFrame.minY - height + 6)
        frame = CGRect(x: x, y: y, width: width, height: height)
        label.frame = bounds
    }
}

/// The strip of alternative characters (accents, punctuation) shown while a key is held.
final class AlternatesPopupView: UIView {
    private var labels: [UILabel] = []
    private let displayItems: [String]
    private let itemWidth: CGFloat
    private let inset: CGFloat = 4
    private(set) var highlightedIndex = 0

    /// The character that will be inserted if the finger lifts now.
    var selectedItem: String { return displayItems[highlightedIndex] }

    init(alternates: [String], keyFrame: CGRect, hostBounds: CGRect) {
        let startsAtKey = keyFrame.midX <= hostBounds.midX
        // On the right half of the keyboard the strip grows to the left and is reversed, so the
        // first alternate is always the one closest to the key.
        self.displayItems = startsAtKey ? alternates : Array(alternates.reversed())
        self.itemWidth = max(keyFrame.width, 36)
        super.init(frame: .zero)

        isUserInteractionEnabled = false
        backgroundColor = Theme.letterKey
        layer.cornerRadius = 8
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 3
        layer.shadowOffset = CGSize(width: 0, height: 1)

        let count = CGFloat(displayItems.count)
        let width = itemWidth * count + inset * 2
        let height = keyFrame.height + 10
        var x = startsAtKey ? keyFrame.minX - inset : keyFrame.maxX - width + inset
        x = max(2, min(x, hostBounds.width - width - 2))
        let y = max(0, keyFrame.minY - height - 4)
        frame = CGRect(x: x, y: y, width: width, height: height)

        for (index, item) in displayItems.enumerated() {
            let label = UILabel(frame: CGRect(x: inset + CGFloat(index) * itemWidth,
                                              y: inset,
                                              width: itemWidth,
                                              height: height - inset * 2))
            label.text = item
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: 26)
            label.layer.cornerRadius = 6
            label.layer.masksToBounds = true
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
        for (index, label) in labels.enumerated() {
            let selected = (index == highlightedIndex)
            label.backgroundColor = selected ? Theme.accent : UIColor.clear
            label.textColor = selected ? UIColor.white : UIColor.label
        }
    }
}
