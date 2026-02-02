"use client";

import { motion } from "framer-motion";
import { Leaf, Settings, Truck } from "lucide-react";
import { ScrollReveal } from "@/components/ui/ScrollReveal";

const cards = [
  {
    icon: Leaf,
    title: "Eco-Friendly Tech",
    description:
      "Sustainable Fly Ash bricks reduce environmental impact. We use industrial by-products to create high-strength building materials.",
  },
  {
    icon: Settings,
    title: "Automated Precision",
    description:
      "State-of-the-art automated pressing ensures consistent quality and strength. Every brick meets rigorous standards.",
  },
  {
    icon: Truck,
    title: "Seamless Logistics",
    description:
      "GPS-tracked delivery with real-time updates. Reliable scheduling and on-time delivery to your site.",
  },
];

export function ValueProposition() {
  return (
    <section className="py-24 px-6 bg-obsidian/50">
      <div className="max-w-6xl mx-auto">
        <ScrollReveal className="text-center mb-16" delay={0}>
          <h2 className="text-3xl md:text-4xl font-bold text-foreground mb-4">
            Why Choose Us
          </h2>
          <p className="text-muted-foreground text-lg max-w-2xl mx-auto">
            Intelligence meets industry. Our integrated approach delivers
            quality bricks with smart logistics.
          </p>
        </ScrollReveal>

        <div className="grid md:grid-cols-3 gap-8">
          {cards.map(({ icon: Icon, title, description }, index) => (
            <ScrollReveal key={title} delay={index * 0.1}>
              <motion.div
                className="group relative p-8 rounded-2xl border border-neon-cyan/20 bg-obsidian/60 backdrop-blur-sm shadow-xl hover:shadow-neon-cyan/5 hover:border-neon-cyan/40 transition-all duration-300 overflow-hidden"
                whileHover={{ y: -6 }}
              >
                <div className="absolute inset-0 bg-gradient-to-b from-neon-cyan/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
                <div className="relative">
                  <div className="inline-flex p-3 rounded-xl bg-neon-cyan/10 text-neon-cyan mb-6 group-hover:bg-neon-cyan/20 transition-colors">
                    <Icon className="h-8 w-8" />
                  </div>
                  <h3 className="text-xl font-semibold text-foreground mb-3">
                    {title}
                  </h3>
                  <p className="text-muted-foreground leading-relaxed">
                    {description}
                  </p>
                </div>
              </motion.div>
            </ScrollReveal>
          ))}
        </div>
      </div>
    </section>
  );
}
