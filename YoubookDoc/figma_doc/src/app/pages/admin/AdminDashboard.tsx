import { useState } from 'react';
import { useNavigate } from 'react-router';
import {
  LayoutDashboard, Building, Users, UserCog, Calendar, Package,
  Warehouse, ShoppingCart, MessageSquare, Phone, BarChart3,
  Menu, X, LogOut, Bell, Plus, Search, Filter, Download, 
  Edit, Trash2, Eye, MapPin, Mail, FileText, TrendingUp,
  Clock, Euro, Star, Tag, Send, CheckCircle
} from 'lucide-react';
import KPICard from '../../components/KPICard';
import DataTable from '../../components/DataTable';
import StatusBadge from '../../components/StatusBadge';
import LoadingState from '../../components/LoadingState';
import EmptyState from '../../components/EmptyState';
import ErrorState from '../../components/ErrorState';
import SaloniModuleEnhanced from '../../components/admin/SaloniModuleEnhanced';
import MessaggiModuleEnhanced from '../../components/admin/MessaggiModuleEnhanced';
import ServiziModuleEnhanced from '../../components/admin/ServiziModuleEnhanced';
import AppuntamentoBottomSheet from '../../components/admin/AppuntamentoBottomSheet';
import AgendaCalendarModern from '../../components/admin/AgendaCalendarModern';
import { toast } from 'sonner';

// Admin/Dashboard/Layout/Responsive/Default
export default function AdminDashboard() {
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [activeModule, setActiveModule] = useState('panoramica');
  const navigate = useNavigate();

  const modules = [
    { id: 'panoramica', label: 'Panoramica', icon: LayoutDashboard },
    { id: 'saloni', label: 'Saloni', icon: Building },
    { id: 'staff', label: 'Staff', icon: UserCog },
    { id: 'clienti', label: 'Clienti', icon: Users },
    { id: 'movimenti', label: 'Movimenti App', icon: TrendingUp },
    { id: 'agenda', label: 'Agenda', icon: Calendar },
    { id: 'servizi', label: 'Servizi & Pacchetti', icon: Package },
    { id: 'magazzino', label: 'Magazzino', icon: Warehouse },
    { id: 'vendite', label: 'Vendite & Cassa', icon: ShoppingCart },
    { id: 'messaggi', label: 'Messaggi & Marketing', icon: MessageSquare },
    { id: 'whatsapp', label: 'WhatsApp', icon: Phone },
    { id: 'report', label: 'Report', icon: BarChart3 },
  ];

  const handleLogout = () => {
    toast.success('Logout effettuato');
    navigate('/');
  };

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="bg-card border-b border-border sticky top-0 z-40">
        <div className="flex items-center justify-between px-4 lg:px-6 h-16">
          <div className="flex items-center gap-4">
            <button
              onClick={() => setSidebarOpen(!sidebarOpen)}
              className="lg:hidden p-2 hover:bg-muted rounded-lg transition-colors"
            >
              {sidebarOpen ? <X className="size-5" /> : <Menu className="size-5" />}
            </button>
            <h1 className="text-xl font-bold text-primary">YouBook Admin</h1>
          </div>

          <div className="flex items-center gap-3">
            <button className="relative p-2 hover:bg-muted rounded-lg transition-colors">
              <Bell className="size-5" />
              <span className="absolute top-1 right-1 w-2 h-2 bg-error rounded-full"></span>
            </button>
            <button
              onClick={handleLogout}
              className="flex items-center gap-2 px-4 py-2 hover:bg-muted rounded-lg transition-colors"
            >
              <LogOut className="size-5" />
              <span className="hidden sm:inline">Esci</span>
            </button>
          </div>
        </div>
      </header>

      <div className="flex">
        {/* Sidebar - Solo Icone con Tooltip */}
        <aside className={`
          fixed lg:sticky top-16 left-0 bottom-0 w-20 bg-card border-r border-border
          transition-transform duration-300 z-30
          ${sidebarOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'}
        `}>
          <nav className="p-3 space-y-2 overflow-y-auto h-[calc(100vh-4rem)]">
            {modules.map((module) => {
              const isAgenda = module.id === 'agenda';
              const isActive = activeModule === module.id;
              
              return (
                <button
                  key={module.id}
                  onClick={() => setActiveModule(module.id)}
                  className={`group relative w-full flex items-center justify-center p-3 rounded-xl transition-all duration-200 ${
                    isActive
                      ? 'bg-primary text-primary-foreground shadow-lg'
                      : isAgenda
                        ? 'bg-gradient-to-br from-primary via-primary/90 to-primary/70 hover:from-primary hover:via-primary/95 hover:to-primary/80 border-2 border-primary shadow-[0_0_20px_rgba(212,175,55,0.5),0_4px_12px_rgba(0,0,0,0.3),inset_0_1px_0_rgba(255,255,255,0.3)] hover:shadow-[0_0_30px_rgba(212,175,55,0.7),0_6px_16px_rgba(0,0,0,0.4),inset_0_1px_0_rgba(255,255,255,0.4)] transform hover:scale-105 animate-pulse-slow'
                        : 'hover:bg-muted'
                  }`}
                >
                  <module.icon className={`flex-shrink-0 transition-all duration-200 ${
                    isActive 
                      ? 'size-6' 
                      : isAgenda
                        ? 'size-7 text-background drop-shadow-[0_2px_4px_rgba(0,0,0,0.5)]'
                        : 'size-5 group-hover:size-7'
                  }`} />
                  
                  {/* Tooltip Sotto l'Icona */}
                  <span className="fixed mt-16 left-10 px-4 py-2.5 bg-foreground text-background rounded-lg text-sm font-semibold whitespace-nowrap pointer-events-none opacity-0 scale-90 group-hover:opacity-100 group-hover:scale-100 transition-all duration-200 shadow-2xl z-50">
                    {module.label}
                    {/* Freccia Triangolare Superiore */}
                    <span className="absolute bottom-full left-8 border-8 border-transparent border-b-foreground"></span>
                  </span>
                </button>
              );
            })}
          </nav>
        </aside>

        {/* Main Content */}
        <main className="flex-1 p-4 lg:p-8 min-h-[calc(100vh-4rem)]">
          {activeModule === 'panoramica' && <PanoramicaModule />}
          {activeModule === 'saloni' && <SaloniModuleEnhanced />}
          {activeModule === 'staff' && <StaffModule />}
          {activeModule === 'clienti' && <ClientiModule />}
          {activeModule === 'movimenti' && <MovimentiModule />}
          {activeModule === 'agenda' && <AgendaModule />}
          {activeModule === 'servizi' && <ServiziModuleEnhanced />}
          {activeModule === 'magazzino' && <MagazzinoModule />}
          {activeModule === 'vendite' && <VenditeModule />}
          {activeModule === 'messaggi' && <MessaggiModuleEnhanced />}
          {activeModule === 'whatsapp' && <WhatsAppModule />}
          {activeModule === 'report' && <ReportModule />}
        </main>
      </div>
    </div>
  );
}

// ===================================
// 1. PANORAMICA MODULE
// ===================================
// Admin/Panoramica/Overview/Responsive/Default
function PanoramicaModule() {
  const [loading] = useState(false);

  if (loading) {
    return <LoadingState message="Caricamento panoramica..." />;
  }

  return (
    <div className="max-w-7xl mx-auto space-y-8">
      {/* Header */}
      <div>
        <h2 className="text-3xl font-bold mb-2">Panoramica</h2>
        <p className="text-muted-foreground">Vista generale dell'attività</p>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 lg:gap-6">
        <KPICard
          title="Appuntamenti Oggi"
          value={24}
          icon={Calendar}
          trend={{ value: '+12%', positive: true }}
        />
        <KPICard
          title="Pacchetti Attivi"
          value={18}
          icon={Package}
        />
        <KPICard
          title="Scontrini (Anno)"
          value={1247}
          icon={ShoppingCart}
          trend={{ value: '+8%', positive: true }}
        />
        <KPICard
          title="Incasso Anno"
          value="€45.320"
          subtitle="Servizi + Pacchetti"
          icon={Euro}
          trend={{ value: '+15%', positive: true }}
        />
      </div>

      {/* Additional Metrics */}
      <div className="grid sm:grid-cols-2 gap-4 lg:gap-6">
        <KPICard
          title="Incasso Posticipato"
          value="€2.450"
          subtitle="8 clienti con saldo aperto"
          icon={Clock}
          onClick={() => toast.info('Apertura dettaglio incassi posticipati')}
        />
        <KPICard
          title="Punti Fedeltà Totali"
          value="3.420"
          subtitle="Assegnati: 4.120 | Usati: 700"
          icon={Star}
        />
      </div>

      {/* Quick Actions */}
      <div className="bg-card border border-border rounded-xl p-6">
        <h3 className="text-lg font-semibold mb-4">Azioni Rapide</h3>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
          <button className="flex items-center gap-3 p-4 border border-border rounded-lg hover:bg-muted transition-colors">
            <Calendar className="size-5 text-primary" />
            <span className="text-sm font-medium">Nuovo Appuntamento</span>
          </button>
          <button className="flex items-center gap-3 p-4 border border-border rounded-lg hover:bg-muted transition-colors">
            <Users className="size-5 text-primary" />
            <span className="text-sm font-medium">Aggiungi Cliente</span>
          </button>
          <button className="flex items-center gap-3 p-4 border border-border rounded-lg hover:bg-muted transition-colors">
            <ShoppingCart className="size-5 text-primary" />
            <span className="text-sm font-medium">Registra Vendita</span>
          </button>
          <button className="flex items-center gap-3 p-4 border border-border rounded-lg hover:bg-muted transition-colors">
            <MessageSquare className="size-5 text-primary" />
            <span className="text-sm font-medium">Invia Messaggio</span>
          </button>
        </div>
      </div>
    </div>
  );
}

// ===================================
// 2. SALONI MODULE
// ===================================
// Admin/Saloni/List/Responsive/Default
function SaloniModule() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(false);
  
  const saloniData = [
    {
      id: 1,
      nome: 'Hair & Beauty Milano Centro',
      indirizzo: 'Via Roma 123, Milano',
      telefono: '+39 02 1234567',
      email: 'milano@hairbeauty.it',
      staff: 8,
      status: 'active' as const
    },
    {
      id: 2,
      nome: 'Elegance Salon Roma',
      indirizzo: 'Corso Vittorio 45, Roma',
      telefono: '+39 06 9876543',
      email: 'roma@elegance.it',
      staff: 12,
      status: 'active' as const
    },
    {
      id: 3,
      nome: 'Beauty Point Torino',
      indirizzo: 'Via Po 78, Torino',
      telefono: '+39 011 5555555',
      email: 'torino@beautypoint.it',
      staff: 5,
      status: 'inactive' as const
    }
  ];

  const columns = [
    {
      key: 'nome',
      label: 'Nome Salone',
      sortable: true,
      render: (item: typeof saloniData[0]) => (
        <div>
          <div className="font-semibold">{item.nome}</div>
          <div className="text-xs text-muted-foreground flex items-center gap-1 mt-1">
            <MapPin className="size-3" />
            {item.indirizzo}
          </div>
        </div>
      )
    },
    {
      key: 'telefono',
      label: 'Contatti',
      render: (item: typeof saloniData[0]) => (
        <div className="text-sm">
          <div>{item.telefono}</div>
          <div className="text-muted-foreground text-xs">{item.email}</div>
        </div>
      )
    },
    {
      key: 'staff',
      label: 'Staff',
      render: (item: typeof saloniData[0]) => (
        <span className="font-medium">{item.staff} persone</span>
      )
    },
    {
      key: 'status',
      label: 'Stato',
      render: (item: typeof saloniData[0]) => (
        <StatusBadge 
          status={item.status} 
          label={item.status === 'active' ? 'Attivo' : 'Inattivo'} 
        />
      )
    },
    {
      key: 'actions',
      label: 'Azioni',
      render: (item: typeof saloniData[0]) => (
        <div className="flex gap-2">
          <button 
            className="p-2 hover:bg-muted rounded-lg transition-colors"
            onClick={() => toast.info(`Visualizza ${item.nome}`)}
          >
            <Eye className="size-4" />
          </button>
          <button 
            className="p-2 hover:bg-muted rounded-lg transition-colors"
            onClick={() => toast.info(`Modifica ${item.nome}`)}
          >
            <Edit className="size-4" />
          </button>
        </div>
      )
    }
  ];

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto">
        <h2 className="text-3xl font-bold mb-6">Saloni</h2>
        <LoadingState message="Caricamento saloni..." />
      </div>
    );
  }

  if (error) {
    return (
      <div className="max-w-7xl mx-auto">
        <h2 className="text-3xl font-bold mb-6">Saloni</h2>
        <ErrorState 
          message="Impossibile caricare i dati dei saloni"
          onRetry={() => setError(false)}
        />
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-3xl font-bold mb-2">Saloni</h2>
          <p className="text-muted-foreground">Gestione e configurazione saloni</p>
        </div>
        <button className="flex items-center gap-2 px-6 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors shadow-sm">
          <Plus className="size-5" />
          Aggiungi Salone
        </button>
      </div>

      {/* Filters */}
      <div className="flex flex-col sm:flex-row gap-3">
        <div className="flex-1 relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 size-5 text-muted-foreground" />
          <input
            type="text"
            placeholder="Cerca salone..."
            className="w-full pl-10 pr-4 py-3 bg-input-background border border-border rounded-lg focus:outline-none focus:ring-2 focus:ring-ring"
          />
        </div>
        <button className="flex items-center justify-center gap-2 px-4 py-3 border border-border rounded-lg hover:bg-muted transition-colors">
          <Filter className="size-5" />
          <span className="hidden sm:inline">Filtri</span>
        </button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">Saloni Attivi</div>
          <div className="text-2xl font-bold">2</div>
        </div>
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">Staff Totale</div>
          <div className="text-2xl font-bold">20</div>
        </div>
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">Città Coperte</div>
          <div className="text-2xl font-bold">3</div>
        </div>
      </div>

      {/* Data Table */}
      <DataTable
        columns={columns}
        data={saloniData}
        keyExtractor={(item) => item.id}
        onRowClick={(item) => toast.info(`Apri dettaglio ${item.nome}`)}
        emptyMessage="Nessun salone trovato"
      />
    </div>
  );
}

// ===================================
// 3. STAFF MODULE
// ===================================
// Admin/Staff/List/Responsive/Default
function StaffModule() {
  const [loading] = useState(false);

  const staffData = [
    {
      id: 1,
      nome: 'Maria Rossi',
      ruolo: 'Hair Stylist Senior',
      salone: 'Milano Centro',
      email: 'maria.rossi@example.com',
      telefono: '+39 333 1234567',
      appuntamenti: 145,
      status: 'active' as const
    },
    {
      id: 2,
      nome: 'Luca Bianchi',
      ruolo: 'Barbiere',
      salone: 'Milano Centro',
      email: 'luca.bianchi@example.com',
      telefono: '+39 333 7654321',
      appuntamenti: 98,
      status: 'active' as const
    },
    {
      id: 3,
      nome: 'Sofia Verde',
      ruolo: 'Estetista',
      salone: 'Roma',
      email: 'sofia.verde@example.com',
      telefono: '+39 333 9999999',
      appuntamenti: 76,
      status: 'inactive' as const
    }
  ];

  const columns = [
    {
      key: 'nome',
      label: 'Membro Staff',
      sortable: true,
      render: (item: typeof staffData[0]) => (
        <div>
          <div className="font-semibold">{item.nome}</div>
          <div className="text-xs text-muted-foreground">{item.ruolo}</div>
        </div>
      )
    },
    {
      key: 'salone',
      label: 'Salone',
      render: (item: typeof staffData[0]) => (
        <span className="text-sm">{item.salone}</span>
      )
    },
    {
      key: 'contatti',
      label: 'Contatti',
      render: (item: typeof staffData[0]) => (
        <div className="text-sm">
          <div className="text-muted-foreground text-xs">{item.email}</div>
          <div className="text-xs">{item.telefono}</div>
        </div>
      )
    },
    {
      key: 'appuntamenti',
      label: 'Appuntamenti',
      sortable: true,
      render: (item: typeof staffData[0]) => (
        <span className="font-medium">{item.appuntamenti}</span>
      )
    },
    {
      key: 'status',
      label: 'Stato',
      render: (item: typeof staffData[0]) => (
        <StatusBadge 
          status={item.status} 
          label={item.status === 'active' ? 'Attivo' : 'Inattivo'} 
        />
      )
    },
    {
      key: 'actions',
      label: 'Azioni',
      render: (item: typeof staffData[0]) => (
        <div className="flex gap-2">
          <button className="p-2 hover:bg-muted rounded-lg transition-colors">
            <Eye className="size-4" />
          </button>
          <button className="p-2 hover:bg-muted rounded-lg transition-colors">
            <Edit className="size-4" />
          </button>
        </div>
      )
    }
  ];

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto">
        <h2 className="text-3xl font-bold mb-6">Staff</h2>
        <LoadingState message="Caricamento staff..." />
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-3xl font-bold mb-2">Staff</h2>
          <p className="text-muted-foreground">Gestione team e turni</p>
        </div>
        <button className="flex items-center gap-2 px-6 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors shadow-sm">
          <Plus className="size-5" />
          Aggiungi Membro
        </button>
      </div>

      <div className="flex flex-col sm:flex-row gap-3">
        <div className="flex-1 relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 size-5 text-muted-foreground" />
          <input
            type="text"
            placeholder="Cerca staff..."
            className="w-full pl-10 pr-4 py-3 bg-input-background border border-border rounded-lg focus:outline-none focus:ring-2 focus:ring-ring"
          />
        </div>
        <button className="flex items-center justify-center gap-2 px-4 py-3 border border-border rounded-lg hover:bg-muted transition-colors">
          <Filter className="size-5" />
          <span className="hidden sm:inline">Filtri</span>
        </button>
      </div>

      <DataTable
        columns={columns}
        data={staffData}
        keyExtractor={(item) => item.id}
        onRowClick={(item) => toast.info(`Apri profilo ${item.nome}`)}
        emptyMessage="Nessun membro staff trovato"
      />
    </div>
  );
}

// ===================================
// 4. CLIENTI MODULE
// ===================================
// Admin/Clienti/List/Responsive/Default
function ClientiModule() {
  const navigate = useNavigate();
  const [loading] = useState(false);

  const clientiData = [
    {
      id: 1,
      nome: 'Anna Ferrari',
      email: 'anna.ferrari@email.it',
      telefono: '+39 320 1234567',
      appuntamenti: 24,
      ultimaVisita: '2026-02-28',
      spesaTotale: 1240,
      status: 'active' as const
    },
    {
      id: 2,
      nome: 'Marco Romano',
      email: 'marco.romano@email.it',
      telefono: '+39 320 9876543',
      appuntamenti: 8,
      ultimaVisita: '2026-03-01',
      spesaTotale: 480,
      status: 'active' as const
    },
    {
      id: 3,
      nome: 'Giulia Conti',
      email: 'giulia.conti@email.it',
      telefono: '+39 320 5555555',
      appuntamenti: 45,
      ultimaVisita: '2026-02-15',
      spesaTotale: 3200,
      status: 'active' as const
    }
  ];

  const columns = [
    {
      key: 'nome',
      label: 'Cliente',
      sortable: true,
      render: (item: typeof clientiData[0]) => (
        <div>
          <div className="font-semibold">{item.nome}</div>
          <div className="text-xs text-muted-foreground">{item.email}</div>
        </div>
      )
    },
    {
      key: 'telefono',
      label: 'Telefono',
      render: (item: typeof clientiData[0]) => (
        <span className="text-sm">{item.telefono}</span>
      )
    },
    {
      key: 'appuntamenti',
      label: 'Visite',
      sortable: true,
      render: (item: typeof clientiData[0]) => (
        <span className="font-medium">{item.appuntamenti}</span>
      )
    },
    {
      key: 'ultimaVisita',
      label: 'Ultima Visita',
      render: (item: typeof clientiData[0]) => (
        <span className="text-sm">{new Date(item.ultimaVisita).toLocaleDateString('it-IT')}</span>
      )
    },
    {
      key: 'spesaTotale',
      label: 'Spesa Totale',
      sortable: true,
      render: (item: typeof clientiData[0]) => (
        <span className="font-semibold text-primary">€{item.spesaTotale}</span>
      )
    },
    {
      key: 'actions',
      label: 'Azioni',
      render: (item: typeof clientiData[0]) => (
        <div className="flex gap-2">
          <button 
            onClick={(e) => {
              e.stopPropagation();
              navigate(`/admin/cliente/${item.id}`);
            }}
            className="p-2 hover:bg-muted rounded-lg transition-colors"
          >
            <Eye className="size-4" />
          </button>
          <button 
            onClick={(e) => {
              e.stopPropagation();
              toast.info(`Invia email a ${item.nome}`);
            }}
            className="p-2 hover:bg-muted rounded-lg transition-colors"
          >
            <Mail className="size-4" />
          </button>
        </div>
      )
    }
  ];

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto">
        <h2 className="text-3xl font-bold mb-6">Clienti</h2>
        <LoadingState message="Caricamento clienti..." />
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-3xl font-bold mb-2">Clienti</h2>
          <p className="text-muted-foreground">Anagrafica e gestione clienti</p>
        </div>
        <button className="flex items-center gap-2 px-6 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors shadow-sm">
          <Plus className="size-5" />
          Aggiungi Cliente
        </button>
      </div>

      <div className="flex flex-col sm:flex-row gap-3">
        <div className="flex-1 relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 size-5 text-muted-foreground" />
          <input
            type="text"
            placeholder="Cerca cliente..."
            className="w-full pl-10 pr-4 py-3 bg-input-background border border-border rounded-lg focus:outline-none focus:ring-2 focus:ring-ring"
          />
        </div>
        <button className="flex items-center justify-center gap-2 px-4 py-3 border border-border rounded-lg hover:bg-muted transition-colors">
          <Filter className="size-5" />
          <span className="hidden sm:inline">Filtri</span>
        </button>
        <button className="flex items-center justify-center gap-2 px-4 py-3 border border-border rounded-lg hover:bg-muted transition-colors">
          <Download className="size-5" />
          <span className="hidden sm:inline">Esporta</span>
        </button>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">Clienti Totali</div>
          <div className="text-2xl font-bold">342</div>
        </div>
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">Nuovi (Mese)</div>
          <div className="text-2xl font-bold text-success">+18</div>
        </div>
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">Clienti VIP</div>
          <div className="text-2xl font-bold text-primary">24</div>
        </div>
      </div>

      <DataTable
        columns={columns}
        data={clientiData}
        keyExtractor={(item) => item.id}
        onRowClick={(item) => navigate(`/admin/cliente/${item.id}`)}
        emptyMessage="Nessun cliente trovato"
      />
    </div>
  );
}

// ===================================
// 5. MOVIMENTI APP MODULE
// ===================================
// Admin/Movimenti/List/Responsive/Default
function MovimentiModule() {
  const [loading] = useState(false);

  const movimentiData = [
    {
      id: 1,
      tipo: 'Pacchetto Acquistato',
      cliente: 'Anna Ferrari',
      importo: 299,
      data: '2026-03-03 10:30',
      metodo: 'Carta',
      status: 'success' as const
    },
    {
      id: 2,
      tipo: 'Prenotazione',
      cliente: 'Marco Romano',
      importo: 0,
      data: '2026-03-03 09:15',
      metodo: '-',
      status: 'pending' as const
    },
    {
      id: 3,
      tipo: 'Cancellazione',
      cliente: 'Giulia Conti',
      importo: -50,
      data: '2026-03-02 18:20',
      metodo: 'Bonifico',
      status: 'cancelled' as const
    }
  ];

  const columns = [
    {
      key: 'tipo',
      label: 'Tipo Movimento',
      render: (item: typeof movimentiData[0]) => (
        <div>
          <div className="font-semibold">{item.tipo}</div>
          <div className="text-xs text-muted-foreground">{item.data}</div>
        </div>
      )
    },
    {
      key: 'cliente',
      label: 'Cliente',
      render: (item: typeof movimentiData[0]) => (
        <span className="text-sm">{item.cliente}</span>
      )
    },
    {
      key: 'importo',
      label: 'Importo',
      render: (item: typeof movimentiData[0]) => (
        <span className={`font-semibold ${item.importo > 0 ? 'text-success' : item.importo < 0 ? 'text-error' : ''}`}>
          {item.importo > 0 ? '+' : ''}€{Math.abs(item.importo)}
        </span>
      )
    },
    {
      key: 'metodo',
      label: 'Metodo',
      render: (item: typeof movimentiData[0]) => (
        <span className="text-sm">{item.metodo}</span>
      )
    },
    {
      key: 'status',
      label: 'Stato',
      render: (item: typeof movimentiData[0]) => {
        const labels = {
          success: 'Completato',
          pending: 'In Attesa',
          cancelled: 'Cancellato'
        };
        return <StatusBadge status={item.status} label={labels[item.status]} />;
      }
    }
  ];

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto">
        <h2 className="text-3xl font-bold mb-6">Movimenti App</h2>
        <LoadingState message="Caricamento movimenti..." />
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      <div>
        <h2 className="text-3xl font-bold mb-2">Movimenti App</h2>
        <p className="text-muted-foreground">Tracciamento attività e transazioni app cliente</p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-4 gap-4">
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">Oggi</div>
          <div className="text-2xl font-bold">12</div>
        </div>
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">Questa Settimana</div>
          <div className="text-2xl font-bold">48</div>
        </div>
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">Volume €</div>
          <div className="text-2xl font-bold text-success">€3.240</div>
        </div>
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">In Attesa</div>
          <div className="text-2xl font-bold text-warning">5</div>
        </div>
      </div>

      <div className="flex flex-col sm:flex-row gap-3">
        <div className="flex-1 relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 size-5 text-muted-foreground" />
          <input
            type="text"
            placeholder="Cerca movimento..."
            className="w-full pl-10 pr-4 py-3 bg-input-background border border-border rounded-lg focus:outline-none focus:ring-2 focus:ring-ring"
          />
        </div>
        <button className="flex items-center justify-center gap-2 px-4 py-3 border border-border rounded-lg hover:bg-muted transition-colors">
          <Filter className="size-5" />
          <span className="hidden sm:inline">Filtri</span>
        </button>
      </div>

      <DataTable
        columns={columns}
        data={movimentiData}
        keyExtractor={(item) => item.id}
        emptyMessage="Nessun movimento trovato"
      />
    </div>
  );
}

// ===================================
// 6. AGENDA MODULE
// ===================================
// Admin/Agenda/Calendar/Responsive/Enhanced
function AgendaModule() {
  const [loading] = useState(false);
  const [showAppuntamentoModal, setShowAppuntamentoModal] = useState(false);
  const [selectedAppuntamento, setSelectedAppuntamento] = useState<any>(null);

  const handleAppuntamentoClick = (appuntamento: any) => {
    setSelectedAppuntamento(appuntamento);
    setShowAppuntamentoModal(true);
  };

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto">
        <h2 className="text-3xl font-bold mb-6">Agenda</h2>
        <LoadingState message="Caricamento agenda..." />
      </div>
    );
  }

  return (
    <>
      <div className="space-y-6">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div>
            <h2 className="text-3xl font-bold mb-2">Agenda</h2>
            <p className="text-muted-foreground">Calendario settimanale con drag & drop</p>
          </div>
          <button 
            onClick={() => {
              setSelectedAppuntamento(null);
              setShowAppuntamentoModal(true);
            }}
            className="flex items-center gap-2 px-6 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors shadow-sm"
          >
            <Plus className="size-5" />
            Nuovo Appuntamento
          </button>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-4 gap-4">
          <div className="bg-card border border-border rounded-xl p-4">
            <div className="text-muted-foreground text-sm mb-1">Oggi</div>
            <div className="text-2xl font-bold">24</div>
          </div>
          <div className="bg-card border border-border rounded-xl p-4">
            <div className="text-muted-foreground text-sm mb-1">Questa Settimana</div>
            <div className="text-2xl font-bold">156</div>
          </div>
          <div className="bg-card border border-border rounded-xl p-4">
            <div className="text-muted-foreground text-sm mb-1">Confermati</div>
            <div className="text-2xl font-bold text-success">140</div>
          </div>
          <div className="bg-card border border-border rounded-xl p-4">
            <div className="text-muted-foreground text-sm mb-1">Da Confermare</div>
            <div className="text-2xl font-bold text-warning">16</div>
          </div>
        </div>

        {/* Calendario Enhanced con Drag & Drop */}
        <AgendaCalendarModern onAppuntamentoClick={handleAppuntamentoClick} />
      </div>

      {/* Appuntamento Bottom Sheet */}
      <AppuntamentoBottomSheet
        isOpen={showAppuntamentoModal}
        onClose={() => {
          setShowAppuntamentoModal(false);
          setSelectedAppuntamento(null);
        }}
        mode={selectedAppuntamento ? 'edit' : 'create'}
        initialData={selectedAppuntamento}
      />
    </>
  );
}

// Import remaining modules from separate file
import { 
  MagazzinoModule, 
  VenditeModule, 
  WhatsAppModule, 
  ReportModule 
} from './AdminModules';