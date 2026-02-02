"use client";

import { motion } from "framer-motion";
import { Factory, MapPin } from "lucide-react";
import { useState } from "react";

const pathD =
  "M 40 160 Q 200 160, 320 100 T 600 100";

export function TruckingVisualizer() {
  const [isHovered, setIsHovered] = useState(false);
  const pathLength = 650;

  return (
    <div
      className="relative w-full max-w-2xl mx-auto py-12 group"
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
    >
      <svg viewBox="0 0 640 200" className="w-full h-auto" fill="none">
        <defs>
          <linearGradient
            id="pathGradient"
            x1="0%"
            y1="0%"
            x2="100%"
            y2="0%"
          >
            <stop offset="0%" stopColor="#22d3ee" stopOpacity="0.4" />
            <stop offset="100%" stopColor="#22d3ee" stopOpacity="1" />
          </linearGradient>
        </defs>

        {/* Background path */}
        <path
          d={pathD}
          stroke="rgba(34, 211, 238, 0.1)"
          strokeWidth="3"
          fill="none"
          strokeLinecap="round"
          strokeLinejoin="round"
        />

        {/* Animated drawing path */}
        <motion.path
          d={pathD}
          stroke="url(#pathGradient)"
          strokeWidth="2.5"
          fill="none"
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeDasharray={pathLength}
          strokeDashoffset={isHovered ? 0 : pathLength}
          transition={{
            duration: 1.5,
            ease: [0.4, 0, 0.2, 1],
          }}
        />

        {/* Factory icon (start) */}
        <foreignObject x="0" y="135" width="80" height="50">
          <div className="flex flex-col items-center gap-1">
            <div className="p-2 rounded-lg bg-neon-cyan/20 border border-neon-cyan/40 group-hover:border-neon-cyan/60 transition-colors">
              <Factory className="h-6 w-6 text-neon-cyan" />
            </div>
            <span className="text-[10px] text-muted-foreground font-medium">
              Factory
            </span>
          </div>
        </foreignObject>

        {/* Target icon (end) */}
        <foreignObject x="560" y="75" width="80" height="50">
          <div className="flex flex-col items-center gap-1">
            <div
              className={`p-2 rounded-lg border transition-all duration-500 ${
                isHovered
                  ? "bg-neon-cyan/20 border-neon-cyan/60"
                  : "bg-neon-cyan/10 border-neon-cyan/30"
              }`}
            >
              <MapPin className="h-6 w-6 text-neon-cyan" />
            </div>
            <span className="text-[10px] text-muted-foreground font-medium">
              Delivery
            </span>
          </div>
        </foreignObject>
      </svg>

      <p className="text-center text-sm text-muted-foreground mt-4">
        Hover to trace the delivery route
      </p>
    </div>
  );
}
