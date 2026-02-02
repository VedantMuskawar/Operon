import type { Metadata } from "next";
import { Inter_Tight, JetBrains_Mono } from "next/font/google";
import "./globals.css";
import { LenisProvider } from "@/components/providers/LenisProvider";

const fontSans = Inter_Tight({
  variable: "--font-sans",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700", "800"],
});

const fontMono = JetBrains_Mono({
  variable: "--font-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "LAKSHMEE INTELLIGENT TECHNOLOGIES | Fly Ash Bricks Manufacturing & Delivery",
  description:
    "Premier Fly Ash Bricks Manufacturing & Smart Delivery. Eco-friendly, automated precision, seamless logistics.",
  keywords: [
    "Fly Ash Bricks Delivery",
    "Fly Ash Bricks",
    "Eco-friendly bricks",
    "Smart delivery",
  ],
  openGraph: {
    title: "LAKSHMEE INTELLIGENT TECHNOLOGIES | Fly Ash Bricks Manufacturing & Delivery",
    description:
      "Premier Fly Ash Bricks Manufacturing & Smart Delivery. Eco-friendly, automated precision, seamless logistics.",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning className="dark">
      <body
        className={`${fontSans.variable} ${fontMono.variable} font-sans bg-obsidian`}
      >
        <LenisProvider>{children}</LenisProvider>
        <div className="grain-overlay" aria-hidden />
      </body>
    </html>
  );
}
