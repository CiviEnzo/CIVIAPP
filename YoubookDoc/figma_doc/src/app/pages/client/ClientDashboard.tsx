import { useState } from 'react';
import { useNavigate } from 'react-router';
import {
  Home, Calendar, ShoppingBag, ShoppingCart, Info,
  Menu, X, Bell, LogOut, Award, Package, FileText,
  CreditCard, ClipboardList, Image, Settings, ChevronRight, Clock,
  Star, MapPin, Phone, Mail, Check, AlertCircle, Search, Filter,
  User, Euro, Gift, Camera, Lock, Plus, Minus, ArrowLeft,
  CheckCircle, XCircle, Copy, Download, Sparkles, TrendingUp
} from 'lucide-react';
import { toast } from 'sonner';
import StatusBadge from '../../components/StatusBadge';
import LoadingState from '../../components/LoadingState';
import EmptyState from '../../components/EmptyState';

// Client/Dashboard/Layout/Responsive/Default
export default function ClientDashboard() {
  const [activeTab, setActiveTab] = useState<'home' | 'agenda' | 'prenota' | 'carrello' | 'info'>('home');
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [drawerContent, setDrawerContent] = useState<string | null>(null);
  const [notificationsOpen, setNotificationsOpen] = useState(false);
  const navigate = useNavigate();

  const handleLogout = () => {
    toast.success('Logout effettuato');
    navigate('/');
  };

  const openDrawerContent = (content: string) => {
    setDrawerContent(content);
    setDrawerOpen(false);
  };

  const closeDrawerContent = () => {
    setDrawerContent(null);
  };

  return (
    <div className="min-h-screen bg-background pb-20 lg:pb-0">
      {/* Header */}
      <header className="bg-card border-b border-border sticky top-0 z-40">
        <div className="flex items-center justify-between px-4 lg:px-6 h-16">
          <button
            onClick={() => setDrawerOpen(true)}
            className="p-2 hover:bg-muted rounded-lg relative transition-colors lg:hidden"
          >
            <Menu className="size-5" />
            <span className="absolute top-1 right-1 w-2 h-2 bg-primary rounded-full"></span>
          </button>
          <h1 className="text-xl font-bold text-primary">Salone Bellezza</h1>
          <button 
            onClick={() => setNotificationsOpen(true)}
            className="relative p-2 hover:bg-muted rounded-lg transition-colors"
          >
            <Bell className="size-5" />
            <span className="absolute top-1 right-1 w-2 h-2 bg-error rounded-full"></span>
          </button>
        </div>
      </header>

      {/* Side Drawer (Mobile) */}
      {drawerOpen && (
        <>
          <div
            className="fixed inset-0 bg-black/50 z-40 lg:hidden"
            onClick={() => setDrawerOpen(false)}
          />
          <aside className="fixed top-0 left-0 bottom-0 w-80 bg-card z-50 overflow-y-auto lg:hidden">
            <div className="p-4 border-b border-border flex items-center justify-between">
              <h2 className="font-semibold">Menu</h2>
              <button
                onClick={() => setDrawerOpen(false)}
                className="p-2 hover:bg-muted rounded-lg transition-colors"
              >
                <X className="size-5" />
              </button>
            </div>

            <nav className="p-4 space-y-1">
              <DrawerItem 
                icon={Award} 
                label="Punti Fedeltà" 
                badge="420 punti" 
                onClick={() => openDrawerContent('loyalty')}
              />
              <DrawerItem 
                icon={Package} 
                label="Pacchetti" 
                badge="3" 
                onClick={() => openDrawerContent('packages')}
              />
              <DrawerItem 
                icon={FileText} 
                label="Preventivi" 
                badge="1" 
                onClick={() => openDrawerContent('quotes')}
              />
              <DrawerItem 
                icon={CreditCard} 
                label="Fatturazione" 
                onClick={() => openDrawerContent('invoices')}
              />
              <DrawerItem 
                icon={ClipboardList} 
                label="Questionari" 
                onClick={() => openDrawerContent('surveys')}
              />
              <DrawerItem 
                icon={Image} 
                label="Le Mie Foto" 
                onClick={() => openDrawerContent('photos')}
              />
              <DrawerItem 
                icon={Settings} 
                label="Impostazioni" 
                onClick={() => openDrawerContent('settings')}
              />
            </nav>

            <div className="p-4 border-t border-border">
              <button
                onClick={handleLogout}
                className="w-full flex items-center gap-3 px-4 py-3 text-error hover:bg-error/10 rounded-lg transition-colors"
              >
                <LogOut className="size-5" />
                <span>Esci</span>
              </button>
            </div>
          </aside>
        </>
      )}

      {/* Desktop Sidebar */}
      <aside className="hidden lg:block fixed left-0 top-16 bottom-0 w-64 bg-card border-r border-border overflow-y-auto">
        <nav className="p-4 space-y-1">
          <DrawerItem 
            icon={Award} 
            label="Punti Fedeltà" 
            badge="420 punti" 
            onClick={() => openDrawerContent('loyalty')}
          />
          <DrawerItem 
            icon={Package} 
            label="Pacchetti" 
            badge="3" 
            onClick={() => openDrawerContent('packages')}
          />
          <DrawerItem 
            icon={FileText} 
            label="Preventivi" 
            badge="1" 
            onClick={() => openDrawerContent('quotes')}
          />
          <DrawerItem 
            icon={CreditCard} 
            label="Fatturazione" 
            onClick={() => openDrawerContent('invoices')}
          />
          <DrawerItem 
            icon={ClipboardList} 
            label="Questionari" 
            onClick={() => openDrawerContent('surveys')}
          />
          <DrawerItem 
            icon={Image} 
            label="Le Mie Foto" 
            onClick={() => openDrawerContent('photos')}
          />
          <DrawerItem 
            icon={Settings} 
            label="Impostazioni" 
            onClick={() => openDrawerContent('settings')}
          />
        </nav>
        <div className="p-4 border-t border-border">
          <button
            onClick={handleLogout}
            className="w-full flex items-center gap-3 px-4 py-3 text-error hover:bg-error/10 rounded-lg transition-colors"
          >
            <LogOut className="size-5" />
            <span>Esci</span>
          </button>
        </div>
      </aside>

      {/* Main Content */}
      <main className="p-4 lg:p-8 lg:ml-64 pb-24 lg:pb-8">
        {activeTab === 'home' && <HomeTab onNavigate={openDrawerContent} />}
        {activeTab === 'agenda' && <AgendaTab />}
        {activeTab === 'prenota' && <PrenotaTab />}
        {activeTab === 'carrello' && <CarrelloTab />}
        {activeTab === 'info' && <InfoTab />}
      </main>

      {/* Bottom Navigation (Mobile) */}
      <nav className="fixed bottom-0 left-0 right-0 bg-card border-t border-border z-30 lg:hidden">
        <div className="flex items-center justify-around h-20">
          <NavItem
            icon={Home}
            label="Home"
            active={activeTab === 'home'}
            onClick={() => setActiveTab('home')}
          />
          <NavItem
            icon={Calendar}
            label="Agenda"
            active={activeTab === 'agenda'}
            onClick={() => setActiveTab('agenda')}
            badge={2}
          />
          <NavItem
            icon={ShoppingBag}
            label="Prenota"
            active={activeTab === 'prenota'}
            onClick={() => setActiveTab('prenota')}
          />
          <NavItem
            icon={ShoppingCart}
            label="Carrello"
            active={activeTab === 'carrello'}
            onClick={() => setActiveTab('carrello')}
            badge={1}
          />
          <NavItem
            icon={Info}
            label="Info"
            active={activeTab === 'info'}
            onClick={() => setActiveTab('info')}
          />
        </div>
      </nav>

      {/* Drawer Content Overlay */}
      {drawerContent && (
        <DrawerContentOverlay content={drawerContent} onClose={closeDrawerContent} />
      )}

      {/* Notifications Overlay */}
      {notificationsOpen && (
        <NotificationsOverlay onClose={() => setNotificationsOpen(false)} />
      )}
    </div>
  );
}

// ===================================
// NAVIGATION COMPONENTS
// ===================================
interface NavItemProps {
  icon: any;
  label: string;
  active: boolean;
  onClick: () => void;
  badge?: number;
}

function NavItem({ icon: Icon, label, active, onClick, badge }: NavItemProps) {
  return (
    <button
      onClick={onClick}
      className={`flex flex-col items-center gap-1 px-3 py-2 relative transition-colors ${
        active ? 'text-primary' : 'text-muted-foreground'
      }`}
    >
      <Icon className="size-6" />
      <span className="text-xs font-medium">{label}</span>
      {badge && badge > 0 && (
        <span className="absolute top-0 right-2 bg-error text-white text-xs w-5 h-5 rounded-full flex items-center justify-center font-semibold">
          {badge}
        </span>
      )}
    </button>
  );
}

interface DrawerItemProps {
  icon: any;
  label: string;
  badge?: string;
  onClick?: () => void;
}

function DrawerItem({ icon: Icon, label, badge, onClick }: DrawerItemProps) {
  return (
    <button 
      onClick={onClick}
      className="w-full flex items-center gap-3 px-4 py-3 hover:bg-muted rounded-lg transition-colors text-left"
    >
      <Icon className="size-5 text-muted-foreground" />
      <span className="flex-1">{label}</span>
      {badge && (
        <span className="text-sm text-muted-foreground">{badge}</span>
      )}
      <ChevronRight className="size-4 text-muted-foreground" />
    </button>
  );
}

// ===================================
// 1. HOME TAB
// ===================================
// Client/Home/Feed/Responsive/Default
interface HomeTabProps {
  onNavigate: (content: string) => void;
}

function HomeTab({ onNavigate }: HomeTabProps) {
  return (
    <div className="max-w-4xl mx-auto space-y-6">
      {/* Welcome Card */}
      <div className="bg-gradient-to-br from-primary via-primary to-primary/80 text-primary-foreground rounded-xl p-6 shadow-lg">
        <h2 className="text-2xl font-bold mb-2">Benvenuta, Maria!</h2>
        <div className="flex items-center gap-2">
          <Star className="size-5 fill-current" />
          <p className="opacity-90 font-medium">420 punti fedeltà disponibili</p>
        </div>
        <button 
          onClick={() => onNavigate('loyalty')}
          className="mt-4 px-4 py-2 bg-white/20 hover:bg-white/30 rounded-lg text-sm font-medium transition-colors"
        >
          Usa i Tuoi Punti
        </button>
      </div>

      {/* Next Appointment */}
      <div>
        <h3 className="font-semibold mb-3 text-lg">Prossimo Appuntamento</h3>
        <div className="bg-card border border-border rounded-xl p-4 hover:border-primary transition-colors">
          <div className="flex items-start gap-4">
            <div className="w-12 h-12 bg-primary/10 rounded-lg flex items-center justify-center flex-shrink-0">
              <Calendar className="size-6 text-primary" />
            </div>
            <div className="flex-1 min-w-0">
              <h4 className="font-semibold mb-1">Taglio e Piega</h4>
              <p className="text-sm text-muted-foreground mb-1">Con Francesca</p>
              <p className="text-sm text-muted-foreground">Venerdì 7 Marzo alle 15:00</p>
            </div>
            <button className="px-4 py-2 bg-primary text-primary-foreground rounded-lg text-sm hover:bg-primary/90 transition-colors font-semibold shadow-sm">
              Modifica
            </button>
          </div>
        </div>
      </div>

      {/* Promozioni */}
      <div>
        <h3 className="font-semibold mb-3 text-lg">Promozioni Attive</h3>
        <div className="bg-warning/10 border border-warning/30 rounded-xl p-4">
          <div className="flex items-start gap-3">
            <div className="w-10 h-10 bg-warning/20 rounded-lg flex items-center justify-center flex-shrink-0">
              <Gift className="size-5 text-warning" />
            </div>
            <div className="flex-1">
              <h4 className="font-semibold mb-1">Sconto 20% su Trattamenti Viso</h4>
              <p className="text-sm text-muted-foreground mb-2">Valido fino al 15 Marzo</p>
              <button className="text-sm text-primary hover:underline font-medium">
                Scopri di più →
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Last Minute */}
      <div>
        <h3 className="font-semibold mb-3 text-lg">Slot Last-Minute</h3>
        <div className="bg-card border border-error/30 rounded-xl p-4">
          <div className="flex items-start gap-3 mb-3">
            <div className="w-10 h-10 bg-error/10 rounded-lg flex items-center justify-center flex-shrink-0">
              <Clock className="size-5 text-error" />
            </div>
            <div className="flex-1">
              <h4 className="font-semibold mb-1">Manicure Express</h4>
              <p className="text-sm text-muted-foreground">Oggi alle 17:00 • Sconto 15%</p>
            </div>
            <span className="px-3 py-1 bg-error/10 text-error text-xs font-semibold rounded-full">
              Last Minute
            </span>
          </div>
          <button className="w-full px-4 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors font-semibold shadow-sm">
            Prenota Ora
          </button>
        </div>
      </div>

      {/* Pacchetti */}
      <div>
        <div className="flex items-center justify-between mb-3">
          <h3 className="font-semibold text-lg">I Tuoi Pacchetti</h3>
          <button 
            onClick={() => onNavigate('packages')}
            className="text-sm text-primary hover:underline font-medium"
          >
            Vedi tutti →
          </button>
        </div>
        <div className="grid gap-3">
          <div className="bg-card border border-border rounded-xl p-4">
            <div className="flex items-start justify-between mb-3">
              <h4 className="font-semibold">Pacchetto Bellezza Completa</h4>
              <StatusBadge status="active" label="Attivo" size="sm" />
            </div>
            <p className="text-sm text-muted-foreground mb-3">3 di 5 servizi utilizzati</p>
            <div className="w-full bg-muted rounded-full h-2">
              <div className="bg-primary h-2 rounded-full transition-all" style={{ width: '60%' }}></div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// Continue with remaining tabs and drawer content in next file due to length...

// Import additional modules
import { AgendaTab, PrenotaTab, CarrelloTab } from './ClientModules';

// ===================================
// 5. INFO TAB
// ===================================
// Client/SalonInfo/Details/Responsive/Default
function InfoTab() {
  return (
    <div className="max-w-4xl mx-auto space-y-6">
      <div>
        <h2 className="text-3xl font-bold mb-2">Info Salone</h2>
        <p className="text-muted-foreground">Contatti e orari</p>
      </div>

      {/* Contatti */}
      <div className="bg-card border border-border rounded-xl p-6">
        <h3 className="font-semibold text-lg mb-4">Contatti</h3>
        <div className="space-y-4">
          <a href="tel:+390212345678" className="flex items-center gap-3 p-3 hover:bg-muted rounded-lg transition-colors">
            <Phone className="size-5 text-primary" />
            <div>
              <p className="text-sm text-muted-foreground mb-1">Telefono</p>
              <p className="font-medium">+39 02 1234 5678</p>
            </div>
          </a>
          <a href="mailto:info@salonebellezza.it" className="flex items-center gap-3 p-3 hover:bg-muted rounded-lg transition-colors">
            <Mail className="size-5 text-primary" />
            <div>
              <p className="text-sm text-muted-foreground mb-1">Email</p>
              <p className="font-medium">info@salonebellezza.it</p>
            </div>
          </a>
          <div className="flex items-start gap-3 p-3">
            <MapPin className="size-5 text-primary mt-0.5" />
            <div>
              <p className="text-sm text-muted-foreground mb-1">Indirizzo</p>
              <p className="font-medium">Via Roma 10, 20121 Milano MI</p>
              <button className="text-sm text-primary hover:underline mt-1">
                Apri in Maps →
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Orari */}
      <div className="bg-card border border-border rounded-xl p-6">
        <h3 className="font-semibold text-lg mb-4">Orari di Apertura</h3>
        <div className="space-y-3">
          {[
            { day: 'Lunedì - Venerdì', hours: '9:00 - 19:00', open: true },
            { day: 'Sabato', hours: '9:00 - 18:00', open: true },
            { day: 'Domenica', hours: 'Chiuso', open: false },
          ].map((schedule) => (
            <div key={schedule.day} className="flex items-center justify-between p-3 bg-muted/50 rounded-lg">
              <span className="font-medium">{schedule.day}</span>
              <span className={schedule.open ? 'text-success font-medium' : 'text-error'}>
                {schedule.hours}
              </span>
            </div>
          ))}
        </div>
      </div>

      {/* Social & Reviews */}
      <div className="bg-card border border-border rounded-xl p-6">
        <h3 className="font-semibold text-lg mb-4">Recensioni</h3>
        <div className="flex items-center gap-3 mb-4">
          <div className="flex items-center gap-1">
            {[1, 2, 3, 4, 5].map((star) => (
              <Star key={star} className="size-5 fill-warning text-warning" />
            ))}
          </div>
          <span className="text-2xl font-bold">4.9</span>
          <span className="text-muted-foreground">(247 recensioni)</span>
        </div>
        <button className="w-full px-4 py-3 bg-muted hover:bg-muted/80 rounded-lg font-medium transition-colors">
          Leggi le Recensioni
        </button>
      </div>
    </div>
  );
}

// ===================================
// DRAWER CONTENT OVERLAY
// ===================================
interface DrawerContentOverlayProps {
  content: string;
  onClose: () => void;
}

function DrawerContentOverlay({ content, onClose }: DrawerContentOverlayProps) {
  return (
    <div className="fixed inset-0 bg-background z-50 overflow-y-auto">
      <div className="sticky top-0 bg-card border-b border-border z-10">
        <div className="flex items-center justify-between px-4 lg:px-6 h-16">
          <h2 className="text-xl font-semibold">
            {content === 'loyalty' && 'Punti Fedeltà'}
            {content === 'packages' && 'I Tuoi Pacchetti'}
            {content === 'quotes' && 'Preventivi'}
            {content === 'invoices' && 'Fatturazione'}
            {content === 'surveys' && 'Questionari'}
            {content === 'photos' && 'Le Mie Foto'}
            {content === 'settings' && 'Impostazioni'}
          </h2>
          <button
            onClick={onClose}
            className="p-2 hover:bg-muted rounded-lg transition-colors"
          >
            <X className="size-5" />
          </button>
        </div>
      </div>

      <div className="p-4 lg:p-8 max-w-4xl mx-auto lg:ml-64">
        {content === 'loyalty' && <LoyaltyContent />}
        {content === 'packages' && <PackagesContent />}
        {content === 'quotes' && <QuotesContent />}
        {content === 'invoices' && <InvoicesContent />}
        {content === 'surveys' && <SurveysContent />}
        {content === 'photos' && <PhotosContent />}
        {content === 'settings' && <SettingsContent />}
      </div>
    </div>
  );
}

// Drawer Content Sections
function LoyaltyContent() {
  return (
    <div className="space-y-6">
      {/* Points Summary */}
      <div className="bg-gradient-to-br from-primary via-primary to-primary/80 text-primary-foreground rounded-xl p-6 shadow-lg">
        <div className="flex items-center gap-3 mb-4">
          <Award className="size-8" />
          <div>
            <p className="text-sm opacity-90">Punti Disponibili</p>
            <p className="text-4xl font-bold">420</p>
          </div>
        </div>
        <p className="opacity-90">
          Ogni 100 punti = €5 di sconto
        </p>
      </div>

      {/* Rewards */}
      <div>
        <h3 className="font-semibold text-lg mb-4">Premi Disponibili</h3>
        <div className="space-y-3">
          {[
            { points: 100, value: 5, name: 'Sconto €5' },
            { points: 200, value: 10, name: 'Sconto €10' },
            { points: 500, value: 30, name: 'Sconto €30' },
          ].map((reward) => (
            <div key={reward.points} className="bg-card border border-border rounded-xl p-4">
              <div className="flex items-center justify-between">
                <div>
                  <h4 className="font-semibold mb-1">{reward.name}</h4>
                  <p className="text-sm text-muted-foreground">{reward.points} punti necessari</p>
                </div>
                <button 
                  disabled={420 < reward.points}
                  className={`px-4 py-2 rounded-lg text-sm font-semibold transition-colors ${
                    420 >= reward.points
                      ? 'bg-primary text-primary-foreground hover:bg-primary/90 shadow-sm'
                      : 'bg-muted text-muted-foreground cursor-not-allowed'
                  }`}
                >
                  {420 >= reward.points ? 'Riscatta' : 'Bloccato'}
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* History */}
      <div>
        <h3 className="font-semibold text-lg mb-4">Storico Punti</h3>
        <div className="space-y-2">
          {[
            { date: '28 Feb 2026', points: 45, type: 'earned', desc: 'Taglio e Piega' },
            { date: '15 Feb 2026', points: -100, type: 'spent', desc: 'Sconto €5 utilizzato' },
            { date: '2 Feb 2026', points: 30, type: 'earned', desc: 'Manicure' },
          ].map((item, i) => (
            <div key={i} className="flex items-center justify-between p-3 bg-muted/50 rounded-lg">
              <div className="flex-1">
                <p className="font-medium text-sm">{item.desc}</p>
                <p className="text-xs text-muted-foreground">{item.date}</p>
              </div>
              <span className={`font-semibold ${item.type === 'earned' ? 'text-success' : 'text-error'}`}>
                {item.points > 0 ? '+' : ''}{item.points}
              </span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function PackagesContent() {
  return (
    <div className="space-y-6">
      <div className="space-y-3">
        {[
          {
            id: '1',
            name: 'Pacchetto Bellezza Completa',
            total: 5,
            used: 3,
            price: 199,
            expires: '30 Mag 2026',
            status: 'active'
          },
          {
            id: '2',
            name: 'Pacchetto Relax',
            total: 3,
            used: 1,
            price: 129,
            expires: '15 Apr 2026',
            status: 'active'
          },
          {
            id: '3',
            name: 'Pacchetto Capelli',
            total: 4,
            used: 4,
            price: 159,
            expires: '1 Mar 2026',
            status: 'expired'
          },
        ].map((pkg) => (
          <div key={pkg.id} className="bg-card border border-border rounded-xl p-6">
            <div className="flex items-start justify-between mb-4">
              <div>
                <h4 className="font-semibold text-lg mb-1">{pkg.name}</h4>
                <p className="text-sm text-muted-foreground">Scade il {pkg.expires}</p>
              </div>
              <StatusBadge
                status={pkg.status === 'active' ? 'success' : 'cancelled'}
                label={pkg.status === 'active' ? 'Attivo' : 'Scaduto'}
                size="sm"
              />
            </div>
            <div className="mb-4">
              <div className="flex items-center justify-between text-sm mb-2">
                <span className="text-muted-foreground">Servizi utilizzati</span>
                <span className="font-medium">{pkg.used} di {pkg.total}</span>
              </div>
              <div className="w-full bg-muted rounded-full h-2">
                <div
                  className="bg-primary h-2 rounded-full transition-all"
                  style={{ width: `${(pkg.used / pkg.total) * 100}%` }}
                />
              </div>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-lg font-bold text-primary">€{pkg.price}</span>
              {pkg.status === 'active' && pkg.used < pkg.total && (
                <button className="px-4 py-2 bg-primary text-primary-foreground rounded-lg text-sm font-semibold hover:bg-primary/90 shadow-sm">
                  Usa Servizio
                </button>
              )}
            </div>
          </div>
        ))}
      </div>

      <button className="w-full px-6 py-4 bg-muted hover:bg-muted/80 rounded-lg font-semibold transition-colors">
        Acquista Nuovo Pacchetto
      </button>
    </div>
  );
}

function QuotesContent() {
  const [quoteStep, setQuoteStep] = useState<'list' | 'create' | 'payment'>('list');
  const [selectedServices, setSelectedServices] = useState<string[]>([]);

  const quotes = [
    {
      id: '1',
      name: 'Preventivo Matrimonio',
      services: ['Taglio', 'Piega', 'Trucco'],
      total: 150,
      status: 'pending',
      date: '2026-03-01'
    }
  ];

  if (quoteStep === 'create') {
    return (
      <div className="space-y-6">
        <button onClick={() => setQuoteStep('list')} className="flex items-center gap-2 text-muted-foreground hover:text-foreground">
          <ArrowLeft className="size-4" />
          Indietro
        </button>

        <div>
          <h3 className="font-semibold text-lg mb-4">Crea Preventivo</h3>
          <p className="text-muted-foreground mb-6">Seleziona i servizi per il tuo evento</p>
        </div>

        <div className="space-y-3">
          {['Taglio', 'Piega', 'Colore', 'Trucco', 'Acconciatura'].map((service) => (
            <label key={service} className="flex items-center gap-3 p-4 bg-card border border-border rounded-xl cursor-pointer hover:border-primary transition-colors">
              <input
                type="checkbox"
                checked={selectedServices.includes(service)}
                onChange={(e) => {
                  if (e.target.checked) {
                    setSelectedServices([...selectedServices, service]);
                  } else {
                    setSelectedServices(selectedServices.filter(s => s !== service));
                  }
                }}
                className="w-5 h-5"
              />
              <span className="flex-1 font-medium">{service}</span>
              <span className="text-primary font-semibold">€45</span>
            </label>
          ))}
        </div>

        {selectedServices.length > 0 && (
          <button
            onClick={() => setQuoteStep('payment')}
            className="w-full px-6 py-4 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 font-semibold shadow-lg"
          >
            Richiedi Preventivo ({selectedServices.length} servizi)
          </button>
        )}
      </div>
    );
  }

  if (quoteStep === 'payment') {
    return (
      <div className="space-y-6">
        <button onClick={() => setQuoteStep('create')} className="flex items-center gap-2 text-muted-foreground hover:text-foreground">
          <ArrowLeft className="size-4" />
          Indietro
        </button>

        <div className="bg-card border border-border rounded-xl p-6">
          <h3 className="font-semibold text-lg mb-4">Riepilogo Preventivo</h3>
          <div className="space-y-3 mb-4">
            {selectedServices.map((service, i) => (
              <div key={i} className="flex items-center justify-between">
                <span>{service}</span>
                <span className="font-medium">€45</span>
              </div>
            ))}
          </div>
          <div className="border-t pt-3 flex items-center justify-between">
            <span className="font-semibold">Totale</span>
            <span className="text-2xl font-bold text-primary">€{selectedServices.length * 45}</span>
          </div>
        </div>

        {/* Stripe Payment Simulation */}
        <div className="bg-muted rounded-xl p-6">
          <h4 className="font-semibold mb-4">Pagamento con Stripe</h4>
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium mb-2">Numero Carta</label>
              <input
                type="text"
                placeholder="4242 4242 4242 4242"
                className="w-full px-4 py-3 bg-input-background border border-border rounded-lg"
              />
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium mb-2">Scadenza</label>
                <input
                  type="text"
                  placeholder="MM/YY"
                  className="w-full px-4 py-3 bg-input-background border border-border rounded-lg"
                />
              </div>
              <div>
                <label className="block text-sm font-medium mb-2">CVV</label>
                <input
                  type="text"
                  placeholder="123"
                  className="w-full px-4 py-3 bg-input-background border border-border rounded-lg"
                />
              </div>
            </div>
          </div>
        </div>

        <button
          onClick={() => {
            toast.success('Pagamento completato!');
            setQuoteStep('list');
            setSelectedServices([]);
          }}
          className="w-full px-6 py-4 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 font-semibold shadow-lg"
        >
          Paga €{selectedServices.length * 45} con Stripe
        </button>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="space-y-3">
        {quotes.map((quote) => (
          <div key={quote.id} className="bg-card border border-border rounded-xl p-6">
            <div className="flex items-start justify-between mb-4">
              <div>
                <h4 className="font-semibold text-lg mb-2">{quote.name}</h4>
                <p className="text-sm text-muted-foreground mb-2">
                  {quote.services.join(', ')}
                </p>
                <p className="text-xs text-muted-foreground">
                  Richiesto il {new Date(quote.date).toLocaleDateString('it-IT')}
                </p>
              </div>
              <StatusBadge status="pending" label="In attesa" size="sm" />
            </div>
            <div className="flex items-center justify-between">
              <span className="text-2xl font-bold text-primary">€{quote.total}</span>
              <button className="px-4 py-2 bg-muted hover:bg-muted/80 rounded-lg text-sm font-medium">
                Dettagli
              </button>
            </div>
          </div>
        ))}
      </div>

      <button
        onClick={() => setQuoteStep('create')}
        className="w-full px-6 py-4 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 font-semibold shadow-lg flex items-center justify-center gap-2"
      >
        <Plus className="size-5" />
        Nuovo Preventivo
      </button>
    </div>
  );
}

function InvoicesContent() {
  return (
    <div className="space-y-6">
      <div className="space-y-3">
        {[
          { id: 'INV-2026-001', date: '2026-02-28', amount: 45, status: 'paid' },
          { id: 'INV-2026-002', date: '2026-02-15', amount: 30, status: 'paid' },
          { id: 'INV-2026-003', date: '2026-02-01', amount: 55, status: 'pending' },
        ].map((invoice) => (
          <div key={invoice.id} className="bg-card border border-border rounded-xl p-4">
            <div className="flex items-center justify-between mb-3">
              <div>
                <h4 className="font-semibold mb-1">{invoice.id}</h4>
                <p className="text-sm text-muted-foreground">
                  {new Date(invoice.date).toLocaleDateString('it-IT')}
                </p>
              </div>
              <StatusBadge
                status={invoice.status === 'paid' ? 'success' : 'pending'}
                label={invoice.status === 'paid' ? 'Pagata' : 'Da pagare'}
                size="sm"
              />
            </div>
            <div className="flex items-center justify-between">
              <span className="text-xl font-bold text-primary">€{invoice.amount}</span>
              <div className="flex gap-2">
                <button className="p-2 hover:bg-muted rounded-lg">
                  <Download className="size-4" />
                </button>
                <button className="p-2 hover:bg-muted rounded-lg">
                  <Copy className="size-4" />
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function SurveysContent() {
  return (
    <div className="space-y-6">
      <EmptyState
        icon={ClipboardList}
        title="Nessun questionario"
        description="Al momento non ci sono questionari da compilare"
      />
    </div>
  );
}

function PhotosContent() {
  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
        {[1, 2, 3, 4, 5, 6].map((i) => (
          <div key={i} className="aspect-square bg-muted rounded-xl flex items-center justify-center">
            <Camera className="size-8 text-muted-foreground" />
          </div>
        ))}
      </div>
      <button className="w-full px-6 py-4 bg-muted hover:bg-muted/80 rounded-lg font-semibold flex items-center justify-center gap-2">
        <Plus className="size-5" />
        Carica Foto
      </button>
    </div>
  );
}

function SettingsContent() {
  return (
    <div className="space-y-6">
      <div className="bg-card border border-border rounded-xl p-6">
        <h3 className="font-semibold mb-4">Profilo</h3>
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-2">Nome</label>
            <input
              type="text"
              defaultValue="Maria Rossi"
              className="w-full px-4 py-3 bg-input-background border border-border rounded-lg"
            />
          </div>
          <div>
            <label className="block text-sm font-medium mb-2">Email</label>
            <input
              type="email"
              defaultValue="maria.rossi@email.it"
              className="w-full px-4 py-3 bg-input-background border border-border rounded-lg"
            />
          </div>
          <div>
            <label className="block text-sm font-medium mb-2">Telefono</label>
            <input
              type="tel"
              defaultValue="+39 320 1234567"
              className="w-full px-4 py-3 bg-input-background border border-border rounded-lg"
            />
          </div>
        </div>
      </div>

      <div className="bg-card border border-border rounded-xl p-6">
        <h3 className="font-semibold mb-4">Notifiche</h3>
        <div className="space-y-3">
          {[
            { id: 'email', label: 'Email', enabled: true },
            { id: 'push', label: 'Notifiche Push', enabled: true },
            { id: 'sms', label: 'SMS', enabled: false },
          ].map((notif) => (
            <label key={notif.id} className="flex items-center justify-between p-3 hover:bg-muted rounded-lg cursor-pointer">
              <span className="font-medium">{notif.label}</span>
              <input
                type="checkbox"
                defaultChecked={notif.enabled}
                className="w-5 h-5"
              />
            </label>
          ))}
        </div>
      </div>

      <button className="w-full px-6 py-4 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 font-semibold shadow-lg">
        Salva Modifiche
      </button>
    </div>
  );
}

// ===================================
// NOTIFICATIONS OVERLAY
// ===================================
interface NotificationsOverlayProps {
  onClose: () => void;
}

function NotificationsOverlay({ onClose }: NotificationsOverlayProps) {
  const notifications = [
    {
      id: '1',
      type: 'appointment',
      title: 'Promemoria Appuntamento',
      message: 'Il tuo appuntamento è domani alle 15:00',
      time: '2 ore fa',
      read: false
    },
    {
      id: '2',
      type: 'promo',
      title: 'Nuova Promozione',
      message: 'Sconto 20% sui trattamenti viso fino al 15 Marzo',
      time: '1 giorno fa',
      read: false
    },
    {
      id: '3',
      type: 'loyalty',
      title: 'Punti Fedeltà',
      message: 'Hai guadagnato 45 punti dal tuo ultimo appuntamento',
      time: '3 giorni fa',
      read: true
    },
  ];

  return (
    <div className="fixed inset-0 bg-background z-50 overflow-y-auto">
      <div className="sticky top-0 bg-card border-b border-border z-10">
        <div className="flex items-center justify-between px-4 h-16">
          <h2 className="text-xl font-semibold">Notifiche</h2>
          <button
            onClick={onClose}
            className="p-2 hover:bg-muted rounded-lg transition-colors"
          >
            <X className="size-5" />
          </button>
        </div>
      </div>

      <div className="p-4 max-w-4xl mx-auto">
        {notifications.length === 0 ? (
          <EmptyState
            icon={Bell}
            title="Nessuna notifica"
            description="Non hai notifiche al momento"
          />
        ) : (
          <div className="space-y-2">
            {notifications.map((notif) => (
              <div
                key={notif.id}
                className={`p-4 rounded-xl cursor-pointer transition-colors ${
                  notif.read
                    ? 'bg-card border border-border hover:border-primary'
                    : 'bg-primary/10 border border-primary/20 hover:border-primary'
                }`}
              >
                <div className="flex items-start gap-3">
                  <div className={`w-2 h-2 rounded-full mt-2 flex-shrink-0 ${notif.read ? 'bg-muted' : 'bg-primary'}`} />
                  <div className="flex-1 min-w-0">
                    <h4 className="font-semibold mb-1">{notif.title}</h4>
                    <p className="text-sm text-muted-foreground mb-2">{notif.message}</p>
                    <p className="text-xs text-muted-foreground">{notif.time}</p>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}