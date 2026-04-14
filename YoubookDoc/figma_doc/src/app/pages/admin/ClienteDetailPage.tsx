import { useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import {
  ArrowLeft, User, Calendar, Package, FileText, Receipt, Image,
  Phone, Mail, MapPin, Edit2, Trash2, Plus, Download, 
  MessageSquare, CheckCircle, Clock, Euro, Star, StickyNote,
  Camera, Send, FileDown, X, ChevronDown, AlertCircle,
  Eye, XCircle, Coins
} from 'lucide-react';
import { toast } from 'sonner';

/**
 * Admin/Cliente/Detail/Responsive/Enhanced
 * Scheda cliente completa con 7 tab: Scheda, Questionario, Archivio foto, 
 * Appuntamenti, Pacchetti, Preventivi, Fatturazione
 */

type TabType = 'scheda' | 'questionario' | 'archivio' | 'appuntamenti' | 'pacchetti' | 'preventivi' | 'fatturazione';

export default function ClienteDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState<TabType>('scheda');

  // Mock cliente data
  const cliente = {
    id: id || '1',
    nome: 'alessandra rizzo',
    telefono: '3921729384',
    email: '',
    indirizzo: '',
    citta: '',
    dataNascita: '',
    eta: '',
    numeroCliente: '193',
    professione: '',
    puntiFedelta: 29,
    comeConosciuto: '',
    note: 'Importi massivi clienti',
    noteInterne: [{
      id: 1,
      testo: 'App ANNULLATO, mandare mess appena arriva il PC per fissare app prossima settimana',
      autore: 'Federica Barbara',
      data: '28/02/2026 09:04'
    }]
  };

  const tabs = [
    { id: 'scheda' as TabType, label: 'Scheda', icon: User },
    { id: 'questionario' as TabType, label: 'Questionario', icon: FileText },
    { id: 'archivio' as TabType, label: 'Archivio foto', icon: Image },
    { id: 'appuntamenti' as TabType, label: 'Appuntamenti', icon: Calendar },
    { id: 'pacchetti' as TabType, label: 'Pacchetti', icon: Package },
    { id: 'preventivi' as TabType, label: 'Preventivi', icon: FileText },
    { id: 'fatturazione' as TabType, label: 'Fatturazione', icon: Receipt }
  ];

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="bg-card border-b border-border sticky top-0 z-40">
        <div className="max-w-7xl mx-auto px-4 lg:px-6 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <button
                onClick={() => navigate('/admin')}
                className="p-2 hover:bg-muted rounded-lg transition-colors"
              >
                <ArrowLeft className="size-5" />
              </button>
              <div>
                <h1 className="text-2xl font-bold capitalize">{cliente.nome}</h1>
                <p className="text-sm text-muted-foreground">Cliente #{cliente.numeroCliente}</p>
              </div>
            </div>
            <div className="flex gap-2">
              <button className="flex items-center gap-2 px-4 py-2 border border-border rounded-lg hover:bg-muted transition-colors">
                <MessageSquare className="size-4" />
                <span className="hidden sm:inline">Messaggio</span>
              </button>
              <button className="flex items-center gap-2 px-4 py-2 bg-warning text-white rounded-lg hover:bg-warning/90 transition-colors">
                <Edit2 className="size-4" />
                <span className="hidden sm:inline">Modifica</span>
              </button>
            </div>
          </div>

          {/* Tabs */}
          <div className="flex gap-1 mt-4 overflow-x-auto no-scrollbar">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={`flex items-center gap-2 px-4 py-2 rounded-lg whitespace-nowrap transition-colors ${
                  activeTab === tab.id
                    ? 'bg-warning text-white'
                    : 'text-muted-foreground hover:bg-muted'
                }`}
              >
                <tab.icon className="size-4" />
                <span className="text-sm font-medium">{tab.label}</span>
              </button>
            ))}
          </div>
        </div>
      </header>

      {/* Content */}
      <main className="max-w-7xl mx-auto px-4 lg:px-6 py-6">
        {activeTab === 'scheda' && <SchedaTab cliente={cliente} />}
        {activeTab === 'questionario' && <QuestionarioTab />}
        {activeTab === 'archivio' && <ArchivioFotoTab />}
        {activeTab === 'appuntamenti' && <AppuntamentiTab />}
        {activeTab === 'pacchetti' && <PacchettiTab />}
        {activeTab === 'preventivi' && <PreventiviTab />}
        {activeTab === 'fatturazione' && <FatturazioneTab />}
      </main>
    </div>
  );
}

// =====================================
// SCHEDA TAB
// =====================================

interface SchedaTabProps {
  cliente: any;
}

function SchedaTab({ cliente }: SchedaTabProps) {
  const [note, setNote] = useState(cliente.noteInterne);

  return (
    <div className="space-y-6">
      {/* Grid principale */}
      <div className="grid lg:grid-cols-2 gap-6">
        {/* Dati anagrafici */}
        <div className="bg-card border border-border rounded-xl p-6">
          <h3 className="text-lg font-semibold mb-4">Dati anagrafici</h3>
          <div className="grid sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs text-warning mb-1.5">Nome e cognome</label>
              <input
                type="text"
                value={cliente.nome}
                disabled
                className="w-full px-3 py-2 bg-input-background border border-border rounded-lg text-sm"
              />
            </div>
            <div>
              <label className="block text-xs text-warning mb-1.5">Sesso</label>
              <input
                type="text"
                value="—"
                disabled
                className="w-full px-3 py-2 bg-input-background border border-border rounded-lg text-sm"
              />
            </div>
            <div>
              <label className="block text-xs text-warning mb-1.5">Data di nascita</label>
              <input
                type="text"
                value="—"
                disabled
                className="w-full px-3 py-2 bg-input-background border border-border rounded-lg text-sm"
              />
            </div>
            <div>
              <label className="block text-xs text-warning mb-1.5">Età</label>
              <input
                type="text"
                value="—"
                disabled
                className="w-full px-3 py-2 bg-input-background border border-border rounded-lg text-sm"
              />
            </div>
            <div>
              <label className="block text-xs text-warning mb-1.5">Numero cliente</label>
              <input
                type="text"
                value={cliente.numeroCliente}
                disabled
                className="w-full px-3 py-2 bg-input-background border border-border rounded-lg text-sm font-semibold"
              />
            </div>
            <div>
              <label className="block text-xs text-warning mb-1.5">Professione</label>
              <input
                type="text"
                value="—"
                disabled
                className="w-full px-3 py-2 bg-input-background border border-border rounded-lg text-sm"
              />
            </div>
            <div className="sm:col-span-2">
              <label className="block text-xs text-warning mb-1.5">Come ci ha conosciuto</label>
              <input
                type="text"
                value="—"
                disabled
                className="w-full px-3 py-2 bg-input-background border border-border rounded-lg text-sm"
              />
            </div>
            <div className="sm:col-span-2">
              <label className="block text-xs text-warning mb-1.5">Punti fedeltà</label>
              <input
                type="text"
                value={cliente.puntiFedelta}
                disabled
                className="w-full px-3 py-2 bg-input-background border border-border rounded-lg text-sm font-semibold"
              />
            </div>
          </div>
        </div>

        {/* Contatti e preferenze */}
        <div className="bg-card border border-border rounded-xl p-6">
          <h3 className="text-lg font-semibold mb-4">Contatti e preferenze</h3>
          <div className="space-y-4">
            <div className="grid sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs text-warning mb-1.5">Telefono</label>
                <input
                  type="text"
                  value={cliente.telefono}
                  disabled
                  className="w-full px-3 py-2 bg-input-background border border-border rounded-lg text-sm"
                />
              </div>
              <div>
                <label className="block text-xs text-warning mb-1.5">Email</label>
                <input
                  type="text"
                  value="—"
                  disabled
                  className="w-full px-3 py-2 bg-input-background border border-border rounded-lg text-sm"
                />
              </div>
              <div>
                <label className="block text-xs text-warning mb-1.5">Indirizzo</label>
                <input
                  type="text"
                  value="—"
                  disabled
                  className="w-full px-3 py-2 bg-input-background border border-border rounded-lg text-sm"
                />
              </div>
              <div>
                <label className="block text-xs text-warning mb-1.5">Città</label>
                <input
                  type="text"
                  value="—"
                  disabled
                  className="w-full px-3 py-2 bg-input-background border border-border rounded-lg text-sm"
                />
              </div>
            </div>

            {/* Preferenze contatto */}
            <div>
              <label className="block text-sm font-semibold mb-2">Preferenze contatto</label>
              <div className="flex flex-wrap gap-2">
                <button className="px-4 py-2 bg-foreground text-background rounded-lg font-medium text-sm">
                  Telefono
                </button>
                <button className="px-4 py-2 bg-foreground text-background rounded-lg font-medium text-sm">
                  Email
                </button>
                <button className="flex items-center gap-2 px-4 py-2 border border-border rounded-lg text-sm">
                  <MessageSquare className="size-4" />
                  WhatsApp
                </button>
                <button className="flex items-center gap-2 px-4 py-2 border border-border rounded-lg text-sm">
                  <Mail className="size-4" />
                  SMS
                </button>
              </div>
              <p className="text-xs text-muted-foreground mt-2">Preferenze non ancora registrate.</p>
            </div>

            {/* Note cliente */}
            <div>
              <label className="block text-sm font-semibold mb-2">Note cliente</label>
              <p className="text-sm text-muted-foreground">{cliente.note}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Lista note */}
      <div className="bg-card border border-border rounded-xl p-6">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h3 className="text-lg font-semibold">Lista note</h3>
            <p className="text-sm text-muted-foreground">{note.length} note interne</p>
          </div>
          <button className="flex items-center gap-2 px-4 py-2 bg-warning text-white rounded-lg hover:bg-warning/90 transition-colors">
            <Plus className="size-4" />
            Aggiungi
          </button>
        </div>

        <div className="space-y-3">
          {note.map((nota: any) => (
            <div key={nota.id} className="p-4 bg-muted/50 border border-border rounded-lg">
              <p className="text-sm mb-2">{nota.testo}</p>
              <div className="flex items-center justify-between">
                <p className="text-xs text-muted-foreground">
                  Creata da {nota.autore} • {nota.data}
                </p>
                <div className="flex gap-2">
                  <button className="p-1.5 hover:bg-background rounded transition-colors">
                    <Edit2 className="size-3.5" />
                  </button>
                  <button className="p-1.5 hover:bg-background rounded transition-colors text-error">
                    <Trash2 className="size-3.5" />
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

// =====================================
// QUESTIONARIO TAB
// =====================================

function QuestionarioTab() {
  const [tab, setTab] = useState<'elenco' | 'disponibili' | 'assegnati'>('assegnati');
  const [selectedQuestionario, setSelectedQuestionario] = useState<number | null>(1);

  const questionari = [
    {
      id: 1,
      nome: 'anamnesi',
      predefinito: true,
      stato: 'In modifica',
      sezioni: [
        { id: 1, nome: 'stile di vita', completato: true, domande: 8, risposte: 8 },
        { id: 2, nome: 'Storia clinica', completato: false, domande: 12, risposte: 3 },
        { id: 3, nome: 'Allergie', completato: false, domande: 5, risposte: 0 }
      ],
      dataAssegnazione: '28/02/2026',
      dataCompilazione: null,
      progresso: 35
    },
    {
      id: 2,
      nome: 'Trattamento laser',
      predefinito: false,
      stato: 'Completato',
      sezioni: [
        { id: 1, nome: 'Tipo di pelle', completato: true, domande: 6, risposte: 6 },
        { id: 2, nome: 'Esposizione solare', completato: true, domande: 4, risposte: 4 }
      ],
      dataAssegnazione: '15/01/2026',
      dataCompilazione: '20/01/2026',
      progresso: 100
    },
    {
      id: 3,
      nome: 'Consenso informato',
      predefinito: false,
      stato: 'Non assegnato',
      sezioni: [],
      dataAssegnazione: null,
      dataCompilazione: null,
      progresso: 0
    }
  ];

  const questionariDisponibili = [
    { id: 4, nome: 'Massaggio terapeutico', sezioni: 3 },
    { id: 5, nome: 'Trattamento viso', sezioni: 4 },
    { id: 6, nome: 'Radiofrequenza', sezioni: 5 }
  ];

  const selectedQ = questionari.find(q => q.id === selectedQuestionario);

  return (
    <div className="space-y-6">
      {/* Header con azioni */}
      <div className="bg-card border border-border rounded-xl p-6">
        <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4 mb-6">
          <div>
            <h3 className="text-lg font-semibold mb-1">Gestione questionari</h3>
            <p className="text-sm text-muted-foreground">
              Assegna e monitora i questionari compilati dal cliente
            </p>
          </div>
          <div className="flex gap-2">
            <button className="flex items-center gap-2 px-4 py-2 border border-border rounded-lg hover:bg-muted transition-colors text-sm">
              <Download className="size-4" />
              Esporta risposte
            </button>
            <button className="flex items-center gap-2 px-4 py-2 bg-warning text-white rounded-lg hover:bg-warning/90 transition-colors text-sm">
              <Plus className="size-4" />
              Assegna nuovo
            </button>
          </div>
        </div>

        {/* Tabs orizzontali */}
        <div className="flex gap-2 border-b border-border">
          <button
            onClick={() => setTab('assegnati')}
            className={`px-4 py-2.5 font-medium border-b-2 transition-colors ${
              tab === 'assegnati'
                ? 'border-warning text-warning'
                : 'border-transparent text-muted-foreground hover:text-foreground'
            }`}
          >
            Assegnati (2)
          </button>
          <button
            onClick={() => setTab('disponibili')}
            className={`px-4 py-2.5 font-medium border-b-2 transition-colors ${
              tab === 'disponibili'
                ? 'border-warning text-warning'
                : 'border-transparent text-muted-foreground hover:text-foreground'
            }`}
          >
            Disponibili (3)
          </button>
          <button
            onClick={() => setTab('elenco')}
            className={`px-4 py-2.5 font-medium border-b-2 transition-colors ${
              tab === 'elenco'
                ? 'border-warning text-warning'
                : 'border-transparent text-muted-foreground hover:text-foreground'
            }`}
          >
            Tutti
          </button>
        </div>
      </div>

      {/* Layout 2 colonne: Lista + Dettaglio */}
      {tab === 'assegnati' && (
        <div className="grid lg:grid-cols-3 gap-6">
          {/* Lista questionari (1/3) */}
          <div className="space-y-3">
            {questionari.filter(q => q.dataAssegnazione).map((q) => (
              <button
                key={q.id}
                onClick={() => setSelectedQuestionario(q.id)}
                className={`w-full text-left p-4 rounded-xl border transition-all ${
                  selectedQuestionario === q.id
                    ? 'border-warning bg-warning/5 shadow-sm'
                    : 'border-border hover:border-warning/50 hover:bg-muted/50'
                }`}
              >
                <div className="flex items-start justify-between mb-3">
                  <div className="flex-1">
                    <h4 className="font-semibold mb-1">{q.nome}</h4>
                    <div className="flex flex-wrap gap-1.5">
                      {q.predefinito && (
                        <span className="text-xs px-2 py-0.5 bg-success/10 text-success rounded">
                          Predefinito
                        </span>
                      )}
                      <span className={`text-xs px-2 py-0.5 rounded ${
                        q.progresso === 100 
                          ? 'bg-success/10 text-success'
                          : q.progresso > 0
                          ? 'bg-warning/10 text-warning'
                          : 'bg-muted text-muted-foreground'
                      }`}>
                        {q.stato}
                      </span>
                    </div>
                  </div>
                  {selectedQuestionario === q.id && (
                    <div className="w-2 h-2 rounded-full bg-warning ml-2 mt-1 flex-shrink-0" />
                  )}
                </div>

                {/* Progress bar */}
                <div className="mb-2">
                  <div className="flex items-center justify-between text-xs text-muted-foreground mb-1">
                    <span>Progresso</span>
                    <span className="font-semibold">{q.progresso}%</span>
                  </div>
                  <div className="w-full h-1.5 bg-muted rounded-full overflow-hidden">
                    <div 
                      className={`h-full transition-all ${
                        q.progresso === 100 ? 'bg-success' : 'bg-warning'
                      }`}
                      style={{ width: `${q.progresso}%` }}
                    />
                  </div>
                </div>

                <div className="flex items-center justify-between text-xs text-muted-foreground">
                  <span>Assegnato: {q.dataAssegnazione}</span>
                  {q.dataCompilazione && (
                    <CheckCircle className="size-3.5 text-success" />
                  )}
                </div>
              </button>
            ))}
          </div>

          {/* Dettaglio questionario (2/3) */}
          {selectedQ && (
            <div className="lg:col-span-2 space-y-4">
              {/* Header dettaglio */}
              <div className="bg-card border border-border rounded-xl p-6">
                <div className="flex items-start justify-between mb-4">
                  <div>
                    <h3 className="text-xl font-bold mb-2">{selectedQ.nome}</h3>
                    <div className="flex gap-2">
                      {selectedQ.predefinito && (
                        <span className="text-xs px-2 py-1 bg-success/10 text-success rounded">
                          Predefinito
                        </span>
                      )}
                      <span className={`text-xs px-2 py-1 rounded ${
                        selectedQ.progresso === 100 
                          ? 'bg-success/10 text-success'
                          : selectedQ.progresso > 0
                          ? 'bg-warning/10 text-warning'
                          : 'bg-muted text-muted-foreground'
                      }`}>
                        {selectedQ.stato}
                      </span>
                    </div>
                  </div>
                  <div className="flex gap-2">
                    <button className="p-2 hover:bg-muted rounded-lg transition-colors">
                      <Edit2 className="size-4" />
                    </button>
                    <button className="p-2 hover:bg-muted rounded-lg transition-colors">
                      <Send className="size-4" />
                    </button>
                    <button className="p-2 hover:bg-muted rounded-lg transition-colors text-error">
                      <Trash2 className="size-4" />
                    </button>
                  </div>
                </div>

                {/* Stats grid */}
                <div className="grid grid-cols-3 gap-4">
                  <div className="text-center p-3 bg-muted/50 rounded-lg">
                    <p className="text-2xl font-bold">{selectedQ.sezioni.length}</p>
                    <p className="text-xs text-muted-foreground">Sezioni</p>
                  </div>
                  <div className="text-center p-3 bg-muted/50 rounded-lg">
                    <p className="text-2xl font-bold">
                      {selectedQ.sezioni.reduce((acc, s) => acc + s.domande, 0)}
                    </p>
                    <p className="text-xs text-muted-foreground">Domande</p>
                  </div>
                  <div className="text-center p-3 bg-muted/50 rounded-lg">
                    <p className="text-2xl font-bold text-warning">
                      {selectedQ.sezioni.reduce((acc, s) => acc + s.risposte, 0)}
                    </p>
                    <p className="text-xs text-muted-foreground">Risposte</p>
                  </div>
                </div>
              </div>

              {/* Sezioni */}
              <div className="space-y-3">
                <h4 className="font-semibold">Sezioni questionario</h4>
                {selectedQ.sezioni.map((sezione, idx) => (
                  <div
                    key={sezione.id}
                    className="bg-card border border-border rounded-xl overflow-hidden"
                  >
                    <button 
                      onClick={() => toast.info(`Apri sezione: ${sezione.nome}`)}
                      className="w-full p-4 hover:bg-muted/50 transition-colors"
                    >
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-3">
                          <div className={`w-8 h-8 rounded-full flex items-center justify-center font-semibold ${
                            sezione.completato 
                              ? 'bg-success/10 text-success'
                              : sezione.risposte > 0
                              ? 'bg-warning/10 text-warning'
                              : 'bg-muted text-muted-foreground'
                          }`}>
                            {sezione.completato ? (
                              <CheckCircle className="size-5" />
                            ) : (
                              <span>{idx + 1}</span>
                            )}
                          </div>
                          <div className="text-left">
                            <p className="font-semibold capitalize">{sezione.nome}</p>
                            <p className="text-sm text-muted-foreground">
                              {sezione.risposte} / {sezione.domande} risposte completate
                            </p>
                          </div>
                        </div>
                        <div className="flex items-center gap-3">
                          {/* Progress bar inline */}
                          <div className="w-24 h-2 bg-muted rounded-full overflow-hidden hidden sm:block">
                            <div 
                              className={`h-full ${
                                sezione.completato ? 'bg-success' : 'bg-warning'
                              }`}
                              style={{ width: `${(sezione.risposte / sezione.domande) * 100}%` }}
                            />
                          </div>
                          <ChevronDown className="size-5 text-muted-foreground" />
                        </div>
                      </div>
                    </button>
                  </div>
                ))}

                {selectedQ.sezioni.length === 0 && (
                  <div className="text-center py-8 text-muted-foreground">
                    <FileText className="size-12 mx-auto mb-2 opacity-50" />
                    <p className="text-sm">Nessuna sezione disponibile</p>
                  </div>
                )}
              </div>

              {/* Actions footer */}
              <div className="flex gap-2">
                <button className="flex-1 px-4 py-3 border border-warning text-warning rounded-lg hover:bg-warning/10 transition-colors font-medium">
                  Apri questionario
                </button>
                <button 
                  onClick={() => toast.success('Link di compilazione inviato via app')}
                  className="flex-1 px-4 py-3 bg-warning text-white rounded-lg hover:bg-warning/90 transition-colors font-medium"
                >
                  Invia in app
                </button>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Tab Disponibili */}
      {tab === 'disponibili' && (
        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {questionariDisponibili.map((q) => (
            <div
              key={q.id}
              className="bg-card border border-border rounded-xl p-5 hover:border-warning/50 hover:shadow-sm transition-all"
            >
              <div className="flex items-start justify-between mb-3">
                <div>
                  <h4 className="font-semibold mb-1">{q.nome}</h4>
                  <p className="text-sm text-muted-foreground">{q.sezioni} sezioni</p>
                </div>
                <Plus className="size-5 text-muted-foreground" />
              </div>
              <button 
                onClick={() => toast.success(`Questionario "${q.nome}" assegnato`)}
                className="w-full px-4 py-2 bg-warning text-white rounded-lg hover:bg-warning/90 transition-colors text-sm font-medium"
              >
                Assegna
              </button>
            </div>
          ))}
        </div>
      )}

      {/* Tab Tutti */}
      {tab === 'elenco' && (
        <div className="bg-card border border-border rounded-xl overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-muted/50 border-b border-border">
                <tr>
                  <th className="text-left px-4 py-3 text-sm font-semibold">Questionario</th>
                  <th className="text-left px-4 py-3 text-sm font-semibold">Stato</th>
                  <th className="text-left px-4 py-3 text-sm font-semibold">Progresso</th>
                  <th className="text-left px-4 py-3 text-sm font-semibold">Assegnato</th>
                  <th className="text-left px-4 py-3 text-sm font-semibold">Completato</th>
                  <th className="text-right px-4 py-3 text-sm font-semibold">Azioni</th>
                </tr>
              </thead>
              <tbody>
                {questionari.map((q) => (
                  <tr key={q.id} className="border-b border-border hover:bg-muted/30 transition-colors">
                    <td className="px-4 py-4">
                      <div className="font-semibold">{q.nome}</div>
                      {q.predefinito && (
                        <span className="text-xs px-2 py-0.5 bg-success/10 text-success rounded inline-block mt-1">
                          Predefinito
                        </span>
                      )}
                    </td>
                    <td className="px-4 py-4">
                      <span className={`text-xs px-2 py-1 rounded ${
                        q.progresso === 100 
                          ? 'bg-success/10 text-success'
                          : q.progresso > 0
                          ? 'bg-warning/10 text-warning'
                          : 'bg-muted text-muted-foreground'
                      }`}>
                        {q.stato}
                      </span>
                    </td>
                    <td className="px-4 py-4">
                      <div className="flex items-center gap-2">
                        <div className="w-20 h-2 bg-muted rounded-full overflow-hidden">
                          <div 
                            className={`h-full ${q.progresso === 100 ? 'bg-success' : 'bg-warning'}`}
                            style={{ width: `${q.progresso}%` }}
                          />
                        </div>
                        <span className="text-sm font-medium">{q.progresso}%</span>
                      </div>
                    </td>
                    <td className="px-4 py-4 text-sm text-muted-foreground">
                      {q.dataAssegnazione || '—'}
                    </td>
                    <td className="px-4 py-4 text-sm text-muted-foreground">
                      {q.dataCompilazione || '—'}
                    </td>
                    <td className="px-4 py-4">
                      <div className="flex gap-1 justify-end">
                        <button className="p-2 hover:bg-muted rounded-lg transition-colors">
                          <Eye className="size-4" />
                        </button>
                        <button className="p-2 hover:bg-muted rounded-lg transition-colors">
                          <Edit2 className="size-4" />
                        </button>
                        <button className="p-2 hover:bg-muted rounded-lg transition-colors text-error">
                          <Trash2 className="size-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}

// =====================================
// ARCHIVIO FOTO TAB
// =====================================

function ArchivioFotoTab() {
  const fotoAngoli = ['Frontale', 'Dietro', 'Destra', 'Sinistra'];

  return (
    <div className="space-y-6">
      <div className="bg-card border border-border rounded-xl p-6">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h3 className="text-lg font-semibold">Archivio fotografico</h3>
            <p className="text-sm text-muted-foreground">Nessuna foto</p>
          </div>
          <button className="flex items-center gap-2 px-4 py-2 bg-warning text-white rounded-lg hover:bg-warning/90 transition-colors">
            <Camera className="size-4" />
            Crea collage
          </button>
        </div>

        {/* Foto grid */}
        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          {fotoAngoli.map((angolo) => (
            <div key={angolo}>
              <label className="block text-sm font-medium mb-2">{angolo}</label>
              <div className="aspect-[3/4] bg-muted border-2 border-dashed border-border rounded-xl flex flex-col items-center justify-center hover:bg-muted/70 cursor-pointer transition-colors">
                <Camera className="size-8 text-muted-foreground mb-2" />
                <p className="text-xs text-muted-foreground">Nessuna foto caricata</p>
              </div>
              <div className="flex gap-2 mt-2">
                <button className="flex-1 p-2 border border-border rounded-lg hover:bg-muted transition-colors">
                  <Download className="size-4 mx-auto text-muted-foreground" />
                </button>
                <button className="flex-1 p-2 border border-border rounded-lg hover:bg-muted transition-colors">
                  <MessageSquare className="size-4 mx-auto text-muted-foreground" />
                </button>
              </div>
            </div>
          ))}
        </div>

        <button className="w-full px-4 py-3 border border-warning text-warning rounded-lg hover:bg-warning/10 transition-colors font-medium">
          Carica set completo
        </button>
      </div>
    </div>
  );
}

// =====================================
// APPUNTAMENTI TAB
// =====================================

function AppuntamentiTab() {
  const appuntamenti = [
    {
      id: 1,
      servizio: 'zona piccola',
      data: '02/04/2026 09:30',
      operatore: 'Federica Barbara',
      prezzo: 20.00,
      stato: 'Programmato'
    },
    {
      id: 2,
      servizio: '3 zone + zona piccola',
      data: '04/05/2026 09:00',
      operatore: 'Federica Barbara',
      prezzo: 97.00,
      stato: 'Programmato'
    }
  ];

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h3 className="text-lg font-semibold">Appuntamenti futuri</h3>
        <button className="flex items-center gap-2 px-4 py-2 bg-warning text-white rounded-lg hover:bg-warning/90 transition-colors">
          <Plus className="size-4" />
          Nuovo appuntamento
        </button>
      </div>

      <div className="space-y-3">
        {appuntamenti.map((app) => (
          <div key={app.id} className="bg-card border border-border rounded-xl p-5">
            <div className="flex items-start justify-between mb-3">
              <div>
                <h4 className="font-semibold mb-1">{app.servizio}</h4>
                <p className="text-sm text-muted-foreground mb-1">{app.data}</p>
                <p className="text-sm text-muted-foreground">Operatore: {app.operatore}</p>
              </div>
              <div className="text-right">
                <p className="text-lg font-bold">{app.prezzo.toFixed(2)} €</p>
              </div>
            </div>

            <div className="flex items-center justify-between">
              <span className="px-3 py-1 bg-warning/10 text-warning rounded-lg text-sm font-medium">
                {app.stato}
              </span>
              <div className="flex gap-2">
                <button className="p-2 hover:bg-muted rounded-lg transition-colors">
                  <Edit2 className="size-4" />
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
  );
}

// =====================================
// PACCHETTI TAB
// =====================================

function PacchettiTab() {
  // Mock data - 3 pacchetti con diversi stati
  const pacchetti = [
    {
      id: 1,
      nome: 'Radiofrequenza e Massaggio',
      stato: 'attivo',
      saldato: true,
      prezzo: 199.00,
      dataAcquisto: '10/11/2025',
      dataScadenza: '08/02/2026',
      servizi: [
        { nome: 'Massaggio', totale: 4, usate: 0, rimanenti: 4 },
        { nome: 'RF corpo 30 min', totale: 4, usate: 0, rimanenti: 4 }
      ],
      acconti: [
        { importo: 199.00, data: '10/11/2025 14:02', metodo: 'POS' }
      ]
    },
    {
      id: 2,
      nome: 'Pacchetto Bellezza Premium',
      stato: 'attivo',
      saldato: false,
      prezzo: 450.00,
      dataAcquisto: '15/01/2026',
      dataScadenza: '15/06/2026',
      servizi: [
        { nome: 'Taglio + Piega', totale: 10, usate: 3, rimanenti: 7 },
        { nome: 'Colore', totale: 5, usate: 1, rimanenti: 4 },
        { nome: 'Trattamento Viso', totale: 5, usate: 2, rimanenti: 3 }
      ],
      acconti: [
        { importo: 200.00, data: '15/01/2026 10:30', metodo: 'Contanti' },
        { importo: 100.00, data: '20/02/2026 15:45', metodo: 'Bonifico' }
      ]
    },
    {
      id: 3,
      nome: 'Pacchetto Spa Relax',
      stato: 'in_scadenza',
      saldato: true,
      prezzo: 320.00,
      dataAcquisto: '05/12/2025',
      dataScadenza: '20/03/2026',
      servizi: [
        { nome: 'Massaggio Rilassante 60min', totale: 6, usate: 5, rimanenti: 1 },
        { nome: 'Sauna + Bagno turco', totale: 6, usate: 4, rimanenti: 2 },
        { nome: 'Scrub corpo', totale: 3, usate: 3, rimanenti: 0 }
      ],
      acconti: [
        { importo: 320.00, data: '05/12/2025 11:20', metodo: 'POS' }
      ]
    }
  ];

  return (
    <div className="space-y-6">
      {/* Header con statistiche */}
      <div className="grid sm:grid-cols-3 gap-4">
        <div className="bg-card border border-border rounded-xl p-5">
          <div className="flex items-center gap-3 mb-2">
            <div className="w-10 h-10 rounded-lg bg-success/10 flex items-center justify-center">
              <Package className="size-5 text-success" />
            </div>
            <div>
              <p className="text-2xl font-bold">{pacchetti.filter(p => p.stato === 'attivo').length}</p>
              <p className="text-sm text-muted-foreground">Pacchetti attivi</p>
            </div>
          </div>
        </div>
        
        <div className="bg-card border border-border rounded-xl p-5">
          <div className="flex items-center gap-3 mb-2">
            <div className="w-10 h-10 rounded-lg bg-warning/10 flex items-center justify-center">
              <AlertCircle className="size-5 text-warning" />
            </div>
            <div>
              <p className="text-2xl font-bold">
                {pacchetti.reduce((acc, p) => acc + p.servizi.filter(s => s.rimanenti > 0).length, 0)}
              </p>
              <p className="text-sm text-muted-foreground">Servizi disponibili</p>
            </div>
          </div>
        </div>
        
        <div className="bg-card border border-border rounded-xl p-5">
          <div className="flex items-center gap-3 mb-2">
            <div className="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center">
              <Coins className="size-5 text-primary" />
            </div>
            <div>
              <p className="text-2xl font-bold">
                € {pacchetti.reduce((acc, p) => acc + p.prezzo, 0).toFixed(2)}
              </p>
              <p className="text-sm text-muted-foreground">Valore totale</p>
            </div>
          </div>
        </div>
      </div>

      {/* Lista Pacchetti - LAYOUT ORIZZONTALE A 2 COLONNE */}
      <div className="grid lg:grid-cols-2 gap-6">
        {pacchetti.map((pacchetto) => (
          <div key={pacchetto.id} className="bg-card border-2 border-border rounded-xl p-6 shadow-sm">
          {/* Header Pacchetto */}
          <div className="flex items-start justify-between mb-4">
            <div className="flex-1">
              <h4 className="text-lg font-bold mb-2">{pacchetto.nome}</h4>
              <div className="flex items-center gap-2 flex-wrap">
                {/* Badge Stato */}
                {pacchetto.stato === 'attivo' && (
                  <span className="inline-flex items-center gap-1 px-2 py-0.5 bg-success/10 text-success rounded-lg text-xs font-semibold">
                    <CheckCircle className="size-3" />
                    Attivo
                  </span>
                )}
                {pacchetto.stato === 'in_scadenza' && (
                  <span className="inline-flex items-center gap-1 px-2 py-0.5 bg-warning/10 text-warning rounded-lg text-xs font-semibold">
                    <AlertCircle className="size-3" />
                    In scadenza
                  </span>
                )}
                
                {/* Badge Pagamento */}
                {pacchetto.saldato ? (
                  <span className="inline-flex items-center gap-1 px-2 py-0.5 bg-success/10 text-success rounded-lg text-xs font-semibold">
                    <CheckCircle className="size-3" />
                    Saldato
                  </span>
                ) : (
                  <span className="inline-flex items-center gap-1 px-2 py-0.5 bg-error/10 text-error rounded-lg text-xs font-semibold">
                    <XCircle className="size-3" />
                    Non saldato
                  </span>
                )}
              </div>
            </div>
            
            {/* Actions */}
            <div className="flex gap-1.5">
              <button 
                className="p-2 hover:bg-muted rounded-lg transition-colors border border-border"
                title="Modifica"
              >
                <Edit2 className="size-3.5" />
              </button>
              <button 
                className="p-2 hover:bg-error/10 rounded-lg transition-colors border border-border"
                title="Elimina"
              >
                <Trash2 className="size-3.5 text-error" />
              </button>
            </div>
          </div>

          {/* Info Grid - 3 colonne compatte */}
          <div className="grid grid-cols-3 gap-3 mb-4 p-3 bg-muted/30 rounded-xl">
            <div>
              <p className="text-[10px] text-muted-foreground mb-0.5">Prezzo</p>
              <p className="text-lg font-bold text-primary">€ {pacchetto.prezzo.toFixed(2)}</p>
            </div>
            <div>
              <p className="text-[10px] text-muted-foreground mb-0.5">Acquisto</p>
              <p className="text-xs font-semibold">{pacchetto.dataAcquisto}</p>
            </div>
            <div>
              <p className="text-[10px] text-muted-foreground mb-0.5">Scadenza</p>
              <p className={`text-xs font-semibold ${
                pacchetto.stato === 'in_scadenza' ? 'text-warning' : ''
              }`}>
                {pacchetto.dataScadenza}
              </p>
            </div>
          </div>

          {/* Servizi e Pagamenti AFFIANCATI */}
          <div className="grid md:grid-cols-2 gap-4">
            {/* Servizi Section - Sinistra */}
            <div>
              <div className="flex items-center justify-between mb-2">
                <h5 className="text-sm font-bold flex items-center gap-1.5">
                  <Package className="size-3.5 text-muted-foreground" />
                  Servizi
                </h5>
                <span className="text-[10px] text-muted-foreground">
                  {pacchetto.servizi.reduce((acc, s) => acc + s.rimanenti, 0)} disp.
                </span>
              </div>
              <div className="space-y-2">
                {pacchetto.servizi.map((servizio, idx) => {
                  const percentualeUsata = (servizio.usate / servizio.totale) * 100;
                  const isEsaurito = servizio.rimanenti === 0;
                  
                  return (
                    <div 
                      key={idx} 
                      className={`p-2.5 rounded-lg border transition-all ${
                        isEsaurito 
                          ? 'bg-muted/50 border-border opacity-60' 
                          : 'bg-background border-border hover:border-primary/30'
                      }`}
                    >
                      <div className="flex items-center justify-between mb-1.5">
                        <p className="font-semibold text-xs truncate flex-1">{servizio.nome}</p>
                        <span className={`text-[10px] font-bold px-1.5 py-0.5 rounded ${
                          isEsaurito 
                            ? 'bg-error/10 text-error' 
                            : servizio.rimanenti <= 2 
                            ? 'bg-warning/10 text-warning'
                            : 'bg-success/10 text-success'
                        }`}>
                          {servizio.rimanenti}
                        </span>
                      </div>
                      
                      {/* Progress Bar */}
                      <div className="mb-1">
                        <div className="h-1.5 bg-muted rounded-full overflow-hidden">
                          <div 
                            className={`h-full transition-all ${
                              isEsaurito 
                                ? 'bg-error' 
                                : percentualeUsata >= 70 
                                ? 'bg-warning' 
                                : 'bg-success'
                            }`}
                            style={{ width: `${percentualeUsata}%` }}
                          />
                        </div>
                      </div>
                      
                      <p className="text-[10px] text-muted-foreground">
                        {servizio.usate}/{servizio.totale}
                        {isEsaurito && <span className="ml-1 text-error font-semibold">• ESAURITO</span>}
                      </p>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Pagamenti Section - Destra */}
            <div>
              <div className="flex items-center justify-between mb-2">
                <h5 className="text-sm font-bold flex items-center gap-1.5">
                  <Coins className="size-3.5 text-muted-foreground" />
                  Pagamenti
                </h5>
                <span className="text-[10px] text-muted-foreground">
                  {pacchetto.acconti.length}
                </span>
              </div>
              <div className="space-y-2">
                {pacchetto.acconti.map((acconto, idx) => (
                  <div 
                    key={idx}
                    className="flex items-center justify-between p-2.5 bg-muted/30 rounded-lg border border-border"
                  >
                    <div className="flex items-center gap-2 flex-1 min-w-0">
                      <div className="w-7 h-7 rounded-lg bg-success/10 flex items-center justify-center flex-shrink-0">
                        <CheckCircle className="size-3.5 text-success" />
                      </div>
                      <div className="min-w-0 flex-1">
                        <p className="text-sm font-bold">€ {acconto.importo.toFixed(2)}</p>
                        <p className="text-[10px] text-muted-foreground truncate">
                          {acconto.data.split(' ')[0]} • {acconto.metodo}
                        </p>
                      </div>
                    </div>
                    <button 
                      className="p-1 hover:bg-background rounded transition-colors flex-shrink-0"
                      title="Dettagli"
                    >
                      <ChevronDown className="size-3.5" />
                    </button>
                  </div>
                ))}
                
                {/* Totale Pagato - Compatto */}
                <div className="p-2.5 bg-primary/5 rounded-lg border border-primary/20">
                  <div className="flex items-center justify-between">
                    <span className="text-[10px] font-semibold text-muted-foreground">Totale:</span>
                    <span className="text-base font-bold text-primary">
                      € {pacchetto.acconti.reduce((acc, a) => acc + a.importo, 0).toFixed(2)}
                    </span>
                  </div>
                  {!pacchetto.saldato && (
                    <p className="text-[10px] text-error font-semibold mt-1">
                      Residuo: € {(pacchetto.prezzo - pacchetto.acconti.reduce((acc, a) => acc + a.importo, 0)).toFixed(2)}
                    </p>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
        ))}
      </div>

      {/* Pulsante Nuovo Pacchetto */}
      <div className="flex justify-center pt-4">
        <button className="flex items-center gap-2 px-6 py-3 bg-warning text-white rounded-xl hover:bg-warning/90 transition-colors shadow-md font-semibold">
          <Plus className="size-5" />
          Aggiungi nuovo pacchetto
        </button>
      </div>
    </div>
  );
}

// =====================================
// PREVENTIVI TAB
// =====================================

function PreventiviTab() {
  return (
    <div className="space-y-6">
      <div className="flex justify-end">
        <button className="flex items-center gap-2 px-4 py-2 bg-warning text-white rounded-lg hover:bg-warning/90 transition-colors">
          <Plus className="size-4" />
          Nuovo preventivo
        </button>
      </div>

      <div className="bg-card border border-border rounded-xl p-6">
        <div className="mb-4">
          <p className="text-sm text-muted-foreground mb-1">Bozza</p>
          <p className="font-medium mb-2">1 × rf + massaggio — 199,00 €</p>
          <p className="text-lg font-bold">Totale: 199,00 €</p>
        </div>

        <div className="flex flex-wrap gap-2">
          <button className="flex items-center gap-2 px-4 py-2 border border-warning text-warning rounded-lg hover:bg-warning/10 transition-colors text-sm">
            <Edit2 className="size-4" />
            Modifica
          </button>
          <button className="flex items-center gap-2 px-4 py-2 border border-warning text-warning rounded-lg hover:bg-warning/10 transition-colors text-sm">
            <StickyNote className="size-4" />
            Segna inviato
          </button>
          <button className="flex items-center gap-2 px-4 py-2 bg-warning text-white rounded-lg hover:bg-warning/90 transition-colors text-sm">
            <FileDown className="size-4" />
            Invia PDF
          </button>
          <button className="flex items-center gap-2 px-4 py-2 border border-success text-success rounded-lg hover:bg-success/10 transition-colors text-sm">
            <CheckCircle className="size-4" />
            Accetta
          </button>
          <button className="flex items-center gap-2 px-4 py-2 border border-border rounded-lg hover:bg-muted transition-colors text-sm">
            <X className="size-4" />
            Rifiuta
          </button>
          <button className="flex items-center gap-2 px-4 py-2 border border-error text-error rounded-lg hover:bg-error/10 transition-colors text-sm">
            <Trash2 className="size-4" />
            Elimina
          </button>
        </div>
      </div>
    </div>
  );
}

// =====================================
// FATTURAZIONE TAB
// =====================================

function FatturazioneTab() {
  const pagamenti = [
    {
      id: 1,
      descrizione: 'Vendita del 10/11/2025 14:02',
      metodo: 'POS',
      stato: 'Saldato',
      articoli: 1,
      totale: 199.00
    }
  ];

  return (
    <div className="space-y-6">
      <div className="flex justify-end">
        <button className="flex items-center gap-2 px-4 py-2 bg-warning text-white rounded-lg hover:bg-warning/90 transition-colors">
          <Receipt className="size-4" />
          Registra vendita
        </button>
      </div>

      {/* Riepilogo incassi */}
      <div className="bg-card border border-border rounded-xl p-6">
        <h3 className="text-lg font-semibold mb-4">Riepilogo incassi</h3>
        <div className="grid sm:grid-cols-2 gap-6">
          <div>
            <p className="text-sm text-muted-foreground mb-1">Incassato</p>
            <p className="text-3xl font-bold">199,00 €</p>
          </div>
          <div>
            <p className="text-sm text-muted-foreground mb-1">Da incassare</p>
            <p className="text-3xl font-bold">0,00 €</p>
          </div>
          <div>
            <p className="text-sm text-muted-foreground mb-1">Punti utilizzati</p>
            <p className="text-2xl font-bold">0 punti</p>
          </div>
          <div>
            <p className="text-sm text-muted-foreground mb-1">Saldo utilizzabile</p>
            <p className="text-2xl font-bold">20 punti</p>
          </div>
        </div>
      </div>

      {/* Pagamenti in sospeso */}
      <div className="bg-card border border-border rounded-xl p-6">
        <div className="flex items-center gap-2 mb-4">
          <AlertCircle className="size-5" />
          <h3 className="text-lg font-semibold">Nessun pagamento in sospeso</h3>
        </div>
      </div>

      {/* Storico pagamenti */}
      <div className="bg-card border border-border rounded-xl p-6">
        <h3 className="text-lg font-semibold mb-4">Storico pagamenti</h3>
        <div className="space-y-3">
          {pagamenti.map((pag) => (
            <div key={pag.id} className="border border-border rounded-xl p-4">
              <div className="flex items-center justify-between mb-2">
                <div>
                  <h4 className="font-semibold mb-1">{pag.descrizione}</h4>
                  <div className="flex items-center gap-3 text-sm text-muted-foreground">
                    <span>Metodo: {pag.metodo}</span>
                    <span>Stato: {pag.stato}</span>
                    <span>Articoli: {pag.articoli}</span>
                  </div>
                </div>
                <div className="text-right">
                  <p className="text-xl font-bold">{pag.totale.toFixed(2)} €</p>
                  <button className="p-2 hover:bg-muted rounded-lg transition-colors mt-1">
                    <ChevronDown className="size-5" />
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}