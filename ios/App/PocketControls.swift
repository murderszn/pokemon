import SwiftUI
import UIKit

/// A Game Boy button that reports its held state, including when the finger leaves the glass.
struct PocketTouchButton: UIViewRepresentable {
    let key: GameBoyButton
    let color: UIColor
    let label: String
    let onChange: (GameBoyButton, Bool) -> Void

    func makeUIView(context: Context) -> MultiTouchButtonView {
        let view = MultiTouchButtonView()
        view.key = key
        view.tint = color
        view.label = label
        view.onChange = onChange
        return view
    }

    func updateUIView(_ view: MultiTouchButtonView, context: Context) {
        view.key = key
        view.tint = color
        view.label = label
        view.onChange = onChange
    }
}

final class MultiTouchButtonView: UIView {
    var key: GameBoyButton = .a
    var tint: UIColor = .systemRed
    var label = "A"
    var onChange: ((GameBoyButton, Bool) -> Void)?
    private var heldTouches = Set<ObjectIdentifier>()
    private let title = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isOpaque = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 2
        layer.shadowOffset = CGSize(width: 0, height: 3)
        title.textAlignment = .center
        title.font = .systemFont(ofSize: 20, weight: .black)
        title.textColor = UIColor.white.withAlphaComponent(0.92)
        title.isUserInteractionEnabled = false
        addSubview(title)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
        title.frame = bounds
    }

    override func draw(_ rect: CGRect) {
        let path = UIBezierPath(ovalIn: bounds.insetBy(dx: 2, dy: 2))
        tint.setFill()
        path.fill()
        UIColor.white.withAlphaComponent(0.24).setStroke()
        path.lineWidth = 2
        path.stroke()
        title.text = label
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let wasEmpty = heldTouches.isEmpty
        touches.forEach { heldTouches.insert(ObjectIdentifier($0)) }
        if wasEmpty && !heldTouches.isEmpty { onChange?(key, true) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { release(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { release(touches) }

    private func release(_ touches: Set<UITouch>) {
        touches.forEach { heldTouches.remove(ObjectIdentifier($0)) }
        if heldTouches.isEmpty { onChange?(key, false) }
    }
}

/// A multi-touch, sliding D-pad. Each contact independently contributes its current direction.
struct PocketDPad: UIViewRepresentable {
    let onChange: (GameBoyButton, Bool) -> Void

    func makeUIView(context: Context) -> MultiTouchDPadView {
        let view = MultiTouchDPadView()
        view.onChange = onChange
        return view
    }

    func updateUIView(_ view: MultiTouchDPadView, context: Context) { view.onChange = onChange }
}

final class MultiTouchDPadView: UIView {
    var onChange: ((GameBoyButton, Bool) -> Void)?
    private var directionsByTouch: [ObjectIdentifier: Set<GameBoyButton>] = [:]
    private var active = Set<GameBoyButton>()
    private let cross = CAShapeLayer()
    private let center = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isOpaque = false
        cross.fillColor = UIColor(white: 0.19, alpha: 1).cgColor
        cross.strokeColor = UIColor(white: 0.08, alpha: 0.8).cgColor
        cross.lineWidth = 2
        center.fillColor = UIColor(white: 0.14, alpha: 1).cgColor
        layer.addSublayer(cross)
        layer.addSublayer(center)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side = min(bounds.width, bounds.height)
        let unit = side / 3
        let x = (bounds.width - side) / 2
        let y = (bounds.height - side) / 2
        let path = UIBezierPath()
        path.move(to: CGPoint(x: x + unit, y: y)); path.addLine(to: CGPoint(x: x + 2 * unit, y: y))
        path.addLine(to: CGPoint(x: x + 2 * unit, y: y + unit)); path.addLine(to: CGPoint(x: x + 3 * unit, y: y + unit))
        path.addLine(to: CGPoint(x: x + 3 * unit, y: y + 2 * unit)); path.addLine(to: CGPoint(x: x + 2 * unit, y: y + 2 * unit))
        path.addLine(to: CGPoint(x: x + 2 * unit, y: y + 3 * unit)); path.addLine(to: CGPoint(x: x + unit, y: y + 3 * unit))
        path.addLine(to: CGPoint(x: x + unit, y: y + 2 * unit)); path.addLine(to: CGPoint(x: x, y: y + 2 * unit))
        path.addLine(to: CGPoint(x: x, y: y + unit)); path.addLine(to: CGPoint(x: x + unit, y: y + unit)); path.close()
        cross.path = path.cgPath
        center.path = UIBezierPath(ovalIn: CGRect(x: x + unit * 1.12, y: y + unit * 1.12, width: unit * 0.76, height: unit * 0.76)).cgPath
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { update(touches) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { update(touches) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { end(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { end(touches) }

    private func update(_ touches: Set<UITouch>) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            let p = touch.location(in: self)
            let dx = p.x - bounds.midX
            let dy = p.y - bounds.midY
            let distance = hypot(dx, dy)
            let next: Set<GameBoyButton>
            if distance < min(bounds.width, bounds.height) * 0.12 {
                next = []
            } else {
                var directions = Set<GameBoyButton>()
                if abs(dx) > abs(dy) * 0.42 { directions.insert(dx < 0 ? .left : .right) }
                if abs(dy) > abs(dx) * 0.42 { directions.insert(dy < 0 ? .up : .down) }
                next = directions
            }
            directionsByTouch[id] = next
        }
        publish()
    }

    private func end(_ touches: Set<UITouch>) {
        touches.forEach { directionsByTouch.removeValue(forKey: ObjectIdentifier($0)) }
        publish()
    }

    private func publish() {
        let next = directionsByTouch.values.reduce(into: Set<GameBoyButton>()) { $0.formUnion($1) }
        for key in active.subtracting(next) { onChange?(key, false) }
        for key in next.subtracting(active) { onChange?(key, true) }
        active = next
    }
}
