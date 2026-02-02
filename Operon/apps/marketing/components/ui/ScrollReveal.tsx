"use client";

import { motion } from "framer-motion";

interface ScrollRevealProps {
  children: React.ReactNode;
  className?: string;
  delay?: number;
  direction?: "up" | "down" | "left" | "right";
  rotateX?: boolean;
}

export function ScrollReveal({
  children,
  className = "",
  delay = 0,
  direction = "up",
  rotateX = true,
}: ScrollRevealProps) {
  const directionOffset = {
    up: { y: 40 },
    down: { y: -40 },
    left: { x: 40 },
    right: { x: -40 },
  }[direction];

  return (
    <motion.div
      className={className}
      initial={{
        opacity: 0,
        ...directionOffset,
        rotateX: rotateX ? 15 : 0,
        transformPerspective: 1000,
      }}
      whileInView={{
        opacity: 1,
        x: 0,
        y: 0,
        rotateX: 0,
      }}
      viewport={{ once: true, margin: "-80px" }}
      transition={{
        duration: 0.7,
        delay,
        ease: [0.25, 0.4, 0.25, 1],
      }}
    >
      {children}
    </motion.div>
  );
}
