import UIKit

/// One drawn key. It never receives touches itself: `KeyboardView` handles all touches so that
/// multi-touch typing, long-press accents and swiping work across key boundaries.
final class KeyView: UIView {
    private(set) var spec: KeySpec
    let label = UILabel()
    private let iconView = UIImageView()

    var isPressed = false { didSet { refreshAppearance() } }
    var isActive = false { didSet { refreshAppearance() } }

    init(spec: KeySpec) {
        self.spec = spec
        super.init(frame: .zero)
        isUserInteractionEnabled = false

        layer.cornerRadius = 6
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 0
        layer.shadowOffset = CGSize(width: 0, height: 1)

        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        label.baselineAdjustment = .alignCenters
        addSubview(label)

        iconView.contentMode = .scaleAspectFit
        addSubview(iconView)

        configureContent()
        refreshAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func configureContent() {
        if let symbol = spec.symbol {
            iconView.image = UIImage(systemName: symbol,
                                     withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .regular))
            iconView.isHidden = false
            label.isHidden = true
        } else {
            label.text = spec.title
            if spec.action == .space {
                label.font = UIFont.systemFont(ofSize: 15)
            } else if spec.title.count == 1 {
                label.font = UIFont.systemFont(ofSize: 25)
            } else {
                label.font = UIFont.systemFont(ofSize: 16)
            }
            label.isHidden = false
            iconView.isHidden = true
        }
    }

    func setIcon(_ symbolName: String) {
        iconView.image = UIImage(systemName: symbolName,
                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .regular))
    }

    func setTitle(_ title: String) {
        spec.title = title
        label.text = title
    }

    private func refreshAppearance() {
        if isPressed {
            backgroundColor = spec.isFunction ? Theme.functionKeyPressed : Theme.letterKeyPressed
        } else if isActive {
            backgroundColor = Theme.activeKey
        } else {
            backgroundColor = spec.isFunction ? Theme.functionKey : Theme.letterKey
        }
        let textColor: UIColor = isActive ? UIColor.black : UIColor.label
        label.textColor = textColor
        iconView.tintColor = textColor
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds.insetBy(dx: 2, dy: 0)
        let side: CGFloat = 26
        iconView.frame = CGRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side, height: side)
    }
}
