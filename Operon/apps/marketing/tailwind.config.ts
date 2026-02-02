import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: "class",
  content: [
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        obsidian: "#0f172a",
        "neon-cyan": "#22d3ee",
        primary: {
          DEFAULT: "#22d3ee",
          foreground: "#0f172a",
        },
        secondary: {
          DEFAULT: "var(--secondary)",
          foreground: "var(--secondary-foreground)",
        },
        destructive: {
          DEFAULT: "#ef4444",
          foreground: "#ffffff",
        },
        "destructive-foreground": "#ffffff",
        accent: {
          DEFAULT: "#22d3ee",
          foreground: "#0f172a",
        },
        muted: {
          DEFAULT: "#1e293b",
          foreground: "#94a3b8",
        },
        slate: {
          DEFAULT: "#1e293b",
          foreground: "#f8fafc",
        },
        background: "var(--background)",
        foreground: "var(--foreground)",
        input: "#334155",
        ring: "#22d3ee",
        border: "var(--border)",
      },
      fontFamily: {
        sans: ["var(--font-sans)", "Inter Tight", "system-ui", "sans-serif"],
        mono: ["var(--font-mono)", "JetBrains Mono", "monospace"],
      },
      backdropBlur: {
        xs: "2px",
      },
      animation: {
        "fade-in": "fadeIn 0.5s ease-out",
        "slide-up": "slideUp 0.5s ease-out",
        "draw-path": "drawPath 1.5s ease-out forwards",
      },
      boxShadow: {
        "neon-cyan/5": "0 0 60px -12px rgba(34, 211, 238, 0.05)",
        "neon-cyan/10": "0 0 60px -12px rgba(34, 211, 238, 0.1)",
      },
      keyframes: {
        fadeIn: {
          "0%": { opacity: "0" },
          "100%": { opacity: "1" },
        },
        slideUp: {
          "0%": { opacity: "0", transform: "translateY(20px)" },
          "100%": { opacity: "1", transform: "translateY(0)" },
        },
        drawPath: {
          "0%": { strokeDashoffset: "1000" },
          "100%": { strokeDashoffset: "0" },
        },
      },
    },
  },
  plugins: [],
};

export default config;
