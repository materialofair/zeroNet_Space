import SwiftUI
import UIKit

/// Keeps system Back and UIKit interactive transitions, with a save gate scoped to this diary.
/// The native interactive transition still owns completion/cancellation.
struct DiaryBackGesture: UIViewControllerRepresentable {
    var canLeave: () -> Bool
    var onBack: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIViewController(context: Context) -> Host {
        let host = Host()
        host.install = { [weak coordinator = context.coordinator, weak host] in
            guard let host else { return }
            coordinator?.attach(from: host)
        }
        context.coordinator.canLeave = canLeave
        context.coordinator.onBack = onBack
        return host
    }
    func updateUIViewController(_ host: Host, context: Context) {
        context.coordinator.canLeave = canLeave
        context.coordinator.onBack = onBack
        host.install?()
    }
    static func dismantleUIViewController(_ host: Host, coordinator: Coordinator) {
        host.install = nil
        coordinator.restore()
    }

    final class Host: UIViewController {
        var install: (() -> Void)?
        override func viewDidLoad() { super.viewDidLoad(); view.isUserInteractionEnabled = false }
        override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); install?() }
        override func didMove(toParent parent: UIViewController?) { super.didMove(toParent: parent); install?() }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var canLeave: () -> Bool = { false }
        var onBack: () -> Void = {}
        private weak var navigation: UINavigationController?
        private weak var owner: UIViewController?
        private weak var previous: (any UIGestureRecognizerDelegate)?
        private var wasEnabled = true
        private weak var item: UINavigationItem?
        private var previousAction: UIAction?
        private let actionID = UIAction.Identifier("diary.back." + UUID().uuidString)
        private weak var contentRecognizer: UIGestureRecognizer?
        private var contentGate: LeadingContentGate?
        private var contentWasEnabled = true

        final class LeadingContentGate: NSObject, UIGestureRecognizerDelegate {
            weak var previous: (any UIGestureRecognizerDelegate)?
            var canBegin: () -> Bool = { false }
            override func responds(to selector: Selector!) -> Bool {
                super.responds(to: selector) || previous?.responds(to: selector) == true
            }
            override func forwardingTarget(for selector: Selector!) -> Any? {
                if previous?.responds(to: selector) == true { return previous }
                return super.forwardingTarget(for: selector)
            }
            func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
                guard let view = recognizer.view else { return false }
                return Self.beginsAtLeadingEdge(in: view, point: touch.location(in: view))
                    && (previous?.gestureRecognizer?(recognizer, shouldReceive: touch) ?? true)
            }
            static func beginsAtLeadingEdge(in view: UIView, point: CGPoint) -> Bool {
                guard view.bounds.contains(point) else { return false }
                // Leave the text container's own leading padding available for selection.
                return view.effectiveUserInterfaceLayoutDirection == .rightToLeft
                    ? point.x >= view.bounds.maxX - 24 : point.x <= view.bounds.minX + 24
            }
            func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
                (previous?.gestureRecognizerShouldBegin?(recognizer) ?? true) && canBegin()
            }
        }


        override func responds(to selector: Selector!) -> Bool {
            super.responds(to: selector) || previous?.responds(to: selector) == true
        }
        override func forwardingTarget(for selector: Selector!) -> Any? {
            if previous?.responds(to: selector) == true { return previous }
            return super.forwardingTarget(for: selector)
        }

        func attach(from host: UIViewController) {
            guard let nav = host.navigationController,
                  let top = nav.topViewController, nav.viewControllers.count > 1,
                  let gesture = nav.interactivePopGestureRecognizer else { return }
            var ancestor: UIViewController? = host
            while let current = ancestor, current !== top { ancestor = current.parent }
            guard ancestor === top else { return }
            if navigation !== nav { restore() }
            if item !== top.navigationItem {
                item = top.navigationItem; previousAction = item?.backAction
            }
            if item?.backAction?.identifier != actionID {
                item?.backAction = UIAction(title: String(localized: "diary.back"), identifier: actionID) { [weak self] _ in
                    self?.requestBack()
                }
            }
            if gesture.delegate !== self {
                previous = gesture.delegate; wasEnabled = gesture.isEnabled
                navigation = nav; owner = top
                gesture.delegate = self; gesture.isEnabled = true
            }
            if #available(iOS 26.0, *), let content = nav.interactiveContentPopGestureRecognizer,
               content !== gesture, (contentGate == nil || contentRecognizer !== content || content.delegate !== contentGate) {
                restoreContent()
                let gate = LeadingContentGate()
                gate.previous = content.delegate
                gate.canBegin = { [weak self] in self?.canNavigate() ?? false }
                contentRecognizer = content; contentGate = gate; contentWasEnabled = content.isEnabled
                content.delegate = gate
            }
        }
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (previous?.gestureRecognizerShouldBegin?(gestureRecognizer) ?? true) && canNavigate()
        }
        func requestBack() {
            if canNavigate() { onBack() }
        }
        func canNavigate() -> Bool {
            guard let nav = navigation, nav.topViewController === owner,
                  nav.viewControllers.count > 1, nav.transitionCoordinator == nil else { return false }
            // Save before UIKit can remove the editor. A failed save vetoes the gesture.
            // A cancelled native transition retains the same view, text and undo stack.
            return canLeave()
        }
        private func restoreContent() {
            if let contentRecognizer, contentRecognizer.delegate === contentGate {
                contentRecognizer.delegate = contentGate?.previous
                contentRecognizer.isEnabled = contentWasEnabled
            }
            contentRecognizer = nil; contentGate = nil
        }
        func restore() {
            restoreContent()
            if item?.backAction?.identifier == actionID { item?.backAction = previousAction }
            item = nil; previousAction = nil
            if let gesture = navigation?.interactivePopGestureRecognizer, gesture.delegate === self {
                gesture.delegate = previous; gesture.isEnabled = wasEnabled
            }
            navigation = nil; owner = nil; previous = nil
        }
    }
}
