import { useState } from 'react';
import { DndProvider, useDrag, useDrop } from 'react-dnd';
import { HTML5Backend } from 'react-dnd-html5-backend';
import {
  Calendar, ChevronLeft, ChevronRight, Clock, User, MapPin,
  Phone, Hash, CheckCircle, AlertCircle, XCircle, MoreVertical,
  Star, MessageSquare, UserX, AlertTriangle, Package, Coins
} from 'lucide-react';
import { toast } from 'sonner';
import * as HoverCard from '@radix-ui/react-hover-card';

/**
 * Admin/Agenda/Calendar/Modern/WeeklyScroll
 * Calendario settimanale moderno con scroll orizzontale, turni visibili e card eleganti
 */

interface Appuntamento {
  id: string;
  operatore: string;
  cliente: string;
  telefono: string;
  numeroCliente: string;
  servizio: string;
  oraInizio: string;
  oraFine: string;
  durata: number; // minuti
  stato: 'programmato' | 'completato' | 'noshow' | 'annullato';
  priorita?: 'alta' | 'normale' | 'bassa';
  note?: string;
  luogo?: string;
  categorie: string[]; // Array di categorie per supportare doppie categorie
  prorogato?: boolean; // Flag per appuntamento prorogato
  haPacchetti?: boolean; // Flag per cliente con pacchetti attivi
}

interface AgendaCalendarModernProps {
  onAppuntamentoClick: (appuntamento: Appuntamento) => void;
}

const GIORNI_SETTIMANA = [
  { id: 1, nome: 'Lunedì', numero: '09', data: '2026-03-09', oggi: false },
  { id: 2, nome: 'Martedì', numero: '10', data: '2026-03-10', oggi: false },
  { id: 3, nome: 'Mercoledì', numero: '11', data: '2026-03-11', oggi: true },
  { id: 4, nome: 'Giovedì', numero: '12', data: '2026-03-12', oggi: false },
  { id: 5, nome: 'Venerdì', numero: '13', data: '2026-03-13', oggi: false },
  { id: 6, nome: 'Sabato', numero: '14', data: '2026-03-14', oggi: false },
  { id: 7, nome: 'Domenica', numero: '15', data: '2026-03-15', oggi: false }
];

const OPERATORI = [
  { 
    id: 1, 
    nome: 'Federica Rossi', 
    colore: '#FFB366', 
    avatar: 'FR', 
    specialita: 'Hair Stylist',
    turnoInizio: '09:00',
    turnoFine: '19:00'
  },
  { 
    id: 2, 
    nome: 'Antonella Verdi', 
    colore: '#FF8FB3', 
    avatar: 'AV', 
    specialita: 'Estetista',
    turnoInizio: '09:00',
    turnoFine: '13:00'
  },
  { 
    id: 3, 
    nome: 'Silvia Bianchi', 
    colore: '#6FE6B3', 
    avatar: 'SB', 
    specialita: 'Massaggi',
    turnoInizio: '13:00',
    turnoFine: '19:00'
  },
  { 
    id: 4, 
    nome: 'Vacu Martinez', 
    colore: '#4A9FFF', 
    avatar: 'VM', 
    specialita: 'Makeup Artist',
    turnoInizio: '09:00',
    turnoFine: '19:00'
  },
  { 
    id: 5, 
    nome: 'Marco Neri', 
    colore: '#A78BFA', 
    avatar: 'MN', 
    specialita: 'Barbiere',
    turnoInizio: '09:00',
    turnoFine: '15:00'
  }
];

const ORARI = Array.from({ length: 20 }, (_, i) => {
  const hour = Math.floor(9 + i * 0.5);
  const minute = (i % 2) * 30;
  return `${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}`;
});

// Mappa Categorie → Colori
const CATEGORIE_COLORI: Record<string, string> = {
  'Taglio': '#4A9FFF',      // Blu
  'Piega': '#A78BFA',       // Viola
  'Colore': '#FF8FB3',      // Rosa
  'Trattamento': '#6FE6B3', // Verde
  'Massaggio': '#FFB366',   // Arancione
  'Trucco': '#F59E0B',      // Ambra
  'Unghie': '#EC4899',      // Rosa intenso
  'Depilazione': '#10B981', // Verde smeraldo
  'Barba': '#8B5CF6',       // Viola scuro
  'Extension': '#6366F1'    // Indaco
};

// Helper per ottenere colori categorie
function getCategoriaColori(categorie: string[]): string[] {
  if (!categorie || categorie.length === 0) return ['#94A3B8']; // Default grigio
  return categorie.map(cat => CATEGORIE_COLORI[cat] || '#94A3B8');
}

// Helper per calcolare altezza colonna in base al turno
function calcolaAltezzaColonna(turnoInizio: string, turnoFine: string): number {
  const [oreInizio, minutiInizio] = turnoInizio.split(':').map(Number);
  const [oreFine, minutiFine] = turnoFine.split(':').map(Number);
  
  const minutiInizio24 = oreInizio * 60 + minutiInizio;
  const minutiFine24 = oreFine * 60 + minutiFine;
  const durataMinuti = minutiFine24 - minutiInizio24;
  
  // 1 ora = 80px
  return (durataMinuti / 60) * 80;
}

// Helper per calcolare altezza card in base alla durata
function calcolaAltezzaCard(durata: number): number {
  // 15 min = 60px, 30 min = 80px, 60 min = 120px, 90 min = 160px, 120 min = 200px
  return Math.max(60, durata * 1.2);
}

// Mock data appuntamenti con durate 15, 30, 60, 90, 120 min
const mockAppuntamenti: Appuntamento[] = [
  // Appuntamenti 15 minuti
  {
    id: '1',
    operatore: 'Federica Rossi',
    cliente: 'Anna Ferrari',
    telefono: '3201234567',
    numeroCliente: '4159',
    servizio: 'Consulenza Taglio',
    oraInizio: '09:00',
    oraFine: '09:15',
    durata: 15,
    stato: 'programmato',
    priorita: 'normale',
    luogo: 'Sala 1',
    categorie: ['Taglio'],
    prorogato: true, // Esempio prorogato
    haPacchetti: true // Esempio con pacchetti
  },
  {
    id: '2',
    operatore: 'Marco Neri',
    cliente: 'Luca Bianchi',
    telefono: '3339876543',
    numeroCliente: '3201',
    servizio: 'Ritocco Barba',
    oraInizio: '09:15',
    oraFine: '09:30',
    durata: 15,
    stato: 'programmato',
    luogo: 'Postazione 3',
    categorie: ['Barba'],
    haPacchetti: true // Cliente con pacchetti
  },
  
  // Appuntamenti 30 minuti
  {
    id: '3',
    operatore: 'Antonella Verdi',
    cliente: 'Maria Rossi',
    telefono: '3287654321',
    numeroCliente: '2145',
    servizio: 'Depilazione Sopracciglia',
    oraInizio: '09:30',
    oraFine: '10:00',
    durata: 30,
    stato: 'programmato',
    luogo: 'Cabina 1',
    categorie: ['Depilazione']
  },
  {
    id: '4',
    operatore: 'Silvia Bianchi',
    cliente: 'Elena Conti',
    telefono: '3201112233',
    numeroCliente: '1876',
    servizio: 'Massaggio Express',
    oraInizio: '10:00',
    oraFine: '10:30',
    durata: 30,
    stato: 'programmato',
    luogo: 'Cabina 3',
    categorie: ['Massaggio']
  },
  {
    id: '5',
    operatore: 'Vacu Martinez',
    cliente: 'Chiara Neri',
    telefono: '3334445566',
    numeroCliente: '4521',
    servizio: 'Manicure Base',
    oraInizio: '09:00',
    oraFine: '09:30',
    durata: 30,
    stato: 'programmato',
    luogo: 'Sala Unghie',
    categorie: ['Unghie']
  },

  // Appuntamenti 60 minuti
  {
    id: '6',
    operatore: 'Federica Rossi',
    cliente: 'Giulia Conti',
    telefono: '3209876543',
    numeroCliente: '4110',
    servizio: 'Taglio + Piega',
    oraInizio: '10:30',
    oraFine: '11:30',
    durata: 60,
    stato: 'programmato',
    priorita: 'alta',
    luogo: 'Sala 1',
    categorie: ['Taglio', 'Piega'] // Doppia categoria
  },
  {
    id: '7',
    operatore: 'Antonella Verdi',
    cliente: 'Panaiota Ganci',
    telefono: '3297462114',
    numeroCliente: '4159',
    servizio: 'Trattamento Viso Completo',
    oraInizio: '10:30',
    oraFine: '11:30',
    durata: 60,
    stato: 'programmato',
    priorita: 'normale',
    luogo: 'Cabina 2',
    categorie: ['Trattamento']
  },
  {
    id: '8',
    operatore: 'Silvia Bianchi',
    cliente: 'Marco Romano',
    telefono: '',
    numeroCliente: '4113',
    servizio: 'Massaggio 50min',
    oraInizio: '11:30',
    oraFine: '12:30',
    durata: 60,
    stato: 'completato',
    luogo: 'Cabina 3',
    categorie: ['Massaggio']
  },

  // Appuntamenti 90 minuti
  {
    id: '9',
    operatore: 'Vacu Martinez',
    cliente: 'Sofia Russo',
    telefono: '3207777777',
    numeroCliente: '25',
    servizio: 'Trucco Sposa',
    oraInizio: '10:30',
    oraFine: '12:00',
    durata: 90,
    stato: 'programmato',
    priorita: 'alta',
    luogo: 'Sala Makeup',
    categorie: ['Trucco']
  },
  {
    id: '10',
    operatore: 'Marco Neri',
    cliente: 'Alessandro Martini',
    telefono: '3398765432',
    numeroCliente: '5678',
    servizio: 'Taglio + Barba Completa',
    oraInizio: '10:30',
    oraFine: '12:00',
    durata: 90,
    stato: 'programmato',
    luogo: 'Postazione 3',
    categorie: ['Taglio', 'Barba'] // Doppia categoria
  },

  // Appuntamenti 120 minuti
  {
    id: '11',
    operatore: 'Federica Rossi',
    cliente: 'Isabella Ferrari',
    telefono: '3201234999',
    numeroCliente: '8765',
    servizio: 'Colore Completo + Piega',
    oraInizio: '13:00',
    oraFine: '15:00',
    durata: 120,
    stato: 'noshow', // No Show
    priorita: 'alta',
    luogo: 'Sala 1',
    categorie: ['Colore', 'Piega'] // Doppia categoria
  },
  {
    id: '12',
    operatore: 'Antonella Verdi',
    cliente: 'Francesca Bianchi',
    telefono: '3287654999',
    numeroCliente: '9012',
    servizio: 'Trattamento + Depilazione',
    oraInizio: '12:00',
    oraFine: '14:00',
    durata: 120,
    stato: 'annullato', // Annullato
    luogo: 'Cabina 2',
    categorie: ['Trattamento', 'Depilazione'] // Doppia categoria
  },
  // Esempio appuntamento 45min noshow
  {
    id: '13',
    operatore: 'Vacu Martinez',
    cliente: 'Laura Bianchi',
    telefono: '3201234567',
    numeroCliente: '7890',
    servizio: 'Manicure Gel',
    oraInizio: '13:00',
    oraFine: '13:45',
    durata: 45,
    stato: 'noshow',
    luogo: 'Sala Unghie',
    categorie: ['Unghie']
  },
  // Esempio appuntamento 30min annullato
  {
    id: '14',
    operatore: 'Marco Neri',
    cliente: 'Paolo Verdi',
    telefono: '3339876543',
    numeroCliente: '1234',
    servizio: 'Barba Express',
    oraInizio: '13:00',
    oraFine: '13:30',
    durata: 30,
    stato: 'annullato',
    luogo: 'Postazione 3',
    categorie: ['Barba']
  }
];

export default function AgendaCalendarModern({ onAppuntamentoClick }: AgendaCalendarModernProps) {
  const [appuntamenti, setAppuntamenti] = useState<Appuntamento[]>(mockAppuntamenti);
  const [settimanaCorrente, setSettimanaCorrente] = useState(0);

  const handleDrop = (appuntamentoId: string, nuovoOperatore: string, nuovoOrario: string, giornoData: string) => {
    setAppuntamenti(prev => prev.map(app => 
      app.id === appuntamentoId 
        ? { ...app, operatore: nuovoOperatore, oraInizio: nuovoOrario }
        : app
    ));
    toast.success('Appuntamento spostato', {
      description: `${nuovoOperatore} - ${nuovoOrario}`
    });
  };

  return (
    <DndProvider backend={HTML5Backend}>
      <div className="space-y-6">
        {/* Header Controls */}
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <button 
              onClick={() => setSettimanaCorrente(prev => prev - 1)}
              className="p-2.5 border border-border rounded-lg hover:bg-muted transition-colors"
            >
              <ChevronLeft className="size-5" />
            </button>
            <div className="text-center">
              <h3 className="text-lg font-bold">9 - 15 Marzo 2026</h3>
              <p className="text-sm text-muted-foreground">Settimana 10</p>
            </div>
            <button 
              onClick={() => setSettimanaCorrente(prev => prev + 1)}
              className="p-2.5 border border-border rounded-lg hover:bg-muted transition-colors"
            >
              <ChevronRight className="size-5" />
            </button>
          </div>

          <div className="flex items-center gap-2">
            <button 
              onClick={() => toast.info('Vai a oggi')}
              className="px-4 py-2.5 bg-warning text-white rounded-lg hover:bg-warning/90 transition-colors font-medium text-sm"
            >
              Oggi
            </button>
            <button 
              onClick={() => toast.info('Seleziona data')}
              className="flex items-center gap-2 px-4 py-2.5 border border-border rounded-lg hover:bg-muted transition-colors text-sm"
            >
              <Calendar className="size-4" />
              Seleziona data
            </button>
          </div>
        </div>

        {/* Calendario - Giorni e Staff in Colonne */}
        <div className="bg-card border border-border rounded-2xl overflow-hidden shadow-sm">
          <div className="overflow-x-auto">
            <div className="flex min-w-max">
              {/* Colonna per ogni giorno */}
              {GIORNI_SETTIMANA.map((giorno) => (
                <GiornoColumn
                  key={giorno.id}
                  giorno={giorno}
                  appuntamenti={appuntamenti}
                  onDrop={handleDrop}
                  onAppuntamentoClick={onAppuntamentoClick}
                />
              ))}
            </div>
          </div>
        </div>

        {/* Legenda */}
        <div className="flex flex-wrap items-center gap-4 text-sm">
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-success"></div>
            <span className="text-muted-foreground">Confermato</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-warning"></div>
            <span className="text-muted-foreground">In attesa</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-muted"></div>
            <span className="text-muted-foreground">Completato</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-error"></div>
            <span className="text-muted-foreground">Annullato</span>
          </div>
        </div>
      </div>
    </DndProvider>
  );
}

// =====================================
// GIORNO COLUMN (COLONNA GIORNO)
// =====================================

interface GiornoColumnProps {
  giorno: typeof GIORNI_SETTIMANA[0];
  appuntamenti: Appuntamento[];
  onDrop: (appuntamentoId: string, operatore: string, orario: string, giornoData: string) => void;
  onAppuntamentoClick: (appuntamento: Appuntamento) => void;
}

function GiornoColumn({ giorno, appuntamenti, onDrop, onAppuntamentoClick }: GiornoColumnProps) {
  return (
    <div className="flex-shrink-0 border-r border-border last:border-r-0">
      {/* Header Giorno - COMPATTO */}
      <div className={`p-2 border-b border-border text-center ${
        giorno.oggi ? 'bg-warning/10' : 'bg-muted/30'
      }`}>
        <div className={`text-[10px] font-medium mb-0.5 ${giorno.oggi ? 'text-warning' : 'text-muted-foreground'}`}>
          {giorno.nome}
        </div>
        <div className={`text-2xl font-bold mb-1 ${giorno.oggi ? 'text-warning' : ''}`}>
          {giorno.numero}
        </div>
        {giorno.oggi && (
          <span className="inline-block text-[9px] px-2 py-0.5 bg-warning text-white rounded-full font-medium">
            Oggi
          </span>
        )}
      </div>

      {/* Sub-colonne Staff */}
      <div className="flex">
        {OPERATORI.map((operatore) => (
          <StaffCell
            key={`${giorno.id}-${operatore.id}`}
            giorno={giorno}
            operatore={operatore}
            appuntamenti={appuntamenti}
            onDrop={onDrop}
            onAppuntamentoClick={onAppuntamentoClick}
          />
        ))}
      </div>
    </div>
  );
}

// =====================================
// STAFF CELL (CELLA OPERATORE)
// =====================================

interface StaffCellProps {
  giorno: typeof GIORNI_SETTIMANA[0];
  operatore: typeof OPERATORI[0];
  appuntamenti: Appuntamento[];
  onDrop: (appuntamentoId: string, operatore: string, orario: string, giornoData: string) => void;
  onAppuntamentoClick: (appuntamento: Appuntamento) => void;
}

function StaffCell({ 
  giorno, 
  operatore, 
  appuntamenti, 
  onDrop, 
  onAppuntamentoClick 
}: StaffCellProps) {
  const [{ isOver }, drop] = useDrop({
    accept: 'APPUNTAMENTO',
    drop: (item: { id: string; orario: string }) => {
      onDrop(item.id, operatore.nome, item.orario, giorno.data);
    },
    collect: (monitor) => ({
      isOver: monitor.isOver()
    })
  });

  // Filtra appuntamenti per questo operatore (in futuro: filtro anche per giorno)
  const appuntamentiCella = appuntamenti.filter(
    app => app.operatore === operatore.nome
  );

  // Calcola altezza dinamica in base al turno
  const altezzaColonna = calcolaAltezzaColonna(operatore.turnoInizio, operatore.turnoFine);

  return (
    <div className="flex flex-col border-r border-border last:border-r-0">
      {/* Header Operatore con orario turno - COMPATTO */}
      <div className="p-2 border-b border-border bg-muted/20 flex flex-col items-center gap-1 w-32">
        <div 
          className="w-7 h-7 rounded-full flex items-center justify-center text-white font-bold text-[10px] shadow-sm"
          style={{ backgroundColor: operatore.colore }}
        >
          {operatore.avatar}
        </div>
        <div className="text-center w-full">
          <div className="font-semibold text-[10px] truncate px-1">{operatore.nome}</div>
          <div className="text-[8px] text-muted-foreground truncate">{operatore.specialita}</div>
          <div className="text-[8px] text-muted-foreground mt-0.5">
            {operatore.turnoInizio}-{operatore.turnoFine}
          </div>
        </div>
      </div>

      {/* Area Appuntamenti con altezza dinamica */}
      <div
        ref={drop}
        className={`p-2 w-32 transition-colors ${
          isOver ? 'bg-warning/10' : giorno.oggi ? 'bg-warning/5' : 'bg-background'
        }`}
        style={{ height: `${altezzaColonna}px` }}
      >
        <div className="space-y-1.5">
          {appuntamentiCella.map((app) => (
            <AppuntamentoCardModern
              key={app.id}
              appuntamento={app}
              operatoreColore={operatore.colore}
              onClick={() => onAppuntamentoClick(app)}
            />
          ))}
        </div>

        {/* Indicatore vuoto */}
        {appuntamentiCella.length === 0 && (
          <div className="flex items-center justify-center h-full">
            <span className="text-[10px] text-muted-foreground/30">Libero</span>
          </div>
        )}
      </div>
    </div>
  );
}

// =====================================
// APPUNTAMENTO CARD MODERNA
// =====================================

interface AppuntamentoCardModernProps {
  appuntamento: Appuntamento;
  operatoreColore: string;
  onClick: () => void;
}

function AppuntamentoCardModern({ appuntamento, operatoreColore, onClick }: AppuntamentoCardModernProps) {
  const [{ isDragging }, drag] = useDrag({
    type: 'APPUNTAMENTO',
    item: { id: appuntamento.id, orario: appuntamento.oraInizio },
    collect: (monitor) => ({
      isDragging: monitor.isDragging()
    })
  });

  // Configurazione stati con icone e colori sfondo
  const statoConfig = {
    programmato: { 
      icon: null, // Nessuna icona per programmato
      bgColor: 'bg-muted/30', // Grigetto
      iconColor: ''
    },
    completato: { 
      icon: CheckCircle, 
      bgColor: 'bg-muted/30', // Grigetto
      iconColor: 'text-success'
    },
    noshow: { 
      icon: UserX, 
      bgColor: 'bg-error/20', // Rosso
      iconColor: 'text-error'
    },
    annullato: { 
      icon: XCircle, 
      bgColor: 'bg-background', // Bianco
      iconColor: 'text-muted-foreground'
    }
  };

  const config = statoConfig[appuntamento.stato] || statoConfig.programmato; // Fallback a programmato
  const IconStato = config.icon;

  // Ottieni colori delle categorie
  const categoriaColori = getCategoriaColori(appuntamento.categorie);
  const isDoppiaCategoria = categoriaColori.length === 2;

  // Calcola altezza dinamica basata sulla durata
  const altezzaCard = calcolaAltezzaCard(appuntamento.durata);
  
  // Colore bordo = colore categoria (prende il primo colore se doppia categoria)
  const borderColor = categoriaColori[0];

  // Calcola se appuntamento è in ritardo (orario passato e non completato)
  const isInRitardo = (() => {
    // Simulazione ora corrente: oggi è mercoledì 11 marzo 2026 alle 12:00
    const oraCorrente = '12:00';
    const [oreApp, minutiApp] = appuntamento.oraFine.split(':').map(Number);
    const [oreCurrent, minutiCurrent] = oraCorrente.split(':').map(Number);
    const minutiAppuntamento = oreApp * 60 + minutiApp;
    const minutiAttuali = oreCurrent * 60 + minutiCurrent;
    
    // Appuntamento in ritardo se: orario passato E stato non completato/annullato
    return minutiAppuntamento < minutiAttuali && 
           appuntamento.stato !== 'completato' && 
           appuntamento.stato !== 'annullato';
  })();

  // Raccogli tutte le icone extra (prorogato, pacchetti, ritardo)
  const extraIcons = [];
  if (isInRitardo) {
    extraIcons.push({ 
      Icon: AlertTriangle, 
      color: 'text-error', 
      tooltip: 'In ritardo' 
    });
  }
  if (appuntamento.prorogato) {
    extraIcons.push({ 
      Icon: Coins, 
      color: 'text-warning', 
      tooltip: 'Prorogato' 
    });
  }
  if (appuntamento.haPacchetti) {
    extraIcons.push({ 
      Icon: Package, 
      color: 'text-success', 
      tooltip: 'Ha pacchetti' 
    });
  }

  return (
    <HoverCard.Root openDelay={200}>
      <HoverCard.Trigger asChild>
        <div
          ref={drag}
          onClick={onClick}
          className={`
            relative group cursor-pointer p-2 border-2 transition-all duration-200
            hover:shadow-lg hover:scale-[1.02] hover:-translate-y-0.5
            ${config.bgColor}
            ${isDragging ? 'opacity-50 scale-95' : 'opacity-100'}
          `}
          style={{ 
            minHeight: `${altezzaCard}px`,
            borderColor: borderColor
          }}
        >
          {/* Barra laterale colorata CATEGORIE (singola o doppia) - DELINEATA */}
          {isDoppiaCategoria ? (
            <div className="absolute left-0 top-0 bottom-0 w-2 overflow-hidden shadow-sm">
              {/* Doppia categoria - split netto 50/50 */}
              <div 
                className="absolute inset-0"
                style={{ 
                  background: `linear-gradient(180deg, ${categoriaColori[0]} 0%, ${categoriaColori[0]} 48%, #FFFFFF 48%, #FFFFFF 52%, ${categoriaColori[1]} 52%, ${categoriaColori[1]} 100%)`
                }}
              />
            </div>
          ) : (
            <div 
              className="absolute left-0 top-0 bottom-0 w-2 shadow-sm border-r border-white/20"
              style={{ 
                backgroundColor: borderColor
              }}
            />
          )}

          {/* Contenuto MINIMAL - Orario, icona stato, nome cliente e icone extra */}
          <div className="ml-2 space-y-1">
            {/* Riga 1: Orario e icona stato */}
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold truncate">
                {appuntamento.oraInizio}
              </span>
              
              {/* Icona stato - solo per stati non programmati */}
              {IconStato && (
                <IconStato className={`size-3 ${config.iconColor} flex-shrink-0`} />
              )}
            </div>

            {/* Riga 2: Nome Cliente */}
            {appuntamento.cliente && (
              <div className="text-[10px] text-foreground/80 truncate font-medium">
                {appuntamento.cliente}
              </div>
            )}

            {/* Riga 3: Icone extra (ritardo, prorogato, pacchetti) */}
            {extraIcons.length > 0 && (
              <div className="flex items-center gap-1">
                {extraIcons.map((item, idx) => (
                  <item.Icon 
                    key={idx} 
                    className={`size-4 ${item.color} flex-shrink-0`} 
                    title={item.tooltip}
                  />
                ))}
              </div>
            )}
          </div>
        </div>
      </HoverCard.Trigger>

      {/* Hover Preview - dettagli completi */}
      <HoverCard.Portal>
        <HoverCard.Content
          side="top"
          align="center"
          className="w-80 bg-card border-2 border-border rounded-2xl shadow-2xl p-5 z-50 animate-in fade-in-0 zoom-in-95"
        >
          <div className="space-y-4">
            {/* Header Preview con Categorie */}
            <div className="flex items-start justify-between">
              <div className="flex-1">
                <h4 className="font-bold text-lg mb-2">{appuntamento.servizio}</h4>
                
                {/* Badge Categorie Grandi */}
                <div className="flex flex-wrap gap-2 mb-3">
                  {appuntamento.categorie.map((categoria, idx) => (
                    <span
                      key={idx}
                      className="text-xs px-3 py-1 rounded-lg text-white font-semibold shadow-sm"
                      style={{ backgroundColor: CATEGORIE_COLORI[categoria] || '#94A3B8' }}
                    >
                      {categoria}
                    </span>
                  ))}
                </div>

                <div className="flex items-center gap-2 flex-wrap">
                  <div className="flex items-center gap-2">
                    <Clock className="size-4 text-muted-foreground" />
                    <span className="text-sm font-medium">
                      {appuntamento.oraInizio} - {appuntamento.oraFine}
                    </span>
                    <span className="text-sm text-muted-foreground">
                      ({appuntamento.durata} min)
                    </span>
                  </div>
                  
                  {/* Badge extra nel preview */}
                  {isInRitardo && (
                    <span className="inline-flex items-center gap-1 px-2 py-0.5 bg-error/20 text-error rounded-md text-xs font-semibold">
                      <AlertTriangle className="size-3" />
                      In ritardo
                    </span>
                  )}
                  {appuntamento.prorogato && (
                    <span className="inline-flex items-center gap-1 px-2 py-0.5 bg-warning/20 text-warning rounded-md text-xs font-semibold">
                      <Coins className="size-3" />
                      Prorogato
                    </span>
                  )}
                  {appuntamento.haPacchetti && (
                    <span className="inline-flex items-center gap-1 px-2 py-0.5 bg-success/20 text-success rounded-md text-xs font-semibold">
                      <Package className="size-3" />
                      Pacchetti attivi
                    </span>
                  )}
                </div>
              </div>
              
              {/* Badge Stato */}
              <div className="flex items-center gap-2">
                {IconStato && (
                  <IconStato className={`size-4 ${config.iconColor}`} />
                )}
                <span className={`px-3 py-1.5 rounded-lg text-xs font-semibold ${config.bgColor}`}>
                  {appuntamento.stato === 'programmato' ? 'Programmato' :
                   appuntamento.stato === 'noshow' ? 'No Show' :
                   appuntamento.stato === 'completato' ? 'Completato' :
                   'Annullato'}
                </span>
              </div>
            </div>

            {/* Divider */}
            <div className="h-px bg-border"></div>

            {/* Cliente Info */}
            <div className="space-y-3">
              {appuntamento.cliente && (
                <div className="flex items-center gap-3">
                  <div className="w-9 h-9 rounded-full bg-primary/10 flex items-center justify-center flex-shrink-0">
                    <User className="size-4 text-primary" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold">{appuntamento.cliente}</p>
                    <p className="text-xs text-muted-foreground">Cliente</p>
                  </div>
                </div>
              )}

              {appuntamento.telefono && (
                <div className="flex items-center gap-3">
                  <div className="w-9 h-9 rounded-full bg-success/10 flex items-center justify-center flex-shrink-0">
                    <Phone className="size-4 text-success" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-mono font-semibold">{appuntamento.telefono}</p>
                    <p className="text-xs text-muted-foreground">Telefono</p>
                  </div>
                </div>
              )}

              {appuntamento.numeroCliente && (
                <div className="flex items-center gap-3">
                  <div className="w-9 h-9 rounded-full bg-warning/10 flex items-center justify-center flex-shrink-0">
                    <Hash className="size-4 text-warning" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold">N° {appuntamento.numeroCliente}</p>
                    <p className="text-xs text-muted-foreground">Codice cliente</p>
                  </div>
                </div>
              )}

              {appuntamento.luogo && (
                <div className="flex items-center gap-3">
                  <div className="w-9 h-9 rounded-full bg-muted flex items-center justify-center flex-shrink-0">
                    <MapPin className="size-4 text-foreground" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold">{appuntamento.luogo}</p>
                    <p className="text-xs text-muted-foreground">Luogo</p>
                  </div>
                </div>
              )}
            </div>

            {/* Note */}
            {appuntamento.note && (
              <>
                <div className="h-px bg-border"></div>
                <div className="flex items-start gap-2 p-3 bg-muted/30 rounded-lg">
                  <MessageSquare className="size-4 text-muted-foreground mt-0.5 flex-shrink-0" />
                  <p className="text-sm text-muted-foreground italic">{appuntamento.note}</p>
                </div>
              </>
            )}

            {/* Actions */}
            <div className="flex gap-2 pt-2">
              <button 
                onClick={(e) => {
                  e.stopPropagation();
                  toast.info('Modifica appuntamento');
                }}
                className="flex-1 px-4 py-2 text-sm border-2 border-border rounded-lg hover:bg-muted transition-colors font-medium"
              >
                Modifica
              </button>
              <button 
                onClick={(e) => {
                  e.stopPropagation();
                  onClick();
                }}
                className="flex-1 px-4 py-2 text-sm bg-warning text-white rounded-lg hover:bg-warning/90 transition-colors font-medium"
              >
                Dettagli
              </button>
            </div>
          </div>

          <HoverCard.Arrow className="fill-border" />
        </HoverCard.Content>
      </HoverCard.Portal>
    </HoverCard.Root>
  );
}