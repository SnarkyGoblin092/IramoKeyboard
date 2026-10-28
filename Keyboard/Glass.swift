import UIKit

/// A plain container with a `contentView`, used for the flat parts of the keyboard
/// (suggestion bar, emoji search field, tab bar).
final class FlatPanel: UIView {
    var contentView: UIView { return self }

    init(background: UIColor? = nil, cornerRadius: CGFloat = 0) {
        super.init(frame: .zero)
        backgroundColor = background ?? UIColor.clear
        if cornerRadius > 0 {
            layer.cornerRadius = cornerRadius
            layer.cornerCurve = .continuous
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
