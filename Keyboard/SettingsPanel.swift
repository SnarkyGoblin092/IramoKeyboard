import UIKit

protocol SettingsPanelDelegate: AnyObject {
    func settingsPanelDidClose(_ panel: SettingsPanel)
}

/// A small fallback panel, only reachable (gear tool) when the app's settings cannot reach the
/// keyboard because no App Group is available. The full settings live in the HunKeys app.
final class SettingsPanel: UIView {
    weak var delegate: SettingsPanelDelegate?

    private let hasFullAccess: Bool
    private let scroll = UIScrollView()
    private let stack = UIStackView()

    init(hasFullAccess: Bool) {
        self.hasFullAccess = hasFullAccess
        super.init(frame: .zero)
        backgroundColor = Theme.panelBackground
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func build() {
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 12
        addSubview(scroll)
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),

            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32)
        ])

        let settings = Settings.shared

        let title = UILabel()
        title.text = "HunKeys quick settings"
        title.font = UIFont.boldSystemFont(ofSize: 17)
        let done = UIButton(type: .system)
        done.setTitle("Done", for: .normal)
        done.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
        done.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.settingsPanelDidClose(self)
        }, for: .touchUpInside)
        let header = UIStackView(arrangedSubviews: [title, UIView(), done])
        header.axis = .horizontal
        header.alignment = .center
        stack.addArrangedSubview(header)

        let note = UILabel()
        note.numberOfLines = 0
        note.font = UIFont.systemFont(ofSize: 12)
        note.textColor = UIColor.systemOrange
        note.text = "The HunKeys app can't reach this keyboard on this install (no App Group), so the essentials are here. Try the \"App Group\" IPA to use the full settings in the app."
        stack.addArrangedSubview(note)

        addSlider(title: "Hold delay",
                  lower: Float(Settings.holdDelayRange.lowerBound),
                  upper: Float(Settings.holdDelayRange.upperBound),
                  value: Float(settings.holdDelay),
                  format: { String(format: "%.2f s", Double($0)) },
                  onChange: { Settings.shared.holdDelay = Double($0) })

        addSlider(title: "Vibration strength",
                  lower: 0,
                  upper: 1,
                  value: Float(settings.vibrationStrength),
                  format: { $0 < 0.01 ? "Off" : "\(Int((Double($0) * 100).rounded()))%" },
                  onChange: { Settings.shared.vibrationStrength = Double($0) },
                  onRelease: { Haptics.shared.keyPress() })

        if !hasFullAccess {
            let access = UILabel()
            access.numberOfLines = 0
            access.font = UIFont.systemFont(ofSize: 12)
            access.textColor = UIColor.systemOrange
            access.text = "Vibration needs \"Allow Full Access\": Settings > General > Keyboard > Keyboards > HunKeys."
            stack.addArrangedSubview(access)
        }

        addSwitch(title: "Swipe typing", isOn: settings.swipeEnabled) { Settings.shared.swipeEnabled = $0 }
        addSwitch(title: "Word suggestions", isOn: settings.suggestionsEnabled) { Settings.shared.suggestionsEnabled = $0 }
        addSwitch(title: "Emoji suggestions", isOn: settings.emojiSuggestionsEnabled) { Settings.shared.emojiSuggestionsEnabled = $0 }
        addSwitch(title: "Auto-capitalize", isOn: settings.autoCapitalize) { Settings.shared.autoCapitalize = $0 }
        addSwitch(title: "Space-bar cursor control", isOn: settings.cursorControl) { Settings.shared.cursorControl = $0 }
        addSwitch(title: "Click sound", isOn: settings.clickSound) { Settings.shared.clickSound = $0 }
    }

    private func addSlider(title: String,
                           lower: Float,
                           upper: Float,
                           value: Float,
                           format: @escaping (Float) -> String,
                           onChange: @escaping (Float) -> Void,
                           onRelease: (() -> Void)? = nil) {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 15)
        label.text = "\(title): \(format(value))"

        let slider = UISlider()
        slider.minimumValue = lower
        slider.maximumValue = upper
        slider.value = value
        slider.addAction(UIAction { [weak label, weak slider] _ in
            guard let label = label, let slider = slider else { return }
            label.text = "\(title): \(format(slider.value))"
            onChange(slider.value)
        }, for: .valueChanged)
        if let onRelease = onRelease {
            slider.addAction(UIAction { _ in onRelease() }, for: [.touchUpInside, .touchUpOutside])
        }

        let box = UIStackView(arrangedSubviews: [label, slider])
        box.axis = .vertical
        box.spacing = 4
        stack.addArrangedSubview(box)
    }

    private func addSwitch(title: String, isOn: Bool, onChange: @escaping (Bool) -> Void) {
        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 15)

        let toggle = UISwitch()
        toggle.isOn = isOn
        toggle.addAction(UIAction { [weak toggle] _ in
            if let toggle = toggle { onChange(toggle.isOn) }
        }, for: .valueChanged)

        let row = UIStackView(arrangedSubviews: [label, toggle])
        row.axis = .horizontal
        row.alignment = .center
        stack.addArrangedSubview(row)
    }
}
