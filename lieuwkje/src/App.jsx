import './index.css'

// Floral logo SVG
function Logo() {
  return (
    <svg viewBox="0 0 120 140" className="w-20 h-24" fill="none">
      <path d="M60 10c-8 15-25 30-20 50s20 25 20 25" stroke="white" strokeWidth="2.5" strokeLinecap="round"/>
      <path d="M60 10c8 15 25 30 20 50s-20 25-20 25" stroke="white" strokeWidth="2.5" strokeLinecap="round"/>
      <path d="M40 40c-10 5-25 0-30 15s8 20 15 20" stroke="white" strokeWidth="2.5" strokeLinecap="round"/>
      <path d="M80 40c10 5 25 0 30 15s-8 20-15 20" stroke="white" strokeWidth="2.5" strokeLinecap="round"/>
      <path d="M50 65c-5 10-15 20-10 35s20 15 20 15" stroke="white" strokeWidth="2.5" strokeLinecap="round"/>
      <path d="M70 65c5 10 15 20 10 35s-20 15-20 15" stroke="white" strokeWidth="2.5" strokeLinecap="round"/>
      <path d="M60 30c-5 8-12 15-8 25s12 12 12 12" stroke="white" strokeWidth="2.5" strokeLinecap="round"/>
      <circle cx="60" cy="72" r="4" fill="white"/>
    </svg>
  )
}

// Placeholder artwork card
function ArtCard({ color1, color2, accent }) {
  return (
    <div className={`aspect-[3/4] rounded-lg overflow-hidden relative`} style={{ background: `linear-gradient(135deg, ${color1}, ${color2})` }}>
      <div className="absolute inset-0 flex items-center justify-center">
        <svg viewBox="0 0 100 130" className="w-3/4 h-3/4 opacity-80">
          <path d="M30 20c5-10 20-15 25-5s0 25-10 30" stroke={accent} strokeWidth="2" fill="none" strokeLinecap="round"/>
          <path d="M70 25c-5-10-20-15-25-5s0 25 10 30" stroke={accent} strokeWidth="2" fill="none" strokeLinecap="round"/>
          <path d="M45 60c-8 12-20 20-15 35s25 18 25 18" stroke={accent} strokeWidth="2" fill="none" strokeLinecap="round"/>
          <path d="M55 60c8 12 20 20 15 35s-25 18-25 18" stroke={accent} strokeWidth="2" fill="none" strokeLinecap="round"/>
          <circle cx="50" cy="68" r="3" fill={accent} opacity="0.6"/>
        </svg>
      </div>
    </div>
  )
}

// Instagram icon
function InstagramIcon() {
  return (
    <svg className="w-5 h-5" fill="none" stroke="white" viewBox="0 0 24 24" strokeWidth="1.5">
      <rect x="2" y="2" width="20" height="20" rx="5"/>
      <circle cx="12" cy="12" r="5"/>
      <circle cx="18" cy="6" r="1.5" fill="white"/>
    </svg>
  )
}

// Cart icon
function CartIcon() {
  return (
    <svg className="w-5 h-5" fill="none" stroke="white" viewBox="0 0 24 24" strokeWidth="1.5">
      <path d="M6 6h14l-1.5 9H7.5L6 6z"/>
      <circle cx="9" cy="19" r="1.5"/>
      <circle cx="17" cy="19" r="1.5"/>
    </svg>
  )
}

const products = [
  { c1: '#d4cfc0', c2: '#c8c3b2', a: '#8b9da5' },
  { c1: '#e8ddd0', c2: '#d9cbb8', a: '#c47a6b' },
  { c1: '#c8d5d0', c2: '#b8c8c0', a: '#9ab5ad' },
  { c1: '#e0d4c8', c2: '#d5c7b5', a: '#c9a0a0' },
  { c1: '#b8c5be', c2: '#a8b8ad', a: '#d4856f' },
  { c1: '#d8cec0', c2: '#cfc3b0', a: '#a09585' },
]

function App() {
  return (
    <div className="min-h-screen">
      {/* Header */}
      <header className="bg-beige text-center py-8">
        <Logo />
        <h1 className="text-3xl font-light tracking-wider mt-2" style={{ fontFamily: 'Georgia, serif', fontStyle: 'italic' }}>
          Lieuwkje
        </h1>
        <nav className="flex justify-center gap-8 mt-6 text-sm tracking-wide">
          {['Over', 'Winkel', 'Maatwerk', 'Blog', 'Contact'].map(item => (
            <a key={item} href="#" className="text-white/80 hover:text-white transition-colors">
              {item}
            </a>
          ))}
        </nav>
        <div className="flex justify-end gap-4 mt-4 px-8">
          <InstagramIcon />
          <CartIcon />
        </div>
      </header>

      {/* Product grid */}
      <main className="max-w-4xl mx-auto px-6 py-12">
        <div className="grid grid-cols-3 gap-4">
          {products.map((p, i) => (
            <ArtCard key={i} color1={p.c1} color2={p.c2} accent={p.a} />
          ))}
        </div>
      </main>

      {/* Cookie banner */}
      <footer className="fixed bottom-0 left-0 right-0 bg-[#e8dfc4] py-3 px-6 text-center text-sm">
        <p className="mb-2" style={{ color: '#6b6350' }}>
          Wij gebruiken cookies om statistieken te verzamelen. Voor meer info lees onze{' '}
          <a href="#" className="underline">Cookie Policy</a>
        </p>
        <div className="flex justify-center gap-2">
          <button className="px-4 py-1.5 border rounded text-xs" style={{ borderColor: '#b8a98a', color: '#6b6350' }}>
            Voorkeuren
          </button>
          <button className="px-4 py-1.5 border rounded text-xs" style={{ borderColor: '#b8a98a', color: '#6b6350' }}>
            Afwijzen
          </button>
          <button className="px-4 py-1.5 rounded text-xs" style={{ backgroundColor: '#c8b99a', color: 'white' }}>
            Accepteren
          </button>
        </div>
      </footer>
    </div>
  )
}

export default App
