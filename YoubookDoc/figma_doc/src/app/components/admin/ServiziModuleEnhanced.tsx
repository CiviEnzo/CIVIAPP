import { useState } from 'react';
import {
  Plus, LayoutGrid, ChevronDown, ChevronUp, Clock, Euro,
  Edit, Trash2, Eye, EyeOff, Tag, Calendar, Users
} from 'lucide-react';
import { toast } from 'sonner';

/**
 * Admin/Servizi/Module/Enhanced/Default
 * Modulo Servizi & Pacchetti con:
 * - Tab Servizi: Categorie espandibili, filtri rapidi, Attivi/Disattivati
 * - Tab Pacchetti: Dashboard cliente/Archivio, card layout, filtri
 */

type TabType = 'servizi' | 'pacchetti';
type ServiziStatusTab = 'attivi' | 'disattivati';
type PacchettiStatusTab = 'dashboard' | 'archivio';

interface Servizio {
  id: number;
  nome: string;
  descrizione?: string;
  durata: number;
  prezzo: number;
  attivo: boolean;
}

interface Categoria {
  id: string;
  nome: string;
  servizi: Servizio[];
}

interface Pacchetto {
  id: number;
  nome: string;
  prezzoBase: number;
  prezzoScontato: number;
  visibileClienti: boolean;
  sessioni: number;
  abbonamento: boolean;
  soloPromozione: boolean;
  serviziInclusi: string[];
}

export default function ServiziModuleEnhanced() {
  const [activeTab, setActiveTab] = useState<TabType>('servizi');

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-3xl font-bold mb-2">Servizi & Pacchetti</h2>
          <p className="text-muted-foreground">Gestione catalogo servizi e pacchetti</p>
        </div>
      </div>

      {/* Tab Navigation */}
      <div className="bg-card border border-border rounded-xl p-1">
        <div className="flex items-center gap-1">
          <button
            onClick={() => setActiveTab('servizi')}
            className={`flex-1 px-4 py-2.5 rounded-lg transition-all ${
              activeTab === 'servizi'
                ? 'bg-primary text-primary-foreground shadow-sm'
                : 'hover:bg-muted'
            }`}
          >
            <span className="text-sm font-medium">Servizi</span>
          </button>
          <button
            onClick={() => setActiveTab('pacchetti')}
            className={`flex-1 px-4 py-2.5 rounded-lg transition-all ${
              activeTab === 'pacchetti'
                ? 'bg-primary text-primary-foreground shadow-sm'
                : 'hover:bg-muted'
            }`}
          >
            <span className="text-sm font-medium">Pacchetti</span>
          </button>
        </div>
      </div>

      {/* Tab Content */}
      {activeTab === 'servizi' ? <ServiziTab /> : <PacchettiTab />}
    </div>
  );
}

// =====================================
// SERVIZI TAB
// =====================================

function ServiziTab() {
  const [statusTab, setStatusTab] = useState<ServiziStatusTab>('attivi');
  const [selectedCategoria, setSelectedCategoria] = useState<string>('tutti');
  const [expandedCategories, setExpandedCategories] = useState<string[]>([]);

  const categorie: Categoria[] = [
    {
      id: 'viso',
      nome: 'viso',
      servizi: [
        { id: 1, nome: '18 Acidi', descrizione: '', durata: 60, prezzo: 80, attivo: true },
        { id: 2, nome: 'Pulizia viso', descrizione: '', durata: 60, prezzo: 80, attivo: true },
        { id: 3, nome: 'RF viso', descrizione: '', durata: 60, prezzo: 80, attivo: true },
        { id: 4, nome: 'Radiofrequenza', descrizione: '', durata: 45, prezzo: 65, attivo: true },
        { id: 5, nome: 'Trattamento idratante', descrizione: '', durata: 50, prezzo: 70, attivo: true }
      ]
    },
    {
      id: 'corpo-tech',
      nome: 'Corpo con tecnologia',
      servizi: [
        { id: 6, nome: 'Corpo 30 min', descrizione: '', durata: 30, prezzo: 50, attivo: true },
        { id: 7, nome: 'Corpo 60 min', descrizione: '', durata: 60, prezzo: 90, attivo: true },
        { id: 8, nome: 'Cellumodel', descrizione: '', durata: 45, prezzo: 75, attivo: true },
        { id: 9, nome: 'Cavitazione', descrizione: '', durata: 40, prezzo: 70, attivo: true },
        { id: 10, nome: 'Pressoterapia', descrizione: '', durata: 30, prezzo: 45, attivo: true }
      ]
    },
    {
      id: 'laser',
      nome: 'laser',
      servizi: Array.from({ length: 15 }, (_, i) => ({
        id: 11 + i,
        nome: `Laser ${i + 1}`,
        descrizione: '',
        durata: 30,
        prezzo: 60 + (i * 5),
        attivo: true
      }))
    },
    {
      id: 'corpo',
      nome: 'Corpo',
      servizi: [
        { id: 26, nome: 'Massaggio rilassante', descrizione: '', durata: 60, prezzo: 80, attivo: true },
        { id: 27, nome: 'Massaggio sportivo', descrizione: '', durata: 50, prezzo: 70, attivo: true },
        { id: 28, nome: 'Scrub corpo', descrizione: '', durata: 40, prezzo: 55, attivo: true }
      ]
    },
    {
      id: 'fit',
      nome: 'FIT',
      servizi: [
        { id: 29, nome: 'Personal training', descrizione: '', durata: 60, prezzo: 50, attivo: true },
        { id: 30, nome: 'Allenamento gruppo', descrizione: '', durata: 45, prezzo: 30, attivo: true }
      ]
    },
    {
      id: 'consulenza',
      nome: 'Consulenza',
      servizi: [
        { id: 31, nome: 'Consulenza nutrizionale', descrizione: '', durata: 45, prezzo: 60, attivo: true }
      ]
    },
    {
      id: 'laser2',
      nome: 'Laser 2',
      servizi: [
        { id: 32, nome: 'Laser avanzato A', descrizione: '', durata: 30, prezzo: 85, attivo: true },
        { id: 33, nome: 'Laser avanzato B', descrizione: '', durata: 40, prezzo: 95, attivo: true },
        { id: 34, nome: 'Laser avanzato C', descrizione: '', durata: 35, prezzo: 90, attivo: true }
      ]
    }
  ];

  const totalServiziAttivi = categorie.reduce((acc, cat) => acc + cat.servizi.filter(s => s.attivo).length, 0);
  const totalServiziDisattivati = categorie.reduce((acc, cat) => acc + cat.servizi.filter(s => !s.attivo).length, 0);

  const toggleCategory = (categoryId: string) => {
    if (expandedCategories.includes(categoryId)) {
      setExpandedCategories(expandedCategories.filter(id => id !== categoryId));
    } else {
      setExpandedCategories([...expandedCategories, categoryId]);
    }
  };

  const filteredCategorie = selectedCategoria === 'tutti' 
    ? categorie 
    : categorie.filter(cat => cat.id === selectedCategoria);

  const displayedCategorie = filteredCategorie.map(cat => ({
    ...cat,
    servizi: cat.servizi.filter(s => statusTab === 'attivi' ? s.attivo : !s.attivo)
  })).filter(cat => cat.servizi.length > 0);

  return (
    <div className="space-y-6">
      {/* Header Stats + Actions */}
      <div className="flex items-center justify-between">
        <p className="text-sm text-muted-foreground">{totalServiziAttivi} servizi attivi</p>
        <div className="flex gap-2">
          <button 
            onClick={() => toast.info('Gestione categorie')}
            className="flex items-center gap-2 px-4 py-2 border border-warning bg-warning/10 text-warning rounded-lg hover:bg-warning/20 transition-colors"
          >
            <LayoutGrid className="size-4" />
            Categorie
          </button>
          <button 
            onClick={() => toast.success('Crea nuovo servizio')}
            className="flex items-center gap-2 px-4 py-2 bg-warning text-white rounded-lg hover:bg-warning/90 transition-colors"
          >
            <Plus className="size-4" />
            Nuovo servizio
          </button>
        </div>
      </div>

      {/* Status Tabs */}
      <div className="flex border-b border-border">
        <button
          onClick={() => setStatusTab('attivi')}
          className={`px-6 py-3 font-medium border-b-2 transition-colors ${
            statusTab === 'attivi'
              ? 'border-primary text-primary'
              : 'border-transparent text-muted-foreground hover:text-foreground'
          }`}
        >
          Attivi ({totalServiziAttivi})
        </button>
        <button
          onClick={() => setStatusTab('disattivati')}
          className={`px-6 py-3 font-medium border-b-2 transition-colors ${
            statusTab === 'disattivati'
              ? 'border-primary text-primary'
              : 'border-transparent text-muted-foreground hover:text-foreground'
          }`}
        >
          Disattivati ({totalServiziDisattivati})
        </button>
      </div>

      {/* Categorie Filter Section */}
      <div className="bg-muted/30 border border-border rounded-xl p-4">
        <div className="flex items-center gap-2 mb-2">
          <LayoutGrid className="size-4" />
          <h3 className="font-semibold">Categorie</h3>
        </div>
        <p className="text-xs text-muted-foreground mb-3">
          Seleziona una categoria per filtrare rapidamente l'elenco.
        </p>
        <div className="flex flex-wrap gap-2">
          <button
            onClick={() => setSelectedCategoria('tutti')}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm transition-colors ${
              selectedCategoria === 'tutti'
                ? 'bg-foreground text-background'
                : 'bg-background hover:bg-muted'
            }`}
          >
            <LayoutGrid className="size-3" />
            Tutti i servizi ({totalServiziAttivi})
          </button>
          {categorie.map((cat) => {
            const count = cat.servizi.filter(s => statusTab === 'attivi' ? s.attivo : !s.attivo).length;
            if (count === 0) return null;
            return (
              <button
                key={cat.id}
                onClick={() => setSelectedCategoria(cat.id)}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm transition-colors ${
                  selectedCategoria === cat.id
                    ? 'bg-foreground text-background'
                    : 'bg-background hover:bg-muted'
                }`}
              >
                {cat.nome} ({count})
              </button>
            );
          })}
        </div>
      </div>

      {/* Categorie Accordion List */}
      <div className="space-y-3">
        {displayedCategorie.length === 0 ? (
          <div className="text-center py-12 border-2 border-dashed border-border rounded-lg">
            <LayoutGrid className="size-12 mx-auto text-muted-foreground mb-3" />
            <p className="text-muted-foreground">
              Nessun servizio {statusTab === 'attivi' ? 'attivo' : 'disattivato'} trovato
            </p>
          </div>
        ) : (
          displayedCategorie.map((categoria) => {
            const isExpanded = expandedCategories.includes(categoria.id);
            return (
              <div key={categoria.id} className="bg-card border border-border rounded-xl overflow-hidden">
                {/* Categoria Header */}
                <button
                  onClick={() => toggleCategory(categoria.id)}
                  className="w-full flex items-center justify-between p-4 hover:bg-muted/50 transition-colors"
                >
                  <div className="flex items-center gap-3">
                    <div className="text-left">
                      <h4 className="font-semibold">{categoria.nome}</h4>
                      <p className="text-sm text-muted-foreground">{categoria.servizi.length} servizi</p>
                    </div>
                  </div>
                  {isExpanded ? (
                    <ChevronUp className="size-5 text-muted-foreground" />
                  ) : (
                    <ChevronDown className="size-5 text-muted-foreground" />
                  )}
                </button>

                {/* Servizi List (Expanded) */}
                {isExpanded && (
                  <div className="border-t border-border bg-muted/20">
                    {categoria.servizi.map((servizio, index) => (
                      <div
                        key={servizio.id}
                        className={`flex items-center justify-between p-4 ${
                          index !== categoria.servizi.length - 1 ? 'border-b border-border' : ''
                        } hover:bg-muted/50 transition-colors`}
                      >
                        <div className="flex-1">
                          <h5 className="font-semibold mb-1">{servizio.nome}</h5>
                          {servizio.descrizione && (
                            <p className="text-sm text-muted-foreground mb-2">{servizio.descrizione}</p>
                          )}
                          {!servizio.descrizione && (
                            <p className="text-xs text-muted-foreground mb-2">Nessuna descrizione</p>
                          )}
                          <div className="flex flex-wrap gap-2">
                            <span className="flex items-center gap-1 px-2 py-1 bg-muted rounded text-xs">
                              <Clock className="size-3" />
                              {servizio.durata} min
                            </span>
                            <span className="flex items-center gap-1 px-2 py-1 bg-muted rounded text-xs font-semibold">
                              <Euro className="size-3" />
                              {servizio.prezzo.toFixed(2)}
                            </span>
                          </div>
                        </div>
                        <div className="flex gap-2 ml-4">
                          <button 
                            onClick={() => toast.info('Modifica ' + servizio.nome)}
                            className="p-2 hover:bg-background rounded-lg transition-colors"
                          >
                            <Edit className="size-4" />
                          </button>
                          <button 
                            onClick={() => toast.success('Servizio ' + (servizio.attivo ? 'disattivato' : 'attivato'))}
                            className="p-2 hover:bg-background rounded-lg transition-colors"
                          >
                            {servizio.attivo ? (
                              <EyeOff className="size-4" />
                            ) : (
                              <Eye className="size-4" />
                            )}
                          </button>
                          <button 
                            onClick={() => toast.error('Elimina ' + servizio.nome)}
                            className="p-2 hover:bg-error/10 rounded-lg transition-colors"
                          >
                            <Trash2 className="size-4 text-error" />
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            );
          })
        )}
      </div>
    </div>
  );
}

// =====================================
// PACCHETTI TAB
// =====================================

function PacchettiTab() {
  const [statusTab, setStatusTab] = useState<PacchettiStatusTab>('dashboard');
  const [soloPromozioni, setSoloPromozioni] = useState(false);

  const pacchetti: Pacchetto[] = [
    {
      id: 1,
      nome: 'pack viso 249',
      prezzoBase: 376,
      prezzoScontato: 296,
      visibileClienti: true,
      sessioni: 2,
      abbonamento: true,
      soloPromozione: true,
      serviziInclusi: ['RF viso', '18 Acidi']
    },
    {
      id: 2,
      nome: 'rf + cellumodel',
      prezzoBase: 395,
      prezzoScontato: 360,
      visibileClienti: true,
      sessioni: 2,
      abbonamento: true,
      soloPromozione: false,
      serviziInclusi: ['Corpo 30 min', 'Cellumodel']
    },
    {
      id: 3,
      nome: 'rf + massaggio',
      prezzoBase: 395,
      prezzoScontato: 296,
      visibileClienti: true,
      sessioni: 2,
      abbonamento: true,
      soloPromozione: true,
      serviziInclusi: ['Corpo 30 min', 'Massaggio']
    }
  ];

  const totalDashboard = pacchetti.filter(p => statusTab === 'dashboard').length;
  const totalArchivio = 0;

  const displayedPacchetti = pacchetti.filter(p => {
    if (soloPromozioni && !p.soloPromozione) return false;
    return true;
  });

  return (
    <div className="space-y-6">
      {/* Header Stats + Actions */}
      <div className="flex items-center justify-between">
        <p className="text-sm text-muted-foreground">{totalDashboard} pacchetti attivi</p>
        <button 
          onClick={() => toast.success('Crea nuovo pacchetto')}
          className="flex items-center gap-2 px-4 py-2 bg-warning text-white rounded-lg hover:bg-warning/90 transition-colors"
        >
          <Plus className="size-4" />
          Nuovo pacchetto
        </button>
      </div>

      {/* Status Tabs */}
      <div className="flex border-b border-border">
        <button
          onClick={() => setStatusTab('dashboard')}
          className={`px-6 py-3 font-medium border-b-2 transition-colors ${
            statusTab === 'dashboard'
              ? 'border-primary text-primary'
              : 'border-transparent text-muted-foreground hover:text-foreground'
          }`}
        >
          Dashboard cliente ({totalDashboard})
        </button>
        <button
          onClick={() => setStatusTab('archivio')}
          className={`px-6 py-3 font-medium border-b-2 transition-colors ${
            statusTab === 'archivio'
              ? 'border-primary text-primary'
              : 'border-transparent text-muted-foreground hover:text-foreground'
          }`}
        >
          Archivio ({totalArchivio})
        </button>
      </div>

      {/* Filtri Section */}
      <div className="bg-muted/30 border border-border rounded-xl p-4">
        <div className="flex items-center gap-2 mb-2">
          <Tag className="size-4" />
          <h3 className="font-semibold">Filtri pacchetti</h3>
        </div>
        <p className="text-xs text-muted-foreground mb-3">
          Affina l'elenco per salone e mostra solo le promozioni attive.
        </p>
        <button
          onClick={() => setSoloPromozioni(!soloPromozioni)}
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm transition-colors ${
            soloPromozioni
              ? 'bg-foreground text-background'
              : 'bg-background hover:bg-muted'
          }`}
        >
          <Tag className="size-3" />
          Solo promozioni
        </button>
      </div>

      {/* Pacchetti Grid */}
      {displayedPacchetti.length === 0 ? (
        <div className="text-center py-12 border-2 border-dashed border-border rounded-lg">
          <Tag className="size-12 mx-auto text-muted-foreground mb-3" />
          <p className="text-muted-foreground">Nessun pacchetto trovato</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {displayedPacchetti.map((pacchetto) => (
            <div key={pacchetto.id} className="bg-card border border-border rounded-xl p-4 hover:shadow-md transition-shadow">
              {/* Header */}
              <div className="flex items-start justify-between mb-3">
                <h4 className="font-semibold text-lg">{pacchetto.nome}</h4>
                <div className="flex gap-1">
                  <button 
                    onClick={() => toast.info('Anteprima ' + pacchetto.nome)}
                    className="p-1.5 hover:bg-muted rounded transition-colors"
                  >
                    <Eye className="size-4" />
                  </button>
                  <button 
                    onClick={() => toast.info('Modifica ' + pacchetto.nome)}
                    className="p-1.5 hover:bg-muted rounded transition-colors"
                  >
                    <Edit className="size-4" />
                  </button>
                  <button 
                    onClick={() => toast.error('Elimina ' + pacchetto.nome)}
                    className="p-1.5 hover:bg-error/10 rounded transition-colors"
                  >
                    <Trash2 className="size-4 text-error" />
                  </button>
                </div>
              </div>

              {/* Badges Row 1 */}
              <div className="flex flex-wrap gap-2 mb-3">
                <span className="px-2 py-1 bg-muted rounded text-xs font-semibold">
                  {pacchetto.prezzoBase.toFixed(2)}€
                </span>
                <span className="px-2 py-1 bg-warning/10 text-warning rounded text-xs font-semibold">
                  {pacchetto.prezzoScontato.toFixed(2)}€
                </span>
                {pacchetto.visibileClienti && (
                  <span className="px-2 py-1 bg-muted rounded text-xs flex items-center gap-1">
                    <Eye className="size-3" />
                    Visibile ai clienti
                  </span>
                )}
              </div>

              {/* Badges Row 2 */}
              <div className="flex flex-wrap gap-2 mb-3">
                <span className="px-2 py-1 bg-muted rounded text-xs">
                  {pacchetto.sessioni} sessioni
                </span>
                {pacchetto.abbonamento && (
                  <span className="px-2 py-1 bg-muted rounded text-xs flex items-center gap-1">
                    <Calendar className="size-3" />
                    Abbonamento
                  </span>
                )}
              </div>

              {/* Servizi Inclusi */}
              <div>
                <p className="text-xs text-muted-foreground mb-2">Servizi inclusi:</p>
                <div className="flex flex-wrap gap-2">
                  {pacchetto.serviziInclusi.map((servizio, idx) => (
                    <span key={idx} className="px-2 py-1 bg-muted rounded text-xs">
                      {servizio}
                    </span>
                  ))}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}