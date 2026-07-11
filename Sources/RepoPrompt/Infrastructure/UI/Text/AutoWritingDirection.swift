import AppKit
import SwiftUI

/// Detects right-to-left content for WhatsApp/Google-Docs-style automatic direction.
///
/// Policy: a line (paragraph) is laid out right-to-left when it contains **any** strong
/// right-to-left character — not only when it starts with one. So a line like "Hello مرحبا"
/// becomes right-to-left because it contains an Arabic word. English is left-to-right; the
/// Unicode Bidi Algorithm still renders any Latin runs inside an RTL line correctly.
enum BidiScanner {
    /// True when `text` contains at least one strong right-to-left character.
    static func containsStrongRTL(_ text: Substring) -> Bool {
        for scalar in text.unicodeScalars where isStrongRTL(scalar) {
            return true
        }
        return false
    }

    static func containsStrongRTL(_ text: String) -> Bool {
        containsStrongRTL(text[...])
    }

    /// Strong right-to-left scripts: Hebrew, Arabic (+ supplements/extensions/presentation
    /// forms), Syriac, and Thaana. Persian and Urdu use the Arabic block.
    private static func isStrongRTL(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x0590 ... 0x05FF, // Hebrew
             0x0600 ... 0x06FF, // Arabic
             0x0700 ... 0x074F, // Syriac
             0x0750 ... 0x077F, // Arabic Supplement
             0x0780 ... 0x07BF, // Thaana
             0x08A0 ... 0x08FF, // Arabic Extended-A
             0xFB1D ... 0xFB4F, // Hebrew presentation forms
             0xFB50 ... 0xFDFF, // Arabic presentation forms-A
             0xFE70 ... 0xFEFF: // Arabic presentation forms-B
            true
        default:
            false
        }
    }
}

extension NSAttributedString {
    /// Returns a copy in which every paragraph that contains any right-to-left character is given
    /// an RTL base writing direction and right alignment (WhatsApp/Google-Docs-style auto RTL).
    ///
    /// Paragraphs with no right-to-left character are left byte-for-byte untouched, so existing
    /// left-to-right rendering is unchanged. Fenced code blocks (paragraphs carrying the
    /// `.codeBlockSource` attribute) are skipped so code always stays left-to-right.
    func applyingAutoParagraphWritingDirection() -> NSAttributedString {
        guard length > 0 else { return self }
        let full = string as NSString
        let mutable = NSMutableAttributedString(attributedString: self)
        var didChange = false

        full.enumerateSubstrings(
            in: NSRange(location: 0, length: full.length),
            options: [.byParagraphs, .substringNotRequired]
        ) { _, substringRange, enclosingRange, _ in
            guard substringRange.length > 0 else { return }
            // Fenced code blocks must stay left-to-right regardless of surrounding prose.
            if self.range(substringRange, containsAttribute: .codeBlockSource) { return }

            guard BidiScanner.containsStrongRTL(full.substring(with: substringRange)[...]) else { return }

            let baseStyle = self.attribute(.paragraphStyle, at: substringRange.location, effectiveRange: nil) as? NSParagraphStyle
            let style = (baseStyle?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
            style.baseWritingDirection = .rightToLeft
            style.alignment = .right
            mutable.addAttribute(.paragraphStyle, value: style, range: enclosingRange)
            didChange = true
        }

        return didChange ? mutable : self
    }

    private func range(_ range: NSRange, containsAttribute key: NSAttributedString.Key) -> Bool {
        guard range.length > 0 else { return false }
        var found = false
        enumerateAttribute(key, in: range, options: []) { value, _, stop in
            if value != nil {
                found = true
                stop.pointee = true
            }
        }
        return found
    }
}

extension NSTextView {
    /// Applies WhatsApp/Google-Docs-style per-line auto writing direction directly to this view's
    /// text storage. A line that contains any right-to-left character becomes right-aligned RTL;
    /// every other line stays natural left-to-right.
    ///
    /// The change is applied straight to the storage rather than through
    /// `setBaseWritingDirection(_:range:)` so it does not register undo steps while the user types,
    /// and it works even on plain-text (`isRichText == false`) views. Paragraphs already carrying
    /// the desired direction are skipped to avoid needless relayout while typing.
    func applyAutoParagraphWritingDirection() {
        guard let storage = textStorage else { return }
        let ns = storage.string as NSString
        let length = ns.length
        guard length > 0 else { return }
        storage.beginEditing()
        ns.enumerateSubstrings(
            in: NSRange(location: 0, length: length),
            options: [.byParagraphs, .substringNotRequired]
        ) { _, substringRange, enclosingRange, _ in
            let isRTL = BidiScanner.containsStrongRTL(ns.substring(with: substringRange)[...])
            let desiredDirection: NSWritingDirection = isRTL ? .rightToLeft : .leftToRight
            let desiredAlignment: NSTextAlignment = isRTL ? .right : .natural
            let base = storage.attribute(.paragraphStyle, at: enclosingRange.location, effectiveRange: nil) as? NSParagraphStyle
            if let base, base.baseWritingDirection == desiredDirection, base.alignment == desiredAlignment {
                return
            }
            let style = (base?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
            style.baseWritingDirection = desiredDirection
            style.alignment = desiredAlignment
            storage.addAttribute(.paragraphStyle, value: style, range: enclosingRange)
        }
        storage.endEditing()
    }
}

extension View {
    /// Applies WhatsApp/Google-Docs-style automatic writing direction to a view driven by `text`.
    ///
    /// When `text` contains any right-to-left character the view is flipped to a right-to-left
    /// layout (right-aligned, caret on the right for editable fields). Purely left-to-right or
    /// empty text is left unchanged, so the common case is a no-op.
    @ViewBuilder
    func autoWritingDirection(for text: String) -> some View {
        if BidiScanner.containsStrongRTL(text[...]) {
            environment(\.layoutDirection, .rightToLeft)
                .multilineTextAlignment(.leading)
        } else {
            self
        }
    }
}
