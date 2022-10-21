/** @type {import('tailwindcss').Config} */
module.exports = {
    content: [
        "./templates/**/*.html",
        "./theme/**/*.html",
        "./content/**/*.md"
    ],
    variants: {
        backgroundColor: ["responsive", "hover", "focus", "group-hover"],
        borderColor: ["responsive", "hover", "focus", "group-hover", "focus-within"],
        textColor: ["responsive", "hover", "group-hover", "focus"],
        scale: ["responsive", "hover", "focus", "group-hover"],
        visibility: ["responsive", "group-hover", "group-focus"],
        fill: ["hover"],
        display: ({ variants }) => [...variants("display"), "last"],
    },
        plugins: [
            require('@tailwindcss/forms'),
            require('@tailwindcss/typography'),
        ],
}
