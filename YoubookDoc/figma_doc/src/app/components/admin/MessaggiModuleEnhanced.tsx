import { useState } from 'react';
import {
  RefreshCw, Mail, Tag, Zap, Search, Plus, Edit, Trash2,
  Clock, CheckCircle, Send, Calendar, Phone, MessageSquare,
  Users, ChevronDown, Eye
} from 'lucide-react';
import { toast } from 'sonner';

/**
 * Admin/Messaggi/Module/Enhanced/Default
 * Modulo Messaggi & Marketing completo con 4 tab:
 * - Automazione (promemoria automatici)
 * - Manuali (invio messaggi manuali)
 * - Promozioni (campagne promozionali)
 * - Last-minute (slot last-minute)
 */

type TabType = 'automazione' | 'manuali' | 'promozioni' | 'lastminute';

export default function MessaggiModuleEnhanced() {
  const [activeTab, setActiveTab] = useState<TabType>('automazione');
  const [searchQuery, setSearchQuery] = useState('');

  const tabs = [
    { id: 'automazione' as TabType, label: 'Automazione', icon: RefreshCw },
    { id: 'manuali' as TabType, label: 'Manuali', icon: Mail },
    { id: 'promozioni' as TabType, label: 'Promozioni', icon: Tag },
    { id: 'lastminute' as TabType, label: 'Last-minute', icon: Zap },
  ];

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-3xl font-bold mb-2">Messaggi & Marketing</h2>
          <p className="text-muted-foreground">Gestione comunicazioni e campagne</p>
        </div>
      </div>

      {/* Tab Navigation */}
      <div className="bg-card border border-border rounded-xl p-1">
        <div className="flex items-center gap-1 overflow-x-auto">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`flex items-center gap-2 px-4 py-2.5 rounded-lg transition-all whitespace-nowrap ${
                activeTab === tab.id
                  ? 'bg-primary text-primary-foreground shadow-sm'
                  : 'hover:bg-muted'
              }`}
            >
              <tab.icon className="size-4 flex-shrink-0" />
              <span className="text-sm font-medium">{tab.label}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Tab Content */}
      <div className="bg-card border border-border rounded-xl p-6">
        {activeTab === 'automazione' && <AutomazioneTab />}
        {activeTab === 'manuali' && <ManualiTab searchQuery={searchQuery} setSearchQuery={setSearchQuery} />}
        {activeTab === 'promozioni' && <PromozioniTab />}
        {activeTab === 'lastminute' && <LastMinuteTab />}
      </div>
    </div>
  );
}

// =====================================
// AUTOMAZIONE TAB
// =====================================

function AutomazioneTab() {
  const [automations, setAutomations] = useState([
    {
      id: 1,
      name: 'WhatsApp',
      channels: ['WhatsApp', 'Appointment Confirmed [it]'],
      giorni: '0 giorni',
      ore: '0 ore',
      minuti: '30 minuti',
      enabled: true,
      tipo: 'WhatsApp',
      template: 'Appointment Confirmed [it]'
    },
    {
      id: 2,
      name: 'Muoviti al salone',
      channels: ['WhatsApp', 'Appointment Confirmed [it]'],
      giorni: '0 giorni',
      ore: '0 ore',
      minuti: '15 minuti',
      enabled: true,
      tipo: 'WhatsApp',
      template: 'Appointment Confirmed [it]'
    }
  ]);

  const [showBirthday, setShowBirthday] = useState(true);

  const toggleAutomation = (id: number) => {
    setAutomations(automations.map(a => 
      a.id === id ? { ...a, enabled: !a.enabled } : a
    ));
    toast.success('Automazione aggiornata');
  };

  return (
    <div className="space-y-6">
      {/* Promemoria appuntamenti */}
      <div>
        <h3 className="text-lg font-semibold mb-2">Promemoria appuntamenti</h3>
        <p className="text-sm text-muted-foreground mb-4">
          Seleziona fino a 5 promemoria automatici. Gli offset sono espressi rispetto all'inizio appuntamento.
        </p>

        <div className="space-y-3">
          {automations.map((automation) => (
            <div key={automation.id} className="border border-border rounded-lg p-4">
              <div className="flex items-start justify-between mb-3">
                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-2">
                    {automation.channels.map((channel, idx) => (
                      <span key={idx} className="px-2 py-1 bg-warning/10 text-warning rounded text-xs font-medium">
                        {channel}
                      </span>
                    ))}
                  </div>
                  <p className="text-sm text-muted-foreground">
                    {automation.giorni} • {automation.ore} • {automation.minuti}
                  </p>
                </div>
                <button 
                  onClick={() => toggleAutomation(automation.id)}
                  className={`relative w-12 h-6 rounded-full transition-colors ${
                    automation.enabled ? 'bg-success' : 'bg-muted-foreground/30'
                  }`}
                >
                  <div className={`absolute top-0.5 w-5 h-5 bg-white rounded-full transition-transform ${
                    automation.enabled ? 'translate-x-6' : 'translate-x-0.5'
                  }`} />
                </button>
              </div>

              <div className="grid sm:grid-cols-3 gap-3">
                <div>
                  <label className="block text-xs text-warning mb-1.5">Giorni</label>
                  <select className="w-full px-3 py-2 bg-input-background border border-border rounded-lg text-sm">
                    <option>{automation.giorni}</option>
                  </select>
                </div>
                <div>
                  <label className="block text-xs text-warning mb-1.5">Ore</label>
                  <select className="w-full px-3 py-2 bg-input-background border border-border rounded-lg text-sm">
                    <option>{automation.ore}</option>
                  </select>
                </div>
                <div>
                  <label className="block text-xs text-warning mb-1.5">Minuti</label>
                  <select className="w-full px-3 py-2 bg-input-background border border-border rounded-lg text-sm">
                    <option>{automation.minuti}</option>
                  </select>
                </div>
              </div>

              <div className="mt-3 space-y-2">
                <div>
                  <label className="block text-xs text-warning mb-1.5">Tipo messaggio</label>
                  <select className="w-full px-3 py-2 bg-input-background border border-border rounded-lg text-sm">
                    <option>{automation.tipo}</option>
                  </select>
                </div>
                <div>
                  <label className="block text-xs text-warning mb-1.5">Template WhatsApp (Promemoria)</label>
                  <select className="w-full px-3 py-2 bg-input-background border border-border rounded-lg text-sm">
                    <option>{automation.template}</option>
                  </select>
                </div>
              </div>

              <div className="flex items-center justify-between mt-3 pt-3 border-t border-border">
                <button 
                  onClick={() => toast.info('Aggiungi promemoria')}
                  className="flex items-center gap-2 text-sm text-warning hover:underline"
                >
                  <Plus className="size-4" />
                  Aggiungi promemoria
                </button>
                <div className="flex gap-2">
                  <button className="p-2 hover:bg-muted rounded-lg transition-colors">
                    <RefreshCw className="size-4" />
                  </button>
                  <button className="p-2 hover:bg-muted rounded-lg transition-colors">
                    <Trash2 className="size-4 text-error" />
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Auguri di compleanno */}
      <div className="border border-border rounded-lg p-4">
        <div className="flex items-center justify-between mb-3">
          <div>
            <h4 className="font-semibold mb-1">Auguri di compleanno</h4>
            <p className="text-sm text-muted-foreground">
              Invia un messaggio push automatico il giorno del compleanno.
            </p>
          </div>
          <button 
            onClick={() => {
              setShowBirthday(!showBirthday);
              toast.success('Auguri ' + (!showBirthday ? 'attivati' : 'disattivati'));
            }}
            className={`relative w-12 h-6 rounded-full transition-colors ${
              showBirthday ? 'bg-success' : 'bg-muted-foreground/30'
            }`}
          >
            <div className={`absolute top-0.5 w-5 h-5 bg-white rounded-full transition-transform ${
              showBirthday ? 'translate-x-6' : 'translate-x-0.5'
            }`} />
          </button>
        </div>

        {showBirthday && (
          <div>
            <label className="block text-xs text-warning mb-1.5">Messaggio di auguri</label>
            <textarea
              className="w-full px-3 py-2 bg-input-background border border-border rounded-lg text-sm min-h-[80px]"
              placeholder="Auguri di buon compleanno..."
              defaultValue="Auguri di buon compleanno"
            />
          </div>
        )}
      </div>
    </div>
  );
}

// =====================================
// MANUALI TAB
// =====================================

interface ManualiTabProps {
  searchQuery: string;
  setSearchQuery: (query: string) => void;
}

function ManualiTab({ searchQuery, setSearchQuery }: ManualiTabProps) {
  const [selectedClients, setSelectedClients] = useState(0);
  const [templateName, setTemplateName] = useState('Scrivi manualmente');
  const [messageTitle, setMessageTitle] = useState('Messaggio da YouBook');
  const [messageBody, setMessageBody] = useState('Ciao {{nome}}, lo staff di Civi Salon ti contatta per una comunicazione.');

  return (
    <div className="space-y-6">
      <div>
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-semibold">Notifiche manuali</h3>
          <span className="text-sm text-muted-foreground">{selectedClients}/15 selezionati</span>
        </div>

        {/* Search Bar */}
        <div className="relative mb-4">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 size-5 text-muted-foreground" />
          <input
            type="text"
            placeholder="Cerca clienti"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-10 pr-4 py-3 bg-input-background border border-border rounded-lg focus:outline-none focus:ring-2 focus:ring-ring"
          />
          <button className="absolute right-3 top-1/2 -translate-y-1/2 p-2 hover:bg-muted rounded-lg">
            <Users className="size-5 text-muted-foreground" />
          </button>
        </div>

        {/* Empty State */}
        {!searchQuery && (
          <div className="text-center py-12 border-2 border-dashed border-border rounded-lg">
            <Users className="size-12 mx-auto text-muted-foreground mb-3" />
            <p className="text-muted-foreground">
              Digita nel campo di ricerca per selezionare i clienti.
            </p>
          </div>
        )}
      </div>

      {/* Message Form */}
      <div className="space-y-4">
        <div>
          <label className="block text-sm text-warning mb-2">Template messaggio</label>
          <div className="relative">
            <select 
              value={templateName}
              onChange={(e) => setTemplateName(e.target.value)}
              className="w-full px-3 py-2.5 bg-input-background border border-border rounded-lg text-sm appearance-none pr-8"
            >
              <option>Scrivi manualmente</option>
              <option>Template promozionale</option>
              <option>Template reminder</option>
            </select>
            <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 size-4 text-muted-foreground pointer-events-none" />
          </div>
        </div>

        <div>
          <label className="block text-sm text-warning mb-2">Titolo della notifica</label>
          <input
            type="text"
            value={messageTitle}
            onChange={(e) => setMessageTitle(e.target.value)}
            className="w-full px-3 py-2.5 bg-input-background border border-border rounded-lg text-sm"
          />
        </div>

        <div>
          <label className="block text-sm text-warning mb-2">Corpo del messaggio</label>
          <textarea
            value={messageBody}
            onChange={(e) => setMessageBody(e.target.value)}
            className="w-full px-3 py-2.5 bg-input-background border border-border rounded-lg text-sm min-h-[120px]"
          />
          <p className="text-xs text-muted-foreground mt-2">
            Segnasposti disponibili: <code className="bg-muted px-1 py-0.5 rounded">{'{{nome}}'}</code> <code className="bg-muted px-1 py-0.5 rounded">{'{{cognome}}'}</code> <code className="bg-muted px-1 py-0.5 rounded">{'{{salone}}'}</code>
          </p>
        </div>

        {/* Actions */}
        <div className="flex flex-wrap gap-3">
          <button 
            onClick={() => toast.success('Notifica inviata!')}
            className="flex items-center gap-2 px-6 py-2.5 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors"
          >
            <Send className="size-4" />
            Invia notifica
          </button>
          <button 
            onClick={() => toast.info('Messaggio ripristinato')}
            className="flex items-center gap-2 px-4 py-2.5 border border-border rounded-lg hover:bg-muted transition-colors"
          >
            <RefreshCw className="size-4" />
            Ripristina messaggio
          </button>
          <button 
            onClick={() => toast.info('Anteprima in-app')}
            className="flex items-center gap-2 px-4 py-2.5 border border-border rounded-lg hover:bg-muted transition-colors"
          >
            <Eye className="size-4" />
            Anteprima in-app
          </button>
        </div>
      </div>
    </div>
  );
}

// =====================================
// PROMOZIONI TAB
// =====================================

function PromozioniTab() {
  const [promos, setPromos] = useState([
    {
      id: 1,
      name: 'test',
      dateRange: 'Dal 02/11 al 25/12',
      status: 'Pubblicato',
      visibleToClients: true
    },
    {
      id: 2,
      name: 'Promo Nicola',
      description: 'paghi 2 sconti 1',
      dateRange: 'Attiva senza scadenza',
      status: 'Programmato',
      visibleToClients: true
    }
  ]);

  const togglePromo = (id: number) => {
    setPromos(promos.map(p => 
      p.id === id ? { ...p, visibleToClients: !p.visibleToClients } : p
    ));
    toast.success('Visibilità aggiornata');
  };

  const deletePromo = (id: number) => {
    setPromos(promos.filter(p => p.id !== id));
    toast.success('Promozione eliminata');
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h3 className="text-lg font-semibold mb-1">Campagne promozionali</h3>
          <p className="text-sm text-muted-foreground">
            Promozioni visibili ai clienti
          </p>
          <p className="text-xs text-muted-foreground mt-1">
            Mostra le campagne attive nella home dell'app cliente.
          </p>
        </div>
        <button 
          onClick={() => toast.success('Nuova promozione')}
          className="flex items-center gap-2 px-4 py-2 bg-warning text-white rounded-lg hover:bg-warning/90 transition-colors"
        >
          <Plus className="size-4" />
          Nuova promo
        </button>
      </div>

      <div className="space-y-3">
        {promos.map((promo) => (
          <div key={promo.id} className="border border-border rounded-lg p-4">
            <div className="flex items-start justify-between mb-3">
              <div className="flex-1">
                <h4 className="font-semibold mb-1">{promo.name}</h4>
                {promo.description && (
                  <p className="text-sm text-muted-foreground mb-2">{promo.description}</p>
                )}
                <div className="flex flex-wrap items-center gap-2">
                  <span className="flex items-center gap-1.5 px-2 py-1 bg-muted rounded text-xs">
                    <Calendar className="size-3" />
                    {promo.dateRange}
                  </span>
                  <span className={`px-2 py-1 rounded text-xs ${
                    promo.status === 'Pubblicato' 
                      ? 'bg-info/10 text-info' 
                      : 'bg-warning/10 text-warning'
                  }`}>
                    {promo.status}
                  </span>
                </div>
              </div>
              <button 
                onClick={() => togglePromo(promo.id)}
                className={`relative w-12 h-6 rounded-full transition-colors ${
                  promo.visibleToClients ? 'bg-success' : 'bg-muted-foreground/30'
                }`}
              >
                <div className={`absolute top-0.5 w-5 h-5 bg-white rounded-full transition-transform ${
                  promo.visibleToClients ? 'translate-x-6' : 'translate-x-0.5'
                }`} />
              </button>
            </div>

            <div className="flex gap-2 pt-3 border-t border-border">
              <button 
                onClick={() => toast.info('Modifica ' + promo.name)}
                className="flex items-center gap-1.5 px-3 py-1.5 text-sm text-warning hover:bg-warning/10 rounded-lg transition-colors"
              >
                <Edit className="size-3" />
                Modifica
              </button>
              <button 
                onClick={() => deletePromo(promo.id)}
                className="flex items-center gap-1.5 px-3 py-1.5 text-sm text-error hover:bg-error/10 rounded-lg transition-colors"
              >
                <Trash2 className="size-3" />
                Elimina
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// =====================================
// LAST-MINUTE TAB
// =====================================

function LastMinuteTab() {
  const [showLastMinute, setShowLastMinute] = useState(true);
  const [slots, setSlots] = useState([
    {
      id: 1,
      name: 'test',
      date: '03/11 09:00',
      duration: '60 min',
      staff: 'Antonio Berna',
      priceRange: '80,00 € - base 100,00 €',
      payment: 'Pagamento online immediato'
    },
    {
      id: 2,
      name: 'test',
      date: '14/11 11:00',
      duration: '60 min',
      staff: 'Operatore non assegnato',
      priceRange: '140,00 € - base 200,00 €',
      payment: 'Pagamento online immediato'
    },
    {
      id: 3,
      name: 'dermo diamond',
      date: '21/11 09:15',
      duration: '60 min',
      staff: 'Operatore non assegnato',
      priceRange: '120,00 € - base 150,00 €',
      payment: 'Pagamento online immediato'
    }
  ]);

  const deleteSlot = (id: number) => {
    setSlots(slots.filter(s => s.id !== id));
    toast.success('Slot eliminato');
  };

  return (
    <div className="space-y-6">
      <div>
        <h3 className="text-lg font-semibold mb-1">Impostazioni last-minute</h3>
        <p className="text-xs text-warning mb-4">Notifiche last-minute (predefinite)</p>

        <div className="mb-6">
          <label className="block text-sm font-medium mb-2">Seleziona destinatari</label>
          <div className="relative">
            <select className="w-full px-3 py-2.5 bg-input-background border border-border rounded-lg text-sm appearance-none pr-8">
              <option>Tutti i clienti</option>
              <option>Clienti VIP</option>
              <option>Nuovi clienti</option>
            </select>
            <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 size-4 text-muted-foreground pointer-events-none" />
          </div>
          <p className="text-xs text-muted-foreground mt-2">
            Determina cosa proporre quando crei o modifichi uno slot express.
          </p>
        </div>
      </div>

      {/* Slot List */}
      <div>
        <div className="flex items-center justify-between mb-4">
          <div>
            <h3 className="text-lg font-semibold mb-1">Slot last-minute</h3>
            <p className="text-sm text-muted-foreground">
              Slot last-minute visibili ai clienti
            </p>
            <p className="text-xs text-muted-foreground mt-1">
              Permetti la prenotazione rapida delle offerte last-minute.
            </p>
          </div>
          <button 
            onClick={() => {
              setShowLastMinute(!showLastMinute);
              toast.success('Last-minute ' + (!showLastMinute ? 'attivati' : 'disattivati'));
            }}
            className={`relative w-12 h-6 rounded-full transition-colors ${
              showLastMinute ? 'bg-success' : 'bg-muted-foreground/30'
            }`}
          >
            <div className={`absolute top-0.5 w-5 h-5 bg-white rounded-full transition-transform ${
              showLastMinute ? 'translate-x-6' : 'translate-x-0.5'
            }`} />
          </button>
        </div>

        <div className="space-y-3">
          {slots.map((slot) => (
            <div key={slot.id} className="border border-border rounded-lg p-4">
              <div className="flex items-start justify-between mb-3">
                <div className="flex-1">
                  <h4 className="font-semibold mb-2">{slot.name}</h4>
                  <div className="grid sm:grid-cols-2 gap-2 text-sm">
                    <p className="text-muted-foreground">
                      <span className="font-medium text-foreground">{slot.date}</span> · {slot.duration}
                    </p>
                    <p className="text-muted-foreground">{slot.staff}</p>
                    <p className="text-muted-foreground">{slot.priceRange}</p>
                    <p className="text-muted-foreground">{slot.payment}</p>
                  </div>
                </div>
                <button 
                  onClick={() => deleteSlot(slot.id)}
                  className="p-2 hover:bg-error/10 rounded-lg transition-colors"
                >
                  <Trash2 className="size-4 text-error" />
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
