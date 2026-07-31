// Ink & Lime — Tailwind wiring.
// Pair with tokens.css (load it once globally, e.g. imported into your
// main stylesheet before `@tailwind base`). This snippet maps the CSS
// custom properties from tokens.css onto Tailwind utilities like
// `bg-paper`, `text-ink-2`, `border-rule`, `font-display`.
//
// Merge the `theme.extend` block below into your project's
// tailwind.config.js — don't replace the whole file.

module.exports = {
  theme: {
    extend: {
      fontFamily: {
        display: ['"Space Grotesk"', "system-ui", "sans-serif"],
        sans: ["Archivo", "system-ui", "sans-serif"]
      },
      colors: {
        paper: "var(--color-paper)",
        "paper-2": "var(--color-paper-2)",
        "paper-3": "var(--color-paper-3)",
        ink: "var(--color-ink)",
        "ink-2": "var(--color-ink-2)",
        "ink-3": "var(--color-ink-3)",
        rule: "var(--color-rule)",
        lime: "var(--color-lime)",
        signal: "var(--color-signal)",
        "on-lime": "var(--on-lime)"
      },
      borderRadius: {
        // The system has no rounded corners. Zeroing the DEFAULT key means
        // plain `rounded` resolves to 0; still remove/avoid `rounded-*`
        // utilities with explicit sizes (rounded-lg, rounded-full, etc.)
        // wherever they show up in ported markup.
        DEFAULT: "0px"
      },
      animation: {
        // Optional: the one playful motion exception (an emoji wiggle).
        // Safe to drop if the target site has no equivalent element.
        wave: "wave 0.5s ease-in-out 0.1s 2"
      },
      keyframes: {
        wave: {
          "0%": { transform: "rotate(0deg)" },
          "25%": { transform: "rotate(-25deg)" },
          "50%": { transform: "rotate(5deg)" },
          "75%": { transform: "rotate(-25deg)" },
          "100%": { transform: "rotate(0deg)" }
        }
      }
    }
  }
};
