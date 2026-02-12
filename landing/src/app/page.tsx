import {
  Navbar,
  Hero,
  Features,
  HowItWorks,
  Privacy,
  Preview,
  FAQ,
  DownloadCTA,
  Footer,
} from "@/components/Sections";

export default function Home() {
  return (
    <main>
      <Navbar />
      <Hero />
      <div className="divider" />
      <Features />
      <div className="divider" />
      <HowItWorks />
      <div className="divider" />
      <Privacy />
      <div className="divider" />
      <Preview />
      <div className="divider" />
      <FAQ />
      <div className="divider" />
      <DownloadCTA />
      <Footer />
    </main>
  );
}
