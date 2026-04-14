import { useState } from 'react';
import {
  X, Users, Search, User, Hash, Calendar, Clock, ChevronDown,
  ChevronLeft, ChevronRight, Plus, Minus, Edit2, StickyNote,
  Copy, Save, CheckCircle, Menu, AlertCircle
} from 'lucide-react';
import { toast } from 'sonner';

/**
 * Admin/Appuntamento/BottomSheet/Enhanced/Compact
 * Bottom sheet elegante e compatta per creazione/modifica appuntamento
 */

interface AppuntamentoBottomSheetProps {
  isOpen: boolean;
  onClose: () => void;
  mode?: 'create' | 'edit';
  initialData?: any;
}

export default function AppuntamentoBottomSheet({
  isOpen,
  onClose,
  mode = 'create',
  initialData
}: AppuntamentoBottomSheetProps) {
  const [step, setStep] = useState(1);
  const [operatore, setOperatore] = useState('andrea danna');
  const [clienteNome, setClienteNome] = useState('chirco giuseppina');
  const [clienteTelefono, setClienteTelefono] = useState('3206348313');
  const [numeroCliente, setNumeroCliente] = useState('6');
  const [servizioSelezionato, setServizioSelezionato] = useState('Radio');
  const [oraInizio, setOraInizio] = useState('09:15');
  const [oraFine, setOraFine] = useState('10:15');
  const [durata, setDurata] = useState(60);
  const [stato, setStato] = useState('Programmato');
  const [showServizi, setShowServizi] = useState(false);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center">
      {/* Backdrop */}
      <div 
        className="absolute inset-0 bg-black/50 backdrop-blur-sm"
        onClick={onClose}
      />

      {/* Bottom Sheet */}
      <div className="relative w-full max-w-2xl bg-card rounded-t-2xl sm:rounded-2xl shadow-2xl max-h-[90vh] overflow-y-auto animate-in slide-in-from-bottom duration-300">
        {/* Header */}
        <div className="sticky top-0 bg-card border-b border-border px-6 py-4 flex items-center justify-between">
          <div className="flex-1">
            <h2 className="text-xl font-bold">Dettaglio appuntamento</h2>
            <p className="text-xs text-muted-foreground mt-0.5">Passaggio {step} di 2</p>
          </div>
          <button 
            onClick={onClose}
            className="p-2 hover:bg-muted rounded-lg transition-colors"
          >
            <X className="size-5" />
          </button>
        </div>

        {/* Content */}
        <div className="p-6 space-y-6">
          {/* Top Info Row */}
          <div className="flex items-center justify-between">
            <div>
              <h3 className="text-lg font-semibold">Nuovo appuntamento</h3>
              <p className="text-sm text-muted-foreground">Sabato 7 marzo 2026</p>
            </div>
            <div className="w-48">
              <label className="block text-xs text-warning mb-1">Operatore</label>
              <select 
                value={operatore}
                onChange={(e) => setOperatore(e.target.value)}
                className="w-full px-3 py-2 bg-input-background border border-border rounded-lg text-sm appearance-none"
              >
                <option>andrea danna</option>
                <option>antonio berna</option>
                <option>staff member</option>
              </select>
            </div>
          </div>

          {/* Cliente Section */}
          <div>
            <div className="flex items-center gap-2 mb-3">
              <Users className="size-4" />
              <h4 className="font-semibold">Cliente</h4>
            </div>
            
            <div className="grid sm:grid-cols-2 gap-3">
              {/* Cliente Search/Display */}
              <div>
                <label className="block text-xs text-warning mb-1.5">Cliente</label>
                {clienteNome ? (
                  <div className="flex items-center justify-between p-3 bg-input-background border border-border rounded-lg">
                    <div>
                      <p className="text-sm font-medium">{clienteNome}</p>
                      <p className="text-xs text-muted-foreground">{clienteTelefono}</p>
                    </div>
                    <div className="flex gap-1">
                      <button className="p-1.5 hover:bg-muted rounded transition-colors">
                        <Edit2 className="size-3" />
                      </button>
                      <button className="p-1.5 hover:bg-muted rounded transition-colors">
                        <StickyNote className="size-3" />
                      </button>
                      <button 
                        onClick={() => {
                          setClienteNome('');
                          setClienteTelefono('');
                        }}
                        className="p-1.5 hover:bg-error/10 rounded transition-colors"
                      >
                        <X className="size-3 text-error" />
                      </button>
                    </div>
                  </div>
                ) : (
                  <div className="relative">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-muted-foreground" />
                    <input
                      type="text"
                      placeholder="Nome, cognome, telefono o email"
                      className="w-full pl-9 pr-3 py-2 bg-input-background border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-ring"
                    />
                  </div>
                )}
              </div>

              {/* Numero Cliente */}
              <div>
                <label className="block text-xs text-warning mb-1.5">Numero cliente</label>
                <div className="relative">
                  <Hash className="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-muted-foreground" />
                  <input
                    type="text"
                    value={numeroCliente}
                    onChange={(e) => setNumeroCliente(e.target.value)}
                    placeholder="Numero cliente"
                    className="w-full pl-9 pr-10 py-2 bg-input-background border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-ring"
                  />
                  <button className="absolute right-3 top-1/2 -translate-y-1/2">
                    <Search className="size-4 text-muted-foreground" />
                  </button>
                </div>
              </div>
            </div>
          </div>

          {/* Servizi Section */}
          <div>
            <div className="flex items-center gap-2 mb-3">
              <Calendar className="size-4" />
              <h4 className="font-semibold">Servizi e pacchetti</h4>
            </div>

            {/* Servizio Selector */}
            <div className="mb-3">
              <label className="block text-xs text-warning mb-1.5">Servizi</label>
              <div className="flex items-center gap-2 p-3 bg-input-background border border-border rounded-lg">
                <button className="p-1 hover:bg-muted rounded transition-colors">
                  <ChevronLeft className="size-4" />
                </button>
                <span className="flex-1 text-center text-sm font-medium">{servizioSelezionato}</span>
                <button className="p-1 hover:bg-muted rounded transition-colors">
                  <ChevronRight className="size-4" />
                </button>
                <button 
                  onClick={() => setShowServizi(!showServizi)}
                  className="p-1 hover:bg-muted rounded transition-colors"
                >
                  <Menu className="size-4" />
                </button>
              </div>
            </div>

            {/* Pacchetti Disponibili */}
            <div className="bg-warning/5 border border-warning/20 rounded-lg p-3">
              <div className="flex items-center gap-2 mb-2">
                <AlertCircle className="size-4 text-warning" />
                <p className="text-xs font-semibold text-warning">Pacchetti disponibili</p>
              </div>
              <div className="space-y-2">
                <div className="bg-card border border-warning rounded-lg p-3">
                  <div className="flex items-start justify-between">
                    <div className="flex-1">
                      <p className="text-sm font-semibold mb-1">100 Laser</p>
                      <p className="text-xs text-muted-foreground">2 sessioni disponibili</p>
                    </div>
                    <div className="w-5 h-5 rounded-full border-2 border-warning bg-warning flex items-center justify-center">
                      <div className="w-2 h-2 rounded-full bg-white" />
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Data e Orario Section */}
          <div>
            <div className="flex items-center justify-between mb-3">
              <p className="font-semibold">Sabato 7 marzo 2026</p>
              <div className="flex items-center gap-1 text-warning">
                <Clock className="size-4" />
                <span className="text-sm font-semibold">{durata} min</span>
              </div>
            </div>

            {/* Orari Row */}
            <div className="grid grid-cols-2 gap-3 mb-3">
              <div>
                <label className="block text-xs text-muted-foreground mb-1.5">Ora di inizio</label>
                <input
                  type="time"
                  value={oraInizio}
                  onChange={(e) => setOraInizio(e.target.value)}
                  className="w-full px-3 py-2 bg-input-background border border-border rounded-lg text-sm font-semibold focus:outline-none focus:ring-2 focus:ring-ring"
                />
              </div>
              <div>
                <label className="block text-xs text-muted-foreground mb-1.5">Ora di fine</label>
                <input
                  type="time"
                  value={oraFine}
                  onChange={(e) => setOraFine(e.target.value)}
                  className="w-full px-3 py-2 bg-input-background border border-border rounded-lg text-sm font-semibold focus:outline-none focus:ring-2 focus:ring-ring"
                />
              </div>
            </div>

            {/* Durata Controls */}
            <div className="flex items-center justify-between p-3 bg-muted/50 rounded-lg">
              <span className="text-sm">Regola durata complessiva</span>
              <div className="flex items-center gap-2">
                <button 
                  onClick={() => setDurata(durata - 15)}
                  className="p-1.5 hover:bg-background rounded-full transition-colors border border-border"
                >
                  <Minus className="size-4" />
                </button>
                <button 
                  onClick={() => setDurata(durata + 15)}
                  className="p-1.5 hover:bg-background rounded-full transition-colors border border-border"
                >
                  <Plus className="size-4" />
                </button>
              </div>
            </div>

            {/* Slot Suggestion */}
            <button 
              onClick={() => toast.info('Ricerca slot disponibili')}
              className="w-full mt-3 text-sm text-warning hover:underline flex items-center justify-center gap-1"
            >
              <AlertCircle className="size-4" />
              Tocca per scegliere un altro slot disponibile
            </button>
          </div>

          {/* Regola Durata Servizi (Expandable) */}
          <div className="border border-border rounded-lg overflow-hidden">
            <button 
              onClick={() => toast.info('Espandi regola durata')}
              className="w-full flex items-center justify-between p-3 hover:bg-muted/50 transition-colors"
            >
              <div className="flex items-center gap-2">
                <Clock className="size-4 text-warning" />
                <div className="text-left">
                  <p className="text-sm font-semibold">Regola durata servizi</p>
                  <p className="text-xs text-muted-foreground">Modifica ogni servizio di ±15 min</p>
                </div>
              </div>
              <ChevronDown className="size-4 text-muted-foreground" />
            </button>
          </div>
        </div>

        {/* Footer Actions */}
        <div className="sticky bottom-0 bg-card border-t border-border px-6 py-4">
          <div className="flex items-center justify-between gap-3">
            {/* Stato Dropdown */}
            <div className="flex-1 max-w-xs">
              <label className="block text-xs text-warning mb-1.5">Stato</label>
              <div className="relative">
                <CheckCircle className="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-warning" />
                <select 
                  value={stato}
                  onChange={(e) => setStato(e.target.value)}
                  className="w-full pl-9 pr-8 py-2 bg-input-background border border-border rounded-lg text-sm font-medium appearance-none"
                >
                  <option>Programmato</option>
                  <option>Confermato</option>
                  <option>In corso</option>
                  <option>Completato</option>
                  <option>Annullato</option>
                </select>
                <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 size-4 text-muted-foreground pointer-events-none" />
              </div>
            </div>

            {/* Action Buttons */}
            <div className="flex gap-2">
              <button 
                onClick={() => toast.info('Aggiungi nota')}
                className="flex items-center gap-2 px-4 py-2 bg-warning text-white rounded-lg hover:bg-warning/90 transition-colors"
              >
                <StickyNote className="size-4" />
                Nota
              </button>
              <button 
                onClick={() => toast.success('Appuntamento copiato')}
                className="flex items-center gap-2 px-4 py-2 bg-warning text-white rounded-lg hover:bg-warning/90 transition-colors"
              >
                <Copy className="size-4" />
                Copia
              </button>
              <button 
                onClick={() => {
                  toast.success('Appuntamento salvato!');
                  onClose();
                }}
                className="flex items-center gap-2 px-4 py-2 bg-warning text-white rounded-lg hover:bg-warning/90 transition-colors font-semibold"
              >
                <Save className="size-4" />
                Salva
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Servizi Modal */}
      {showServizi && (
        <ServiziSelectionModal 
          isOpen={showServizi}
          onClose={() => setShowServizi(false)}
        />
      )}
    </div>
  );
}

// =====================================
// SERVIZI SELECTION MODAL
// =====================================

interface ServiziSelectionModalProps {
  isOpen: boolean;
  onClose: () => void;
}

function ServiziSelectionModal({ isOpen, onClose }: ServiziSelectionModalProps) {
  const [tab, setTab] = useState<'elenco' | 'zona'>('elenco');
  const [searchQuery, setSearchQuery] = useState('');

  if (!isOpen) return null;

  const servizi = [
    { id: 1, nome: 'Radio', categoria: 'corpo', durata: 60, prezzo: 79.00, selected: true },
    { id: 2, nome: 'massaggio', categoria: 'massaggi', durata: 30, prezzo: 50.00, selected: false }
  ];

  return (
    <div className="fixed inset-0 z-[60] flex items-end sm:items-center justify-center">
      {/* Backdrop */}
      <div 
        className="absolute inset-0 bg-black/50 backdrop-blur-sm"
        onClick={onClose}
      />

      {/* Modal */}
      <div className="relative w-full max-w-2xl bg-card rounded-t-2xl sm:rounded-2xl shadow-2xl max-h-[80vh] overflow-hidden animate-in slide-in-from-bottom duration-300">
        {/* Header */}
        <div className="bg-card border-b border-border px-6 py-4 flex items-center justify-between">
          <div className="flex-1">
            <h2 className="text-xl font-bold">Seleziona servizi</h2>
            <p className="text-xs text-muted-foreground mt-0.5">Operatore: andrea danna</p>
          </div>
          <button 
            onClick={onClose}
            className="p-2 hover:bg-muted rounded-lg transition-colors"
          >
            <X className="size-5" />
          </button>
        </div>

        {/* Tabs */}
        <div className="flex border-b border-border px-6">
          <button
            onClick={() => setTab('elenco')}
            className={`px-4 py-3 font-medium border-b-2 transition-colors ${
              tab === 'elenco'
                ? 'border-warning text-warning'
                : 'border-transparent text-muted-foreground hover:text-foreground'
            }`}
          >
            Elenco servizi
          </button>
          <button
            onClick={() => setTab('zona')}
            className={`px-4 py-3 font-medium border-b-2 transition-colors ${
              tab === 'zona'
                ? 'border-warning text-warning'
                : 'border-transparent text-muted-foreground hover:text-foreground'
            }`}
          >
            Servizi a zona
          </button>
        </div>

        {/* Search */}
        <div className="px-6 py-4">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-muted-foreground" />
            <input
              type="text"
              placeholder="Cerca servizio"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-9 pr-4 py-2.5 bg-input-background border border-border rounded-lg focus:outline-none focus:ring-2 focus:ring-ring"
            />
          </div>
        </div>

        {/* Servizi List */}
        <div className="px-6 pb-6 space-y-3 overflow-y-auto max-h-[400px]">
          {/* Categoria Header */}
          <h3 className="text-sm font-semibold text-muted-foreground uppercase tracking-wide">corpo</h3>
          
          <button 
            onClick={() => toast.success('Radio selezionato')}
            className="w-full p-4 bg-warning/10 border border-warning rounded-lg hover:bg-warning/20 transition-colors"
          >
            <div className="flex items-center justify-between">
              <div className="flex-1 text-left">
                <p className="font-semibold mb-1">Radio</p>
                <p className="text-sm text-muted-foreground">Durata 60 min • €79.00</p>
              </div>
              <div className="w-5 h-5 rounded bg-warning flex items-center justify-center">
                <CheckCircle className="size-4 text-white" />
              </div>
            </div>
          </button>

          <h3 className="text-sm font-semibold text-muted-foreground uppercase tracking-wide pt-3">massaggi</h3>
          
          <button 
            onClick={() => toast.success('Massaggio selezionato')}
            className="w-full p-4 bg-muted/50 border border-border rounded-lg hover:bg-muted transition-colors"
          >
            <div className="flex items-center justify-between">
              <div className="flex-1 text-left">
                <p className="font-semibold mb-1">massaggio</p>
                <p className="text-sm text-muted-foreground">Durata 30 min • €50.00</p>
              </div>
              <div className="w-5 h-5 rounded border-2 border-border" />
            </div>
          </button>
        </div>

        {/* Footer */}
        <div className="sticky bottom-0 bg-card border-t border-border px-6 py-4 flex gap-3">
          <button 
            onClick={onClose}
            className="flex-1 px-6 py-2.5 border border-border rounded-lg hover:bg-muted transition-colors"
          >
            Annulla
          </button>
          <button 
            onClick={() => {
              toast.success('Servizi confermati');
              onClose();
            }}
            className="flex-1 px-6 py-2.5 bg-warning text-white rounded-lg hover:bg-warning/90 transition-colors font-semibold"
          >
            Conferma
          </button>
        </div>
      </div>
    </div>
  );
}
