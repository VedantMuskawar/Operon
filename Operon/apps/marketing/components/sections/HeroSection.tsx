"use client";

import { useRef, useState, useCallback } from "react";
import { motion } from "framer-motion";
import { Truck } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Brick3D } from "@/components/hero/Brick3D";
import { KineticTypography } from "@/components/hero/KineticTypography";
import { QuoteModal } from "@/components/QuoteModal";

export function HeroSection() {
  const [quoteOpen, setQuoteOpen] = useState(false);
  const mouseRef = useRef({ x: 0, y: 0 });

  const handleMouseMove = useCallback((e: React.MouseEvent) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const x = (e.clientX - rect.left) / rect.width - 0.5;
    const y = (e.clientY - rect.top) / rect.height - 0.5;
    mouseRef.current = { x, y };
  }, []);

  return (
    <>
      <section
        className="relative min-h-screen px-4 py-24 md:px-6 md:py-32"
        onMouseMove={handleMouseMove}
      >
        {/* Bento Grid */}
        <div className="max-w-7xl mx-auto grid grid-cols-12 grid-rows-[auto_auto_auto] md:grid-rows-[200px_280px_180px] gap-3 md:gap-4">
          {/* Box 1: Brand Typography - spans 5 cols, 1 row */}
          <motion.div
            className="col-span-12 md:col-span-5 row-span-1 flex items-center p-6 rounded-xl md:rounded-2xl border border-neon-cyan/20 bg-obsidian/80 backdrop-blur-sm overflow-hidden"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
          >
            <KineticTypography />
          </motion.div>

          {/* Box 2: Tagline - spans 7 cols */}
          <motion.div
            className="col-span-12 md:col-span-7 row-span-1 flex flex-col justify-center p-6 md:p-8 rounded-xl md:rounded-2xl border border-neon-cyan/20 bg-obsidian/60 backdrop-blur-sm"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.1 }}
          >
            <p className="text-neon-cyan/90 font-semibold uppercase tracking-widest text-sm mb-2">
              Premier Fly Ash Bricks
            </p>
            <p className="text-2xl md:text-3xl font-bold text-foreground">
              Precision & Strength — Delivered Smart
            </p>
          </motion.div>

          {/* Box 3: 3D Brick - spans 6 cols, 2 rows */}
          <motion.div
            className="col-span-12 md:col-span-6 row-span-2 rounded-xl md:rounded-2xl border border-neon-cyan/20 bg-obsidian/40 backdrop-blur-sm overflow-hidden group-hover:border-neon-cyan/40 transition-colors"
            initial={{ opacity: 0, scale: 0.98 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 0.8, delay: 0.2 }}
          >
            <Brick3D mouse={mouseRef} className="min-h-[280px] md:min-h-[380px]" />
          </motion.div>

          {/* Box 4: CTA - spans 6 cols, 1 row */}
          <motion.div
            className="col-span-12 md:col-span-6 flex flex-col justify-center p-6 md:p-8 rounded-xl md:rounded-2xl border border-neon-cyan/20 bg-obsidian/60 backdrop-blur-sm"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.3 }}
          >
            <p className="text-muted-foreground mb-6 max-w-md">
              Eco-friendly Fly Ash Bricks with automated precision and
              GPS-tracked logistics.
            </p>
            <Button
              size="lg"
              className="gap-2 w-fit bg-neon-cyan text-obsidian hover:bg-neon-cyan/90"
              onClick={() => setQuoteOpen(true)}
            >
              <Truck className="h-5 w-5" />
              Smart Delivery
            </Button>
          </motion.div>

          {/* Box 5: Stats/Features - spans 6 cols */}
          <motion.div
            className="col-span-12 md:col-span-6 flex flex-wrap gap-4 p-6 rounded-xl md:rounded-2xl border border-neon-cyan/20 bg-obsidian/60 backdrop-blur-sm"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.6, delay: 0.4 }}
          >
            <div className="flex items-center gap-2">
              <span className="w-2 h-2 rounded-full bg-neon-cyan" />
              <span className="text-sm text-muted-foreground">Eco-Friendly</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="w-2 h-2 rounded-full bg-neon-cyan" />
              <span className="text-sm text-muted-foreground">Automated Precision</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="w-2 h-2 rounded-full bg-neon-cyan" />
              <span className="text-sm text-muted-foreground">GPS Delivery</span>
            </div>
          </motion.div>
        </div>
      </section>

      <QuoteModal open={quoteOpen} onOpenChange={setQuoteOpen} />
    </>
  );
}
