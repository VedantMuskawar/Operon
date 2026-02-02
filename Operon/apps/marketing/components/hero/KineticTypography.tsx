"use client";

import { motion } from "framer-motion";

const BRAND_NAME = "LAKSHMEE INTELLIGENT TECHNOLOGIES";

const container = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: {
      staggerChildren: 0.03,
      delayChildren: 0.1,
    },
  },
};

const letter = {
  hidden: {
    opacity: 0,
    y: 20,
  },
  show: {
    opacity: 1,
    y: 0,
  },
};

export function KineticTypography() {
  return (
    <motion.h1
      className="text-3xl sm:text-4xl md:text-5xl lg:text-6xl font-extrabold tracking-tight text-transparent select-none"
      style={{
        WebkitTextStroke: "0.5px #22d3ee",
        paintOrder: "stroke fill",
        fill: "transparent",
      }}
      variants={container}
      initial="hidden"
      animate="show"
    >
      {BRAND_NAME.split("").map((char, i) => (
        <motion.span
          key={i}
          variants={letter}
          className="inline-block"
          style={{
            display: char === " " ? "inline" : "inline-block",
          }}
        >
          {char}
        </motion.span>
      ))}
    </motion.h1>
  );
}
