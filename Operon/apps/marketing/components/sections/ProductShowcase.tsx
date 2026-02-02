"use client";

import { motion } from "framer-motion";
import { Ruler, Zap, Droplets } from "lucide-react";
import { ScrollReveal } from "@/components/ui/ScrollReveal";

const products = [
  {
    name: "Standard Brick",
    dimensions: "230 × 110 × 70 mm",
    compressiveStrength: "7.5 N/mm²",
    waterAbsorption: "< 12%",
    description: "Ideal for load-bearing walls and general construction.",
  },
  {
    name: "Modular Brick",
    dimensions: "190 × 90 × 90 mm",
    compressiveStrength: "10 N/mm²",
    waterAbsorption: "< 10%",
    description: "Higher strength for demanding applications.",
  },
  {
    name: "Jumbo Brick",
    dimensions: "290 × 140 × 90 mm",
    compressiveStrength: "5 N/mm²",
    waterAbsorption: "< 15%",
    description: "Faster construction, fewer joints.",
  },
];

export function ProductShowcase() {
  return (
    <section className="py-24 px-6 bg-obsidian/50">
      <div className="max-w-6xl mx-auto">
        <ScrollReveal className="text-center mb-16">
          <h2 className="text-3xl md:text-4xl font-bold text-foreground mb-4">
            Product Specifications
          </h2>
          <p className="text-muted-foreground text-lg max-w-2xl mx-auto">
            Premium Fly Ash Bricks with certified compressive strength and low
            water absorption.
          </p>
        </ScrollReveal>

        <div className="grid md:grid-cols-3 gap-8">
          {products.map((product, index) => (
            <ScrollReveal key={product.name} delay={index * 0.1}>
              <motion.div
                className="group relative p-8 rounded-2xl border border-neon-cyan/20 bg-obsidian/60 backdrop-blur-sm shadow-xl hover:shadow-neon-cyan/5 hover:border-neon-cyan/40 transition-all duration-300 overflow-hidden"
                whileHover={{ y: -6 }}
              >
                <div className="absolute inset-0 bg-gradient-to-b from-neon-cyan/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none rounded-2xl" />
                <div className="relative">
                  <h3 className="text-xl font-semibold text-foreground mb-2">
                    {product.name}
                  </h3>
                  <p className="text-sm text-muted-foreground mb-6">
                    {product.description}
                  </p>

                  <div className="space-y-4">
                    <div className="flex items-center gap-3">
                      <Ruler className="h-5 w-5 text-neon-cyan shrink-0" />
                      <div>
                        <p className="text-xs text-muted-foreground uppercase tracking-wider">
                          Dimensions
                        </p>
                        <p className="font-medium text-foreground">{product.dimensions}</p>
                      </div>
                    </div>
                    <div className="flex items-center gap-3">
                      <Zap className="h-5 w-5 text-neon-cyan shrink-0" />
                      <div>
                        <p className="text-xs text-muted-foreground uppercase tracking-wider">
                          Compressive Strength
                        </p>
                        <p className="font-medium text-foreground">{product.compressiveStrength}</p>
                      </div>
                    </div>
                    <div className="flex items-center gap-3">
                      <Droplets className="h-5 w-5 text-neon-cyan shrink-0" />
                      <div>
                        <p className="text-xs text-muted-foreground uppercase tracking-wider">
                          Water Absorption
                        </p>
                        <p className="font-medium text-foreground">{product.waterAbsorption}</p>
                      </div>
                    </div>
                  </div>
                </div>
              </motion.div>
            </ScrollReveal>
          ))}
        </div>
      </div>
    </section>
  );
}
