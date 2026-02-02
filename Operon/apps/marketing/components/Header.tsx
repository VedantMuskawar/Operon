"use client";

import { useState } from "react";
import { motion } from "framer-motion";
import { Menu, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { QuoteModal } from "@/components/QuoteModal";

export function Header() {
  const [mobileOpen, setMobileOpen] = useState(false);
  const [quoteOpen, setQuoteOpen] = useState(false);

  const navLinks = [
    { href: "#why-us", label: "Why Us" },
    { href: "#process", label: "Process" },
    { href: "#products", label: "Products" },
    { href: "#delivery", label: "Delivery" },
  ];

  return (
    <>
      <header className="fixed top-0 left-0 right-0 z-50 border-b border-neon-cyan/10 bg-obsidian/80 backdrop-blur-xl">
        <div className="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
          <a href="/" className="font-bold text-xl text-foreground">
            <span className="text-neon-cyan">LAKSHMEE</span> INTELLIGENT TECHNOLOGIES
          </a>

          <nav className="hidden md:flex items-center gap-8">
            {navLinks.map(({ href, label }) => (
              <a
                key={href}
                href={href}
                className="text-sm font-medium text-muted-foreground hover:text-neon-cyan transition-colors"
              >
                {label}
              </a>
            ))}
            <Button
              onClick={() => setQuoteOpen(true)}
              size="sm"
              className="bg-neon-cyan text-obsidian hover:bg-neon-cyan/90"
            >
              Request a Quote
            </Button>
          </nav>

          <button
            className="md:hidden p-2 text-foreground"
            onClick={() => setMobileOpen(!mobileOpen)}
            aria-label="Toggle menu"
          >
            {mobileOpen ? <X className="h-6 w-6" /> : <Menu className="h-6 w-6" />}
          </button>
        </div>

        {mobileOpen && (
          <motion.nav
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: "auto" }}
            exit={{ opacity: 0, height: 0 }}
            className="md:hidden border-t border-neon-cyan/10 px-6 py-4 flex flex-col gap-4 bg-obsidian/95"
          >
            {navLinks.map(({ href, label }) => (
              <a
                key={href}
                href={href}
                className="text-sm font-medium text-muted-foreground hover:text-neon-cyan"
                onClick={() => setMobileOpen(false)}
              >
                {label}
              </a>
            ))}
            <Button
              onClick={() => setQuoteOpen(true)}
              className="w-full bg-neon-cyan text-obsidian hover:bg-neon-cyan/90"
            >
              Request a Quote
            </Button>
          </motion.nav>
        )}
      </header>

      <QuoteModal open={quoteOpen} onOpenChange={setQuoteOpen} />
    </>
  );
}
