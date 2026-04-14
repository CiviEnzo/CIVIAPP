import { useState } from 'react';
import { DndProvider, useDrag, useDrop } from 'react-dnd';
import { HTML5Backend } from 'react-dnd-html5-backend';
import {
  Calendar, ChevronLeft, ChevronRight, Eye, AlertTriangle, 
  Clock, Phone, User, Hash
} from 'lucide-react';
import { toast } from 'sonner';
import * as HoverCard from '@radix-ui/react-hover-card';

/**
 * Admin/Agenda/Calendar/Enhanced/DragDrop
 * Calendario settimanale con drag & drop, hover preview e click per dettaglio
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
  colore: 'blue' | 'yellow' | 'green' | 'pink' | 'orange';
  stato: 'confermato' | 'attesa' | 'completato' | 'annullato';
  note?: string;
}

interface AgendaCalendarEnhancedProps {
  onAppuntamentoClick: (appuntamento: Appuntamento) => void;
}

const OPERATORI = ['Vacu', 'Federica', 'Antoniel...', 'Silvia', 'Ufficio'];
const ORARI = [
  '09:00', '09:30', '10:00', '10:30', '11:00', '11:30',
  '12:00', '12:30', '13:00', '13:30', '14:00', '14:30',
  '15:00', '15:30', '16:00', '16:30'
];

const GIORNI_SETTIMANA = [
  { giorno: 'Lunedì 09 Mar', data: '2026-03-09', icon: '☀️' },
  { giorno: 'Martedì 10 Mar', data: '2026-03-10', icon: '☁️' },
  { giorno: 'Mercoledì 11 Mar', data: '2026-03-11', icon: '🌧️' }
];

// Mock data appuntamenti
const mockAppuntamenti: Appuntamento[] = [
  {
    id: '1',
    operatore: 'Federica',
    cliente: '----',
    telefono: '',
    numeroCliente: '',
    servizio: '',
    oraInizio: '09:00',
    oraFine: '09:30',
    durata: 30,
    colore: 'yellow',
    stato: 'attesa'
  },
  {
    id: '2',
    operatore: 'Federica',
    cliente: '',
    telefono: '',
    numeroCliente: '4159',
    servizio: '4 zone',
    oraInizio: '10:00',
    oraFine: '11:00',
    durata: 60,
    colore: 'yellow',
    stato: 'confermato'
  },
  {
    id: '3',
    operatore: 'Federica',
    cliente: 'Mass...',
    telefono: '',
    numeroCliente: '4110',
    servizio: '',
    oraInizio: '11:30',
    oraFine: '12:00',
    durata: 30,
    colore: 'green',
    stato: 'confermato'
  },
  {
    id: '4',
    operatore: 'Antoniel...',
    cliente: 'panaiota ganci',
    telefono: '3297462114',
    numeroCliente: '4159',
    servizio: 'Massaggio 1h',
    oraInizio: '11:30',
    oraFine: '12:30',
    durata: 60,
    colore: 'pink',
    stato: 'confermato'
  },
  {
    id: '5',
    operatore: 'Silvia',
    cliente: 'Mass...',
    telefono: '',
    numeroCliente: '4113',
    servizio: '',
    oraInizio: '11:30',
    oraFine: '12:00',
    durata: 30,
    colore: 'green',
    stato: 'confermato'
  },
  {
    id: '6',
    operatore: 'Silvia',
    cliente: 'Cellu...',
    telefono: '',
    numeroCliente: '1520',
    servizio: '',
    oraInizio: '10:30',
    oraFine: '11:00',
    durata: 30,
    colore: 'green',
    stato: 'confermato'
  },
  {
    id: '7',
    operatore: 'Silvia',
    cliente: 'Mass...',
    telefono: '',
    numeroCliente: '25',
    servizio: '',
    oraInizio: '09:00',
    oraFine: '09:30',
    durata: 30,
    colore: 'green',
    stato: 'confermato'
  }
];

export default function AgendaCalendarEnhanced({ onAppuntamentoClick }: AgendaCalendarEnhancedProps) {
  const [appuntamenti, setAppuntamenti] = useState<Appuntamento[]>(mockAppuntamenti);
  const [settimanaCorrente, setSettimanaCorrente] = useState(0);

  const handleDrop = (appuntamentoId: string, nuovoOperatore: string, nuovoOrario: string) => {
    setAppuntamenti(prev => prev.map(app => 
      app.id === appuntamentoId 
        ? { ...app, operatore: nuovoOperatore, oraInizio: nuovoOrario }
        : app
    ));
    toast.success('Appuntamento spostato');
  };

  return (
    <DndProvider backend={HTML5Backend}>
      <div className="space-y-4">
        {/* Header */}
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-center gap-2">
            <button className="flex items-center gap-2 px-4 py-2 bg-warning text-white rounded-lg hover:bg-warning/90 transition-colors font-medium text-sm">
              <Eye className="size-4" />
              Visione agenda
            </button>
            <button 
              onClick={() => toast.info('Vai a oggi')}
              className="px-4 py-2 bg-warning text-white rounded-lg hover:bg-warning/90 transition-colors font-medium text-sm"
            >
              Oggi
            </button>
          </div>

          <div className="flex items-center gap-2">
            <button 
              onClick={() => setSettimanaCorrente(prev => prev - 1)}
              className="p-2 border border-border rounded-lg hover:bg-muted transition-colors"
            >
              <ChevronLeft className="size-5" />
            </button>
            <span className="px-4 py-2 font-semibold">
              Settimana 09 mar → 15 mar
            </span>
            <button 
              onClick={() => setSettimanaCorrente(prev => prev + 1)}
              className="p-2 border border-border rounded-lg hover:bg-muted transition-colors"
            >
              <ChevronRight className="size-5" />
            </button>
          </div>

          <button 
            onClick={() => toast.info('Seleziona data')}
            className="flex items-center gap-2 px-4 py-2 bg-warning text-white rounded-lg hover:bg-warning/90 transition-colors font-medium text-sm"
          >
            <Calendar className="size-4" />
            Vai a data
          </button>
        </div>

        {/* Calendario */}
        <div className="bg-card border border-border rounded-xl overflow-hidden">
          <div className="overflow-x-auto">
            <div className="min-w-[1200px]">
              {/* Header giorni */}
              <div className="grid grid-cols-[80px_repeat(15,1fr)] border-b border-border">
                <div className="bg-muted/50 border-r border-border" />
                {GIORNI_SETTIMANA.map((giorno) => (
                  <div key={giorno.data} className="col-span-5 border-r border-border">
                    <div className="flex items-center gap-2 px-3 py-3 bg-muted/50">
                      <Calendar className="size-4" />
                      <span className="font-semibold text-sm">{giorno.giorno}</span>
                      <span>{giorno.icon}</span>
                    </div>
                    {/* Header operatori */}
                    <div className="grid grid-cols-5">
                      {OPERATORI.map((operatore) => (
                        <div 
                          key={`${giorno.data}-${operatore}`}
                          className="px-2 py-2 border-r border-border text-center text-xs font-medium bg-background"
                        >
                          {operatore}
                        </div>
                      ))}
                    </div>
                  </div>
                ))}
              </div>

              {/* Timeline */}
              <div className="grid grid-cols-[80px_repeat(15,1fr)]">
                {ORARI.map((orario) => (
                  <TimelineRow
                    key={orario}
                    orario={orario}
                    appuntamenti={appuntamenti}
                    onDrop={handleDrop}
                    onAppuntamentoClick={onAppuntamentoClick}
                  />
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </DndProvider>
  );
}

// =====================================
// TIMELINE ROW
// =====================================

interface TimelineRowProps {
  orario: string;
  appuntamenti: Appuntamento[];
  onDrop: (appuntamentoId: string, operatore: string, orario: string) => void;
  onAppuntamentoClick: (appuntamento: Appuntamento) => void;
}

function TimelineRow({ orario, appuntamenti, onDrop, onAppuntamentoClick }: TimelineRowProps) {
  return (
    <>
      {/* Orario label */}
      <div className="flex items-start justify-end px-3 py-2 text-sm font-medium text-muted-foreground bg-muted/30 border-r border-b border-border">
        {orario}
      </div>

      {/* Celle per ogni giorno/operatore */}
      {GIORNI_SETTIMANA.map((giorno) =>
        OPERATORI.map((operatore) => (
          <CalendarCell
            key={`${giorno.data}-${operatore}-${orario}`}
            giorno={giorno.data}
            operatore={operatore}
            orario={orario}
            appuntamenti={appuntamenti}
            onDrop={onDrop}
            onAppuntamentoClick={onAppuntamentoClick}
          />
        ))
      )}
    </>
  );
}

// =====================================
// CALENDAR CELL (DROP TARGET)
// =====================================

interface CalendarCellProps {
  giorno: string;
  operatore: string;
  orario: string;
  appuntamenti: Appuntamento[];
  onDrop: (appuntamentoId: string, operatore: string, orario: string) => void;
  onAppuntamentoClick: (appuntamento: Appuntamento) => void;
}

function CalendarCell({ 
  giorno, 
  operatore, 
  orario, 
  appuntamenti, 
  onDrop,
  onAppuntamentoClick 
}: CalendarCellProps) {
  const [{ isOver }, drop] = useDrop({
    accept: 'APPUNTAMENTO',
    drop: (item: { id: string }) => {
      onDrop(item.id, operatore, orario);
    },
    collect: (monitor) => ({
      isOver: monitor.isOver()
    })
  });

  const appuntamento = appuntamenti.find(
    app => app.operatore === operatore && app.oraInizio === orario
  );

  // Determina se è una cella "vuota disponibile" (fascia rosa)
  const isDisponibile = !appuntamento && ['09:00', '15:00', '16:00'].includes(orario);

  return (
    <div
      ref={drop}
      className={`relative min-h-[50px] border-r border-b border-border transition-colors ${
        isOver 
          ? 'bg-warning/20' 
          : isDisponibile 
          ? 'bg-error/5' 
          : 'bg-background'
      }`}
    >
      {appuntamento && (
        <AppuntamentoCard 
          appuntamento={appuntamento} 
          onClick={() => onAppuntamentoClick(appuntamento)}
        />
      )}
      {isDisponibile && !appuntamento && (
        <div className="absolute inset-0 flex items-center justify-center">
          <span className="text-xs text-error/30 font-medium">Ferie</span>
        </div>
      )}
    </div>
  );
}

// =====================================
// APPUNTAMENTO CARD (DRAGGABLE + HOVER)
// =====================================

interface AppuntamentoCardProps {
  appuntamento: Appuntamento;
  onClick: () => void;
}

function AppuntamentoCard({ appuntamento, onClick }: AppuntamentoCardProps) {
  const [{ isDragging }, drag] = useDrag({
    type: 'APPUNTAMENTO',
    item: { id: appuntamento.id },
    collect: (monitor) => ({
      isDragging: monitor.isDragging()
    })
  });

  const colorClasses = {
    blue: 'bg-[#4A9FFF] text-white',
    yellow: 'bg-[#FFE066] text-foreground',
    green: 'bg-[#6FE6B3] text-foreground',
    pink: 'bg-[#FF8FB3] text-white',
    orange: 'bg-[#FFB366] text-foreground'
  };

  const hasWarning = appuntamento.note?.includes('ANNULLATO');

  return (
    <HoverCard.Root openDelay={300}>
      <HoverCard.Trigger asChild>
        <div
          ref={drag}
          onClick={onClick}
          className={`
            absolute inset-0 m-0.5 rounded-lg p-2 cursor-pointer
            transition-all duration-200 hover:shadow-lg hover:scale-[1.02]
            ${colorClasses[appuntamento.colore]}
            ${isDragging ? 'opacity-50' : 'opacity-100'}
          `}
          style={{
            height: `${appuntamento.durata * 1.6}px`, // 60min = 96px
            zIndex: 10
          }}
        >
          <div className="flex flex-col h-full text-xs">
            <div className="flex items-center justify-between mb-1">
              <span className="font-bold truncate">{appuntamento.oraInizio}</span>
              {hasWarning && <AlertTriangle className="size-3 text-error flex-shrink-0" />}
            </div>
            {appuntamento.servizio && (
              <p className="font-medium truncate">{appuntamento.servizio}</p>
            )}
            {appuntamento.numeroCliente && (
              <p className="text-[10px] opacity-80 truncate">N° {appuntamento.numeroCliente}</p>
            )}
            {appuntamento.cliente && (
              <p className="text-[10px] opacity-80 truncate">{appuntamento.cliente}</p>
            )}
          </div>
        </div>
      </HoverCard.Trigger>

      {/* Hover Preview */}
      <HoverCard.Portal>
        <HoverCard.Content
          side="right"
          align="start"
          className="w-80 bg-card border border-border rounded-xl shadow-2xl p-4 z-50 animate-in fade-in-0 zoom-in-95"
        >
          <div className="space-y-3">
            {/* Header */}
            <div className="flex items-start justify-between">
              <div>
                <h4 className="font-bold text-lg mb-1">{appuntamento.servizio || 'Appuntamento'}</h4>
                <p className="text-sm text-muted-foreground">
                  {appuntamento.oraInizio} - {appuntamento.oraFine}
                </p>
              </div>
              <div className={`px-2 py-1 rounded text-xs font-medium ${
                appuntamento.stato === 'confermato' ? 'bg-success/10 text-success' :
                appuntamento.stato === 'attesa' ? 'bg-warning/10 text-warning' :
                'bg-muted text-muted-foreground'
              }`}>
                {appuntamento.stato === 'confermato' ? 'Confermato' :
                 appuntamento.stato === 'attesa' ? 'In attesa' :
                 'Da confermare'}
              </div>
            </div>

            {/* Info cliente */}
            <div className="space-y-2 border-t border-border pt-3">
              {appuntamento.cliente && (
                <div className="flex items-center gap-2">
                  <User className="size-4 text-muted-foreground" />
                  <span className="text-sm font-medium">{appuntamento.cliente}</span>
                </div>
              )}
              {appuntamento.numeroCliente && (
                <div className="flex items-center gap-2">
                  <Hash className="size-4 text-muted-foreground" />
                  <span className="text-sm">Cliente N° {appuntamento.numeroCliente}</span>
                </div>
              )}
              {appuntamento.telefono && (
                <div className="flex items-center gap-2">
                  <Phone className="size-4 text-muted-foreground" />
                  <span className="text-sm font-mono">{appuntamento.telefono}</span>
                </div>
              )}
              <div className="flex items-center gap-2">
                <Clock className="size-4 text-muted-foreground" />
                <span className="text-sm">{appuntamento.durata} min ({appuntamento.durata / 60}h)</span>
              </div>
            </div>

            {/* Note */}
            {appuntamento.note && (
              <div className="border-t border-border pt-3">
                <p className="text-sm text-muted-foreground italic">{appuntamento.note}</p>
              </div>
            )}

            {/* Footer */}
            <div className="flex gap-2 border-t border-border pt-3">
              <button className="flex-1 px-3 py-2 text-xs border border-border rounded-lg hover:bg-muted transition-colors">
                Modifica
              </button>
              <button className="flex-1 px-3 py-2 text-xs bg-warning text-white rounded-lg hover:bg-warning/90 transition-colors">
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
