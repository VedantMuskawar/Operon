"use client";

import { useEffect } from "react";
import { motion, useMotionValue, useSpring } from "framer-motion";

export function Brick3D({
  mouse,
  className,
}: {
  mouse: React.MutableRefObject<{ x: number; y: number }>;
  className?: string;
}) {
  const rotateX = useMotionValue(0);
  const rotateY = useMotionValue(0);
  const springX = useSpring(rotateX, { stiffness: 100, damping: 30 });
  const springY = useSpring(rotateY, { stiffness: 100, damping: 30 });

  useEffect(() => {
    let raf: number;
    const update = () => {
      rotateX.set(mouse.current.y * 20);
      rotateY.set(mouse.current.x * 20);
      raf = requestAnimationFrame(update);
    };
    raf = requestAnimationFrame(update);
    return () => cancelAnimationFrame(raf);
  }, [mouse, rotateX, rotateY]);

  return (
    <div
      className={`relative w-full h-full min-h-[280px] flex items-center justify-center [perspective:1000px] ${className ?? ""}`}
    >
      <motion.div
        className="relative w-48 h-24 md:w-64 md:h-32"
        style={{
          rotateX: springX,
          rotateY: springY,
          transformStyle: "preserve-3d",
          transformOrigin: "center center",
        }}
      >
        {/* Front face */}
        <div
          className="absolute inset-0 rounded-lg"
          style={{
            background: "linear-gradient(135deg, #94a3b8 0%, #64748b 50%, #475569 100%)",
            border: "1px solid rgba(255,255,255,0.15)",
            transform: "translateZ(12px)",
            boxShadow: "0 8px 32px rgba(0,0,0,0.4), inset 0 1px 0 rgba(255,255,255,0.2)",
          }}
        >
          <div className="absolute inset-2 rounded opacity-30 pointer-events-none">
            <div className="absolute left-1/3 top-0 bottom-0 w-px bg-white/30" />
            <div className="absolute left-2/3 top-0 bottom-0 w-px bg-white/30" />
            <div className="absolute left-0 right-0 top-1/2 h-px bg-white/30" />
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
            boxShadow: "0 -2px 8px rgba(0,0,0,0.3)",
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
            boxShadow: "4px 0 16px rgba(0,0,0,0.3)",
          }}
        />
      </motion.div>

      {/* Glow */}
      <div
        className="absolute inset-0 -z-10 opacity-20 blur-3xl pointer-events-none"
        style={{
          background: "radial-gradient(circle at center, #22d3ee 0%, transparent 60%)",
        }}
      />
    </div>
  );
}
