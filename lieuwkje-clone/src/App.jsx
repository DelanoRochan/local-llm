import { useState } from "react";

/* ─── data ─── */
const NAV = ["Over", "Winkel", "Maatwerk", "Blog", "Contact"];

const CARDS = [
  { id: 1, bg: "#e5e7d4", colors: ["#a8c8d8", "#e8b4b8", "#f2d9c0", "#7fa8b5"], label: "Dreamy", price: "€3,50" },
  { id: 2, bg: "#f0ebe0", colors: ["#f5e1e4", "#e8d4b0", "#c4a3c7", "#d4e5d0"], label: "Beloved", price: "€3,50", highlighted: true },
  { id: 3, bg: "#d6dac1", colors: ["#d4e8ec", "#e8d88a", "#b8d4c8", "#a8b8a0"], label: "Sunrise", price: "€3,50" },
  { id: 4, bg: "#e0dcd0", colors: ["#f0e4d0", "#d4a0a0", "#8fb890", "#c4a870"], label: "Garden", price: "€3,50" },
  { id: 5, bg: "#ece6d4", colors: ["#f0ece0", "#d07070", "#709870", "#c8b060"], label: "Blooming", price: "€3,50" },
  { id: 6, bg: "#ddd8c4", colors: ["#e8ddd0", "#c8b090", "#a8c0b8", "#b0a898"], label: "Quiet", price: "€3,50" },
  { id: 7, bg: "#dcdcc4", colors: ["#d8e8d8", "#a0c8c0", "#c0d8c8", "#a8c0a0"], label: "Sketch", price: "€4,50" },
  { id: 8, bg: "#e0ddd0", colors: ["#f0e8d0", "#d8c8a0", "#b8c8a8", "#e0d0b0"], label: "Stamp", price: "€3,50" },
  { id: 9, bg: "#e8e0c8", colors: ["#f0e0c8", "#c8a0a0", "#a8c0a0", "#d8c080"], label: "Floral", price: "€3,50" },
];

/* ─── watercolor card illustration ─── */
function CardIllustration({ colors, highlighted }) {
  return (
    <div className="relative w-full h-full flex items-center justify-center p-6">
      {/* product label overlay (only on highlighted card) */}
      {highlighted && (
        <div className="absolute inset-6 sm:inset-8 bg-white/90 rounded-xl flex flex-col items-center justify-center gap-1 px-3 py-5 z-10 shadow-sm">
          <p className="text-body/90 font-serif text-base sm:text-lg leading-snug text-center relative z-10">
            A6 Kaart: Beloved
          </p>
          <p className="text-price font-serif text-lg sm:text-xl mt-1 relative z-10">{colors[0]}</p>
        </div>
      )}

      {/* abstract watercolor SVG */}
      <svg viewBox="0 0 200 300" className="w-full h-full" aria-hidden="true">
        <defs>
          <linearGradient id={`bg-${colors[0].replace("#", "")}`} x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor={colors[0]} stopOpacity="0.75" />
            <stop offset="100%" stopColor={colors[1]} stopOpacity="0.35" />
          </linearGradient>
        </defs>
        {/* card base */}
        <rect x="30" y="10" width="140" height="260" rx="3" fill={`url(#bg-${colors[0].replace("#", "")})`} />
        {/* soft washes */}
        <ellipse cx="100" cy="110" rx="60" ry="50" fill={colors[1]} opacity="0.4" />
        <ellipse cx="80" cy="200" rx="50" ry="45" fill={colors[2] || colors[1]} opacity="0.35" />
        {colors[3] && <ellipse cx="120" cy="180" rx="40" ry="35" fill={colors[3]} opacity="0.3" />}
        {colors[0] && <ellipse cx="60" cy="150" rx="30" ry="40" fill={colors[0]} opacity="0.2" />}
        {/* easel */}
        <rect x="88" y="272" width="24" height="8" rx="2" fill="#c4a87a" opacity="0.5" />
      </svg>
    </div>
  );
}

/* ─── SVG icons ─── */
function InstagramIcon() {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <rect x="2" y="2" width="20" height="20" rx="5" />
      <circle cx="12" cy="12" r="5" />
      <circle cx="17.5" cy="6.5" r="1" fill="currentColor" stroke="none" />
    </svg>
  );
}

function BagIcon() {
  return (
    <svg width="21" height="21" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M6 2L3 6v14a2 2 0 002 2h14a2 2 0 002-2V6l-3-4z" />
      <path d="M3 6h18" />
      <path d="M16 10a4 4 0 01-8 0" />
    </svg>
  );
}

/* ─── floral logo ─── */
function Logo() {
  return (
    <div className="flex flex-col items-center">
      <svg width="120" height="120" viewBox="0 0 200 200" fill="none" className="opacity-85">
        {/* frame */}
        <rect x="12" y="12" width="176" height="176" rx="18" stroke="white" strokeWidth="1.5" opacity="0.35" />
        {/* flowers */}
        <path d="M100 35 Q118 55 100 75 Q82 55 100 35Z" fill="white" opacity="0.65" />
        <path d="M100 55 Q128 65 122 95 Q102 88 100 55Z" fill="white" opacity="0.55" />
        <path d="M82 48 Q96 65 82 85 Q68 68 82 48Z" fill="white" opacity="0.45" />
        <path d="M118 48 Q132 65 118 85 Q104 68 118 48Z" fill="white" opacity="0.45" />
        <path d="M100 75 Q112 92 100 110 Q88 92 100 75Z" fill="white" opacity="0.5" />
        <path d="M65 72 Q76 78 68 92 Q56 84 65 72Z" fill="white" opacity="0.35" />
        <path d="M135 72 Q144 78 136 92 Q124 84 135 72Z" fill="white" opacity="0.35" />
        <path d="M92 100 Q98 112 92 124 Q86 112 92 100Z" fill="white" opacity="0.3" />
        <path d="M108 100 Q114 112 108 124 Q102 112 108 100Z" fill="white" opacity="0.3" />
        {/* leaves */}
        <path d="M58 108 Q44 100 38 84 Q48 90 58 108Z" fill="white" opacity="0.25" />
        <path d="M142 108 Q156 100 162 84 Q152 90 142 108Z" fill="white" opacity="0.25" />
        <path d="M72 128 Q62 142 58 156 Q68 146 72 128Z" fill="white" opacity="0.25" />
        <path d="M128 128 Q138 142 142 156 Q132 146 128 128Z" fill="white" opacity="0.25" />
        {/* dots */}
        <circle cx="88" cy="50" r="3.5" fill="white" opacity="0.3" />
        <circle cx="112" cy="50" r="3" fill="white" opacity="0.3" />
        <circle cx="72" cy="86" r="2.5" fill="white" opacity="0.25" />
        <circle cx="128" cy="86" r="2.5" fill="white" opacity="0.25" />
      </svg>
      <p className="text-white font-serif italic text-3xl tracking-wide font-light mt-1" style={{ fontFamily: "'Cormorant Garamond', Georgia, serif" }}>
        Lieuwkje
      </p>
    </div>
  );
}

/* ─── card tile ─── */
function CardTile({ card, i }) {
  return (
    <div
      className="card-animate rounded-3xl overflow-hidden shadow-sm hover:shadow-md transition-shadow duration-300"
      style={{ backgroundColor: card.bg, animationDelay: `${i * 80}ms` }}
    >
      <CardIllustration colors={card.colors} highlighted={card.highlighted} />
    </div>
  );
}

/* ─── cookie banner ─── */
function CookieBanner({ onDismiss }) {
  return (
    <div className="fixed bottom-0 inset-x-0 z-50 bg-cookie-bg border-t border-cookie-border px-4 py-3 shadow-lg">
      <div className="max-w-3xl mx-auto flex flex-col sm:flex-row items-center justify-center gap-3 text-sm text-body">
        <p className="text-center leading-snug">
          Wij gebruiken cookies om statistieken te verzamelen.
          <br />
          Voor meer info lees onze{" "}
          <button className="underline hover:text-body/80">Cookie Policy</button>
        </p>
        <div className="flex gap-2 shrink-0">
          <button className="px-4 py-1.5 rounded-md bg-white/70 border border-black/10 text-body hover:bg-white transition-colors text-sm">
            Voorkeuren
          </button>
          <button className="px-4 py-1.5 rounded-md bg-white/70 border border-black/10 text-body hover:bg-white transition-colors text-sm">
            Afwijzen
          </button>
          <button
            onClick={onDismiss}
            className="px-4 py-1.5 rounded-md bg-white border border-black/10 text-body hover:bg-white transition-colors text-sm font-medium"
          >
            Accepteren
          </button>
        </div>
      </div>
    </div>
  );
}

/* ─── app ─── */
export default function App() {
  const [cookieShown, setCookieShown] = useState(true);

  return (
    <div className="min-h-screen flex flex-col">
      {/* header */}
      <header className="bg-warm-bg rounded-b-3xl pt-8 pb-5 px-4">
        <div className="max-w-4xl mx-auto">
          <Logo />

          <nav className="flex items-center justify-center gap-5 sm:gap-7 mt-4 text-white/90 text-sm font-medium tracking-wide">
            {NAV.map((item) => (
              <a key={item} href="#" className="hover:text-white transition-colors py-1">
                {item}
              </a>
            ))}
          </nav>

          <div className="flex justify-end gap-4 mt-2 pr-1 text-white/80">
            <button aria-label="Instagram" className="hover:text-white transition-colors">
              <InstagramIcon />
            </button>
            <button aria-label="Shop" className="hover:text-white transition-colors">
              <BagIcon />
            </button>
          </div>
        </div>
      </header>

      {/* card grid */}
      <main className="flex-1 px-4 sm:px-6 pb-32">
        <div className="max-w-5xl mx-auto grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-5 mt-6">
          {CARDS.map((card, i) => (
            <CardTile key={card.id} card={card} i={i} />
          ))}
        </div>
      </main>

      {/* cookie banner */}
      {cookieShown && <CookieBanner onDismiss={() => setCookieShown(false)} />}
    </div>
  );
}
