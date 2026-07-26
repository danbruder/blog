module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/blog_web/**/*.*ex",
    // Post/page bodies live in the DB but originate from these markdown
    // files, whose embedded HTML uses Tailwind classes (e.g. the `.browser`
    // chrome). Scan them so those classes aren't purged.
    "../priv/legacy_content/**/*.md"
  ],
  theme: {
    extend: {
      // Dan Bruder system v2 tokens. Values live as CSS custom properties in
      // app.css (:root / [data-theme="dark"]); these expose them to Tailwind
      // utilities like `bg-paper`, `text-ink-2`, `border-rule`.
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
        "on-lime": "oklch(0.185 0.015 255)"
      },
      borderRadius: {
        DEFAULT: "0px"
      },
      animation: {
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
  },
  plugins: [require("@tailwindcss/forms"), require("@tailwindcss/typography")]
};
