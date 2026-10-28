import UIKit

/// The gradient behind the whole keyboard (keys, suggestion strip and the emoji picker) for gradient
/// themes. It sits at the bottom of the keyboard's container, covering the system backdrop.
final class BackdropView: UIView {
    private let gradient = CAGradientLayer()

    init(theme: ThemeDefinition, opacity: CGFloat) {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = UIColor.clear
        gradient.colors = theme.gradientStops.map { $0.uiColor.cgColor }
        gradient.locations = theme.gradientLocations.map { NSNumber(value: $0) }
        gradient.startPoint = theme.gradientStart
        gradient.endPoint = theme.gradientEnd
        gradient.opacity = Float(opacity)
        layer.addSublayer(gradient)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        CATransaction.commit()
    }
}
