import UIKit

protocol LanguagePickerDelegate: AnyObject {
    func languagePicker(_ picker: LanguagePicker, didSelect language: Language)
    func languagePickerDidClose(_ picker: LanguagePicker)
}

/// A compact overlay that lists the enabled languages (opened from the tool row).
final class LanguagePicker: UIView {
    weak var delegate: LanguagePickerDelegate?

    private let languages: [Language]
    private let current: Language
    private let scroll = UIScrollView()
    private var buttons: [UIButton] = []
    private let closeButton = UIButton(type: .system)

    init(languages: [Language], current: Language) {
        self.languages = languages
        self.current = current
        super.init(frame: .zero)
        backgroundColor = Theme.panelBackground     // opaque: nothing may show through from the keys behind

        addSubview(scroll)
        scroll.showsVerticalScrollIndicator = false

        for (index, language) in languages.enumerated() {
            let button = UIButton(type: .system)
            button.tag = index
            let selected = (language == current)
            button.setTitle("\(language.displayName)  \(language.shortCode)", for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: selected ? .semibold : .regular)
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.7
            button.setTitleColor(selected ? UIColor.white : UIColor.label, for: .normal)
            button.backgroundColor = selected ? Theme.accent : UIColor.tertiarySystemFill
            button.layer.cornerRadius = 10
            button.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
            scroll.addSubview(button)
            buttons.append(button)
        }

        closeButton.setImage(UIImage(systemName: "xmark.circle.fill",
                                     withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)),
                             for: .normal)
        closeButton.tintColor = UIColor.secondaryLabel
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        addSubview(closeButton)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let margin: CGFloat = 12
        let top: CGFloat = 8
        closeButton.frame = CGRect(x: bounds.width - 44, y: top, width: 40, height: 36)

        scroll.frame = CGRect(x: 0, y: top + 40, width: bounds.width, height: max(0, bounds.height - top - 40))
        let columns = bounds.width > 520 ? 4 : 2
        let gap: CGFloat = 8
        let width = (bounds.width - margin * 2 - gap * CGFloat(columns - 1)) / CGFloat(columns)
        let height: CGFloat = 42
        for (index, button) in buttons.enumerated() {
            let row = index / columns
            let column = index % columns
            button.frame = CGRect(x: margin + CGFloat(column) * (width + gap),
                                  y: CGFloat(row) * (height + gap),
                                  width: width,
                                  height: height)
        }
        let rows = (buttons.count + columns - 1) / columns
        scroll.contentSize = CGSize(width: bounds.width, height: CGFloat(rows) * (height + gap) + margin)
    }

    @objc private func tapped(_ sender: UIButton) {
        guard sender.tag < languages.count else { return }
        Haptics.shared.keyPress()
        delegate?.languagePicker(self, didSelect: languages[sender.tag])
    }

    @objc private func closeTapped() {
        Haptics.shared.keyPress()
        delegate?.languagePickerDidClose(self)
    }
}
