import { useState } from 'react';
import {
  Plus, Search, Filter, Download, Edit, Trash2, Eye, 
  Warehouse, ShoppingCart, MessageSquare, Phone, BarChart3,
  FileText, Send, CheckCircle, Users, UserCog, Euro, 
  TrendingUp, Mail
} from 'lucide-react';
import DataTable from '../../components/DataTable';
import StatusBadge from '../../components/StatusBadge';
import LoadingState from '../../components/LoadingState';
import { toast } from 'sonner';

// ===================================
// 8. MAGAZZINO MODULE
// ===================================
// Admin/Magazzino/Inventory/Responsive/Default
export function MagazzinoModule() {
  const [loading] = useState(false);

  const magazzinoData = [
    { id: 1, prodotto: 'Shampoo Professionale', categoria: 'Capelli', quantita: 24, minimo: 10, prezzo: 18.50, status: 'active' as const },
    { id: 2, prodotto: 'Balsamo Rigenerante', categoria: 'Capelli', quantita: 8, minimo: 10, prezzo: 22.00, status: 'warning' as const },
    { id: 3, prodotto: 'Crema Viso Idratante', categoria: 'Viso', quantita: 3, minimo: 5, prezzo: 35.00, status: 'warning' as const }
  ];

  const columns = [
    {
      key: 'prodotto',
      label: 'Prodotto',
      sortable: true,
      render: (item: typeof magazzinoData[0]) => (
        <div>
          <div className="font-semibold">{item.prodotto}</div>
          <div className="text-xs text-muted-foreground">{item.categoria}</div>
        </div>
      )
    },
    {
      key: 'quantita',
      label: 'Giacenza',
      sortable: true,
      render: (item: typeof magazzinoData[0]) => (
        <div>
          <span className={`font-medium ${item.quantita < item.minimo ? 'text-warning' : ''}`}>
            {item.quantita} unità
          </span>
          <div className="text-xs text-muted-foreground">Min: {item.minimo}</div>
        </div>
      )
    },
    {
      key: 'prezzo',
      label: 'Prezzo',
      render: (item: typeof magazzinoData[0]) => (
        <span className="font-semibold">€{item.prezzo.toFixed(2)}</span>
      )
    },
    {
      key: 'status',
      label: 'Stato',
      render: (item: typeof magazzinoData[0]) => {
        const label = item.quantita < item.minimo ? 'Scorta Bassa' : 'Disponibile';
        const status = item.quantita < item.minimo ? 'warning' as const : 'active' as const;
        return <StatusBadge status={status} label={label} />;
      }
    },
    {
      key: 'actions',
      label: 'Azioni',
      render: () => (
        <div className="flex gap-2">
          <button className="p-2 hover:bg-muted rounded-lg transition-colors">
            <Edit className="size-4" />
          </button>
          <button className="p-2 hover:bg-muted rounded-lg transition-colors">
            <Plus className="size-4" />
          </button>
        </div>
      )
    }
  ];

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto">
        <h2 className="text-3xl font-bold mb-6">Magazzino</h2>
        <LoadingState message="Caricamento inventario..." />
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-3xl font-bold mb-2">Magazzino</h2>
          <p className="text-muted-foreground">Gestione inventario e scorte</p>
        </div>
        <button className="flex items-center gap-2 px-6 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors shadow-sm">
          <Plus className="size-5" />
          Aggiungi Prodotto
        </button>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-4 gap-4">
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">Prodotti Totali</div>
          <div className="text-2xl font-bold">48</div>
        </div>
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">Valore Inventario</div>
          <div className="text-2xl font-bold">€3.240</div>
        </div>
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">Scorte Basse</div>
          <div className="text-2xl font-bold text-warning">5</div>
        </div>
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">Esauriti</div>
          <div className="text-2xl font-bold text-error">2</div>
        </div>
      </div>

      <div className="flex flex-col sm:flex-row gap-3">
        <div className="flex-1 relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 size-5 text-muted-foreground" />
          <input
            type="text"
            placeholder="Cerca prodotto..."
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
        data={magazzinoData}
        keyExtractor={(item) => item.id}
        emptyMessage="Nessun prodotto in magazzino"
      />
    </div>
  );
}

// ===================================
// 9. VENDITE & CASSA MODULE
// ===================================
// Admin/Vendite/List/Responsive/Default
export function VenditeModule() {
  const [loading] = useState(false);

  const venditeData = [
    {
      id: 1,
      numero: 'VEN-2026-001',
      cliente: 'Anna Ferrari',
      importo: 125,
      metodo: 'Carta',
      data: '2026-03-03 14:30',
      status: 'success' as const
    },
    {
      id: 2,
      numero: 'VEN-2026-002',
      cliente: 'Marco Romano',
      importo: 85,
      metodo: 'Contanti',
      data: '2026-03-03 11:15',
      status: 'success' as const
    },
    {
      id: 3,
      numero: 'VEN-2026-003',
      cliente: 'Giulia Conti',
      importo: 210,
      metodo: 'Bonifico',
      data: '2026-03-02 16:45',
      status: 'pending' as const
    }
  ];

  const columns = [
    {
      key: 'numero',
      label: 'Numero Vendita',
      render: (item: typeof venditeData[0]) => (
        <div>
          <div className="font-semibold">{item.numero}</div>
          <div className="text-xs text-muted-foreground">{item.data}</div>
        </div>
      )
    },
    {
      key: 'cliente',
      label: 'Cliente',
      render: (item: typeof venditeData[0]) => (
        <span className="text-sm">{item.cliente}</span>
      )
    },
    {
      key: 'importo',
      label: 'Importo',
      sortable: true,
      render: (item: typeof venditeData[0]) => (
        <span className="font-semibold text-primary">€{item.importo}</span>
      )
    },
    {
      key: 'metodo',
      label: 'Metodo',
      render: (item: typeof venditeData[0]) => (
        <span className="text-sm">{item.metodo}</span>
      )
    },
    {
      key: 'status',
      label: 'Stato',
      render: (item: typeof venditeData[0]) => {
        const labels = { success: 'Completata', pending: 'In Attesa' };
        return <StatusBadge status={item.status} label={labels[item.status]} />;
      }
    },
    {
      key: 'actions',
      label: 'Azioni',
      render: () => (
        <div className="flex gap-2">
          <button className="p-2 hover:bg-muted rounded-lg transition-colors">
            <Eye className="size-4" />
          </button>
          <button className="p-2 hover:bg-muted rounded-lg transition-colors">
            <FileText className="size-4" />
          </button>
        </div>
      )
    }
  ];

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto">
        <h2 className="text-3xl font-bold mb-6">Vendite & Cassa</h2>
        <LoadingState message="Caricamento vendite..." />
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-3xl font-bold mb-2">Vendite & Cassa</h2>
          <p className="text-muted-foreground">Registrazione vendite e gestione cassa</p>
        </div>
        <button className="flex items-center gap-2 px-6 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors shadow-sm">
          <Plus className="size-5" />
          Nuova Vendita
        </button>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-4 gap-4">
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">Vendite Oggi</div>
          <div className="text-2xl font-bold">12</div>
        </div>
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">Incasso Oggi</div>
          <div className="text-2xl font-bold text-success">€1.420</div>
        </div>
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">Incasso Mese</div>
          <div className="text-2xl font-bold text-primary">€12.340</div>
        </div>
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">In Attesa</div>
          <div className="text-2xl font-bold text-warning">€420</div>
        </div>
      </div>

      <DataTable
        columns={columns}
        data={venditeData}
        keyExtractor={(item) => item.id}
        onRowClick={(item) => toast.info(`Apri vendita ${item.numero}`)}
        emptyMessage="Nessuna vendita registrata"
      />
    </div>
  );
}

// ===================================
// 10. MESSAGGI & MARKETING MODULE
// ===================================
// Admin/Messaggi/Campaigns/Responsive/Default
export function MessaggiModule() {
  const [loading] = useState(false);

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto">
        <h2 className="text-3xl font-bold mb-6">Messaggi & Marketing</h2>
        <LoadingState message="Caricamento campagne..." />
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-3xl font-bold mb-2">Messaggi & Marketing</h2>
          <p className="text-muted-foreground">Comunicazioni e campagne promozionali</p>
        </div>
        <button className="flex items-center gap-2 px-6 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors shadow-sm">
          <Plus className="size-5" />
          Nuova Campagna
        </button>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-4 gap-4">
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">Campagne Attive</div>
          <div className="text-2xl font-bold">3</div>
        </div>
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">Messaggi Inviati</div>
          <div className="text-2xl font-bold">1.240</div>
        </div>
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">Tasso Apertura</div>
          <div className="text-2xl font-bold text-success">68%</div>
        </div>
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">Conversioni</div>
          <div className="text-2xl font-bold text-primary">124</div>
        </div>
      </div>

      <div className="grid md:grid-cols-2 gap-6">
        <div className="bg-card border border-border rounded-xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-semibold">Campagne Recenti</h3>
            <Send className="size-5 text-primary" />
          </div>
          <div className="space-y-3">
            {[
              { nome: 'Promo Marzo', destinatari: 342, inviati: 342, status: 'success' as const },
              { nome: 'Pacchetti Primavera', destinatari: 180, inviati: 120, status: 'pending' as const },
              { nome: 'Reminder Appuntamenti', destinatari: 24, inviati: 24, status: 'success' as const }
            ].map((camp, idx) => (
              <div key={idx} className="flex items-center justify-between p-3 border border-border rounded-lg">
                <div>
                  <div className="font-medium">{camp.nome}</div>
                  <div className="text-xs text-muted-foreground">{camp.inviati}/{camp.destinatari} inviati</div>
                </div>
                <StatusBadge 
                  status={camp.status} 
                  label={camp.status === 'success' ? 'Completata' : 'In Corso'} 
                  size="sm"
                />
              </div>
            ))}
          </div>
        </div>

        <div className="bg-card border border-border rounded-xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-semibold">Template Messaggi</h3>
            <FileText className="size-5 text-primary" />
          </div>
          <div className="space-y-3">
            {[
              'Conferma Appuntamento',
              'Promemoria 24h',
              'Promozione Mensile',
              'Compleanno Cliente',
              'Pacchetto in Scadenza'
            ].map((template, idx) => (
              <button key={idx} className="w-full text-left p-3 border border-border rounded-lg hover:bg-muted transition-colors">
                <div className="font-medium">{template}</div>
                <div className="text-xs text-muted-foreground mt-1">Template personalizzabile</div>
              </button>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

// ===================================
// 11. WHATSAPP MODULE
// ===================================
// Admin/WhatsApp/Integration/Responsive/Default
export function WhatsAppModule() {
  const [loading] = useState(false);

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto">
        <h2 className="text-3xl font-bold mb-6">WhatsApp Business</h2>
        <LoadingState message="Caricamento WhatsApp..." />
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      <div>
        <h2 className="text-3xl font-bold mb-2">WhatsApp Business</h2>
        <p className="text-muted-foreground">Integrazione WhatsApp Business API</p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-4 gap-4">
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">Messaggi Inviati</div>
          <div className="text-2xl font-bold">847</div>
        </div>
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">Risposte Ricevute</div>
          <div className="text-2xl font-bold">592</div>
        </div>
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">Tasso Risposta</div>
          <div className="text-2xl font-bold text-success">70%</div>
        </div>
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="text-muted-foreground text-sm mb-1">Template Attivi</div>
          <div className="text-2xl font-bold text-primary">8</div>
        </div>
      </div>

      <div className="grid md:grid-cols-2 gap-6">
        <div className="bg-card border border-border rounded-xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-semibold">Template WhatsApp</h3>
            <button className="px-4 py-2 text-sm bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors">
              Aggiungi Template
            </button>
          </div>
          <div className="space-y-3">
            {[
              { nome: 'appointment_confirmation', status: 'active' as const, utilizzi: 342 },
              { nome: 'appointment_reminder', status: 'active' as const, utilizzi: 298 },
              { nome: 'promotion_monthly', status: 'pending' as const, utilizzi: 0 }
            ].map((temp, idx) => (
              <div key={idx} className="p-4 border border-border rounded-lg">
                <div className="flex items-center justify-between mb-2">
                  <span className="font-medium">{temp.nome}</span>
                  <StatusBadge 
                    status={temp.status} 
                    label={temp.status === 'active' ? 'Approvato' : 'In Revisione'}
                    size="sm"
                  />
                </div>
                <div className="text-xs text-muted-foreground">
                  Utilizzi: {temp.utilizzi}
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-card border border-border rounded-xl p-6">
          <h3 className="text-lg font-semibold mb-4">Configurazione API</h3>
          <div className="space-y-4">
            <div className="flex items-center justify-between p-4 bg-success/10 border border-success/20 rounded-lg">
              <div className="flex items-center gap-3">
                <CheckCircle className="size-5 text-success" />
                <div>
                  <div className="font-medium">API Connessa</div>
                  <div className="text-xs text-muted-foreground">Business Account verificato</div>
                </div>
              </div>
            </div>

            <div className="space-y-2">
              <div className="flex justify-between text-sm">
                <span className="text-muted-foreground">Numero WhatsApp</span>
                <span className="font-medium">+39 02 1234567</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-muted-foreground">Business ID</span>
                <span className="font-mono text-xs">123456789012345</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-muted-foreground">Stato Verifica</span>
                <StatusBadge status="success" label="Verificato" size="sm" />
              </div>
            </div>

            <button className="w-full px-4 py-3 border border-border rounded-lg hover:bg-muted transition-colors">
              Modifica Configurazione
            </button>
          </div>
        </div>
      </div>

      <div className="bg-card border border-border rounded-xl p-6">
        <h3 className="text-lg font-semibold mb-4">Statistiche Invii</h3>
        <div className="text-center py-8">
          <BarChart3 className="size-16 text-muted-foreground mx-auto mb-4" />
          <p className="text-muted-foreground">
            Grafico statistiche messaggi WhatsApp per periodo
          </p>
        </div>
      </div>
    </div>
  );
}

// ===================================
// 12. REPORT MODULE
// ===================================
// Admin/Report/Analytics/Responsive/Default
export function ReportModule() {
  const [loading] = useState(false);

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto">
        <h2 className="text-3xl font-bold mb-6">Report</h2>
        <LoadingState message="Generazione report..." />
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-3xl font-bold mb-2">Report & Analytics</h2>
          <p className="text-muted-foreground">Statistiche e analisi dati</p>
        </div>
        <div className="flex gap-2">
          <button className="flex items-center gap-2 px-4 py-3 border border-border rounded-lg hover:bg-muted transition-colors">
            <Filter className="size-5" />
            Periodo
          </button>
          <button className="flex items-center gap-2 px-4 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors shadow-sm">
            <Download className="size-5" />
            Esporta PDF
          </button>
        </div>
      </div>

      {/* KPI Overview */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="flex items-center justify-between mb-2">
            <span className="text-muted-foreground text-sm">Fatturato Mese</span>
            <Euro className="size-5 text-primary" />
          </div>
          <div className="text-2xl font-bold mb-1">€12.340</div>
          <div className="text-xs text-success">+15% vs mese scorso</div>
        </div>
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="flex items-center justify-between mb-2">
            <span className="text-muted-foreground text-sm">Nuovi Clienti</span>
            <Users className="size-5 text-primary" />
          </div>
          <div className="text-2xl font-bold mb-1">18</div>
          <div className="text-xs text-success">+22% vs mese scorso</div>
        </div>
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="flex items-center justify-between mb-2">
            <span className="text-muted-foreground text-sm">Tasso Occupazione</span>
            <TrendingUp className="size-5 text-primary" />
          </div>
          <div className="text-2xl font-bold mb-1">82%</div>
          <div className="text-xs text-success">+5% vs mese scorso</div>
        </div>
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="flex items-center justify-between mb-2">
            <span className="text-muted-foreground text-sm">Ticket Medio</span>
            <ShoppingCart className="size-5 text-primary" />
          </div>
          <div className="text-2xl font-bold mb-1">€52</div>
          <div className="text-xs text-muted-foreground">Stabile</div>
        </div>
      </div>

      {/* Report Cards */}
      <div className="grid md:grid-cols-2 gap-6">
        <div className="bg-card border border-border rounded-xl p-6">
          <h3 className="text-lg font-semibold mb-4">Report Disponibili</h3>
          <div className="space-y-3">
            {[
              { nome: 'Vendite per Periodo', icon: ShoppingCart, descrizione: 'Analisi vendite mensile/annuale' },
              { nome: 'Performance Staff', icon: UserCog, descrizione: 'Produttività e statistiche team' },
              { nome: 'Analisi Clienti', icon: Users, descrizione: 'Segmentazione e comportamento' },
              { nome: 'Inventario', icon: Warehouse, descrizione: 'Movimenti magazzino' },
              { nome: 'Campagne Marketing', icon: MessageSquare, descrizione: 'ROI e conversioni' }
            ].map((report, idx) => (
              <button key={idx} className="w-full flex items-center justify-between p-4 border border-border rounded-lg hover:bg-muted transition-colors">
                <div className="flex items-center gap-3">
                  <report.icon className="size-5 text-primary" />
                  <div className="text-left">
                    <div className="font-medium">{report.nome}</div>
                    <div className="text-xs text-muted-foreground">{report.descrizione}</div>
                  </div>
                </div>
                <Download className="size-4 text-muted-foreground" />
              </button>
            ))}
          </div>
        </div>

        <div className="bg-card border border-border rounded-xl p-6">
          <h3 className="text-lg font-semibold mb-4">Grafici Analytics</h3>
          <div className="space-y-4">
            <div className="text-center py-12 bg-muted/30 rounded-lg">
              <BarChart3 className="size-16 text-muted-foreground mx-auto mb-4" />
              <p className="text-sm text-muted-foreground">
                Grafico trend fatturato ultimi 12 mesi
              </p>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <button className="p-3 border border-border rounded-lg hover:bg-muted transition-colors text-sm">
                Vendite
              </button>
              <button className="p-3 border border-border rounded-lg hover:bg-muted transition-colors text-sm">
                Appuntamenti
              </button>
              <button className="p-3 border border-border rounded-lg hover:bg-muted transition-colors text-sm">
                Clienti
              </button>
              <button className="p-3 border border-border rounded-lg hover:bg-muted transition-colors text-sm">
                Staff
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Export Options */}
      <div className="bg-card border border-border rounded-xl p-6">
        <h3 className="text-lg font-semibold mb-4">Esportazione Dati</h3>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <button className="flex items-center gap-3 p-4 border border-border rounded-lg hover:bg-muted transition-colors">
            <FileText className="size-5 text-primary" />
            <div className="text-left">
              <div className="font-medium">Esporta PDF</div>
              <div className="text-xs text-muted-foreground">Report completo</div>
            </div>
          </button>
          <button className="flex items-center gap-3 p-4 border border-border rounded-lg hover:bg-muted transition-colors">
            <Download className="size-5 text-primary" />
            <div className="text-left">
              <div className="font-medium">Esporta Excel</div>
              <div className="text-xs text-muted-foreground">Dati grezzi</div>
            </div>
          </button>
          <button className="flex items-center gap-3 p-4 border border-border rounded-lg hover:bg-muted transition-colors">
            <Mail className="size-5 text-primary" />
            <div className="text-left">
              <div className="font-medium">Invia via Email</div>
              <div className="text-xs text-muted-foreground">Report programmato</div>
            </div>
          </button>
        </div>
      </div>
    </div>
  );
}
