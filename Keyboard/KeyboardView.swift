import UIKit

protocol KeyboardViewDelegate: AnyObject {
    func keyboardView(_ view: KeyboardView, didTap action: KeyAction)
    func keyboardView(_ view: KeyboardView, didSelectAlternate text: String)
    func keyboardView(_ view: KeyboardView, didMoveCursorBy offset: Int)
    func keyboardViewDidRequestDeleteWord(_ view: KeyboardView)
    func keyboardViewDidHoldGlobe(_ view: KeyboardView)
    /// A quick horizontal swipe on the space bar: +1 = next language, -1 = previous.
    func keyboardView(_ view: KeyboardView, didSwipeSpaceBy direction: Int)
    func keyboardView(_ view: KeyboardView, didFinishSwipe path: [CGPoint])
}

/// Draws the keys and owns ALL touch handling, so that
///  - several fingers can type at once,
///  - holding a key shows its accents / alternatives (after the user's hold delay),
///  - holding the space bar and sliding moves the text cursor,
///  - sliding left from backspace deletes word by word,
///  - dragging across the letter keys is recognised as swipe typing.
final class KeyboardView: UIView {
    weak var delegate: KeyboardViewDelegate?
    /// Decides how letters are capitalised (Turkish i -> İ).
    var typingLanguage: Language = .english
    /// Popups are added here (the controller's root view) so they can rise above the first row.
    weak var popupHost: UIView?

    private var rows: [[KeySpec]] = []
    private var keyViews: [[KeyView]] = []
    private var hitRects: [[CGRect]] = []
    private var page: KeyboardPage = .letters
    private var shift: ShiftState = .off
    private var returnProminent = false

    private let preview = KeyPreviewView()
    private var alternatesPopup: AlternatesPopupView?
    private let trailLayer = CAShapeLayer()

    private final class TouchState {
        var key: KeyView?
        let startPoint: CGPoint
        var path: [CGPoint]
        var startedOnLetter = false
        var startedOnSpace = false
        var isSwiping = false
        var popupActive = false
        var handledByHold = false
        var isCursorMode = false
        var languageSwiped = false
        var cursorMoved = false
        var cursorLastX: CGFloat = 0
        var cursorRemainder: CGFloat = 0
        var isWordDeleting = false
        var wordSteps = 0
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

        trailLayer.strokeColor = Theme.accent.withAlphaComponent(0.55).cgColor
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
        applyReturnProminence()
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

    /// The return key turns accent-coloured for actions like Go / Search / Send.
    func setReturnProminent(_ prominent: Bool) {
        returnProminent = prominent
        applyReturnProminence()
    }

    private func applyReturnProminence() {
        for row in keyViews {
            for key in row where key.spec.action == .enter {
                key.isProminent = returnProminent
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
                        key.label.text = (shift == .off) ? text : typingLanguage.uppercase(text)
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

        let sidePadding: CGFloat = 1
        let verticalPadding: CGFloat = 4
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
                let key = keyViews[r][c]
                if key.transform == .identity {
                    key.frame = hit.insetBy(dx: 3, dy: 5.5)
                }
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

            if state.isCursorMode {
                moveCursor(state, to: point)
                continue
            }
            if state.isSwiping {
                updateTrail(state.path)
                continue
            }
            if state.popupActive, let popup = alternatesPopup {
                let hostPoint = touch.location(in: popup.superview)
                popup.updateHighlight(hostX: hostPoint.x)
                continue
            }
            if let key = state.key, key.spec.action == .backspace {
                slideFromBackspace(state, to: point)
                continue
            }
            if state.startedOnSpace {
                // A quick sideways swipe (before the hold delay turns the bar into a trackpad)
                // switches the language: swipe left = next, swipe right = previous.
                if state.languageSwiped { continue }
                let dx = point.x - state.startPoint.x
                let dy = point.y - state.startPoint.y
                if abs(dx) > 28 && abs(dx) > abs(dy) {
                    state.languageSwiped = true
                    state.handledByHold = true
                    state.holdTimer?.invalidate()
                    state.holdTimer = nil
                    state.key?.isPressed = false
                    hidePreview()
                    Haptics.shared.keyPress()
                    delegate?.keyboardView(self, didSwipeSpaceBy: dx < 0 ? 1 : -1)
                    continue
                }
                if abs(dx) > 10 || abs(dy) > 10 { continue }   // stay on the space bar, no key slide
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
        case .space:
            state.startedOnSpace = true
            if Settings.shared.cursorControl {
                startHoldTimer(state, delay: max(0.2, Settings.shared.holdDelay))
            }
        default:
            if !key.spec.alternates.isEmpty || key.spec.action == .emoji {
                startHoldTimer(state, delay: Settings.shared.holdDelay)
            }
        }
    }

    private func slide(_ state: TouchState, to point: CGPoint) {
        guard let index = keyIndex(at: point) else { return }
        let newKey = keyViews[index.row][index.col]
        guard newKey !== state.key else { return }

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
        if !newKey.spec.alternates.isEmpty || newKey.spec.action == .emoji {
            startHoldTimer(state, delay: Settings.shared.holdDelay)
        }
    }

    private func makeTimer(after interval: TimeInterval, repeats: Bool, _ block: @escaping () -> Void) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: repeats) { _ in block() }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    private func startHoldTimer(_ state: TouchState, delay: TimeInterval) {
        state.holdTimer?.invalidate()
        state.holdTimer = makeTimer(after: delay, repeats: false) { [weak self, weak state] in
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
        switch key.spec.action {
        case .space:
            if Settings.shared.cursorControl && !state.languageSwiped {
                beginCursorMode(state, at: state.path.last ?? state.startPoint)
            }
        case .emoji:
            // Holding the emoji key hands over to the next installed keyboard.
            state.handledByHold = true
            Haptics.shared.keyPress()
            delegate?.keyboardViewDidHoldGlobe(self)
        default:
            if !key.spec.alternates.isEmpty {
                showAlternates(for: key, state: state)
            }
        }
    }

    private func finish(_ state: TouchState, cancelled: Bool) {
        state.holdTimer?.invalidate()
        state.repeatTimer?.invalidate()
        state.key?.isPressed = false
        hidePreview()

        if state.isCursorMode {
            setCursorAppearance(false)
            return
        }
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
        if state.isWordDeleting { return }
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
        setCursorAppearance(false)
        trailLayer.path = nil
    }

    // MARK: Cursor control (hold + slide on the space bar)

    private func beginCursorMode(_ state: TouchState, at point: CGPoint) {
        state.isCursorMode = true
        state.holdTimer?.invalidate()
        state.holdTimer = nil
        state.cursorLastX = point.x
        state.cursorRemainder = 0
        hidePreview()
        setCursorAppearance(true)
        Haptics.shared.keyPress()
    }

    private func moveCursor(_ state: TouchState, to point: CGPoint) {
        let step = max(6, bounds.width / 40)
        state.cursorRemainder += point.x - state.cursorLastX
        state.cursorLastX = point.x
        let steps = Int(state.cursorRemainder / step)       // rounds toward zero
        if steps != 0 {
            state.cursorMoved = true
            state.cursorRemainder -= CGFloat(steps) * step
            delegate?.keyboardView(self, didMoveCursorBy: steps)
            Haptics.shared.tick()
        }
    }

    /// While the space bar is a trackpad the letters fade out, like the system keyboard.
    private func setCursorAppearance(_ on: Bool) {
        let alpha: CGFloat = on ? 0.12 : 1.0
        UIView.animate(withDuration: 0.12) {
            for row in self.keyViews {
                for key in row {
                    key.setContentAlpha(alpha)
                }
            }
        }
    }

    // MARK: Delete words (slide left from backspace)

    private func slideFromBackspace(_ state: TouchState, to point: CGPoint) {
        guard Settings.shared.deleteSwipe else { return }
        let dx = point.x - state.startPoint.x
        let activation: CGFloat = 26
        guard dx < -activation else { return }

        if !state.isWordDeleting {
            state.isWordDeleting = true
            state.holdTimer?.invalidate()
            state.repeatTimer?.invalidate()
        }
        let steps = Int((-dx - activation) / 38) + 1
        while state.wordSteps < steps {
            state.wordSteps += 1
            delegate?.keyboardViewDidRequestDeleteWord(self)
            Haptics.shared.tick()
        }
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
        trailLayer.strokeColor = Theme.accent.withAlphaComponent(0.55).cgColor
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
        guard Settings.shared.keyPopups else {
            hidePreview()
            return
        }
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
        let items = key.spec.alternates.map { uppercase ? typingLanguage.uppercase($0) : $0 }
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
