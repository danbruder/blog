/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./templates/**/*.html", "./theme/**/*.html", "./content/**/*.md"],
  theme: {
    extend: {
      animation: {
        wave: "wave 0.5s ease-in-out 0.1s 2",
      },
      keyframes: {
        wave: {
          "0%": { transform: "rotate(0deg)" },
          "25%": { transform: "rotate(-25deg)" },
          "50%": { transform: "rotate(5deg)" },
          "75%": { transform: "rotate(-25deg)" },
          "100%": { transform: "rotate(0deg)" },
        },
      },
    },
  },
  variants: {
    backgroundColor: ["responsive", "hover", "focus", "group-hover"],
    borderColor: [
      "responsive",
      "hover",
      "focus",
      "group-hover",
      "focus-within",
    ],
    textColor: ["responsive", "hover", "group-hover", "focus"],
    scale: ["responsive", "hover", "focus", "group-hover"],
    visibility: ["responsive", "group-hover", "group-focus"],
    fill: ["hover"],
    display: ({ variants }) => [...variants("display"), "last"],
  },
  plugins: [require("@tailwindcss/forms"), require("@tailwindcss/typography")],
};
