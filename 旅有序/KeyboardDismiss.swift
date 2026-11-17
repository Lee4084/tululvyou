import SwiftUI
import UIKit

/// A non-interactive view that listens for taps anywhere in the app window.
/// It leaves taps inside text inputs alone and never cancels control touches.
struct WindowKeyboardDismissInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        let coordinator = context.coordinator
        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window else { return }
            coordinator.install(in: window)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var window: UIWindow?
        private var recognizer: UITapGestureRecognizer?

        func install(in window: UIWindow) {
            guard self.window !== window else { return }
            uninstall()
            let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            tap.cancelsTouchesInView = false
            tap.delegate = self
            window.addGestureRecognizer(tap)
            recognizer = tap
            self.window = window
        }

        func uninstall() {
            if let recognizer { window?.removeGestureRecognizer(recognizer) }
            recognizer = nil
            window = nil
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var touchedView: UIView? = touch.view
            while let current = touchedView {
                if current is UITextField || current is UITextView { return false }
                touchedView = current.superview
            }
            return true
        }

        @objc private func dismissKeyboard() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}
