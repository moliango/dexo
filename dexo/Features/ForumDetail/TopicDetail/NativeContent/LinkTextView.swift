import UIKit

/// A UITextView subclass that disables text selection while preserving link tap interaction.
/// `isSelectable` remains `true` (required for link detection), but selection handles and
/// copy/paste menus are suppressed.
final class LinkTextView: UITextView {
    override var selectedTextRange: UITextRange? {
        get { nil }
        set { }
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        false
    }
}
