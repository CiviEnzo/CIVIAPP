import { useState } from 'react';
import { useNavigate } from 'react-router';
import { 
  Calendar, Briefcase, LogOut, Bell, ChevronRight, ChevronLeft,
  Clock, User, Phone, Mail, MapPin, X, Plus, Eye, Check, XCircle,
  AlertCircle, FileText, Tag
} from 'lucide-react';
import { toast } from 'sonner';
import StatusBadge from '../../components/StatusBadge';
import LoadingState from '../../components/LoadingState';
import EmptyState from '../../components/EmptyState';

// Staff/Dashboard/Layout/Responsive/Default
export default function StaffDashboard() {
  const [activeTab, setActiveTab] = useState<'agenda' | 'ferie'>('agenda');
  const navigate = useNavigate();

  const handleLogout = () => {
    toast.success('Logout effettuato');
    navigate('/');
  };

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="bg-card border-b border-border sticky top-0 z-40">
        <div className="flex items-center justify-between px-4 lg:px-6 h-16">
          <h1 className="text-xl font-bold text-primary">YouBook Staff</h1>
          <div className="flex items-center gap-3">
            <button className="relative p-2 hover:bg-muted rounded-lg transition-colors">
              <Bell className="size-5" />
              <span className="absolute top-1 right-1 w-2 h-2 bg-error rounded-full"></span>
            </button>
            <button
              onClick={handleLogout}
              className="p-2 hover:bg-muted rounded-lg transition-colors"
            >
              <LogOut className="size-5" />
            </button>
          </div>
        </div>
      </header>

      {/* Tabs */}
      <div className="bg-card border-b border-border">
        <div className="flex">
          <button
            onClick={() => setActiveTab('agenda')}
            className={`flex-1 flex items-center justify-center gap-2 px-4 py-3 border-b-2 transition-colors ${
              activeTab === 'agenda'
                ? 'border-primary text-primary font-medium'
                : 'border-transparent text-muted-foreground'
            }`}
          >
            <Calendar className="size-5" />
            <span>Agenda</span>
          </button>
          <button
            onClick={() => setActiveTab('ferie')}
            className={`flex-1 flex items-center justify-center gap-2 px-4 py-3 border-b-2 transition-colors ${
              activeTab === 'ferie'
                ? 'border-primary text-primary font-medium'
                : 'border-transparent text-muted-foreground'
            }`}
          >
            <Briefcase className="size-5" />
            <span>Ferie & Permessi</span>
          </button>
        </div>
      </div>

      {/* Content */}
      <main className="p-4 lg:p-8">
        {activeTab === 'agenda' ? <AgendaTab /> : <FerieTab />}
      </main>
    </div>
  );
}

// ===================================
// AGENDA TAB
// ===================================
// Staff/Agenda/Calendar/Responsive/Default
function AgendaTab() {
  const [viewType, setViewType] = useState<'day' | 'week'>('day');
  const [selectedDate, setSelectedDate] = useState(new Date(2026, 2, 3)); // 3 Marzo 2026
  const [selectedClient, setSelectedClient] = useState<string | null>(null);
  const [loading] = useState(false);

  const appointments = [
    {
      id: '1',
      clientName: 'Maria Rossi',
      clientId: 'client-1',
      service: 'Taglio e Piega',
      time: '09:00',
      duration: 90,
      status: 'confirmed' as const,
      price: 45,
      notes: 'Cliente preferisce taglio scalato'
    },
    {
      id: '2',
      clientName: 'Giulia Bianchi',
      clientId: 'client-2',
      service: 'Colore Completo',
      time: '11:00',
      duration: 120,
      status: 'confirmed' as const,
      price: 85,
      notes: ''
    },
    {
      id: '3',
      clientName: 'Laura Verdi',
      clientId: 'client-3',
      service: 'Trattamento Viso',
      time: '14:00',
      duration: 60,
      status: 'pending' as const,
      price: 55,
      notes: 'Prima volta, pelle sensibile'
    },
    {
      id: '4',
      clientName: 'Sofia Neri',
      clientId: 'client-4',
      service: 'Piega',
      time: '16:00',
      duration: 30,
      status: 'confirmed' as const,
      price: 25,
      notes: ''
    },
  ];

  // Mock data per vista settimana (giorni da Lunedì a Domenica)
  const weekDays = [
    { date: new Date(2026, 2, 2), label: 'Lun', day: '2', count: 3 },
    { date: new Date(2026, 2, 3), label: 'Mar', day: '3', count: 4 },
    { date: new Date(2026, 2, 4), label: 'Mer', day: '4', count: 5 },
    { date: new Date(2026, 2, 5), label: 'Gio', day: '5', count: 6 },
    { date: new Date(2026, 2, 6), label: 'Ven', day: '6', count: 7 },
    { date: new Date(2026, 2, 7), label: 'Sab', day: '7', count: 8 },
    { date: new Date(2026, 2, 8), label: 'Dom', day: '8', count: 0 },
  ];

  const goToPreviousDay = () => {
    const newDate = new Date(selectedDate);
    newDate.setDate(newDate.getDate() - 1);
    setSelectedDate(newDate);
  };

  const goToNextDay = () => {
    const newDate = new Date(selectedDate);
    newDate.setDate(newDate.getDate() + 1);
    setSelectedDate(newDate);
  };

  const goToPreviousWeek = () => {
    const newDate = new Date(selectedDate);
    newDate.setDate(newDate.getDate() - 7);
    setSelectedDate(newDate);
  };

  const goToNextWeek = () => {
    const newDate = new Date(selectedDate);
    newDate.setDate(newDate.getDate() + 7);
    setSelectedDate(newDate);
  };

  const formatTime = (time: string, duration: number) => {
    const [hours, minutes] = time.split(':').map(Number);
    const endHours = Math.floor((hours * 60 + minutes + duration) / 60);
    const endMinutes = (hours * 60 + minutes + duration) % 60;
    return `${time} - ${String(endHours).padStart(2, '0')}:${String(endMinutes).padStart(2, '0')}`;
  };

  if (loading) {
    return <LoadingState message="Caricamento agenda..." />;
  }

  // Client Detail Drawer
  if (selectedClient) {
    const appointment = appointments.find(a => a.clientId === selectedClient);
    if (appointment) {
      return <ClientDetailDrawer appointment={appointment} onClose={() => setSelectedClient(null)} />;
    }
  }

  return (
    <div className="max-w-6xl mx-auto space-y-6">
      {/* Header with View Switcher */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold mb-1">
            {viewType === 'day' ? 'Agenda Giorno' : 'Agenda Settimana'}
          </h2>
          <p className="text-muted-foreground">
            {selectedDate.toLocaleDateString('it-IT', { 
              weekday: 'long', 
              year: 'numeric', 
              month: 'long', 
              day: 'numeric' 
            })}
          </p>
        </div>
        <div className="flex gap-2">
          <button
            onClick={() => setViewType('day')}
            className={`px-4 py-2 rounded-lg transition-colors ${
              viewType === 'day'
                ? 'bg-primary text-primary-foreground'
                : 'bg-muted text-foreground hover:bg-muted/80'
            }`}
          >
            Giorno
          </button>
          <button
            onClick={() => setViewType('week')}
            className={`px-4 py-2 rounded-lg transition-colors ${
              viewType === 'week'
                ? 'bg-primary text-primary-foreground'
                : 'bg-muted text-foreground hover:bg-muted/80'
            }`}
          >
            Settimana
          </button>
        </div>
      </div>

      {/* Vista Giorno */}
      {viewType === 'day' && (
        <>
          {/* Navigation */}
          <div className="flex items-center justify-between bg-card border border-border rounded-xl p-4">
            <button
              onClick={goToPreviousDay}
              className="p-2 hover:bg-muted rounded-lg transition-colors"
            >
              <ChevronLeft className="size-5" />
            </button>
            <div className="text-center">
              <div className="text-lg font-semibold">
                {selectedDate.toLocaleDateString('it-IT', { weekday: 'long' })}
              </div>
              <div className="text-sm text-muted-foreground">
                {selectedDate.toLocaleDateString('it-IT', { day: 'numeric', month: 'long', year: 'numeric' })}
              </div>
            </div>
            <button
              onClick={goToNextDay}
              className="p-2 hover:bg-muted rounded-lg transition-colors"
            >
              <ChevronRight className="size-5" />
            </button>
          </div>

          {/* Stats */}
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            <div className="bg-card border border-border rounded-xl p-4">
              <div className="text-muted-foreground text-sm mb-1">Appuntamenti</div>
              <div className="text-2xl font-bold">{appointments.length}</div>
            </div>
            <div className="bg-card border border-border rounded-xl p-4">
              <div className="text-muted-foreground text-sm mb-1">Confermati</div>
              <div className="text-2xl font-bold text-success">
                {appointments.filter(a => a.status === 'confirmed').length}
              </div>
            </div>
            <div className="bg-card border border-border rounded-xl p-4">
              <div className="text-muted-foreground text-sm mb-1">In Attesa</div>
              <div className="text-2xl font-bold text-warning">
                {appointments.filter(a => a.status === 'pending').length}
              </div>
            </div>
            <div className="bg-card border border-border rounded-xl p-4">
              <div className="text-muted-foreground text-sm mb-1">Incasso Previsto</div>
              <div className="text-2xl font-bold text-primary">
                €{appointments.reduce((sum, a) => sum + a.price, 0)}
              </div>
            </div>
          </div>

          {/* Appointments List */}
          {appointments.length === 0 ? (
            <EmptyState
              icon={Calendar}
              title="Nessun appuntamento"
              description="Non ci sono appuntamenti programmati per oggi"
            />
          ) : (
            <div className="space-y-3">
              {appointments.map((apt) => (
                <div
                  key={apt.id}
                  onClick={() => setSelectedClient(apt.clientId)}
                  className="bg-card border border-border rounded-xl p-4 hover:border-primary transition-colors cursor-pointer"
                >
                  <div className="flex items-start justify-between mb-3">
                    <div className="flex-1">
                      <div className="flex items-center gap-2 mb-1">
                        <h3 className="font-semibold">{apt.clientName}</h3>
                        <StatusBadge
                          status={apt.status === 'confirmed' ? 'success' : 'pending'}
                          label={apt.status === 'confirmed' ? 'Confermato' : 'In attesa'}
                          size="sm"
                        />
                      </div>
                      <p className="text-sm text-muted-foreground">{apt.service}</p>
                      {apt.notes && (
                        <div className="flex items-start gap-2 mt-2 p-2 bg-muted/50 rounded-lg">
                          <FileText className="size-4 text-muted-foreground mt-0.5 flex-shrink-0" />
                          <p className="text-xs text-muted-foreground">{apt.notes}</p>
                        </div>
                      )}
                    </div>
                  </div>

                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-4 text-sm text-muted-foreground">
                      <div className="flex items-center gap-1">
                        <Clock className="size-4" />
                        <span>{formatTime(apt.time, apt.duration)}</span>
                      </div>
                      <div className="flex items-center gap-1">
                        <Tag className="size-4" />
                        <span className="font-medium text-primary">€{apt.price}</span>
                      </div>
                    </div>
                    <ChevronRight className="size-5 text-muted-foreground" />
                  </div>
                </div>
              ))}
            </div>
          )}
        </>
      )}

      {/* Vista Settimana */}
      {viewType === 'week' && (
        <>
          {/* Navigation */}
          <div className="flex items-center justify-between bg-card border border-border rounded-xl p-4">
            <button
              onClick={goToPreviousWeek}
              className="p-2 hover:bg-muted rounded-lg transition-colors"
            >
              <ChevronLeft className="size-5" />
            </button>
            <div className="text-center">
              <div className="text-lg font-semibold">
                Settimana {Math.ceil(selectedDate.getDate() / 7)}
              </div>
              <div className="text-sm text-muted-foreground">
                {selectedDate.toLocaleDateString('it-IT', { month: 'long', year: 'numeric' })}
              </div>
            </div>
            <button
              onClick={goToNextWeek}
              className="p-2 hover:bg-muted rounded-lg transition-colors"
            >
              <ChevronRight className="size-5" />
            </button>
          </div>

          {/* Week Grid */}
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-7 gap-3">
            {weekDays.map((day, index) => {
              const isToday = day.date.toDateString() === selectedDate.toDateString();
              const isWeekend = index >= 5;
              
              return (
                <button
                  key={index}
                  onClick={() => {
                    setSelectedDate(day.date);
                    setViewType('day');
                  }}
                  className={`bg-card border rounded-xl p-4 transition-colors text-left ${
                    isToday
                      ? 'border-primary bg-primary/5'
                      : 'border-border hover:border-primary/50'
                  }`}
                >
                  <div className="text-xs text-muted-foreground mb-1">{day.label}</div>
                  <div className={`text-2xl font-bold mb-2 ${isToday ? 'text-primary' : ''}`}>
                    {day.day}
                  </div>
                  <div className="flex items-center gap-1">
                    <Calendar className="size-3 text-muted-foreground" />
                    <span className={`text-xs font-medium ${
                      day.count > 0 ? 'text-foreground' : 'text-muted-foreground'
                    }`}>
                      {day.count} app.
                    </span>
                  </div>
                  {isWeekend && (
                    <div className="text-xs text-warning mt-1">Weekend</div>
                  )}
                </button>
              );
            })}
          </div>

          {/* Week Summary */}
          <div className="bg-card border border-border rounded-xl p-6">
            <h3 className="text-lg font-semibold mb-4">Riepilogo Settimana</h3>
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <div>
                <div className="text-muted-foreground text-sm mb-1">Tot. Appuntamenti</div>
                <div className="text-2xl font-bold">
                  {weekDays.reduce((sum, day) => sum + day.count, 0)}
                </div>
              </div>
              <div>
                <div className="text-muted-foreground text-sm mb-1">Media Giornaliera</div>
                <div className="text-2xl font-bold">
                  {Math.round(weekDays.reduce((sum, day) => sum + day.count, 0) / 7)}
                </div>
              </div>
              <div>
                <div className="text-muted-foreground text-sm mb-1">Incasso Previsto</div>
                <div className="text-2xl font-bold text-primary">€1.240</div>
              </div>
            </div>
          </div>
        </>
      )}
    </div>
  );
}

// ===================================
// CLIENT DETAIL DRAWER
// ===================================
// Staff/Client/Detail/Responsive/ReadOnly
interface ClientDetailDrawerProps {
  appointment: {
    id: string;
    clientName: string;
    clientId: string;
    service: string;
    time: string;
    duration: number;
    status: 'confirmed' | 'pending';
    price: number;
    notes: string;
  };
  onClose: () => void;
}

function ClientDetailDrawer({ appointment, onClose }: ClientDetailDrawerProps) {
  // Mock client data - read-only
  const clientData = {
    id: appointment.clientId,
    name: appointment.clientName,
    email: `${appointment.clientName.toLowerCase().replace(' ', '.')}@email.it`,
    phone: '+39 320 1234567',
    address: 'Via Roma 123, Milano',
    totalVisits: 24,
    totalSpent: 1240,
    lastVisit: '28 Febbraio 2026',
    memberSince: 'Gennaio 2024',
    notes: 'Cliente VIP, preferisce prodotti naturali',
    preferences: [
      'Prodotti senza parabeni',
      'Taglio scalato',
      'Colore caldo'
    ],
    allergies: 'Nessuna allergia nota',
    recentServices: [
      { date: '28 Feb 2026', service: 'Taglio e Colore', price: 95 },
      { date: '15 Feb 2026', service: 'Piega', price: 25 },
      { date: '2 Feb 2026', service: 'Trattamento', price: 55 }
    ]
  };

  return (
    <div className="fixed inset-0 bg-background z-50 overflow-y-auto">
      {/* Header */}
      <div className="sticky top-0 bg-card border-b border-border z-10">
        <div className="flex items-center justify-between px-4 lg:px-6 h-16">
          <h2 className="text-xl font-semibold">Dettaglio Cliente</h2>
          <button
            onClick={onClose}
            className="p-2 hover:bg-muted rounded-lg transition-colors"
          >
            <X className="size-5" />
          </button>
        </div>
      </div>

      {/* Content */}
      <div className="p-4 lg:p-8 max-w-4xl mx-auto space-y-6">
        {/* Current Appointment */}
        <div className="bg-primary/10 border border-primary/20 rounded-xl p-6">
          <div className="flex items-center gap-2 mb-4">
            <Calendar className="size-5 text-primary" />
            <h3 className="text-lg font-semibold">Appuntamento Corrente</h3>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <div className="text-sm text-muted-foreground mb-1">Servizio</div>
              <div className="font-medium">{appointment.service}</div>
            </div>
            <div>
              <div className="text-sm text-muted-foreground mb-1">Orario</div>
              <div className="font-medium">{appointment.time} ({appointment.duration} min)</div>
            </div>
            <div>
              <div className="text-sm text-muted-foreground mb-1">Prezzo</div>
              <div className="font-medium text-primary">€{appointment.price}</div>
            </div>
            <div>
              <div className="text-sm text-muted-foreground mb-1">Stato</div>
              <StatusBadge
                status={appointment.status === 'confirmed' ? 'success' : 'pending'}
                label={appointment.status === 'confirmed' ? 'Confermato' : 'In attesa'}
                size="sm"
              />
            </div>
          </div>
          {appointment.notes && (
            <div className="mt-4 p-3 bg-card rounded-lg">
              <div className="text-sm text-muted-foreground mb-1">Note Appuntamento</div>
              <div className="text-sm">{appointment.notes}</div>
            </div>
          )}
        </div>

        {/* Client Info */}
        <div className="bg-card border border-border rounded-xl p-6">
          <div className="flex items-center gap-2 mb-4">
            <User className="size-5 text-primary" />
            <h3 className="text-lg font-semibold">Informazioni Cliente</h3>
          </div>
          <div className="space-y-4">
            <div>
              <div className="text-sm text-muted-foreground mb-1">Nome Completo</div>
              <div className="font-medium text-lg">{clientData.name}</div>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="flex items-center gap-3">
                <Mail className="size-5 text-muted-foreground" />
                <div>
                  <div className="text-sm text-muted-foreground">Email</div>
                  <div className="text-sm">{clientData.email}</div>
                </div>
              </div>
              <div className="flex items-center gap-3">
                <Phone className="size-5 text-muted-foreground" />
                <div>
                  <div className="text-sm text-muted-foreground">Telefono</div>
                  <div className="text-sm">{clientData.phone}</div>
                </div>
              </div>
            </div>
            <div className="flex items-start gap-3">
              <MapPin className="size-5 text-muted-foreground mt-0.5" />
              <div>
                <div className="text-sm text-muted-foreground">Indirizzo</div>
                <div className="text-sm">{clientData.address}</div>
              </div>
            </div>
          </div>
        </div>

        {/* Client Stats */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
          <div className="bg-card border border-border rounded-xl p-4">
            <div className="text-muted-foreground text-sm mb-1">Visite Totali</div>
            <div className="text-2xl font-bold">{clientData.totalVisits}</div>
          </div>
          <div className="bg-card border border-border rounded-xl p-4">
            <div className="text-muted-foreground text-sm mb-1">Spesa Totale</div>
            <div className="text-2xl font-bold text-primary">€{clientData.totalSpent}</div>
          </div>
          <div className="bg-card border border-border rounded-xl p-4">
            <div className="text-muted-foreground text-sm mb-1">Ultima Visita</div>
            <div className="text-sm font-medium">{clientData.lastVisit}</div>
          </div>
          <div className="bg-card border border-border rounded-xl p-4">
            <div className="text-muted-foreground text-sm mb-1">Cliente dal</div>
            <div className="text-sm font-medium">{clientData.memberSince}</div>
          </div>
        </div>

        {/* Preferences & Notes */}
        <div className="bg-card border border-border rounded-xl p-6">
          <div className="flex items-center gap-2 mb-4">
            <FileText className="size-5 text-primary" />
            <h3 className="text-lg font-semibold">Preferenze e Note</h3>
          </div>
          <div className="space-y-4">
            <div>
              <div className="text-sm text-muted-foreground mb-2">Preferenze</div>
              <div className="flex flex-wrap gap-2">
                {clientData.preferences.map((pref, index) => (
                  <span
                    key={index}
                    className="px-3 py-1 bg-primary/10 text-primary text-sm rounded-full"
                  >
                    {pref}
                  </span>
                ))}
              </div>
            </div>
            <div>
              <div className="text-sm text-muted-foreground mb-1">Allergie</div>
              <div className="text-sm">{clientData.allergies}</div>
            </div>
            <div>
              <div className="text-sm text-muted-foreground mb-1">Note Generali</div>
              <div className="text-sm p-3 bg-muted/50 rounded-lg">{clientData.notes}</div>
            </div>
          </div>
        </div>

        {/* Recent Services */}
        <div className="bg-card border border-border rounded-xl p-6">
          <h3 className="text-lg font-semibold mb-4">Servizi Recenti</h3>
          <div className="space-y-3">
            {clientData.recentServices.map((service, index) => (
              <div
                key={index}
                className="flex items-center justify-between p-3 border border-border rounded-lg"
              >
                <div>
                  <div className="font-medium">{service.service}</div>
                  <div className="text-xs text-muted-foreground">{service.date}</div>
                </div>
                <div className="font-semibold text-primary">€{service.price}</div>
              </div>
            ))}
          </div>
        </div>

        {/* Action Button */}
        <button
          onClick={onClose}
          className="w-full px-6 py-3 bg-muted text-foreground rounded-lg hover:bg-muted/80 transition-colors"
        >
          Chiudi
        </button>
      </div>
    </div>
  );
}

// ===================================
// FERIE & PERMESSI TAB
// ===================================
// Staff/Requests/List/Responsive/Default
function FerieTab() {
  const [showForm, setShowForm] = useState(false);
  const [loading] = useState(false);
  const [formData, setFormData] = useState({
    type: 'ferie',
    startDate: '',
    endDate: '',
    notes: '',
  });

  const requests = [
    {
      id: '1',
      type: 'ferie',
      startDate: '15 Marzo 2026',
      endDate: '20 Marzo 2026',
      days: 6,
      status: 'pending' as const,
      submittedAt: '1 Marzo 2026',
      notes: 'Vacanza famiglia'
    },
    {
      id: '2',
      type: 'permesso',
      startDate: '8 Aprile 2026',
      endDate: '8 Aprile 2026',
      days: 1,
      status: 'approved' as const,
      submittedAt: '25 Febbraio 2026',
      approvedAt: '26 Febbraio 2026',
      notes: 'Visita medica'
    },
    {
      id: '3',
      type: 'malattia',
      startDate: '10 Febbraio 2026',
      endDate: '12 Febbraio 2026',
      days: 3,
      status: 'approved' as const,
      submittedAt: '10 Febbraio 2026',
      approvedAt: '10 Febbraio 2026',
      notes: 'Influenza'
    },
    {
      id: '4',
      type: 'ferie',
      startDate: '1 Agosto 2026',
      endDate: '15 Agosto 2026',
      days: 15,
      status: 'rejected' as const,
      submittedAt: '28 Febbraio 2026',
      rejectedAt: '29 Febbraio 2026',
      rejectionReason: 'Periodo già richiesto da altro staff',
      notes: 'Ferie estive'
    },
  ];

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    toast.success('Richiesta inviata con successo');
    setShowForm(false);
    setFormData({ type: 'ferie', startDate: '', endDate: '', notes: '' });
  };

  if (loading) {
    return <LoadingState message="Caricamento richieste..." />;
  }

  // Form View
  if (showForm) {
    return (
      <div className="max-w-2xl mx-auto">
        <div className="mb-6">
          <h2 className="text-2xl font-bold mb-2">Nuova Richiesta</h2>
          <p className="text-muted-foreground">Invia una richiesta di ferie, permesso o malattia</p>
        </div>

        <form onSubmit={handleSubmit} className="bg-card border border-border rounded-xl p-6 space-y-6">
          <div>
            <label className="block text-sm font-medium mb-2">Tipo *</label>
            <select
              value={formData.type}
              onChange={(e) => setFormData({ ...formData, type: e.target.value })}
              className="w-full px-4 py-3 bg-input-background border border-border rounded-lg focus:outline-none focus:ring-2 focus:ring-ring"
              required
            >
              <option value="ferie">Ferie</option>
              <option value="permesso">Permesso</option>
              <option value="malattia">Malattia</option>
            </select>
          </div>

          <div className="grid sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium mb-2">Data Inizio *</label>
              <input
                type="date"
                value={formData.startDate}
                onChange={(e) => setFormData({ ...formData, startDate: e.target.value })}
                className="w-full px-4 py-3 bg-input-background border border-border rounded-lg focus:outline-none focus:ring-2 focus:ring-ring"
                required
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-2">Data Fine *</label>
              <input
                type="date"
                value={formData.endDate}
                onChange={(e) => setFormData({ ...formData, endDate: e.target.value })}
                className="w-full px-4 py-3 bg-input-background border border-border rounded-lg focus:outline-none focus:ring-2 focus:ring-ring"
                required
              />
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium mb-2">Note</label>
            <textarea
              value={formData.notes}
              onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
              rows={3}
              placeholder="Aggiungi dettagli o motivazione..."
              className="w-full px-4 py-3 bg-input-background border border-border rounded-lg resize-none focus:outline-none focus:ring-2 focus:ring-ring"
            />
          </div>

          <div className="flex gap-3">
            <button
              type="button"
              onClick={() => setShowForm(false)}
              className="flex-1 px-6 py-3 bg-muted text-foreground rounded-lg hover:bg-muted/80 transition-colors"
            >
              Annulla
            </button>
            <button
              type="submit"
              className="flex-1 px-6 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors shadow-sm"
            >
              Invia Richiesta
            </button>
          </div>
        </form>
      </div>
    );
  }

  // List View
  return (
    <div className="max-w-4xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold mb-1">Le Mie Richieste</h2>
          <p className="text-muted-foreground">Ferie, permessi e malattie</p>
        </div>
        <button
          onClick={() => setShowForm(true)}
          className="flex items-center justify-center gap-2 px-6 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors shadow-sm"
        >
          <Plus className="size-5" />
          Nuova Richiesta
        </button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">Totali</div>
          <div className="text-2xl font-bold">{requests.length}</div>
        </div>
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">In Attesa</div>
          <div className="text-2xl font-bold text-warning">
            {requests.filter(r => r.status === 'pending').length}
          </div>
        </div>
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">Approvate</div>
          <div className="text-2xl font-bold text-success">
            {requests.filter(r => r.status === 'approved').length}
          </div>
        </div>
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">Rifiutate</div>
          <div className="text-2xl font-bold text-error">
            {requests.filter(r => r.status === 'rejected').length}
          </div>
        </div>
      </div>

      {/* Requests List */}
      {requests.length === 0 ? (
        <EmptyState
          icon={Briefcase}
          title="Nessuna richiesta"
          description="Non hai ancora inviato richieste di ferie o permessi"
          action={{
            label: 'Nuova Richiesta',
            onClick: () => setShowForm(true)
          }}
        />
      ) : (
        <div className="space-y-3">
          {requests.map((request) => (
            <div
              key={request.id}
              className="bg-card border border-border rounded-xl p-4 sm:p-6"
            >
              {/* Header */}
              <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3 mb-4">
                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-2">
                    <h3 className="font-semibold capitalize text-lg">{request.type}</h3>
                    <StatusBadge
                      status={
                        request.status === 'approved' 
                          ? 'success' 
                          : request.status === 'rejected' 
                          ? 'cancelled' 
                          : 'pending'
                      }
                      label={
                        request.status === 'approved' 
                          ? 'Approvata' 
                          : request.status === 'rejected' 
                          ? 'Rifiutata' 
                          : 'In attesa'
                      }
                      size="sm"
                    />
                  </div>
                  <p className="text-sm text-muted-foreground">
                    Dal {request.startDate} al {request.endDate} ({request.days} {request.days === 1 ? 'giorno' : 'giorni'})
                  </p>
                </div>
                <div className="flex items-center gap-2 self-start">
                  {request.status === 'approved' && (
                    <div className="p-2 bg-success/10 rounded-lg">
                      <Check className="size-5 text-success" />
                    </div>
                  )}
                  {request.status === 'rejected' && (
                    <div className="p-2 bg-error/10 rounded-lg">
                      <XCircle className="size-5 text-error" />
                    </div>
                  )}
                  {request.status === 'pending' && (
                    <div className="p-2 bg-warning/10 rounded-lg">
                      <AlertCircle className="size-5 text-warning" />
                    </div>
                  )}
                </div>
              </div>

              {/* Details */}
              <div className="space-y-3">
                {request.notes && (
                  <div className="p-3 bg-muted/50 rounded-lg">
                    <div className="text-xs text-muted-foreground mb-1">Note</div>
                    <div className="text-sm">{request.notes}</div>
                  </div>
                )}

                {request.status === 'rejected' && request.rejectionReason && (
                  <div className="p-3 bg-error/10 border border-error/20 rounded-lg">
                    <div className="text-xs text-error font-medium mb-1">Motivo Rifiuto</div>
                    <div className="text-sm text-error">{request.rejectionReason}</div>
                  </div>
                )}

                {/* Timeline */}
                <div className="flex flex-wrap gap-4 text-xs text-muted-foreground">
                  <div className="flex items-center gap-1">
                    <Clock className="size-3" />
                    <span>Inviata il {request.submittedAt}</span>
                  </div>
                  {request.approvedAt && (
                    <div className="flex items-center gap-1">
                      <Check className="size-3 text-success" />
                      <span>Approvata il {request.approvedAt}</span>
                    </div>
                  )}
                  {request.rejectedAt && (
                    <div className="flex items-center gap-1">
                      <XCircle className="size-3 text-error" />
                      <span>Rifiutata il {request.rejectedAt}</span>
                    </div>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
