import UIKit

struct Suggestion {
    enum Kind {
        case literal           // exactly what has been typed so far
        case word              // dictionary completion
        case emoji             // emoji that matches the word
        case swipeAlternative  // another reading of the word that was just swiped
    }
    let text: String
    let kind: Kind
}

protocol SuggestionBarDelegate: AnyObject {
    func suggestionBar(_ bar: SuggestionBar, didSelect suggestion: Suggestion)
    func suggestionBarDidTapSettings(_ bar: SuggestionBar)
}

/// Settings button + four suggestion slots (words and emoji).
final class SuggestionBar: UIView {
    weak var delegate: SuggestionBarDelegate?

    private let settingsButton = UIButton(type: .system)
    private var slotButtons: [UIButton] = []
    private var suggestions: [Suggestion] = []
    private let slotCount = 4

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.clear

        settingsButton.setImage(UIImage(systemName: "gearshape"), for: .normal)
        settingsButton.tintColor = UIColor.secondaryLabel
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        addSubview(settingsButton)

        for index in 0..<slotCount {
            let button = UIButton(type: .system)
            button.tag = index
            button.setTitleColor(UIColor.label, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 17)
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.6
            button.titleLabel?.lineBreakMode = .byTruncatingTail
            button.addTarget(self, action: #selector(slotTapped(_:)), for: .touchUpInside)
            addSubview(button)
            slotButtons.append(button)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(_ newSuggestions: [Suggestion]) {
        suggestions = Array(newSuggestions.prefix(slotCount))
        for (index, button) in slotButtons.enumerated() {
            if index < suggestions.count {
                let item = suggestions[index]
                button.setTitle(item.text, for: .normal)
                button.titleLabel?.font = UIFont.systemFont(ofSize: item.kind == .emoji ? 26 : 17)
                button.isEnabled = true
            } else {
                button.setTitle(nil, for: .normal)
                button.isEnabled = false
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let settingsWidth: CGFloat = 40
        settingsButton.frame = CGRect(x: 4, y: 0, width: settingsWidth, height: bounds.height)
        let slotWidth = (bounds.width - settingsWidth - 8) / CGFloat(slotCount)
        for (index, button) in slotButtons.enumerated() {
            button.frame = CGRect(x: settingsWidth + 4 + CGFloat(index) * slotWidth,
                                  y: 0,
                                  width: slotWidth,
                                  height: bounds.height)
        }
    }

    @objc private func settingsTapped() {
        delegate?.suggestionBarDidTapSettings(self)
    }

    @objc private func slotTapped(_ sender: UIButton) {
        guard sender.tag < suggestions.count else { return }
        delegate?.suggestionBar(self, didSelect: suggestions[sender.tag])
    }
}
