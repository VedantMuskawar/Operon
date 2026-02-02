"use client";

import { Truck } from "lucide-react";
import { Button } from "@/components/ui/button";
import { QuoteModal } from "@/components/QuoteModal";
import { useState } from "react";

export function Footer() {
  const [quoteOpen, setQuoteOpen] = useState(false);

  return (
    <>
      <footer className="py-16 px-6 bg-obsidian/80 border-t border-neon-cyan/10">
        <div className="max-w-6xl mx-auto flex flex-col md:flex-row items-center justify-between gap-8">
          <div className="text-center md:text-left">
            <p className="font-bold text-xl mb-2 text-foreground">
              <span className="text-neon-cyan">LAKSHMEE</span> INTELLIGENT TECHNOLOGIES
            </p>
            <p className="text-sm text-muted-foreground max-w-md">
              Premier Fly Ash Bricks Manufacturing & Delivery. Eco-friendly,
              automated precision, seamless logistics.
            </p>
          </div>
          <div>
            <Button
              variant="outline"
              className="border-neon-cyan/40 text-neon-cyan hover:bg-neon-cyan/10 hover:text-neon-cyan gap-2"
              onClick={() => setQuoteOpen(true)}
            >
              <Truck className="h-4 w-4" />
              Request a Quote
            </Button>
          </div>
        </div>
        <div className="max-w-6xl mx-auto mt-12 pt-8 border-t border-neon-cyan/10 text-center text-sm text-muted-foreground">
          © {new Date().getFullYear()} Lakshmee Intelligent Technologies. All
          rights reserved.
        </div>
      </footer>

      <QuoteModal open={quoteOpen} onOpenChange={setQuoteOpen} />
    </>
  );
}
