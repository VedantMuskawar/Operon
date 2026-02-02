"use client";

import { motion } from "framer-motion";

export function BrickIllustration() {
  return (
    <motion.div
      className="relative flex items-center justify-center"
      initial={{ opacity: 0, rotateY: -15 }}
      animate={{ opacity: 1, rotateY: 0 }}
      transition={{ duration: 0.8, ease: "easeOut" }}
      style={{ perspective: "1000px" }}
    >
      <div
        className="relative"
        style={{
          perspective: "1000px",
          transformStyle: "preserve-3d",
        }}
      >
        {/* 3D Brick - CSS transform for depth */}
        <motion.div
          className="relative w-48 h-24 md:w-64 md:h-32"
          style={{
            transformStyle: "preserve-3d",
          }}
          whileHover={{ scale: 1.05, rotateY: 5 }}
          transition={{ type: "spring", stiffness: 300 }}
        >
          {/* Front face */}
          <div
            className="absolute inset-0 rounded-lg shadow-xl"
            style={{
              background: "linear-gradient(135deg, #94a3b8 0%, #64748b 50%, #475569 100%)",
              border: "1px solid rgba(255,255,255,0.2)",
              transform: "translateZ(12px)",
              boxShadow: "0 4px 20px rgba(0,0,0,0.3), inset 0 1px 0 rgba(255,255,255,0.2)",
            }}
          >
            {/* Brick texture lines */}
            <div className="absolute inset-2 rounded opacity-30">
              <div className="h-full w-px bg-white/30 absolute left-1/3" />
              <div className="h-full w-px bg-white/30 absolute left-2/3" />
              <div className="w-full h-px bg-white/30 absolute top-1/2" />
            </div>
          </div>
          {/* Top face */}
          <div
            className="absolute rounded-lg"
            style={{
              width: "100%",
              height: "24px",
              left: 0,
              bottom: "100%",
              background: "linear-gradient(180deg, #cbd5e1 0%, #94a3b8 100%)",
              transform: "translateZ(12px) rotateX(-90deg) translateY(-12px)",
              transformOrigin: "bottom",
              boxShadow: "0 -2px 8px rgba(0,0,0,0.2)",
            }}
          />
          {/* Right face */}
          <div
            className="absolute rounded-r-lg"
            style={{
              width: "24px",
              height: "100%",
              right: 0,
              top: 0,
              background: "linear-gradient(90deg, #64748b 0%, #475569 100%)",
              transform: "translateZ(12px) rotateY(90deg) translateX(12px)",
              transformOrigin: "left",
              boxShadow: "4px 0 12px rgba(0,0,0,0.2)",
            }}
          />
        </motion.div>

        {/* Glow effect */}
        <div
          className="absolute -inset-8 -z-10 opacity-30 blur-3xl"
          style={{
            background: "radial-gradient(circle, #0070f3 0%, transparent 70%)",
          }}
        />
      </div>
    </motion.div>
  );
}
