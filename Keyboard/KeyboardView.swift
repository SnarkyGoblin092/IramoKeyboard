import UIKit

protocol KeyboardViewDelegate: AnyObject {
    func keyboardView(_ view: KeyboardView, didTap action: KeyAction)
    func keyboardView(_ view: KeyboardView, didSelectAlternate text: String)
    func keyboardViewDidHoldGlobe(_ view: KeyboardView)
    func keyboardView(_ view: KeyboardView, didFinishSwipe path: [CGPoint])
}

/// Draws the keys and owns ALL touch handling, so that
///  - several fingers can type at once,
///  - holding a key shows its accents / alternatives (after the user's hold delay),
///  - dragging across the letter keys is recognised as swipe typing.
final class KeyboardView: UIView {
    weak var delegate: KeyboardViewDelegate?
    /// Popups are added here (the controller's root view) so they can rise above the first row.
    weak var popupHost: UIView?

    private var rows: [[KeySpec]] = []
    private var keyViews: [[KeyView]] = []
    private var hitRects: [[CGRect]] = []
    private var page: KeyboardPage = .letters
    private var shift: ShiftState = .off

    private let preview = KeyPreviewView()
    private var alternatesPopup: AlternatesPopupView?
    private let trailLayer = CAShapeLayer()

    private final class TouchState {
        var key: KeyView?
        let startPoint: CGPoint
        var path: [CGPoint]
        var startedOnLetter = false
        var isSwiping = false
        var popupActive = false
        var handledByHold = false
        var holdTimer: Timer?
        var repeatTimer: Timer?

        init(start: CGPoint) {
            startPoint = start
            path = [start]
        }
    }

    private var states: [UITouch: TouchState] = [:]

    // MARK: Setup

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = UIColor.clear

        trailLayer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.5).cgColor
        trailLayer.fillColor = nil
        trailLayer.lineWidth = 7
        trailLayer.lineCap = .round
        trailLayer.lineJoin = .round
        trailLayer.zPosition = 100
        layer.addSublayer(trailLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(rows newRows: [[KeySpec]], page newPage: KeyboardPage, shift newShift: ShiftState) {
        cancelAllTouches()
        for row in keyViews {
            for key in row { key.removeFromSuperview() }
        }
        rows = newRows
        page = newPage
        shift = newShift
        var built: [[KeyView]] = []
        for row in newRows {
            var builtRow: [KeyView] = []
            for spec in row {
                let key = KeyView(spec: spec)
                if !spec.isSpacer { addSubview(key) }
                builtRow.append(key)
            }
            built.append(builtRow)
        }
        keyViews = built
        hitRects = []
        applyShift()
        setNeedsLayout()
        layoutIfNeeded()   // hit areas must match the new rows before the next touch
    }

    func setShift(_ newShift: ShiftState) {
        shift = newShift
        applyShift()
    }

    func setReturnTitle(_ title: String) {
        for row in keyViews {
            for key in row where key.spec.action == .enter {
                key.setTitle(title)
            }
        }
    }

    private func applyShift() {
        for (r, row) in rows.enumerated() {
            for (c, spec) in row.enumerated() {
                let key = keyViews[r][c]
                switch spec.action {
                case .character(let text):
                    if page == .letters && text.count == 1 && text.first?.isLetter == true {
                        key.label.text = (shift == .off) ? text : text.uppercased()
                    }
                case .shift:
                    key.isActive = (shift != .off)
                    switch shift {
                    case .off: key.setIcon("shift")
                    case .once: key.setIcon("shift.fill")
                    case .locked: key.setIcon("capslock.fill")
                    }
                default:
                    break
                }
            }
        }
    }

    // MARK: Geometry (also used by swipe typing)

    /// Centre of every letter key, in this view's coordinates. Only meaningful on the letters page.
    func letterCenters() -> [Character: CGPoint] {
        var centers: [Character: CGPoint] = [:]
        for (r, row) in rows.enumerated() {
            for (c, spec) in row.enumerated() {
                if case .character(let text) = spec.action,
                   text.count == 1,
                   let letter = text.lowercased().first,
                   letter.isLetter {
                    let frame = keyViews[r][c].frame
                    centers[letter] = CGPoint(x: frame.midX, y: frame.midY)
                }
            }
        }
        return centers
    }

    func letterKeySize() -> CGSize {
        for (r, row) in rows.enumerated() {
            for (c, spec) in row.enumerated() {
                if case .character(let text) = spec.action, text.count == 1, text.first?.isLetter == true {
                    return keyViews[r][c].frame.size
                }
            }
        }
        return CGSize(width: bounds.width / 10, height: 44)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        trailLayer.frame = bounds
        guard !rows.isEmpty else { return }

        let sidePadding: CGFloat = 3
        let verticalPadding: CGFloat = 6
        let rowHeight = (bounds.height - verticalPadding * 2) / CGFloat(rows.count)

        hitRects = []
        for (r, row) in rows.enumerated() {
            let totalWeight = row.reduce(0) { $0 + $1.weight }
            let unit = (bounds.width - sidePadding * 2) / totalWeight
            var x = sidePadding
            let y = verticalPadding + CGFloat(r) * rowHeight
            var rects: [CGRect] = []
            for (c, spec) in row.enumerated() {
                let width = spec.weight * unit
                let hit = CGRect(x: x, y: y, width: width, height: rowHeight)
                rects.append(hit)
                keyViews[r][c].frame = hit.insetBy(dx: 3, dy: 4)
                x += width
            }
            hitRects.append(rects)
        }
    }

    /// The key under (or nearest to) a point. Rows and keys tile the whole area, so there are no dead gaps.
    private func keyIndex(at point: CGPoint) -> (row: Int, col: Int)? {
        guard !hitRects.isEmpty, hitRects.count == rows.count, keyViews.count == rows.count else { return nil }

        var bestRow = 0
        var bestRowDistance = CGFloat.greatestFiniteMagnitude
        for (index, rects) in hitRects.enumerated() {
            guard let sample = rects.first else { continue }
            let distance: CGFloat
            if point.y < sample.minY {
                distance = sample.minY - point.y
            } else if point.y > sample.maxY {
                distance = point.y - sample.maxY
            } else {
                distance = 0
            }
            if distance < bestRowDistance {
                bestRowDistance = distance
                bestRow = index
            }
        }

        var bestCol: Int? = nil
        var bestColDistance = CGFloat.greatestFiniteMagnitude
        for (index, rect) in hitRects[bestRow].enumerated() where !rows[bestRow][index].isSpacer {
            let distance: CGFloat
            if point.x < rect.minX {
                distance = rect.minX - point.x
            } else if point.x > rect.maxX {
                distance = point.x - rect.maxX
            } else {
                distance = 0
            }
            if distance < bestColDistance {
                bestColDistance = distance
                bestCol = index
            }
        }
        guard let col = bestCol else { return nil }
        return (row: bestRow, col: col)
    }

    // MARK: Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            let state = TouchState(start: point)
            states[touch] = state
            guard let index = keyIndex(at: point) else { continue }
            press(state, key: keyViews[index.row][index.col])
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let state = states[touch] else { continue }
            let point = touch.location(in: self)
            state.path.append(point)

            if state.isSwiping {
                updateTrail(state.path)
                continue
            }
            if state.popupActive, let popup = alternatesPopup {
                let hostPoint = touch.location(in: popup.superview)
                popup.updateHighlight(hostX: hostPoint.x)
                continue
            }
            if shouldStartSwipe(state, at: point) {
                beginSwipe(state)
                continue
            }
            slide(state, to: point)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let state = states.removeValue(forKey: touch) {
                finish(state, cancelled: false)
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let state = states.removeValue(forKey: touch) {
                finish(state, cancelled: true)
            }
        }
    }

    // MARK: Press / hold / slide

    private func press(_ state: TouchState, key: KeyView) {
        state.key = key
        key.isPressed = true
        Haptics.shared.keyPress()
        showPreview(for: key)

        if case .character(let text) = key.spec.action, text.count == 1, text.first?.isLetter == true {
            state.startedOnLetter = true
        }

        switch key.spec.action {
        case .backspace:
            delegate?.keyboardView(self, didTap: .backspace)
            startBackspaceRepeat(state)
        default:
            if !key.spec.alternates.isEmpty || key.spec.action == .nextLanguage {
                startHoldTimer(state)
            }
        }
    }

    private func slide(_ state: TouchState, to point: CGPoint) {
        guard let index = keyIndex(at: point) else { return }
        let newKey = keyViews[index.row][index.col]
        guard newKey !== state.key else { return }
        if state.key?.spec.action == .backspace { return }   // already deleting; don't change key

        state.holdTimer?.invalidate()
        state.holdTimer = nil
        state.key?.isPressed = false

        if newKey.spec.action == .backspace {
            state.key = nil            // sliding onto backspace must not delete anything
            hidePreview()
            return
        }
        state.key = newKey
        newKey.isPressed = true
        showPreview(for: newKey)
        if !newKey.spec.alternates.isEmpty || newKey.spec.action == .nextLanguage {
            startHoldTimer(state)
        }
    }

    private func makeTimer(after interval: TimeInterval, repeats: Bool, _ block: @escaping () -> Void) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: repeats) { _ in block() }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    private func startHoldTimer(_ state: TouchState) {
        state.holdTimer?.invalidate()
        state.holdTimer = makeTimer(after: Settings.shared.holdDelay, repeats: false) { [weak self, weak state] in
            guard let self = self, let state = state else { return }
            self.holdFired(state)
        }
    }

    private func startBackspaceRepeat(_ state: TouchState) {
        state.holdTimer?.invalidate()
        state.holdTimer = makeTimer(after: Settings.shared.holdDelay, repeats: false) { [weak self, weak state] in
            guard let self = self, let state = state else { return }
            state.repeatTimer?.invalidate()
            state.repeatTimer = self.makeTimer(after: 0.06, repeats: true) { [weak self] in
                guard let self = self else { return }
                Haptics.shared.keyPress()
                self.delegate?.keyboardView(self, didTap: .backspace)
            }
        }
    }

    private func holdFired(_ state: TouchState) {
        guard let key = state.key, !state.isSwiping else { return }
        if key.spec.action == .nextLanguage {
            state.handledByHold = true
            Haptics.shared.keyPress()
            delegate?.keyboardViewDidHoldGlobe(self)
            return
        }
        if !key.spec.alternates.isEmpty {
            showAlternates(for: key, state: state)
        }
    }

    private func finish(_ state: TouchState, cancelled: Bool) {
        state.holdTimer?.invalidate()
        state.repeatTimer?.invalidate()
        state.key?.isPressed = false
        hidePreview()

        if state.isSwiping {
            fadeTrail()
            if !cancelled { delegate?.keyboardView(self, didFinishSwipe: state.path) }
            return
        }
        if state.popupActive {
            if !cancelled, let popup = alternatesPopup {
                delegate?.keyboardView(self, didSelectAlternate: popup.selectedItem)
            }
            hideAlternates()
            return
        }
        guard !cancelled, !state.handledByHold, let key = state.key else { return }
        if key.spec.action != .backspace {          // backspace already fired on touch-down
            delegate?.keyboardView(self, didTap: key.spec.action)
        }
    }

    private func cancelAllTouches() {
        for state in states.values {
            state.holdTimer?.invalidate()
            state.repeatTimer?.invalidate()
        }
        states.removeAll()
        hidePreview()
        hideAlternates()
        trailLayer.path = nil
    }

    // MARK: Swipe typing

    private func shouldStartSwipe(_ state: TouchState, at point: CGPoint) -> Bool {
        guard Settings.shared.swipeEnabled, page == .letters, state.startedOnLetter, states.count == 1 else {
            return false
        }
        let dx = point.x - state.startPoint.x
        let dy = point.y - state.startPoint.y
        let threshold = max(24, bounds.width / 10 * 0.9)
        return dx * dx + dy * dy > threshold * threshold
    }

    private func beginSwipe(_ state: TouchState) {
        state.isSwiping = true
        state.holdTimer?.invalidate()
        state.holdTimer = nil
        state.key?.isPressed = false
        hidePreview()
        trailLayer.removeAllAnimations()
        trailLayer.opacity = 1
        updateTrail(state.path)
    }

    private func updateTrail(_ points: [CGPoint]) {
        guard let first = points.first else { return }
        let path = UIBezierPath()
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        trailLayer.path = path.cgPath
    }

    private func fadeTrail() {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = 0.25
        trailLayer.opacity = 0
        trailLayer.add(fade, forKey: "fade")
    }

    // MARK: Popups

    private func showPreview(for key: KeyView) {
        guard case .character = key.spec.action else {
            hidePreview()
            return
        }
        guard let host = popupHost else { return }
        let text = key.label.text ?? key.spec.title
        guard !text.isEmpty else { return }
        if preview.superview !== host { host.addSubview(preview) }
        preview.show(text: text, keyFrame: convert(key.frame, to: host), hostBounds: host.bounds)
        host.bringSubviewToFront(preview)
    }

    private func hidePreview() {
        preview.removeFromSuperview()
    }

    private func showAlternates(for key: KeyView, state: TouchState) {
        guard let host = popupHost else { return }
        hidePreview()
        let uppercase = (page == .letters && shift != .off)
        let items = key.spec.alternates.map { uppercase ? $0.uppercased() : $0 }
        let popup = AlternatesPopupView(alternates: items,
                                        keyFrame: convert(key.frame, to: host),
                                        hostBounds: host.bounds)
        host.addSubview(popup)
        alternatesPopup = popup
        state.popupActive = true
        Haptics.shared.keyPress()
    }

    private func hideAlternates() {
        alternatesPopup?.removeFromSuperview()
        alternatesPopup = nil
    }
}
