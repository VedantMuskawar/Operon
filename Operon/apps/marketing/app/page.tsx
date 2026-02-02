import { Header } from "@/components/Header";
import { HeroSection } from "@/components/sections/HeroSection";
import { ValueProposition } from "@/components/sections/ValueProposition";
import { ProcessTimeline } from "@/components/ProcessTimeline";
import { ProductShowcase } from "@/components/sections/ProductShowcase";
import { Footer } from "@/components/Footer";

export default function HomePage() {
  return (
    <main className="pt-16">
      <Header />
      <HeroSection />
      <section id="why-us">
        <ValueProposition />
      </section>
      <section id="process">
        <ProcessTimeline />
      </section>
      <section id="products">
        <ProductShowcase />
      </section>
      <Footer />
    </main>
  );
}
