import { useState } from 'react';
import {
  Building, Phone, Mail, FileText, Edit, Plus, UserCog, Users,
  Calendar, Clock, Package, CheckCircle, LayoutDashboard, TrendingUp,
  Filter, Euro, Send, Eye, ShoppingBag, Scissors, Box, TrendingDown, Percent
} from 'lucide-react';
import StatusBadge from '../StatusBadge';
import { toast } from 'sonner';

/**
 * Admin/Saloni/Module/Enhanced/Default
 * Modulo Saloni completo con gestione dettagliata per ogni salone:
 * - Header con informazioni di contatto
 * - Operatività e risorse (KPI, Stato operativo, Registrazione)
 * - Integrazione Stripe
 * - Integrazione WhatsApp Business
 */

interface SalonData {
  id: number;
  nome: string;
  indirizzo: string;
  telefono: string;
  email: string;
  piva: string;
  status: 'active' | 'inactive';
  // KPI
  staffAttivo: number;
  staffTotale: number;
  clientiAssociati: number;
  clientiNuoviMese: number;
  appuntamentiFuturi: number;
  appuntamentiOggi: number;
  // Stato operativo
  slotOrari: number;
  macchinari: number;
  cabineStanze: number;
  // Registrazione clienti
  modalitaAccesso: string;
  campiAggiuntivi: string;
  // Catalogo
  serviziAttivi: number;
  prodottiCatalogo: number;
  pacchettiAttivi: number;
  // Performance
  fatturatoMese: number;
  tassoOccupazione: number;
  mediaAppGiorno: number;
  // Orari
  giorniApertura: string;
  orarioApertura: string;
  orarioChiusura: string;
  // Stripe
  stripeConnesso: boolean;
  stripeAccountId?: string;
  stripeTransazioni?: boolean;
  stripeBonifici?: boolean;
  stripeDatiFiscali?: boolean;
  stripePagamentiOnline?: boolean;
  // WhatsApp
  whatsappConnesso: boolean;
  whatsappModalita?: string;
  whatsappAggiornamento?: string;
  whatsappNumero?: string;
  whatsappDataCollegamento?: string;
  whatsappPhoneId?: string;
  whatsappBusinessManagerId?: string;
  whatsappWabaId?: string;
  whatsappSecretToken?: string;
}

export default function SaloniModuleEnhanced() {
  const [selectedSalon, setSelectedSalon] = useState<number | null>(1);
  
  const saloniData: SalonData[] = [
    {
      id: 1,
      nome: 'Civi Salon',
      indirizzo: 'via napoli dietro civilandia, Civitità',
      telefono: '3218456684',
      email: 'civi0680@hotmail.it',
      piva: '04260030',
      status: 'active',
      // KPI
      staffAttivo: 4,
      staffTotale: 6,
      clientiAssociati: 16,
      clientiNuoviMese: 3,
      appuntamentiFuturi: 0,
      appuntamentiOggi: 2,
      // Stato operativo
      slotOrari: 7,
      macchinari: 3,
      cabineStanze: 0,
      // Registrazione clienti
      modalitaAccesso: 'Accesso immediato (senza approvazione)',
      campiAggiuntivi: 'Nessuno',
      // Catalogo
      serviziAttivi: 10,
      prodottiCatalogo: 5,
      pacchettiAttivi: 2,
      // Performance
      fatturatoMese: 1500,
      tassoOccupazione: 75,
      mediaAppGiorno: 3,
      // Orari
      giorniApertura: 'Lun-Ven',
      orarioApertura: '09:00',
      orarioChiusura: '18:00',
      // Stripe
      stripeConnesso: true,
      stripeAccountId: 'acct_1SHI2P86XBiQTGcF',
      stripeTransazioni: true,
      stripeBonifici: false,
      stripeDatiFiscali: true,
      stripePagamentiOnline: true,
      // WhatsApp
      whatsappConnesso: true,
      whatsappModalita: 'own',
      whatsappAggiornamento: '01 mar 2026 22:18',
      whatsappNumero: '15551589447',
      whatsappDataCollegamento: '27 feb 2026 23:26',
      whatsappPhoneId: '1050132798174192',
      whatsappBusinessManagerId: '• • • 6445',
      whatsappWabaId: '• • • 6447',
      whatsappSecretToken: '• • • oken'
    },
    {
      id: 2,
      nome: 'Elegance Salon Roma',
      indirizzo: 'Corso Vittorio 45, Roma',
      telefono: '+39 06 9876543',
      email: 'roma@elegance.it',
      piva: '08765432100',
      status: 'active',
      staffAttivo: 12,
      staffTotale: 15,
      clientiAssociati: 45,
      clientiNuoviMese: 5,
      appuntamentiFuturi: 8,
      appuntamentiOggi: 4,
      slotOrari: 10,
      macchinari: 5,
      cabineStanze: 3,
      modalitaAccesso: 'Con approvazione admin',
      campiAggiuntivi: 'Data di nascita, Allergie',
      serviziAttivi: 18,
      prodottiCatalogo: 12,
      pacchettiAttivi: 5,
      fatturatoMese: 4200,
      tassoOccupazione: 85,
      mediaAppGiorno: 6,
      giorniApertura: 'Lun-Sab',
      orarioApertura: '08:30',
      orarioChiusura: '19:00',
      stripeConnesso: false,
      whatsappConnesso: false
    },
    {
      id: 3,
      nome: 'Beauty Point Torino',
      indirizzo: 'Via Po 78, Torino',
      telefono: '+39 011 5555555',
      email: 'torino@beautypoint.it',
      piva: '01234567890',
      status: 'inactive',
      staffAttivo: 0,
      staffTotale: 3,
      clientiAssociati: 28,
      clientiNuoviMese: 0,
      appuntamentiFuturi: 0,
      appuntamentiOggi: 0,
      slotOrari: 8,
      macchinari: 2,
      cabineStanze: 1,
      modalitaAccesso: 'Accesso immediato',
      campiAggiuntivi: 'Nessuno',
      serviziAttivi: 8,
      prodottiCatalogo: 3,
      pacchettiAttivi: 1,
      fatturatoMese: 0,
      tassoOccupazione: 0,
      mediaAppGiorno: 0,
      giorniApertura: '-',
      orarioApertura: '-',
      orarioChiusura: '-',
      stripeConnesso: false,
      whatsappConnesso: false
    }
  ];

  const selectedSalonData = saloniData.find(s => s.id === selectedSalon);

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-3xl font-bold mb-2">Saloni</h2>
          <p className="text-muted-foreground">Gestione e configurazione saloni</p>
        </div>
        <button 
          onClick={() => toast.success('Funzionalità in arrivo')}
          className="flex items-center gap-2 px-6 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors shadow-sm"
        >
          <Plus className="size-5" />
          Aggiungi Salone
        </button>
      </div>

      {/* Salon Selector */}
      <div className="bg-card border border-border rounded-xl p-4">
        <div className="flex items-center gap-3 overflow-x-auto">
          {saloniData.map((salon) => (
            <button
              key={salon.id}
              onClick={() => setSelectedSalon(salon.id)}
              className={`flex items-center gap-3 px-4 py-2 rounded-lg transition-all whitespace-nowrap ${
                selectedSalon === salon.id
                  ? 'bg-primary text-primary-foreground shadow-sm'
                  : 'bg-muted hover:bg-muted/80'
              }`}
            >
              <Building className="size-4 flex-shrink-0" />
              <span className="text-sm font-medium">{salon.nome}</span>
            </button>
          ))}
        </div>
      </div>

      {selectedSalonData && (
        <>
          {/* Top Cards - Info Base, Stripe, WhatsApp */}
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
            {/* Card Salone - Info Base */}
            <div className="bg-card border border-border rounded-xl p-4">
              <div className="flex items-start justify-between mb-3">
                <div className="flex items-center gap-2">
                  <Building className="size-5 text-primary" />
                  <h3 className="font-semibold">Info Salone</h3>
                </div>
                <StatusBadge 
                  status={selectedSalonData.status === 'active' ? 'success' : 'cancelled'} 
                  label={selectedSalonData.status === 'active' ? 'Attivo' : 'Inattivo'} 
                />
              </div>

              <div className="space-y-2 text-sm">
                <div>
                  <p className="text-muted-foreground text-xs">Nome</p>
                  <p className="font-medium">{selectedSalonData.nome}</p>
                </div>
                <div>
                  <p className="text-muted-foreground text-xs">Indirizzo</p>
                  <p className="font-medium">{selectedSalonData.indirizzo}</p>
                </div>
                <div className="flex gap-3 pt-1">
                  <div className="flex items-center gap-1.5">
                    <Phone className="size-3 text-muted-foreground" />
                    <span className="text-xs">{selectedSalonData.telefono}</span>
                  </div>
                </div>
                <div className="flex items-center gap-1.5">
                  <FileText className="size-3 text-muted-foreground" />
                  <span className="text-xs">P.IVA: {selectedSalonData.piva}</span>
                </div>
              </div>

              <button 
                onClick={() => toast.info('Apertura form modifica')}
                className="w-full mt-3 flex items-center justify-center gap-2 px-3 py-2 border border-border rounded-lg hover:bg-muted transition-colors text-sm"
              >
                <Edit className="size-4" />
                Modifica
              </button>
            </div>

            {/* Card Stripe */}
            <div className="bg-card border border-border rounded-xl p-4">
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-2">
                  <Euro className="size-5 text-primary" />
                  <h3 className="font-semibold">Stripe</h3>
                </div>
                {selectedSalonData.stripeConnesso && (
                  <span className="px-2 py-0.5 bg-success/10 text-success rounded-full text-xs font-semibold">
                    Attivo
                  </span>
                )}
              </div>

              {selectedSalonData.stripeConnesso ? (
                <div className="space-y-3">
                  <div className="p-2 bg-muted/50 rounded text-xs">
                    <p className="text-muted-foreground mb-1">Account ID</p>
                    <code className="font-mono text-xs">{selectedSalonData.stripeAccountId}</code>
                  </div>

                  <div className="flex items-center justify-between text-sm">
                    <span className="text-muted-foreground text-xs">Pagamenti online</span>
                    <button 
                      onClick={() => toast.success('Toggle pagamenti')}
                      className={`relative w-9 h-5 rounded-full transition-colors ${
                        selectedSalonData.stripePagamentiOnline ? 'bg-success' : 'bg-muted-foreground/30'
                      }`}
                    >
                      <div className={`absolute top-0.5 w-4 h-4 bg-white rounded-full transition-transform ${
                        selectedSalonData.stripePagamentiOnline ? 'translate-x-4.5' : 'translate-x-0.5'
                      }`} />
                    </button>
                  </div>

                  <div className="flex flex-wrap gap-1.5">
                    {selectedSalonData.stripeTransazioni && (
                      <span className="px-2 py-0.5 bg-success/10 text-success rounded text-xs">✓ Transazioni</span>
                    )}
                    {selectedSalonData.stripeDatiFiscali && (
                      <span className="px-2 py-0.5 bg-success/10 text-success rounded text-xs">✓ Dati fiscali</span>
                    )}
                  </div>

                  <button 
                    onClick={() => toast.info('Apertura Stripe Dashboard')}
                    className="w-full flex items-center justify-center gap-2 px-3 py-2 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors text-xs"
                  >
                    <Send className="size-3" />
                    Dashboard
                  </button>
                </div>
              ) : (
                <div className="text-center py-6">
                  <p className="text-xs text-muted-foreground mb-3">Non configurato</p>
                  <button 
                    onClick={() => toast.info('Avvio configurazione Stripe')}
                    className="px-4 py-2 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors text-xs"
                  >
                    Configura
                  </button>
                </div>
              )}
            </div>

            {/* Card WhatsApp */}
            <div className="bg-card border border-border rounded-xl p-4">
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-2">
                  <Phone className="size-5 text-success" />
                  <h3 className="font-semibold">WhatsApp</h3>
                </div>
                {selectedSalonData.whatsappConnesso && (
                  <span className="px-2 py-0.5 bg-success/10 text-success rounded-full text-xs font-semibold">
                    Collegato
                  </span>
                )}
              </div>

              {selectedSalonData.whatsappConnesso ? (
                <div className="space-y-3">
                  <div className="space-y-2">
                    <div className="p-2 bg-muted/50 rounded">
                      <p className="text-muted-foreground text-xs mb-0.5">Numero</p>
                      <p className="text-xs font-semibold">{selectedSalonData.whatsappNumero}</p>
                    </div>
                    <div className="p-2 bg-muted/50 rounded">
                      <p className="text-muted-foreground text-xs mb-0.5">Modalità</p>
                      <p className="text-xs font-semibold">{selectedSalonData.whatsappModalita}</p>
                    </div>
                  </div>

                  <div className="flex items-center gap-1.5 px-2 py-1 bg-success/10 text-success rounded text-xs">
                    <CheckCircle className="size-3" />
                    <span>Sincronizzato</span>
                  </div>

                  <div className="text-xs text-muted-foreground">
                    Ultimo agg: {selectedSalonData.whatsappAggiornamento}
                  </div>

                  <button 
                    onClick={() => toast.info('Dettagli WhatsApp')}
                    className="w-full flex items-center justify-center gap-2 px-3 py-2 border border-border rounded-lg hover:bg-muted transition-colors text-xs"
                  >
                    <Eye className="size-3" />
                    Dettagli
                  </button>
                </div>
              ) : (
                <div className="text-center py-6">
                  <p className="text-xs text-muted-foreground mb-3">Non configurato</p>
                  <button 
                    onClick={() => toast.info('Avvio configurazione WhatsApp')}
                    className="px-4 py-2 bg-success text-white rounded-lg hover:bg-success/90 transition-colors text-xs"
                  >
                    Configura
                  </button>
                </div>
              )}
            </div>
          </div>

          {/* Operatività e risorse - Layout Compatto */}
          <div className="bg-card border border-border rounded-xl p-6">
            <div className="flex items-center justify-between mb-6">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 bg-primary/10 rounded-lg flex items-center justify-center">
                  <LayoutDashboard className="size-5 text-primary" />
                </div>
                <div>
                  <h3 className="text-lg font-semibold">Operatività e risorse</h3>
                  <p className="text-sm text-muted-foreground">KPI, stato e capacità operative</p>
                </div>
              </div>
            </div>

            {/* Grid Ottimizzata - 2 righe x 5 colonne su desktop */}
            <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-4">
              {/* KPI Cards con dettagli */}
              <div className="bg-gradient-to-br from-primary/5 to-primary/10 border border-primary/20 rounded-xl p-4">
                <div className="flex items-center gap-2 mb-2">
                  <UserCog className="size-4 text-primary" />
                  <span className="text-xs text-muted-foreground">Staff attivo</span>
                </div>
                <p className="text-2xl font-bold">{selectedSalonData.staffAttivo}</p>
                <p className="text-xs text-muted-foreground mt-1">su {selectedSalonData.staffTotale} totali</p>
              </div>

              <div className="bg-gradient-to-br from-primary/5 to-primary/10 border border-primary/20 rounded-xl p-4">
                <div className="flex items-center gap-2 mb-2">
                  <Users className="size-4 text-primary" />
                  <span className="text-xs text-muted-foreground">Clienti</span>
                </div>
                <p className="text-2xl font-bold">{selectedSalonData.clientiAssociati}</p>
                <p className="text-xs text-success mt-1">+{selectedSalonData.clientiNuoviMese} questo mese</p>
              </div>

              <div className="bg-gradient-to-br from-primary/5 to-primary/10 border border-primary/20 rounded-xl p-4">
                <div className="flex items-center gap-2 mb-2">
                  <Calendar className="size-4 text-primary" />
                  <span className="text-xs text-muted-foreground">Appuntamenti</span>
                </div>
                <p className="text-2xl font-bold">{selectedSalonData.appuntamentiFuturi}</p>
                <p className="text-xs text-muted-foreground mt-1">{selectedSalonData.appuntamentiOggi} oggi</p>
              </div>

              <div className="bg-muted/50 border border-border rounded-xl p-4">
                <div className="flex items-center gap-2 mb-2">
                  <Clock className="size-4 text-muted-foreground" />
                  <span className="text-xs text-muted-foreground">Slot orari</span>
                </div>
                <p className="text-2xl font-bold">{selectedSalonData.slotOrari}</p>
                <p className="text-xs text-muted-foreground mt-1">configurati</p>
              </div>

              <div className="bg-muted/50 border border-border rounded-xl p-4">
                <div className="flex items-center gap-2 mb-2">
                  <Package className="size-4 text-muted-foreground" />
                  <span className="text-xs text-muted-foreground">Macchinari</span>
                </div>
                <p className="text-2xl font-bold">{selectedSalonData.macchinari}</p>
                <p className="text-xs text-muted-foreground mt-1">attivi</p>
              </div>

              {/* Riga 2 - Nuove metriche */}
              <div className="bg-muted/50 border border-border rounded-xl p-4">
                <div className="flex items-center gap-2 mb-2">
                  <Scissors className="size-4 text-muted-foreground" />
                  <span className="text-xs text-muted-foreground">Servizi</span>
                </div>
                <p className="text-2xl font-bold">{selectedSalonData.serviziAttivi}</p>
                <p className="text-xs text-muted-foreground mt-1">disponibili</p>
              </div>

              <div className="bg-muted/50 border border-border rounded-xl p-4">
                <div className="flex items-center gap-2 mb-2">
                  <ShoppingBag className="size-4 text-muted-foreground" />
                  <span className="text-xs text-muted-foreground">Prodotti</span>
                </div>
                <p className="text-2xl font-bold">{selectedSalonData.prodottiCatalogo}</p>
                <p className="text-xs text-muted-foreground mt-1">in catalogo</p>
              </div>

              <div className="bg-muted/50 border border-border rounded-xl p-4">
                <div className="flex items-center gap-2 mb-2">
                  <Box className="size-4 text-muted-foreground" />
                  <span className="text-xs text-muted-foreground">Pacchetti</span>
                </div>
                <p className="text-2xl font-bold">{selectedSalonData.pacchettiAttivi}</p>
                <p className="text-xs text-muted-foreground mt-1">attivi</p>
              </div>

              <div className={`border rounded-xl p-4 ${
                selectedSalonData.tassoOccupazione >= 80 
                  ? 'bg-success/10 border-success/30' 
                  : selectedSalonData.tassoOccupazione >= 50 
                    ? 'bg-warning/10 border-warning/30'
                    : 'bg-muted/50 border-border'
              }`}>
                <div className="flex items-center gap-2 mb-2">
                  <Percent className="size-4 text-muted-foreground" />
                  <span className="text-xs text-muted-foreground">Occupazione</span>
                </div>
                <p className="text-2xl font-bold">{selectedSalonData.tassoOccupazione}%</p>
                <p className="text-xs text-muted-foreground mt-1">media {selectedSalonData.mediaAppGiorno} app/gg</p>
              </div>

              <div className="bg-gradient-to-br from-primary/5 to-primary/10 border border-primary/20 rounded-xl p-4">
                <div className="flex items-center gap-2 mb-2">
                  <Euro className="size-4 text-primary" />
                  <span className="text-xs text-muted-foreground">Fatturato</span>
                </div>
                <p className="text-2xl font-bold">€{selectedSalonData.fatturatoMese}</p>
                <p className="text-xs text-muted-foreground mt-1">questo mese</p>
              </div>

              {/* Riga 3 - Info contestuali */}
              <div className="lg:col-span-2 bg-muted/30 border border-border rounded-xl p-4">
                <div className="flex items-center gap-2 mb-3">
                  <Clock className="size-4 text-primary" />
                  <span className="text-xs font-semibold">Orari di Apertura</span>
                </div>
                <div className="space-y-2 text-xs">
                  <div>
                    <span className="text-muted-foreground">Giorni: </span>
                    <span className="font-medium">{selectedSalonData.giorniApertura}</span>
                  </div>
                  <div>
                    <span className="text-muted-foreground">Orario: </span>
                    <span className="font-medium">{selectedSalonData.orarioApertura} - {selectedSalonData.orarioChiusura}</span>
                  </div>
                </div>
              </div>

              <div className="lg:col-span-2 bg-muted/30 border border-border rounded-xl p-4">
                <div className="flex items-center gap-2 mb-3">
                  <Users className="size-4 text-primary" />
                  <span className="text-xs font-semibold">Registrazione Clienti</span>
                </div>
                <div className="space-y-2 text-xs">
                  <div>
                    <span className="text-muted-foreground">Accesso: </span>
                    <span className="font-medium">{selectedSalonData.modalitaAccesso}</span>
                  </div>
                  <div>
                    <span className="text-muted-foreground">Campi: </span>
                    <span className="font-medium">{selectedSalonData.campiAggiuntivi}</span>
                  </div>
                </div>
              </div>

              <div className={`rounded-xl p-4 ${
                selectedSalonData.status === 'active'
                  ? 'bg-success/5 border border-success/20'
                  : 'bg-muted/50 border border-border'
              }`}>
                <div className="flex items-center gap-2 mb-3">
                  <CheckCircle className={`size-4 ${selectedSalonData.status === 'active' ? 'text-success' : 'text-muted-foreground'}`} />
                  <span className="text-xs font-semibold">Stato</span>
                </div>
                <div className="flex items-center justify-between">
                  <StatusBadge 
                    status={selectedSalonData.status === 'active' ? 'success' : 'cancelled'} 
                    label={selectedSalonData.status === 'active' ? 'Attivo' : 'Inattivo'} 
                  />
                  <button className="p-1 hover:bg-muted rounded transition-colors">
                    <Edit className="size-3 text-muted-foreground" />
                  </button>
                </div>
              </div>
            </div>
          </div>
        </>
      )}
    </div>
  );
}