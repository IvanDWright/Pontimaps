import { FormEvent, ReactNode, useEffect, useMemo, useState } from "react"

type IconName = "alert" | "arrow" | "building" | "check" | "chevron" | "clock" | "close" | "coffee" | "door" | "eye" | "heat" | "info" | "layers" | "lock" | "mail" | "map" | "more" | "paper" | "pin" | "plus" | "route" | "search" | "settings" | "shield" | "stairs" | "user" | "users" | "walk"

function Icon({ name, size = 20 }: { name: IconName; size?: number }) {
  const paths: Record<IconName, ReactNode> = {
    alert: (
      <>
        <path d="M12 3 2.8 20h18.4L12 3Z" />
        <path d="M12 9v4m0 3h.01" />
      </>
    ),
    arrow: (
      <>
        <path d="M5 12h14" />
        <path d="m14 7 5 5-5 5" />
      </>
    ),
    building: (
      <>
        <path d="M5 21V4h10v17M15 9h4v12M8 8h4M8 12h4M8 16h4M3 21h18" />
      </>
    ),
    check: <path d="m4 12 5 5L20 6" />,
    chevron: <path d="m9 18 6-6-6-6" />,
    clock: (
      <>
        <circle cx="12" cy="12" r="9" />
        <path d="M12 7v5l3 2" />
      </>
    ),
    close: (
      <>
        <path d="m5 5 14 14M19 5 5 19" />
      </>
    ),
    coffee: (
      <>
        <path d="M4 8h12v7a5 5 0 0 1-5 5H9a5 5 0 0 1-5-5V8Z" />
        <path d="M16 10h2a3 3 0 0 1 0 6h-2M7 4v2m4-2v2" />
      </>
    ),
    door: (
      <>
        <path d="M5 21V3h12v18M9 12h.01M3 21h18" />
      </>
    ),
    eye: (
      <>
        <path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6S2 12 2 12Z" />
        <circle cx="12" cy="12" r="2.5" />
      </>
    ),
    heat: (
      <>
        <path d="M8 18c-2-1.5-3-3.4-2-5.6.8-1.7 2.1-2.3 2-4.4 2.4 1.3 3.2 3 2.7 5 1.8-1 2.6-2.6 2.3-5 3.3 2.4 5 5.5 4.2 8.4A5.4 5.4 0 0 1 12 21a6 6 0 0 1-4-3Z" />
      </>
    ),
    info: (
      <>
        <circle cx="12" cy="12" r="9" />
        <path d="M12 11v5m0-8h.01" />
      </>
    ),
    layers: (
      <>
        <path d="m12 3 9 5-9 5-9-5 9-5Z" />
        <path d="m3 12 9 5 9-5M3 16l9 5 9-5" />
      </>
    ),
    lock: (
      <>
        <rect x="5" y="10" width="14" height="11" rx="2" />
        <path d="M8 10V7a4 4 0 0 1 8 0v3" />
      </>
    ),
    mail: (
      <>
        <rect x="3" y="5" width="18" height="14" rx="2" />
        <path d="m3 7 9 6 9-6" />
      </>
    ),
    map: (
      <>
        <path d="m3 5 6-2 6 2 6-2v16l-6 2-6-2-6 2V5Z" />
        <path d="M9 3v16m6-14v16" />
      </>
    ),
    more: (
      <>
        <circle cx="5" cy="12" r="1.2" fill="currentColor" stroke="none" />
        <circle cx="12" cy="12" r="1.2" fill="currentColor" stroke="none" />
        <circle cx="19" cy="12" r="1.2" fill="currentColor" stroke="none" />
      </>
    ),
    paper: (
      <>
        <path d="M5 3h11l3 3v15H5V3Z" />
        <path d="M15 3v4h4M8 11h8m-8 4h8" />
      </>
    ),
    pin: (
      <>
        <path d="M20 10c0 5-8 11-8 11S4 15 4 10a8 8 0 1 1 16 0Z" />
        <circle cx="12" cy="10" r="2.5" />
      </>
    ),
    plus: (
      <>
        <path d="M12 5v14M5 12h14" />
      </>
    ),
    route: (
      <>
        <circle cx="5" cy="19" r="2" />
        <circle cx="19" cy="5" r="2" />
        <path d="M7 19h6a4 4 0 0 0 0-8h-2a4 4 0 0 1 0-8h6" />
      </>
    ),
    search: (
      <>
        <circle cx="10.5" cy="10.5" r="6.5" />
        <path d="m15.5 15.5 5 5" />
      </>
    ),
    settings: (
      <>
        <circle cx="12" cy="12" r="3" />
        <path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1-2.8 2.8-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.6v.2h-4V21a1.7 1.7 0 0 0-1-1.6 1.7 1.7 0 0 0-1.9.3l-.1.1L4.2 17l.1-.1a1.7 1.7 0 0 0 .3-1.9A1.7 1.7 0 0 0 3 14H2.8v-4H3a1.7 1.7 0 0 0 1.6-1 1.7 1.7 0 0 0-.3-1.9L4.2 7 7 4.2l.1.1a1.7 1.7 0 0 0 1.9.3A1.7 1.7 0 0 0 10 3v-.2h4V3a1.7 1.7 0 0 0 1 1.6 1.7 1.7 0 0 0 1.9-.3l.1-.1L19.8 7l-.1.1a1.7 1.7 0 0 0-.3 1.9 1.7 1.7 0 0 0 1.6 1h.2v4H21a1.7 1.7 0 0 0-1.6 1Z" />
      </>
    ),
    shield: (
      <>
        <path d="M12 2 4 5v6c0 5 3.3 8.3 8 11 4.7-2.7 8-6 8-11V5l-8-3Z" />
        <path d="m9 12 2 2 4-4" />
      </>
    ),
    stairs: (
      <>
        <path d="M4 18h4v-4h4v-4h4V6h4" />
      </>
    ),
    user: (
      <>
        <circle cx="12" cy="8" r="4" />
        <path d="M4 21a8 8 0 0 1 16 0" />
      </>
    ),
    users: (
      <>
        <circle cx="9" cy="8" r="3" />
        <path d="M3 20v-2a5 5 0 0 1 5-5h2a5 5 0 0 1 5 5v2M16 5a3 3 0 0 1 0 6m1 3a5 5 0 0 1 4 5v1" />
      </>
    ),
    walk: (
      <>
        <circle cx="13.5" cy="3.7" r="1.6" />
        <path d="m8 21 2.3-5.3 1.7-3.2m0 0 2.3 2.2 3.2.4M12 12.5l1.2-4-2.3-1.1-2.7 2.8-2.1.7m7.1 3.8 2 5.3" />
      </>
    ),
  }
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.9"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {paths[name]}
    </svg>
  )
}

type Mode = "visitor" | "verified" | "admin"
type EntryScreen = "gate" | "login" | "register" | "verify" | "consent" | "app"
type Tab = "map" | "directory" | "more" | "admin"
type PlaceKind = "building" | "room" | "service"
type ReportType = "Cierre de paso" | "Fila larga" | "Alta afluencia"

type Place = {
  id: string
  name: string
  location: string
  subtitle: string
  kind: PlaceKind
  distance: string
  minutes: number
  x: number
  y: number
  category?: string
  schedule?: string
  status?: "Abierto" | "Cerrado" | "Cierra pronto"
  queue?: string
}

type Report = {
  id: number
  type: ReportType
  label?: string
  x: number
  y: number
  remaining: number
  negatives: number
  official?: boolean
}

const places: Place[] = [
  {
    id: "51",
    name: "Edificio 51 - Gerardo Arango",
    location: "Edificio 51 · Piso 1",
    subtitle: "Facultad de Artes",
    kind: "building",
    distance: "280 m",
    minutes: 4,
    x: 73,
    y: 28,
  },
  {
    id: "11",
    name: "Edificio 11 - Gabriel Giraldo",
    location: "Edificio 11 · Piso 2",
    subtitle: "Ciencias Jurídicas",
    kind: "building",
    distance: "420 m",
    minutes: 6,
    x: 78,
    y: 58,
  },
  {
    id: "2",
    name: "Edificio 2 - Fernando Barón",
    location: "Edificio 2 · Piso 1",
    subtitle: "Facultad de Ciencias",
    kind: "building",
    distance: "350 m",
    minutes: 5,
    x: 19,
    y: 34,
  },
  {
    id: "67",
    name: "Edificio 67",
    location: "Edificio 67 · Piso 3",
    subtitle: "Ingeniería",
    kind: "building",
    distance: "510 m",
    minutes: 7,
    x: 66,
    y: 17,
  },
  {
    id: "library",
    name: "Biblioteca General",
    location: "Edificio 4 · Piso 1",
    subtitle: "Estudio y consulta",
    kind: "service",
    distance: "210 m",
    minutes: 3,
    x: 53,
    y: 39,
    category: "Atención",
    schedule: "6:00 a. m. – 10:00 p. m.",
    status: "Abierto",
    queue: "Sin datos recientes",
  },
  {
    id: "cafe",
    name: "Cafetería Central",
    location: "Edificio 18 · Piso 1",
    subtitle: "Cafetería",
    kind: "service",
    distance: "160 m",
    minutes: 2,
    x: 38,
    y: 62,
    category: "Cafeterías",
    schedule: "7:00 a. m. – 7:00 p. m.",
    status: "Cierra pronto",
    queue: "Fila media · hace 8 min",
  },
  {
    id: "room-205",
    name: "Salón 67-205",
    location: "Edificio 67 · Piso 2",
    subtitle: "Salón 205",
    kind: "room",
    distance: "490 m",
    minutes: 7,
    x: 66,
    y: 17,
  },
  {
    id: "paper",
    name: "Papelería La Séptima",
    location: "Edificio 24 · Piso 1",
    subtitle: "Papelería",
    kind: "service",
    distance: "190 m",
    minutes: 3,
    x: 26,
    y: 69,
    category: "Papelerías",
    schedule: "8:00 a. m. – 6:00 p. m.",
    status: "Abierto",
    queue: "Fila baja · hace 12 min",
  },
  {
    id: "student",
    name: "Atención al Estudiante",
    location: "Edificio 20 · Piso 2",
    subtitle: "Orientación y trámites",
    kind: "service",
    distance: "320 m",
    minutes: 5,
    x: 49,
    y: 19,
    category: "Atención",
    schedule: "8:00 a. m. – 5:00 p. m.",
    status: "Cerrado",
    queue: "Sin datos recientes",
  },
  {
    id: "wellness",
    name: "Centro de Bienestar",
    location: "Edificio 35 · Piso 1",
    subtitle: "Bienestar universitario",
    kind: "service",
    distance: "390 m",
    minutes: 6,
    x: 22,
    y: 49,
    category: "Bienestar",
    schedule: "7:00 a. m. – 6:00 p. m.",
    status: "Abierto",
    queue: "Fila baja · hace 4 min",
  },
]

const initialReports: Report[] = [
  { id: 1, type: "Alta afluencia", x: 61, y: 48, remaining: 43, negatives: 0 },
  { id: 2, type: "Cierre de paso", x: 33, y: 42, remaining: 18, negatives: 1 },
]

const reportIcons: Record<ReportType, IconName> = {
  "Cierre de paso": "door",
  "Fila larga": "users",
  "Alta afluencia": "heat",
}

function Brand() {
  return (
    <div className="brand">
      <span className="brand-mark">
        <Icon name="map" size={22} />
      </span>
      <span>
        <strong>La Pontimaps</strong>
        <small>Universidad Javeriana</small>
      </span>
    </div>
  )
}

function Button({
  children,
  variant = "primary",
  className = "",
  ...props
}: React.ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: "primary" | "secondary" | "ghost"
}) {
  return (
    <button className={`button ${variant} ${className}`} {...props}>
      {children}
    </button>
  )
}

function Field({
  label,
  icon,
  error,
  ...props
}: React.InputHTMLAttributes<HTMLInputElement> & {
  label: string
  icon: IconName
  error?: string
}) {
  return (
    <label className="field">
      <span>{label}</span>
      <div className={error ? "input-wrap has-error" : "input-wrap"}>
        <Icon name={icon} size={19} />
        <input {...props} />
      </div>
      {error && <small className="field-error">{error}</small>}
    </label>
  )
}

function AuthShell({
  children,
  onBack,
}: {
  children: ReactNode
  onBack?: () => void
}) {
  return (
    <div className="entry-screen">
      <div className="entry-top">
        {onBack && (
          <button className="back-button" onClick={onBack} aria-label="Volver">
            ‹
          </button>
        )}
        <Brand />
      </div>
      {children}
    </div>
  )
}

function CampusMap({
  selected,
  reports,
  heatOn,
  navigating,
  arrived,
  gpsOn,
  onPlace,
  onReport,
}: {
  selected: Place | null
  reports: Report[]
  heatOn: boolean
  navigating: boolean
  arrived: boolean
  gpsOn: boolean
  onPlace: (place: Place) => void
  onReport: (report: Report) => void
}) {
  const destination = selected ?? places[0]
  return (
    <div
      className="campus-map"
      aria-label="Mapa ilustrado del campus Javeriano"
    >
      <svg
        viewBox="0 0 360 500"
        preserveAspectRatio="none"
        className="map-art"
        aria-hidden="true"
      >
        <rect width="360" height="500" fill="#edf0e9" />
        <path
          d="M0 36 360 6M0 77 360 47M0 365 360 290M0 405 360 330M74-20 25 520M120-20 71 520M247-20 194 520M303-20 249 520"
          stroke="#fff"
          strokeWidth="22"
        />
        <path
          d="M0 36 360 6M0 77 360 47M0 365 360 290M0 405 360 330M74-20 25 520M120-20 71 520M247-20 194 520M303-20 249 520"
          stroke="#d9dedb"
          strokeWidth="1.2"
        />
        <path
          d="M39 91h63v57H39zM139 45h73v65h-73zM238 75h82v67h-82zM213 174h93v72h-93zM29 218h70v63H29zM124 288h78v67h-78zM238 345h88v72h-88zM25 414h73v57H25z"
          fill="#fafbf8"
          stroke="#cbd2ce"
          strokeWidth="2"
        />
        <path
          d="M123 125c50-25 102 7 91 57-7 34-40 29-54 59-15-30-48-28-52-64-3-23 4-42 15-52Z"
          fill="#d8e8cf"
        />
        <path
          d="M136 144c20 7 41 6 62-4m-73 45c22 13 45 14 68 4m-49 36c14-9 27-9 40 0"
          fill="none"
          stroke="#f8faf5"
          strokeWidth="7"
          strokeLinecap="round"
        />
        {[
          [18, 17],
          [30, 21],
          [330, 22],
          [341, 30],
          [15, 184],
          [26, 177],
          [329, 177],
          [342, 188],
          [109, 397],
          [119, 402],
          [216, 445],
          [228, 452],
          [19, 320],
          [30, 311],
          [327, 271],
        ].map(([x, y], index) => (
          <circle
            key={index}
            cx={x}
            cy={y}
            r="7"
            fill={index % 2 ? "#b9d4ad" : "#c8ddb9"}
          />
        ))}
        <g
          fill="#738079"
          fontFamily="Arial"
          fontSize="10"
          fontWeight="600"
          textAnchor="middle"
        >
          <text x="70" y="121">
            Ed. Fernando Barón
          </text>
          <text x="175" y="80">
            Ed. 67
          </text>
          <text x="279" y="110">
            Gerardo Arango
          </text>
          <text x="258" y="211">
            Biblioteca
          </text>
          <text x="64" y="255">
            Bienestar
          </text>
          <text x="164" y="327">
            Cafetería
          </text>
          <text x="281" y="382">
            Gabriel Giraldo
          </text>
          <text x="163" y="175">
            Plazoleta Central
          </text>
        </g>
        {heatOn && (
          <g opacity=".35">
            <circle cx="175" cy="180" r="52" fill="#F2A900" />
            <circle cx="275" cy="230" r="43" fill="#d97706" />
            <circle cx="80" cy="320" r="45" fill="#62a368" />
          </g>
        )}
        {navigating && !arrived && (
          <>
            <path
              d={`M180 430 L180 370 L225 370 L225 295 L270 295 L270 ${destination.y * 5}`}
              fill="none"
              stroke="#fff"
              strokeWidth="14"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
            <path
              d={`M180 430 L180 370 L225 370 L225 295 L270 295 L270 ${destination.y * 5}`}
              fill="none"
              stroke="#F2A900"
              strokeWidth="7"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </>
        )}
      </svg>
      {places
        .filter(
          (place) =>
            place.kind === "building" || ["library", "cafe"].includes(place.id),
        )
        .map((place) => (
          <button
            key={place.id}
            className={`map-pin ${selected?.id === place.id ? "selected" : ""}`}
            style={{ left: `${place.x}%`, top: `${place.y}%` }}
            onClick={() => onPlace(place)}
            aria-label={`Ver ${place.name}`}
          >
            <Icon
              name={
                place.kind === "service"
                  ? place.id === "cafe"
                    ? "coffee"
                    : "paper"
                  : "building"
              }
              size={18}
            />
          </button>
        ))}
      {reports.map((report) => (
        <button
          key={report.id}
          className={`report-pin ${report.official ? "official" : ""}`}
          style={{ left: `${report.x}%`, top: `${report.y}%` }}
          onClick={() => onReport(report)}
          aria-label={`Reporte: ${report.type}`}
        >
          <Icon
            name={report.official ? "shield" : reportIcons[report.type]}
            size={18}
          />
        </button>
      ))}
      {gpsOn && (
        <div className="location-dot" aria-label="Tu ubicación">
          <span />
        </div>
      )}
      {!gpsOn && (
        <div className="manual-origin">
          <Icon name="pin" size={15} /> Origen manual
        </div>
      )}
    </div>
  )
}

function Modal({
  title,
  children,
  onClose,
}: {
  title: string
  children: ReactNode
  onClose: () => void
}) {
  return (
    <div className="modal-backdrop" role="presentation">
      <section
        className="modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="modal-title"
      >
        <header>
          <h2 id="modal-title">{title}</h2>
          <button className="icon-button" onClick={onClose} aria-label="Cerrar">
            <Icon name="close" />
          </button>
        </header>
        {children}
      </section>
    </div>
  )
}

export default function App() {
  const [entry, setEntry] = useState<EntryScreen>("gate")
  const [mode, setMode] = useState<Mode>("visitor")
  const [tab, setTab] = useState<Tab>("map")
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [role, setRole] = useState("Estudiante")
  const [lawAccepted, setLawAccepted] = useState(false)
  const [registrationTried, setRegistrationTried] = useState(false)
  const [countdown, setCountdown] = useState(60)
  const [gpsOn, setGpsOn] = useState(true)
  const [searchOpen, setSearchOpen] = useState(false)
  const [query, setQuery] = useState("")
  const [selectedPlace, setSelectedPlace] = useState<Place | null>(null)
  const [avoidStairs, setAvoidStairs] = useState(false)
  const [navigating, setNavigating] = useState(false)
  const [navStep, setNavStep] = useState(0)
  const [arrived, setArrived] = useState(false)
  const [nextClassOpen, setNextClassOpen] = useState(false)
  const [heatOn, setHeatOn] = useState(false)
  const [reports, setReports] = useState<Report[]>(initialReports)
  const [reportModal, setReportModal] = useState(false)
  const [activeReport, setActiveReport] = useState<Report | null>(null)
  const [lockedModal, setLockedModal] = useState(false)
  const [toast, setToast] = useState("")
  const [directoryFilter, setDirectoryFilter] = useState("Todos")
  const [userSearch, setUserSearch] = useState("")
  const [blockedUsers, setBlockedUsers] = useState<string[]>([])
  const [blockingUser, setBlockingUser] = useState<string | null>(null)
  const [blockReason, setBlockReason] = useState("")
  const [officialModal, setOfficialModal] = useState(false)
  const [officialText, setOfficialText] = useState("")

  useEffect(() => {
    if (entry !== "verify" || countdown <= 0) return
    const timer = window.setInterval(
      () => setCountdown((value) => value - 1),
      1000,
    )
    return () => window.clearInterval(timer)
  }, [entry, countdown])

  const emailValid = /^[a-zA-Z0-9._%+-]+@javeriana\.edu\.co$/.test(email)
  const emailUser = email.split("@")[0].toLowerCase()
  const passwordRules = [
    { label: "8 caracteres o más", valid: password.length >= 8 },
    {
      label: "Una mayúscula y una minúscula",
      valid: /[A-Z]/.test(password) && /[a-z]/.test(password),
    },
    {
      label: "Un número y un símbolo",
      valid: /\d/.test(password) && /[^A-Za-z0-9\s]/.test(password),
    },
    {
      label: "Sin espacios",
      valid: password.length > 0 && !/\s/.test(password),
    },
    {
      label: "No contiene tu usuario",
      valid:
        password.length > 0 &&
        (!emailUser || !password.toLowerCase().includes(emailUser)),
    },
  ]
  const passwordScore = passwordRules.filter((rule) => rule.valid).length
  const strength =
    passwordScore <= 2 ? "Débil" : passwordScore <= 4 ? "Media" : "Fuerte"
  const registrationValid = emailValid && passwordScore === 5 && lawAccepted

  const filteredPlaces = useMemo(() => {
    const search = query.trim().toLowerCase()
    if (!search) return places.slice(0, 6)
    return places.filter((place) =>
      `${place.name} ${place.location} ${place.subtitle} ${place.category ?? ""}`
        .toLowerCase()
        .includes(search),
    )
  }, [query])

  const directoryPlaces = places.filter(
    (place) =>
      place.kind === "service" &&
      (directoryFilter === "Todos" || place.category === directoryFilter),
  )
  const users = [
    { email: "laura.mora@javeriana.edu.co", role: "Estudiante" },
    { email: "carlos.ruiz@javeriana.edu.co", role: "Profesor" },
    { email: "ana.leon@javeriana.edu.co", role: "Administrativo" },
  ].filter((user) => user.email.includes(userSearch.toLowerCase()))

  const notify = (message: string) => {
    setToast(message)
    window.setTimeout(() => setToast(""), 2600)
  }

  const enterConsent = (nextMode: Mode) => {
    setMode(nextMode)
    setEntry("consent")
  }

  const finishConsent = (accepted: boolean) => {
    setGpsOn(accepted)
    setEntry("app")
    setTab("map")
  }

  const choosePlace = (place: Place) => {
    setSelectedPlace(place)
    setSearchOpen(false)
    setQuery("")
    setNavigating(false)
    setArrived(false)
    setNavStep(0)
  }

  const startNavigation = () => {
    setNavigating(true)
    setNavStep(0)
    setArrived(false)
  }

  const advanceNavigation = () => {
    if (navStep >= 1) {
      setArrived(true)
      setNavigating(false)
      return
    }
    setNavStep(1)
  }

  const requestWrite = (action: () => void) => {
    if (mode === "visitor") setLockedModal(true)
    else action()
  }

  const createReport = (type: ReportType) => {
    setReports((current) => [
      ...current,
      { id: Date.now(), type, x: 45, y: 56, remaining: 60, negatives: 0 },
    ])
    setReportModal(false)
    notify("Reporte publicado de forma 100 % anónima")
  }

  const negativeVote = (report: Report) => {
    const next = report.negatives + 1
    if (next >= 3) {
      setReports((current) => current.filter((item) => item.id !== report.id))
      setActiveReport(null)
      notify("Reporte ocultado. Ruta recalculada")
    } else {
      setReports((current) =>
        current.map((item) =>
          item.id === report.id ? { ...item, negatives: next } : item,
        ),
      )
      setActiveReport({ ...report, negatives: next })
      notify(`Voto registrado · ${3 - next} para ocultarlo`)
    }
  }

  const switchMode = (nextMode: Mode) => {
    setMode(nextMode)
    setTab("map")
    notify(
      nextMode === "visitor"
        ? "Vista de visitante activada"
        : nextMode === "verified"
          ? "Vista institucional verificada"
          : "Vista de administrador activada",
    )
  }

  if (entry !== "app") {
    return (
      <main className="showcase">
        <div className="phone-frame">
          <div className="phone-screen">
            <div className="status-bar">
              <span>9:41</span>
              <span className="camera-island" />
              <span>● ◒ ▰</span>
            </div>
            {entry === "gate" && (
              <AuthShell>
                <div className="gate-hero">
                  <span className="hero-map">
                    <Icon name="map" size={42} />
                  </span>
                  <p className="eyebrow">NAVEGA TU CAMPUS</p>
                  <h1>
                    Encuentra tu camino,
                    <br />
                    sin complicaciones.
                  </h1>
                  <p>
                    Edificios, salones y servicios de la Javeriana en un solo
                    mapa.
                  </p>
                </div>
                <div className="entry-actions">
                  <Button onClick={() => setEntry("login")}>
                    Iniciar sesión <Icon name="arrow" />
                  </Button>
                  <Button
                    variant="secondary"
                    onClick={() => setEntry("register")}
                  >
                    Registrarme
                  </Button>
                  <Button
                    variant="ghost"
                    onClick={() => enterConsent("visitor")}
                  >
                    <Icon name="eye" /> Continuar como visitante
                  </Button>
                  <p className="legal-copy">
                    <Icon name="shield" size={16} /> Tus datos y tu ubicación
                    están protegidos bajo la Ley 1581 de 2012.
                  </p>
                </div>
              </AuthShell>
            )}

            {entry === "login" && (
              <AuthShell onBack={() => setEntry("gate")}>
                <div className="form-heading">
                  <p className="eyebrow">CUENTA INSTITUCIONAL</p>
                  <h1>Qué bueno verte.</h1>
                  <p>Ingresa con tu correo de la Universidad Javeriana.</p>
                </div>
                <form
                  className="auth-form"
                  onSubmit={(event: FormEvent) => {
                    event.preventDefault()
                    enterConsent("verified")
                  }}
                >
                  <Field
                    label="Correo institucional"
                    icon="mail"
                    type="email"
                    placeholder="nombre@javeriana.edu.co"
                    value={email}
                    onChange={(event) => setEmail(event.target.value)}
                    required
                  />
                  <Field
                    label="Contraseña"
                    icon="lock"
                    type="password"
                    placeholder="Tu contraseña"
                    value={password}
                    onChange={(event) => setPassword(event.target.value)}
                    required
                  />
                  <button type="button" className="text-link">
                    ¿Olvidaste tu contraseña?
                  </button>
                  <Button type="submit">
                    Iniciar sesión <Icon name="arrow" />
                  </Button>
                  <div className="auth-divider">
                    <span>o</span>
                  </div>
                  <Button
                    type="button"
                    variant="secondary"
                    onClick={() => setEntry("register")}
                  >
                    Crear una cuenta
                  </Button>
                </form>
              </AuthShell>
            )}

            {entry === "register" && (
              <AuthShell onBack={() => setEntry("gate")}>
                <div className="form-heading compact">
                  <p className="eyebrow">REGISTRO INSTITUCIONAL</p>
                  <h1>Crea tu cuenta.</h1>
                  <p>Usa únicamente tu correo @javeriana.edu.co.</p>
                </div>
                <form
                  className="auth-form register-form"
                  onSubmit={(event: FormEvent) => {
                    event.preventDefault()
                    setRegistrationTried(true)
                    if (registrationValid) {
                      setEntry("verify")
                      setCountdown(60)
                    }
                  }}
                >
                  <Field
                    label="Correo institucional"
                    icon="mail"
                    type="email"
                    placeholder="nombre@javeriana.edu.co"
                    value={email}
                    onChange={(event) => setEmail(event.target.value)}
                    error={
                      email.length > 0 && !emailValid
                        ? "El dominio debe ser @javeriana.edu.co"
                        : undefined
                    }
                  />
                  <Field
                    label="Contraseña"
                    icon="lock"
                    type="password"
                    placeholder="Crea una contraseña segura"
                    value={password}
                    onChange={(event) => setPassword(event.target.value)}
                  />
                  <div className="strength-row">
                    <span>
                      Fortaleza:{" "}
                      <strong className={`strength-${strength.toLowerCase()}`}>
                        {strength}
                      </strong>
                    </span>
                    <span>{passwordScore}/5</span>
                  </div>
                  <div className="strength-track">
                    <span style={{ width: `${passwordScore * 20}%` }} />
                  </div>
                  <ul className="rules-list">
                    {passwordRules.map((rule) => (
                      <li
                        className={rule.valid ? "valid" : ""}
                        key={rule.label}
                      >
                        <span>{rule.valid ? "✓" : "✗"}</span>
                        {rule.label}
                      </li>
                    ))}
                  </ul>
                  <label className="select-label">
                    Rol institucional
                    <select
                      value={role}
                      onChange={(event) => setRole(event.target.value)}
                    >
                      <option>Estudiante</option>
                      <option>Profesor</option>
                      <option>Administrativo</option>
                    </select>
                  </label>
                  <label className="check-row">
                    <input
                      type="checkbox"
                      checked={lawAccepted}
                      onChange={(event) => setLawAccepted(event.target.checked)}
                    />
                    <span>
                      Autorizo el tratamiento de mis datos personales según la{" "}
                      <strong>Ley 1581 de 2012</strong>.
                    </span>
                  </label>
                  {registrationTried && !registrationValid && (
                    <p className="form-error">
                      Completa todos los requisitos para continuar.
                    </p>
                  )}
                  <Button type="submit">
                    Registrarme <Icon name="arrow" />
                  </Button>
                </form>
              </AuthShell>
            )}

            {entry === "verify" && (
              <AuthShell onBack={() => setEntry("register")}>
                <div className="center-message">
                  <span className="message-icon">
                    <Icon name="mail" size={34} />
                  </span>
                  <p className="eyebrow">VERIFICACIÓN DE CORREO</p>
                  <h1>Revisa tu correo</h1>
                  <p>Enviamos un enlace de verificación de Firebase a:</p>
                  <strong>{email || "nombre@javeriana.edu.co"}</strong>
                  <div className="info-card">
                    <Icon name="info" />
                    <span>
                      Abre el enlace en el mismo dispositivo. Puede tardar unos
                      minutos en llegar.
                    </span>
                  </div>
                </div>
                <div className="entry-actions verification-actions">
                  <Button onClick={() => enterConsent("verified")}>
                    <Icon name="check" /> Ya verifiqué
                  </Button>
                  <Button
                    variant="secondary"
                    disabled={countdown > 0}
                    onClick={() => setCountdown(60)}
                  >
                    <Icon name="clock" />{" "}
                    {countdown > 0
                      ? `Reenviar enlace (${countdown}s)`
                      : "Reenviar enlace"}
                  </Button>
                  <Button
                    variant="ghost"
                    onClick={() => enterConsent("visitor")}
                  >
                    <Icon name="eye" /> Continuar sin verificar (solo lectura)
                  </Button>
                </div>
              </AuthShell>
            )}

            {entry === "consent" && (
              <AuthShell onBack={() => setEntry("gate")}>
                <div className="center-message location-consent">
                  <span className="message-icon gold">
                    <Icon name="pin" size={36} />
                  </span>
                  <p className="eyebrow">ANTES DE ACTIVAR EL GPS</p>
                  <h1>Tu ubicación es privada</h1>
                  <p>
                    La usamos únicamente para orientarte mientras tienes el mapa
                    abierto.
                  </p>
                  <div className="privacy-list">
                    <div>
                      <Icon name="check" />
                      <span>
                        <strong>Solo en memoria</strong>
                        <small>Se elimina al cerrar la aplicación.</small>
                      </span>
                    </div>
                    <div>
                      <Icon name="shield" />
                      <span>
                        <strong>Sin historial ligado a ti</strong>
                        <small>No guardamos recorridos ni ubicaciones.</small>
                      </span>
                    </div>
                    <div>
                      <Icon name="eye" />
                      <span>
                        <strong>Tú tienes el control</strong>
                        <small>
                          Puedes pausar el GPS en cualquier momento.
                        </small>
                      </span>
                    </div>
                  </div>
                </div>
                <div className="entry-actions">
                  <Button onClick={() => finishConsent(true)}>
                    Acepto activar ubicación
                  </Button>
                  <Button
                    variant="secondary"
                    onClick={() => finishConsent(false)}
                  >
                    No acepto · Elegir origen manual
                  </Button>
                  <p className="legal-copy">
                    Autorización de ubicación conforme a la Ley 1581 de 2012.
                  </p>
                </div>
              </AuthShell>
            )}
            <div className="home-indicator" />
          </div>
        </div>
      </main>
    )
  }

  return (
    <main className="showcase">
      <div className="phone-frame">
        <div className="phone-screen app-screen">
          <div className="status-bar">
            <span>9:41</span>
            <span className="camera-island" />
            <span>● ◒ ▰</span>
          </div>
          <header className="app-header">
            <Brand />
            {mode === "visitor" ? (
              <span className="mode-badge">
                <Icon name="eye" size={14} /> Modo visitante
              </span>
            ) : (
              <button
                className="avatar-button"
                onClick={() => setTab("more")}
                aria-label="Abrir ajustes"
              >
                {mode === "admin" ? "AD" : "MC"}
              </button>
            )}
          </header>

          {tab === "map" && (
            <div className="map-view">
              <div className="map-search-wrap">
                <button
                  className="map-search"
                  onClick={() => setSearchOpen(true)}
                >
                  <Icon name="search" />
                  <span>Edificio, salón o servicio</span>
                </button>
                <button
                  className="quick-class"
                  onClick={() =>
                    requestWrite(() => setNextClassOpen((value) => !value))
                  }
                >
                  {mode === "visitor" ? (
                    <Icon name="lock" size={16} />
                  ) : (
                    <Icon name="clock" size={16} />
                  )}{" "}
                  Mi próxima clase
                </button>
              </div>
              {nextClassOpen && mode !== "visitor" && (
                <div className="class-card">
                  <button
                    onClick={() => setNextClassOpen(false)}
                    aria-label="Cerrar"
                  >
                    <Icon name="close" size={17} />
                  </button>
                  <p>PRÓXIMA CLASE · 10:00 A. M.</p>
                  <strong>Diseño de Interacción</strong>
                  <span>Edificio 67 · Piso 2 · Salón 205</span>
                  <small>
                    <Icon name="heat" size={14} /> Sal a las 9:48 a. m. ·
                    congestión media
                  </small>
                </div>
              )}
              <CampusMap
                selected={selectedPlace}
                reports={reports}
                heatOn={heatOn}
                navigating={navigating}
                arrived={arrived}
                gpsOn={gpsOn}
                onPlace={choosePlace}
                onReport={setActiveReport}
              />
              <div className="map-tools">
                <button
                  className={heatOn ? "active" : ""}
                  onClick={() => setHeatOn((value) => !value)}
                  aria-label="Alternar capa de congestión"
                >
                  <Icon name="layers" />
                </button>
                {heatOn && (
                  <div className="heat-legend">
                    <strong>Congestión</strong>
                    <span>
                      <i className="low" /> Baja
                    </span>
                    <span>
                      <i className="medium" /> Media
                    </span>
                    <span>
                      <i className="high" /> Alta
                    </span>
                  </div>
                )}
              </div>
              <button
                className="report-fab"
                onClick={() => requestWrite(() => setReportModal(true))}
                aria-label="Crear reporte"
              >
                {mode === "visitor" ? (
                  <Icon name="lock" />
                ) : (
                  <Icon name="plus" />
                )}
                <span>Reportar</span>
              </button>

              {selectedPlace && !navigating && !arrived && (
                <section className="place-sheet">
                  <div className="sheet-handle" />
                  <div className="place-heading">
                    <span className="place-icon">
                      <Icon
                        name={
                          selectedPlace.kind === "building"
                            ? "building"
                            : selectedPlace.id === "cafe"
                              ? "coffee"
                              : "door"
                        }
                      />
                    </span>
                    <span>
                      <small>
                        {selectedPlace.kind === "room"
                          ? "SALÓN"
                          : selectedPlace.kind === "service"
                            ? "SERVICIO"
                            : "DESTINO"}
                      </small>
                      <strong>{selectedPlace.name}</strong>
                      <p>{selectedPlace.location}</p>
                    </span>
                    <button
                      className="icon-button"
                      onClick={() => setSelectedPlace(null)}
                      aria-label="Cerrar"
                    >
                      <Icon name="close" />
                    </button>
                  </div>
                  <div className="trip-meta">
                    <span>
                      <Icon name="walk" /> {selectedPlace.distance}
                    </span>
                    <span>{selectedPlace.minutes} min ± 1 min</span>
                  </div>
                  <label className="toggle-row">
                    <span>
                      <Icon name="stairs" />
                      <span>
                        <strong>Evitar escaleras</strong>
                        <small>Usar rutas accesibles</small>
                      </span>
                    </span>
                    <input
                      type="checkbox"
                      checked={avoidStairs}
                      onChange={(event) => setAvoidStairs(event.target.checked)}
                    />
                    <i />
                  </label>
                  <Button onClick={startNavigation}>
                    Ir <Icon name="arrow" />
                  </Button>
                </section>
              )}

              {navigating && selectedPlace && (
                <section className="navigation-card">
                  <div className="nav-instruction">
                    <span className="turn-arrow">↱</span>
                    <span>
                      <small>SIGUIENTE TRAMO</small>
                      <strong>
                        {navStep === 0
                          ? "Gira a la derecha"
                          : "Continúa por la plazoleta"}
                      </strong>
                      <p>
                        {navStep === 0 ? "en 60 m" : "Tu destino está a 90 m"}
                      </p>
                    </span>
                  </div>
                  <div className="nav-footer">
                    <span>
                      <strong>
                        {Math.max(1, selectedPlace.minutes - navStep * 2)} min
                      </strong>
                      <small>
                        {avoidStairs ? "Ruta accesible" : "Ruta a pie"}
                      </small>
                    </span>
                    <Button onClick={advanceNavigation}>
                      {navStep === 0 ? "Siguiente tramo" : "Simular llegada"}
                    </Button>
                  </div>
                </section>
              )}
              {arrived && selectedPlace && (
                <section className="arrival-card">
                  <span className="message-icon gold">
                    <Icon name="pin" />
                  </span>
                  <span>
                    <small>HAS LLEGADO</small>
                    <strong>{selectedPlace.name}</strong>
                    <p>{selectedPlace.location}</p>
                  </span>
                  <button
                    className="icon-button"
                    onClick={() => {
                      setArrived(false)
                      setSelectedPlace(null)
                    }}
                  >
                    <Icon name="close" />
                  </button>
                </section>
              )}

              {searchOpen && (
                <section className="search-panel">
                  <div className="search-input">
                    <Icon name="search" />
                    <input
                      autoFocus
                      value={query}
                      onChange={(event) => setQuery(event.target.value)}
                      placeholder="Ej. 67-205, biblioteca, café"
                      aria-label="Buscar en el campus"
                    />
                    <button
                      onClick={() => {
                        setSearchOpen(false)
                        setQuery("")
                      }}
                      aria-label="Cerrar búsqueda"
                    >
                      <Icon name="close" />
                    </button>
                  </div>
                  <p className="search-help">
                    Busca por edificio, código de salón o servicio
                  </p>
                  <div className="search-results">
                    {filteredPlaces.length ? (
                      filteredPlaces.map((place) => (
                        <button
                          key={place.id}
                          onClick={() => choosePlace(place)}
                        >
                          <span className="result-icon">
                            <Icon
                              name={
                                place.kind === "building"
                                  ? "building"
                                  : place.kind === "room"
                                    ? "door"
                                    : place.id === "cafe"
                                      ? "coffee"
                                      : "pin"
                              }
                            />
                          </span>
                          <span>
                            <strong>{place.name}</strong>
                            <small>
                              {place.location} · {place.minutes} min
                            </small>
                          </span>
                          <Icon name="chevron" />
                        </button>
                      ))
                    ) : (
                      <div className="empty-state">
                        <Icon name="search" size={30} />
                        <strong>Sin resultados</strong>
                        <span>Prueba con un edificio, salón o servicio.</span>
                      </div>
                    )}
                  </div>
                </section>
              )}
            </div>
          )}

          {tab === "directory" && (
            <section className="page-view">
              <div className="page-header">
                <span>
                  <p className="eyebrow">SERVICIOS DEL CAMPUS</p>
                  <h1>Directorio</h1>
                </span>
                <Icon name="coffee" size={28} />
              </div>
              <div className="filter-scroll">
                {[
                  "Todos",
                  "Cafeterías",
                  "Papelerías",
                  "Atención",
                  "Bienestar",
                ].map((filter) => (
                  <button
                    key={filter}
                    className={directoryFilter === filter ? "active" : ""}
                    onClick={() => setDirectoryFilter(filter)}
                  >
                    {filter}
                  </button>
                ))}
              </div>
              <div className="directory-list">
                {directoryPlaces.map((place) => (
                  <article className="business-card" key={place.id}>
                    <div className="business-top">
                      <span className="place-icon">
                        <Icon
                          name={
                            place.id === "cafe"
                              ? "coffee"
                              : place.category === "Papelerías"
                                ? "paper"
                                : "building"
                          }
                        />
                      </span>
                      <span>
                        <strong>{place.name}</strong>
                        <small>{place.location}</small>
                      </span>
                      <span
                        className={`status ${place.status?.toLowerCase().replaceAll(" ", "-")}`}
                      >
                        {place.status}
                      </span>
                    </div>
                    <div className="business-info">
                      <span>
                        <Icon name="clock" /> {place.schedule}
                      </span>
                      <span>
                        <Icon name="users" /> {place.queue}
                      </span>
                    </div>
                    <div className="business-actions">
                      <button
                        onClick={() => choosePlace(place) || setTab("map")}
                      >
                        <Icon name="map" /> Ver en mapa
                      </button>
                      <button
                        onClick={() =>
                          requestWrite(() => notify("Calificación registrada"))
                        }
                      >
                        {mode === "visitor" && <Icon name="lock" />} Calificar
                      </button>
                      <button
                        onClick={() =>
                          requestWrite(() => notify("Horario guardado"))
                        }
                      >
                        {mode === "visitor" && <Icon name="lock" />} Horario
                      </button>
                    </div>
                  </article>
                ))}
              </div>
            </section>
          )}

          {tab === "more" && (
            <section className="page-view settings-view">
              <div className="page-header">
                <span>
                  <p className="eyebrow">PRIVACIDAD Y CUENTA</p>
                  <h1>Más / Ajustes</h1>
                </span>
                <Icon name="settings" size={28} />
              </div>
              <div className="profile-card">
                <span className="profile-avatar">
                  {mode === "visitor" ? (
                    <Icon name="eye" />
                  ) : mode === "admin" ? (
                    "AD"
                  ) : (
                    "MC"
                  )}
                </span>
                <span>
                  <strong>
                    {mode === "visitor"
                      ? "Modo visitante"
                      : mode === "admin"
                        ? "Administrador del campus"
                        : "Mariana Castro"}
                  </strong>
                  <small>
                    {mode === "visitor"
                      ? "Acceso de solo lectura"
                      : "Cuenta institucional verificada"}
                  </small>
                </span>
              </div>
              <p className="section-label">PRIVACIDAD</p>
              <label className="settings-row">
                <span className="setting-icon">
                  <Icon name="pin" />
                </span>
                <span>
                  <strong>Ubicación GPS</strong>
                  <small>
                    {gpsOn
                      ? "Activa · se procesa solo en memoria"
                      : "Pausada · usa un origen manual"}
                  </small>
                </span>
                <input
                  type="checkbox"
                  checked={gpsOn}
                  onChange={(event) => setGpsOn(event.target.checked)}
                />
                <i />
              </label>
              <div className="privacy-banner">
                <Icon name="shield" />
                <span>
                  <strong>Sin historial de ubicación</strong>
                  <small>
                    La Pontimaps no almacena recorridos ligados a tu cuenta.
                  </small>
                </span>
              </div>
              <p className="section-label">VISTA DE DEMOSTRACIÓN</p>
              <div className="demo-selector">
                {([
                  ["visitor", "Visitante"],
                  ["verified", "Verificado"],
                  ["admin", "Administrador"],
                ] as const).map(([value, label]) => (
                  <button
                    key={value}
                    className={mode === value ? "active" : ""}
                    onClick={() => switchMode(value)}
                  >
                    {label}
                  </button>
                ))}
              </div>
              {mode === "admin" && (
                <Button
                  className="admin-access"
                  onClick={() => setTab("admin")}
                >
                  <Icon name="shield" /> Abrir Administración{" "}
                  <Icon name="arrow" />
                </Button>
              )}
              <Button
                variant="ghost"
                onClick={() => {
                  setEntry("gate")
                  setMode("visitor")
                }}
              >
                Cerrar sesión
              </Button>
            </section>
          )}

          {tab === "admin" && mode === "admin" && (
            <section className="page-view admin-view">
              <div className="page-header">
                <span>
                  <p className="eyebrow">PANEL RESTRINGIDO</p>
                  <h1>Administración</h1>
                </span>
                <button
                  className="icon-button"
                  onClick={() => setTab("more")}
                  aria-label="Cerrar administración"
                >
                  <Icon name="close" />
                </button>
              </div>
              <div className="admin-tabs">
                <span>Usuarios y reportes activos</span>
              </div>
              <p className="section-label">USUARIOS REGISTRADOS</p>
              <div className="admin-search">
                <Icon name="search" />
                <input
                  value={userSearch}
                  onChange={(event) => setUserSearch(event.target.value)}
                  placeholder="Buscar por correo"
                />
              </div>
              <div className="admin-list">
                {users.map((user) => (
                  <div className="admin-item" key={user.email}>
                    <span className="mini-avatar">
                      <Icon name="user" />
                    </span>
                    <span>
                      <strong>{user.email}</strong>
                      <small>
                        {user.role} ·{" "}
                        {blockedUsers.includes(user.email)
                          ? "Bloqueado"
                          : "Activo"}
                      </small>
                    </span>
                    <button
                      onClick={() =>
                        blockedUsers.includes(user.email)
                          ? setBlockedUsers((current) =>
                              current.filter(
                                (emailItem) => emailItem !== user.email,
                              ),
                            )
                          : setBlockingUser(user.email)
                      }
                    >
                      {blockedUsers.includes(user.email)
                        ? "Desbloquear"
                        : "Bloquear"}
                    </button>
                  </div>
                ))}
              </div>
              <div className="admin-section-head">
                <p className="section-label">REPORTES ACTIVOS</p>
                <button onClick={() => setOfficialModal(true)}>
                  <Icon name="plus" /> Alerta oficial
                </button>
              </div>
              <div className="admin-list">
                {reports.map((report) => (
                  <div className="admin-report" key={report.id}>
                    <span className="report-admin-icon">
                      <Icon
                        name={
                          report.official ? "shield" : reportIcons[report.type]
                        }
                      />
                    </span>
                    <span>
                      <strong>{report.label ?? report.type}</strong>
                      <small>
                        {report.official
                          ? "Alerta oficial fija"
                          : `${report.remaining} min restantes · anónimo en el mapa`}
                      </small>
                    </span>
                    <div>
                      <button
                        onClick={() =>
                          setReports((current) =>
                            current.filter((item) => item.id !== report.id),
                          )
                        }
                      >
                        Eliminar
                      </button>
                      {!report.official && (
                        <button
                          onClick={() => {
                            setBlockingUser("Autor interno del reporte")
                          }}
                        >
                          Bloquear autor
                        </button>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </section>
          )}

          <nav className="bottom-nav" aria-label="Navegación principal">
            <button
              className={tab === "map" ? "active" : ""}
              onClick={() => setTab("map")}
            >
              <Icon name="map" />
              <span>Mapa</span>
            </button>
            <button
              className={tab === "directory" ? "active" : ""}
              onClick={() => setTab("directory")}
            >
              <Icon name="building" />
              <span>Directorio</span>
            </button>
            <button
              className={tab === "more" ? "active" : ""}
              onClick={() => setTab("more")}
            >
              <Icon name="more" />
              <span>Más</span>
            </button>
          </nav>
          <div className="home-indicator" />

          {reportModal && (
            <Modal
              title="¿Qué quieres reportar?"
              onClose={() => setReportModal(false)}
            >
              <p className="modal-copy">
                Tu reporte es anónimo y expirará automáticamente en 60 minutos.
              </p>
              <div className="report-options">
                {([
                  "Cierre de paso",
                  "Fila larga",
                  "Alta afluencia",
                ] as ReportType[]).map((type) => (
                  <button key={type} onClick={() => createReport(type)}>
                    <span>
                      <Icon name={reportIcons[type]} />
                    </span>
                    {type}
                    <Icon name="chevron" />
                  </button>
                ))}
              </div>
              <div className="anonymous-note">
                <Icon name="shield" /> Nunca mostramos tu nombre ni correo.
              </div>
            </Modal>
          )}
          {activeReport && (
            <Modal
              title={
                activeReport.official ? "Alerta oficial" : "Reporte anónimo"
              }
              onClose={() => setActiveReport(null)}
            >
              <div className="report-detail">
                <span
                  className={`large-report-icon ${
                    activeReport.official ? "official" : ""
                  }`}
                >
                  <Icon
                    name={
                      activeReport.official
                        ? "shield"
                        : reportIcons[activeReport.type]
                    }
                    size={30}
                  />
                </span>
                <h3>{activeReport.label ?? activeReport.type}</h3>
                <p>
                  {activeReport.official
                    ? "Publicada por Administración del campus"
                    : `Expira en ${activeReport.remaining} minutos`}
                </p>
                {!activeReport.official && (
                  <>
                    <div className="vote-progress">
                      <span
                        style={{ width: `${activeReport.negatives * 33}%` }}
                      />
                    </div>
                    <small>
                      {activeReport.negatives}/3 votos para ocultarlo
                    </small>
                    <div className="modal-actions">
                      <Button
                        onClick={() => {
                          setActiveReport(null)
                          notify("Confirmaste que el reporte sigue ahí")
                        }}
                      >
                        <Icon name="check" /> Sigue ahí
                      </Button>
                      <Button
                        variant="secondary"
                        onClick={() => negativeVote(activeReport)}
                      >
                        Falso / Ya no está
                      </Button>
                    </div>
                  </>
                )}
              </div>
            </Modal>
          )}
          {lockedModal && (
            <Modal
              title="Función para usuarios verificados"
              onClose={() => setLockedModal(false)}
            >
              <div className="locked-content">
                <span className="message-icon">
                  <Icon name="lock" size={30} />
                </span>
                <p>
                  Para colaborar, calificar o ver tu próxima clase necesitas una
                  cuenta institucional verificada.
                </p>
                <Button
                  onClick={() => {
                    setLockedModal(false)
                    setEntry("gate")
                  }}
                >
                  Iniciar sesión / Registrarme
                </Button>
                <Button variant="ghost" onClick={() => setLockedModal(false)}>
                  Seguir como visitante
                </Button>
              </div>
            </Modal>
          )}
          {blockingUser && (
            <Modal
              title="Motivo del bloqueo"
              onClose={() => {
                setBlockingUser(null)
                setBlockReason("")
              }}
            >
              <p className="modal-copy">
                El motivo es obligatorio. Al bloquear, este usuario quedará en
                modo Visitante.
              </p>
              <label className="field">
                <span>Motivo</span>
                <textarea
                  value={blockReason}
                  onChange={(event) => setBlockReason(event.target.value)}
                  placeholder="Describe brevemente el motivo"
                />
              </label>
              <Button
                disabled={!blockReason.trim()}
                onClick={() => {
                  setBlockedUsers((current) => [...current, blockingUser])
                  setBlockingUser(null)
                  setBlockReason("")
                  notify("Usuario bloqueado y degradado a Visitante")
                }}
              >
                Confirmar bloqueo
              </Button>
            </Modal>
          )}
          {officialModal && (
            <Modal
              title="Crear alerta oficial"
              onClose={() => setOfficialModal(false)}
            >
              <p className="modal-copy">
                La alerta permanecerá fija en el mapa hasta que un administrador
                la elimine.
              </p>
              <label className="field">
                <span>Título de la alerta</span>
                <textarea
                  value={officialText}
                  onChange={(event) => setOfficialText(event.target.value)}
                  placeholder="Ej. Acceso norte cerrado"
                />
              </label>
              <Button
                disabled={!officialText.trim()}
                onClick={() => {
                  setReports((current) => [
                    ...current,
                    {
                      id: Date.now(),
                      type: "Cierre de paso",
                      label: officialText.trim(),
                      x: 52,
                      y: 31,
                      remaining: 60,
                      negatives: 0,
                      official: true,
                    },
                  ])
                  setOfficialModal(false)
                  setOfficialText("")
                  notify("Alerta oficial publicada en el mapa")
                }}
              >
                Publicar alerta fija
              </Button>
            </Modal>
          )}
          {toast && (
            <div className="toast" role="status">
              <Icon name="check" /> {toast}
            </div>
          )}
        </div>
      </div>
    </main>
  )
}
