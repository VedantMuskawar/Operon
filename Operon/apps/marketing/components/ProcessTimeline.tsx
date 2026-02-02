"use client";

import { motion } from "framer-motion";
import {
  Factory,
  Gauge,
  CheckCircle2,
  MapPin,
} from "lucide-react";
import { ScrollReveal } from "@/components/ui/ScrollReveal";
import { TruckingVisualizer } from "@/components/TruckingVisualizer";

const steps = [
  {
    icon: Factory,
    title: "Ash Collection",
    description: "Fly ash sourced from thermal power plants, processed and stored.",
  },
  {
    icon: Gauge,
    title: "Automated Pressing",
    description: "High-pressure automated machines form uniform, high-strength bricks.",
  },
  {
    icon: CheckCircle2,
    title: "Quality Check",
    description: "Rigorous testing for compressive strength and water absorption.",
  },
  {
    icon: MapPin,
    title: "GPS-Tracked Delivery",
    description: "Real-time tracking and on-time delivery to your construction site.",
  },
];

export function ProcessTimeline() {
  return (
    <section className="py-24 px-6" id="delivery">
      <div className="max-w-6xl mx-auto">
        <ScrollReveal className="text-center mb-20">
          <h2 className="text-3xl md:text-4xl font-bold text-foreground mb-4">
            Smart Logistics Journey
          </h2>
          <p className="text-muted-foreground text-lg max-w-2xl mx-auto">
            From ash collection to your doorstep — a seamless, traceable process.
          </p>
        </ScrollReveal>

        <div className="relative">
          <div className="hidden md:block absolute top-1/2 left-0 right-0 h-px bg-gradient-to-r from-transparent via-neon-cyan/30 to-transparent -translate-y-1/2" />
          <div className="md:hidden absolute left-8 top-0 bottom-0 w-px bg-gradient-to-b from-neon-cyan/30 via-neon-cyan to-neon-cyan/30" />

          <div className="grid md:grid-cols-4 gap-8 md:gap-4">
            {steps.map(({ icon: Icon, title, description }, index) => (
              <ScrollReveal key={title} delay={index * 0.1}>
                <div className="relative flex flex-col md:flex-row items-center md:items-start gap-4 md:gap-6">
                  <div className="absolute left-8 md:left-1/2 top-8 md:top-1/2 w-3 h-3 rounded-full bg-neon-cyan -translate-x-1/2 md:-translate-x-1/2 md:-translate-y-1/2 z-10 ring-4 ring-obsidian" />
                  <div className="flex flex-col items-center md:items-center text-center md:text-center pl-16 md:pl-0 md:pt-8">
                    <div className="inline-flex p-4 rounded-xl bg-neon-cyan/10 text-neon-cyan mb-4">
                      <Icon className="h-8 w-8" />
                    </div>
                    <h3 className="text-lg font-semibold text-foreground mb-2">
                      {title}
                    </h3>
                    <p className="text-sm text-muted-foreground max-w-[200px]">
                      {description}
                    </p>
                  </div>
                </div>
              </ScrollReveal>
            ))}
          </div>
        </div>

        {/* Trucking Visualizer - appears after steps, hover to animate */}
        <ScrollReveal delay={0.4} className="mt-20">
          <div className="rounded-2xl border border-neon-cyan/20 bg-obsidian/40 backdrop-blur-sm p-6 group-hover:border-neon-cyan/30 transition-colors">
            <h3 className="text-lg font-semibold text-foreground text-center mb-2">
              Delivery Route Visualizer
            </h3>
            <TruckingVisualizer />
          </div>
        </ScrollReveal>
      </div>
    </section>
  );
}
