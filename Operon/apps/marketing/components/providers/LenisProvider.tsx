"use client";

import { useEffect, useRef } from "react";

export function LenisProvider({ children }: { children: React.ReactNode }) {
  const lenisRef = useRef<{ destroy: () => void } | null>(null);
  const rafRef = useRef<number>();

  useEffect(() => {
    let mounted = true;

    import("lenis").then(({ default: Lenis }) => {
      if (!mounted) return;

      const lenis = new Lenis({
        duration: 1.2,
        easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)),
        smoothWheel: true,
      });

      lenisRef.current = lenis;

      function raf(time: number) {
        lenis.raf(time);
        rafRef.current = requestAnimationFrame(raf);
      }
      rafRef.current = requestAnimationFrame(raf);
    });

    return () => {
      mounted = false;
      if (rafRef.current) cancelAnimationFrame(rafRef.current);
      lenisRef.current?.destroy();
    };
  }, []);

  return <>{children}</>;
}
