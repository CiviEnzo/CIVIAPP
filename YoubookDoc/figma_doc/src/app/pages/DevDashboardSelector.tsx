import { useNavigate } from 'react-router';
import { 
  UserCog, Users, User, FileCode, Activity, 
  ArrowRight, Palette, CheckCircle
} from 'lucide-react';

/**
 * DevDashboardSelector
 * Pagina di selezione rapida per sviluppo
 * Permette di navigare velocemente tra Admin, Staff, Client e utility pages
 */

interface DashboardOption {
  id: string;
  title: string;
  description: string;
  path: string;
  icon: React.ComponentType<{ className?: string }>;
  color: string;
  bgColor: string;
  borderColor: string;
}

const dashboards: DashboardOption[] = [
  {
    id: 'admin',
    title: 'Admin Dashboard',
    description: '12 moduli: Panoramica, Saloni, Staff, Clienti, Movimenti, Agenda, Servizi, Magazzino, Vendite, Messaggi, WhatsApp, Report',
    path: '/admin',
    icon: UserCog,
    color: 'text-primary',
    bgColor: 'bg-primary/10',
    borderColor: 'border-primary/30'
  },
  {
    id: 'staff',
    title: 'Staff Dashboard',
    description: '2 sezioni: Agenda (giorno/settimana) con gestione appuntamenti, Ferie con richieste permessi',
    path: '/staff',
    icon: Users,
    color: 'text-info',
    bgColor: 'bg-info/10',
    borderColor: 'border-info/30'
  },
  {
    id: 'client',
    title: 'Client Dashboard',
    description: '5 tab: Home, Agenda, Prenota (4 step), Carrello, Info Salone + 7 drawer sections',
    path: '/client/dashboard',
    icon: User,
    color: 'text-success',
    bgColor: 'bg-success/10',
    borderColor: 'border-success/30'
  },
  {
    id: 'discovery',
    title: 'Client Discovery',
    description: 'Pagina di scoperta saloni per clienti non autenticati',
    path: '/client',
    icon: Palette,
    color: 'text-warning',
    bgColor: 'bg-warning/10',
    borderColor: 'border-warning/30'
  }
];

const utilityPages: DashboardOption[] = [
  {
    id: 'states',
    title: 'Cross-Module States',
    description: '18 edge cases: conflitti agenda, pagamenti falliti, quote scaduti, richieste rifiutate',
    path: '/cross-module-states',
    icon: Activity,
    color: 'text-error',
    bgColor: 'bg-error/10',
    borderColor: 'border-error/30'
  },
  {
    id: 'mcp',
    title: 'MCP Code Connect',
    description: '22 componenti mappati per Flutter: Agenda, KPI, Drawer, Quote/Payment, Notifications',
    path: '/mcp-code-connect',
    icon: FileCode,
    color: 'text-primary',
    bgColor: 'bg-primary/10',
    borderColor: 'border-primary/30'
  }
];

export default function DevDashboardSelector() {
  const navigate = useNavigate();

  return (
    <div className="min-h-screen bg-background p-4 lg:p-8">
      <div className="max-w-6xl mx-auto">
        {/* Header */}
        <div className="text-center mb-12">
          <h1 className="text-5xl font-bold mb-4">
            <span className="text-primary">YouBook</span> Development
          </h1>
          <p className="text-lg text-muted-foreground">
            Seleziona il dashboard da visualizzare
          </p>
        </div>

        {/* Main Dashboards */}
        <div className="mb-12">
          <h2 className="text-2xl font-bold mb-6 flex items-center gap-2">
            <CheckCircle className="size-6 text-success" />
            Main Dashboards
          </h2>
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {dashboards.map((dashboard) => (
              <DashboardCard
                key={dashboard.id}
                dashboard={dashboard}
                onClick={() => navigate(dashboard.path)}
              />
            ))}
          </div>
        </div>

        {/* Utility Pages */}
        <div>
          <h2 className="text-2xl font-bold mb-6 flex items-center gap-2">
            <FileCode className="size-6 text-primary" />
            Utility Pages
          </h2>
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {utilityPages.map((page) => (
              <DashboardCard
                key={page.id}
                dashboard={page}
                onClick={() => navigate(page.path)}
              />
            ))}
          </div>
        </div>

        {/* Quick Links */}
        <div className="mt-12 p-6 bg-card border border-border rounded-xl">
          <h3 className="font-semibold mb-4">Quick Links</h3>
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 text-sm">
            <button
              onClick={() => navigate('/signin')}
              className="p-3 bg-muted rounded-lg hover:bg-muted/80 transition-colors text-left"
            >
              <div className="font-medium">Sign In</div>
              <div className="text-muted-foreground text-xs">Auth page</div>
            </button>
            <button
              onClick={() => navigate('/register')}
              className="p-3 bg-muted rounded-lg hover:bg-muted/80 transition-colors text-left"
            >
              <div className="font-medium">Register Client</div>
              <div className="text-muted-foreground text-xs">Cliente</div>
            </button>
            <button
              onClick={() => navigate('/register-center')}
              className="p-3 bg-muted rounded-lg hover:bg-muted/80 transition-colors text-left"
            >
              <div className="font-medium">Register Center</div>
              <div className="text-muted-foreground text-xs">Centro</div>
            </button>
            <button
              onClick={() => navigate('/onboarding')}
              className="p-3 bg-muted rounded-lg hover:bg-muted/80 transition-colors text-left"
            >
              <div className="font-medium">Onboarding</div>
              <div className="text-muted-foreground text-xs">First setup</div>
            </button>
          </div>
        </div>

        {/* Stats */}
        <div className="mt-8 text-center text-sm text-muted-foreground">
          <div className="inline-flex items-center gap-6 p-4 bg-card border border-border rounded-xl">
            <div>
              <div className="text-2xl font-bold text-foreground">50+</div>
              <div>Pages</div>
            </div>
            <div className="w-px h-12 bg-border" />
            <div>
              <div className="text-2xl font-bold text-foreground">22</div>
              <div>Components Mapped</div>
            </div>
            <div className="w-px h-12 bg-border" />
            <div>
              <div className="text-2xl font-bold text-foreground">18</div>
              <div>Edge Cases</div>
            </div>
            <div className="w-px h-12 bg-border" />
            <div>
              <div className="text-2xl font-bold text-foreground">95%</div>
              <div>Coverage</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// =====================================
// DASHBOARD CARD COMPONENT
// =====================================

interface DashboardCardProps {
  dashboard: DashboardOption;
  onClick: () => void;
}

function DashboardCard({ dashboard, onClick }: DashboardCardProps) {
  const Icon = dashboard.icon;

  return (
    <button
      onClick={onClick}
      className={`group relative bg-card border-2 ${dashboard.borderColor} rounded-xl p-6 text-left transition-all hover:shadow-lg hover:scale-[1.02] hover:border-primary`}
    >
      {/* Icon */}
      <div className={`${dashboard.bgColor} w-14 h-14 rounded-xl flex items-center justify-center mb-4`}>
        <Icon className={`size-7 ${dashboard.color}`} />
      </div>

      {/* Title */}
      <h3 className="text-xl font-bold mb-2 group-hover:text-primary transition-colors">
        {dashboard.title}
      </h3>

      {/* Description */}
      <p className="text-sm text-muted-foreground mb-4 line-clamp-2">
        {dashboard.description}
      </p>

      {/* Arrow */}
      <div className="flex items-center gap-2 text-sm font-medium text-primary">
        <span>Vai al Dashboard</span>
        <ArrowRight className="size-4 group-hover:translate-x-1 transition-transform" />
      </div>

      {/* Path hint */}
      <div className="absolute top-4 right-4 text-xs text-muted-foreground font-mono opacity-50">
        {dashboard.path}
      </div>
    </button>
  );
}
