import UIKit

/// One drawn key. It never receives touches itself: `KeyboardView` handles all touches so that
/// multi-touch typing, long-press accents, cursor control and swiping work across key boundaries.
///
/// Two looks:
///  * default       - a translucent, glass-styled cap (cheap to draw, keeps typing instant)
///  * glass keys    - every cap is a real Liquid Glass view (opt-in; heavier)
final class KeyView: UIView {
    private(set) var spec: KeySpec
    let label = UILabel()
    private let hintLabel = UILabel()
    private let iconView = UIImageView()
    private var glass: GlassView?
    private let useGlass: Bool

    var isPressed = false {
        didSet {
            guard oldValue != isPressed else { return }
            refreshAppearance()
            UIView.animate(withDuration: 0.07, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.transform = self.isPressed ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
            }
        }
    }
    var isActive = false { didSet { refreshAppearance() } }
    var isProminent = false { didSet { refreshAppearance() } }

    init(spec: KeySpec) {
        self.spec = spec
        self.useGlass = Settings.shared.glassKeys && GlassView.usesRealGlass
        super.init(frame: .zero)
        isUserInteractionEnabled = false

        layer.cornerRadius = 9
        layer.cornerCurve = .continuous

        if useGlass {
            let glassView = GlassView()
            addSubview(glassView)
            glass = glassView
        } else {
            layer.borderWidth = 0.5
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.16
            layer.shadowRadius = 0.5
            layer.shadowOffset = CGSize(width: 0, height: 1)
        }

        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        label.baselineAdjustment = .alignCenters
        addSubview(label)

        hintLabel.textAlignment = .right
        hintLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        hintLabel.textColor = UIColor.secondaryLabel
        hintLabel.text = spec.hint
        addSubview(hintLabel)

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

    /// Fades the glyphs (used while the space bar acts as a trackpad).
    func setContentAlpha(_ alpha: CGFloat) {
        label.alpha = alpha
        iconView.alpha = alpha
        hintLabel.alpha = alpha
    }

    private func refreshAppearance() {
        let textColor: UIColor
        if isProminent {
            textColor = UIColor.white
        } else if isActive {
            textColor = UIColor.black
        } else {
            textColor = UIColor.label
        }
        label.textColor = textColor
        iconView.tintColor = textColor

        if useGlass {
            backgroundColor = UIColor.clear
            if isProminent {
                glass?.contentView.backgroundColor = Theme.accent.withAlphaComponent(0.85)
            } else if isActive {
                glass?.contentView.backgroundColor = Theme.activeKey
            } else if isPressed {
                glass?.contentView.backgroundColor = Theme.glassPressedOverlay
            } else if spec.isFunction {
                glass?.contentView.backgroundColor = Theme.glassFunctionOverlay
            } else {
                glass?.contentView.backgroundColor = UIColor.clear
            }
            return
        }

        if isProminent {
            backgroundColor = isPressed ? Theme.accent.withAlphaComponent(0.7) : Theme.accent
        } else if isActive {
            backgroundColor = Theme.activeKey
        } else if isPressed {
            backgroundColor = spec.isFunction ? Theme.functionKeyPressed : Theme.letterKeyPressed
        } else {
            backgroundColor = spec.isFunction ? Theme.functionKey : Theme.letterKey
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        glass?.frame = bounds
        if !useGlass {
            layer.borderColor = Theme.keyBorder.resolvedColor(with: traitCollection).cgColor
        }
        label.frame = bounds.insetBy(dx: 2, dy: 0)
        hintLabel.frame = CGRect(x: bounds.width - 18, y: 3, width: 14, height: 12)
        let side: CGFloat = 26
        iconView.frame = CGRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side, height: side)
    }
}
