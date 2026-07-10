module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/blog_web/**/*.*ex"
  ],
  theme: {
    extend: {
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
