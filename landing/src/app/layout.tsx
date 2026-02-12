import type { Metadata } from "next";
import { Geist_Mono } from "next/font/google";
import { Syne } from "next/font/google";
import { Outfit } from "next/font/google";
import "./globals.css";

const syne = Syne({
  variable: "--font-syne",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700", "800"],
});

const outfit = Outfit({
  variable: "--font-outfit",
  subsets: ["latin"],
  weight: ["300", "400", "500", "600", "700"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "MacPulse — Know How You Spend Your Screen Time",
  description:
    "Privacy-first macOS app that records and summarizes your daily screen activity. Everything stays on your Mac. No cloud, no tracking, no compromise.",
  keywords: [
    "macOS",
    "screen time",
    "productivity",
    "privacy",
    "activity tracker",
    "on-device AI",
  ],
  openGraph: {
    title: "MacPulse — Know How You Spend Your Screen Time",
    description:
      "Privacy-first macOS app that records and summarizes your daily screen activity.",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark">
      <body
        className={`${syne.variable} ${outfit.variable} ${geistMono.variable} antialiased`}
      >
        {children}
      </body>
    </html>
  );
}
