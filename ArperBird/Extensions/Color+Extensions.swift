//
//  Color+Extensions.swift
//  ArperBird
//
//  Created by Olivier Picard on 26/04/2026.
//

import SwiftUI

extension Color {
    static func randomMetricColor() -> Color {
        Color(hue: .random(in: 0...1), saturation: 0.65, brightness: 0.85)
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    /// A control-tint variant of this color, adjusted so it works everywhere a
    /// tint gets drawn: as a fill under white text/glyphs (prominent buttons —
    /// needs to be dark enough) and, in dark mode, as text on near-black
    /// (needs to be light enough). Bright palette colors (yellow, teal) get
    /// pulled down into the allowed luminance band and near-black ones lifted;
    /// colors already inside it pass through unchanged.
    ///
    /// `ratio` is the WCAG contrast target and the single strictness knob:
    /// 4.5:1 is AA for body text (strict — bright colors darken a lot), 3:1 is
    /// AA for large text and UI components (gentler — keeps more of the
    /// original hue's brightness). Defaults to 3:1 since the tint mostly
    /// carries headline-weight labels and glyphs, not body copy.
    func readableControlTint(
        in scheme: ColorScheme,
        ratio: Double = 3.0
    ) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        // System colors are dynamic; resolve against the scheme we're asked
        // about, not whatever trait collection happens to be current.
        let resolved = UIColor(self).resolvedColor(
            with: UITraitCollection(
                userInterfaceStyle: scheme == .dark ? .dark : .light
            )
        )
        guard resolved.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return self
        }
        // White-on-color contrast is 1.05 / (L + 0.05): the target caps L.
        let maxLuminance = 1.05 / ratio - 0.05
        // Color-on-black contrast is (L + 0.05) / 0.05: the target floors L.
        // Only enforced in dark mode, where the tint also draws text; in light
        // mode dark colors sit on white and are fine as they are.
        let minLuminance = scheme == .dark ? ratio * 0.05 - 0.05 : 0
        func toLinear(_ c: CGFloat) -> Double {
            let c = Double(c)
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        func toSRGB(_ c: Double) -> Double {
            c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055
        }
        let (lr, lg, lb) = (toLinear(r), toLinear(g), toLinear(b))
        let luminance = 0.2126 * lr + 0.7152 * lg + 0.0722 * lb
        let target = min(max(luminance, minLuminance), maxLuminance)
        guard target != luminance, luminance > 0 else { return self }
        // Relative luminance is linear in linear-RGB, so a single proportional
        // scale lands exactly on the target — no iteration needed. Clamped per
        // channel: a saturated channel caps at 1 when lifting very dark colors.
        let scale = target / luminance
        return Color(
            red: toSRGB(min(1, lr * scale)),
            green: toSRGB(min(1, lg * scale)),
            blue: toSRGB(min(1, lb * scale)),
            opacity: a
        )
    }
}
