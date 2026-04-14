import { 
  AlertCircle, XCircle, Clock, Calendar, CreditCard, Package,
  Users, Wifi, WifiOff, AlertTriangle, CheckCircle, Ban,
  RefreshCw, Phone, MessageSquare, TrendingDown, Lock
} from 'lucide-react';
import StatusBadge from '../components/StatusBadge';
import ErrorState from '../components/ErrorState';
import EmptyState from '../components/EmptyState';
import { toast } from 'sonner';

/**
 * 40_Cross_Module_States
 * 
 * Questa pagina contiene tutti gli stati edge case e cross-module
 * che possono verificarsi in YouBook. Organizzati per categoria.
 * 
 * Naming: Shared/States/[Category]/[Type]/[State]
 */

// ===================================
// 1. AGENDA CONFLICTS
// ===================================

// Shared/States/Agenda/Conflict/DoubleBooking
export function AgendaDoubleBookingState() {
  return (
    <div className="max-w-2xl mx-auto p-6">
      <div className="bg-error/10 border border-error/30 rounded-xl p-6">
        <div className="flex items-start gap-4 mb-4">
          <div className="w-12 h-12 bg-error/20 rounded-full flex items-center justify-center flex-shrink-0">
            <AlertTriangle className="size-6 text-error" />
          </div>
          <div className="flex-1">
            <h3 className="font-semibold text-lg mb-2 text-error">Conflitto Rilevato</h3>
            <p className="text-sm text-muted-foreground mb-4">
              Questo slot orario è già occupato. Seleziona un orario diverso o uno staff alternativo.
            </p>
            
            {/* Conflicting Appointments */}
            <div className="space-y-2 mb-4">
              <div className="bg-card border border-border rounded-lg p-3">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="font-medium text-sm">Appuntamento Esistente</p>
                    <p className="text-xs text-muted-foreground">15:00 - 16:30 • Francesca</p>
                  </div>
                  <StatusBadge status="success" label="Confermato" size="sm" />
                </div>
              </div>
              <div className="bg-warning/10 border border-warning/30 rounded-lg p-3">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="font-medium text-sm">Tentativo Prenotazione</p>
                    <p className="text-xs text-muted-foreground">15:30 - 17:00 • Francesca</p>
                  </div>
                  <StatusBadge status="cancelled" label="In conflitto" size="sm" />
                </div>
              </div>
            </div>

            {/* Actions */}
            <div className="flex gap-3">
              <button className="flex-1 px-4 py-2 bg-muted text-foreground rounded-lg text-sm font-medium hover:bg-muted/80 transition-colors">
                Cambia Orario
              </button>
              <button className="flex-1 px-4 py-2 bg-primary text-primary-foreground rounded-lg text-sm font-semibold hover:bg-primary/90 transition-colors shadow-sm">
                Scegli Altro Staff
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// Shared/States/Agenda/Conflict/Overbooking
export function AgendaOverbookingState() {
  return (
    <div className="max-w-2xl mx-auto p-6">
      <div className="bg-error/10 border border-error/30 rounded-xl p-6">
        <div className="flex items-start gap-4">
          <Ban className="size-8 text-error flex-shrink-0 mt-1" />
          <div className="flex-1">
            <h3 className="font-semibold text-lg mb-2 text-error">Capacità Massima Raggiunta</h3>
            <p className="text-sm text-muted-foreground mb-4">
              Tutti gli operatori sono al completo per questo orario. Prova con:
            </p>
            <ul className="space-y-2 mb-4">
              <li className="flex items-center gap-2 text-sm">
                <CheckCircle className="size-4 text-success" />
                <span>Un orario diverso (es. 17:00)</span>
              </li>
              <li className="flex items-center gap-2 text-sm">
                <CheckCircle className="size-4 text-success" />
                <span>Un giorno alternativo (es. Giovedì)</span>
              </li>
              <li className="flex items-center gap-2 text-sm">
                <CheckCircle className="size-4 text-success" />
                <span>Un altro salone della rete</span>
              </li>
            </ul>
            <button className="w-full px-4 py-3 bg-primary text-primary-foreground rounded-lg font-semibold hover:bg-primary/90 transition-colors shadow-sm">
              Vedi Disponibilità Alternative
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

// Shared/States/Agenda/Cancelled/BySalon
export function AppointmentCancelledBySalonState() {
  return (
    <div className="max-w-2xl mx-auto p-6">
      <div className="bg-warning/10 border border-warning/30 rounded-xl p-6">
        <div className="flex items-start gap-4">
          <div className="w-12 h-12 bg-warning/20 rounded-full flex items-center justify-center flex-shrink-0">
            <AlertCircle className="size-6 text-warning" />
          </div>
          <div className="flex-1">
            <h3 className="font-semibold text-lg mb-2">Appuntamento Cancellato dal Salone</h3>
            <p className="text-sm text-muted-foreground mb-4">
              Ci scusiamo per l'inconveniente. Il tuo appuntamento del <strong>7 Marzo alle 15:00</strong> è stato cancellato dal salone per un'emergenza.
            </p>
            <div className="bg-card border border-border rounded-lg p-4 mb-4">
              <p className="text-sm font-medium mb-2">Motivo:</p>
              <p className="text-sm text-muted-foreground">
                L'operatore Francesca non è disponibile per malattia improvvisa.
              </p>
            </div>
            <div className="flex gap-3">
              <button className="flex-1 px-4 py-3 bg-muted text-foreground rounded-lg text-sm font-medium hover:bg-muted/80 transition-colors">
                Contatta il Salone
              </button>
              <button className="flex-1 px-4 py-3 bg-primary text-primary-foreground rounded-lg text-sm font-semibold hover:bg-primary/90 transition-colors shadow-sm">
                Riprenota
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// ===================================
// 2. PAYMENT STATES
// ===================================

// Shared/States/Payment/Stripe/Failed
export function PaymentFailedState() {
  return (
    <div className="max-w-2xl mx-auto p-6">
      <div className="bg-error/10 border border-error/30 rounded-xl p-6">
        <div className="flex items-start gap-4">
          <div className="w-12 h-12 bg-error/20 rounded-full flex items-center justify-center flex-shrink-0">
            <XCircle className="size-6 text-error" />
          </div>
          <div className="flex-1">
            <h3 className="font-semibold text-lg mb-2 text-error">Pagamento Non Riuscito</h3>
            <p className="text-sm text-muted-foreground mb-4">
              Il pagamento di <strong>€150</strong> non è stato completato.
            </p>
            
            <div className="bg-card border border-border rounded-lg p-4 mb-4">
              <p className="text-sm font-medium mb-2">Possibili cause:</p>
              <ul className="space-y-1 text-sm text-muted-foreground">
                <li>• Fondi insufficienti</li>
                <li>• Carta scaduta o bloccata</li>
                <li>• Dati inseriti non corretti</li>
                <li>• Limite di spesa raggiunto</li>
              </ul>
            </div>

            <div className="flex gap-3">
              <button className="flex-1 px-4 py-3 bg-muted text-foreground rounded-lg text-sm font-medium hover:bg-muted/80 transition-colors">
                Cambia Metodo
              </button>
              <button className="flex-1 px-4 py-3 bg-primary text-primary-foreground rounded-lg text-sm font-semibold hover:bg-primary/90 transition-colors shadow-sm">
                Riprova
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// Shared/States/Payment/Stripe/Partial
export function PaymentPartialState() {
  return (
    <div className="max-w-2xl mx-auto p-6">
      <div className="bg-warning/10 border border-warning/30 rounded-xl p-6">
        <div className="flex items-start gap-4">
          <div className="w-12 h-12 bg-warning/20 rounded-full flex items-center justify-center flex-shrink-0">
            <TrendingDown className="size-6 text-warning" />
          </div>
          <div className="flex-1">
            <h3 className="font-semibold text-lg mb-2 text-warning">Pagamento Parziale</h3>
            <p className="text-sm text-muted-foreground mb-4">
              Abbiamo ricevuto solo una parte del pagamento. Completa la transazione per confermare la prenotazione.
            </p>
            
            <div className="space-y-3 mb-4">
              <div className="flex items-center justify-between p-3 bg-card border border-border rounded-lg">
                <span className="text-sm text-muted-foreground">Importo totale</span>
                <span className="font-semibold">€150</span>
              </div>
              <div className="flex items-center justify-between p-3 bg-success/10 border border-success/30 rounded-lg">
                <span className="text-sm font-medium text-success">Pagato</span>
                <span className="font-semibold text-success">€100</span>
              </div>
              <div className="flex items-center justify-between p-3 bg-error/10 border border-error/30 rounded-lg">
                <span className="text-sm font-medium text-error">Residuo</span>
                <span className="font-semibold text-error">€50</span>
              </div>
            </div>

            <button className="w-full px-4 py-3 bg-primary text-primary-foreground rounded-lg font-semibold hover:bg-primary/90 transition-colors shadow-sm">
              Completa Pagamento (€50)
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

// Shared/States/Payment/Invoice/Overdue
export function InvoiceOverdueState() {
  return (
    <div className="max-w-2xl mx-auto p-6">
      <div className="bg-error/10 border border-error/30 rounded-xl p-4">
        <div className="flex items-start gap-3 mb-3">
          <Clock className="size-5 text-error flex-shrink-0 mt-0.5" />
          <div className="flex-1">
            <h4 className="font-semibold mb-1 text-error">Fattura Scaduta</h4>
            <p className="text-sm text-muted-foreground mb-2">
              La fattura <strong>INV-2026-003</strong> è scaduta da 15 giorni.
            </p>
          </div>
        </div>
        <div className="flex items-center justify-between p-3 bg-card border border-border rounded-lg mb-3">
          <span className="text-sm">Importo dovuto</span>
          <span className="text-xl font-bold text-error">€55</span>
        </div>
        <div className="flex gap-2">
          <button className="flex-1 px-4 py-2 bg-muted text-foreground rounded-lg text-sm font-medium hover:bg-muted/80">
            Scarica Fattura
          </button>
          <button className="flex-1 px-4 py-2 bg-error text-white rounded-lg text-sm font-semibold hover:bg-error/90 shadow-sm">
            Paga Ora
          </button>
        </div>
      </div>
    </div>
  );
}

// ===================================
// 3. PACKAGE & QUOTE STATES
// ===================================

// Shared/States/Package/Expired/DuringUse
export function PackageExpiredDuringUseState() {
  return (
    <div className="max-w-2xl mx-auto p-6">
      <div className="bg-warning/10 border border-warning/30 rounded-xl p-6">
        <div className="flex items-start gap-4">
          <div className="w-12 h-12 bg-warning/20 rounded-full flex items-center justify-center flex-shrink-0">
            <Package className="size-6 text-warning" />
          </div>
          <div className="flex-1">
            <h3 className="font-semibold text-lg mb-2 text-warning">Pacchetto Scaduto</h3>
            <p className="text-sm text-muted-foreground mb-4">
              Il tuo <strong>Pacchetto Bellezza Completa</strong> è scaduto il 1 Marzo 2026. 
              Hai ancora 2 servizi non utilizzati.
            </p>

            <div className="bg-card border border-border rounded-lg p-4 mb-4">
              <div className="flex items-center justify-between mb-3">
                <span className="text-sm text-muted-foreground">Servizi rimasti</span>
                <span className="font-semibold">2 di 5</span>
              </div>
              <div className="w-full bg-muted rounded-full h-2 mb-3">
                <div className="bg-error h-2 rounded-full" style={{ width: '40%' }}></div>
              </div>
              <p className="text-xs text-muted-foreground">
                Valore residuo: €80
              </p>
            </div>

            <div className="space-y-2 mb-4 p-3 bg-info/10 border border-info/30 rounded-lg">
              <p className="text-sm font-medium">Cosa puoi fare:</p>
              <ul className="space-y-1 text-sm text-muted-foreground">
                <li>✓ Rinnova il pacchetto con estensione validità</li>
                <li>✓ Converti il valore in punti fedeltà</li>
                <li>✓ Richiedi rimborso parziale (entro 30gg)</li>
              </ul>
            </div>

            <div className="flex gap-3">
              <button className="flex-1 px-4 py-3 bg-muted text-foreground rounded-lg text-sm font-medium hover:bg-muted/80 transition-colors">
                Richiedi Rimborso
              </button>
              <button className="flex-1 px-4 py-3 bg-primary text-primary-foreground rounded-lg text-sm font-semibold hover:bg-primary/90 transition-colors shadow-sm">
                Rinnova Pacchetto
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// Shared/States/Quote/Expired/Pending
export function QuoteExpiredState() {
  return (
    <div className="max-w-2xl mx-auto p-6">
      <div className="bg-error/10 border border-error/30 rounded-xl p-6">
        <div className="flex items-start gap-4">
          <XCircle className="size-8 text-error flex-shrink-0" />
          <div className="flex-1">
            <h3 className="font-semibold text-lg mb-2 text-error">Preventivo Scaduto</h3>
            <p className="text-sm text-muted-foreground mb-4">
              Il preventivo <strong>Matrimonio Premium</strong> è scaduto il 28 Febbraio 2026 senza risposta.
            </p>
            
            <div className="bg-card border border-border rounded-lg p-4 mb-4">
              <div className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Validità preventivo</span>
                  <span className="font-medium">30 giorni</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Data scadenza</span>
                  <span className="font-medium text-error">28 Feb 2026</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Importo originale</span>
                  <span className="font-medium">€350</span>
                </div>
              </div>
            </div>

            <div className="flex gap-3">
              <button className="flex-1 px-4 py-3 bg-muted text-foreground rounded-lg text-sm font-medium hover:bg-muted/80 transition-colors">
                Archivia
              </button>
              <button className="flex-1 px-4 py-3 bg-primary text-primary-foreground rounded-lg text-sm font-semibold hover:bg-primary/90 transition-colors shadow-sm">
                Rigenera Preventivo
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// ===================================
// 4. LOYALTY & AVAILABILITY
// ===================================

// Shared/States/Loyalty/Insufficient/Points
export function InsufficientPointsState() {
  return (
    <div className="max-w-2xl mx-auto p-6">
      <div className="bg-warning/10 border border-warning/30 rounded-xl p-6">
        <div className="flex items-start gap-4">
          <Lock className="size-8 text-warning flex-shrink-0" />
          <div className="flex-1">
            <h3 className="font-semibold text-lg mb-2">Punti Insufficienti</h3>
            <p className="text-sm text-muted-foreground mb-4">
              Hai <strong>420 punti</strong> ma servono <strong>500 punti</strong> per riscattare questo premio.
            </p>

            <div className="bg-card border border-border rounded-lg p-4 mb-4">
              <div className="flex items-center justify-between mb-3">
                <span className="text-sm text-muted-foreground">Progressione</span>
                <span className="font-semibold">420 / 500</span>
              </div>
              <div className="w-full bg-muted rounded-full h-2 mb-2">
                <div className="bg-primary h-2 rounded-full" style={{ width: '84%' }}></div>
              </div>
              <p className="text-xs text-muted-foreground">
                Ti mancano solo <strong className="text-warning">80 punti</strong>
              </p>
            </div>

            <div className="space-y-2 p-3 bg-info/10 border border-info/30 rounded-lg mb-4">
              <p className="text-sm font-medium">Come guadagnare punti:</p>
              <ul className="space-y-1 text-sm text-muted-foreground">
                <li>• Prenota un servizio (1 punto = €1 speso)</li>
                <li>• Completa il tuo profilo (+50 punti)</li>
                <li>• Invita un amico (+100 punti)</li>
              </ul>
            </div>

            <button className="w-full px-4 py-3 bg-primary text-primary-foreground rounded-lg font-semibold hover:bg-primary/90 transition-colors shadow-sm">
              Guadagna Punti
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

// Shared/States/Service/Unavailable/Temporary
export function ServiceTemporarilyUnavailableState() {
  return (
    <div className="max-w-2xl mx-auto p-6">
      <div className="bg-warning/10 border border-warning/30 rounded-xl p-6">
        <div className="flex items-start gap-4">
          <div className="w-12 h-12 bg-warning/20 rounded-full flex items-center justify-center flex-shrink-0">
            <AlertCircle className="size-6 text-warning" />
          </div>
          <div className="flex-1">
            <h3 className="font-semibold text-lg mb-2">Servizio Non Disponibile</h3>
            <p className="text-sm text-muted-foreground mb-4">
              Il servizio <strong>Colore Completo</strong> è temporaneamente non disponibile per manutenzione attrezzature.
            </p>

            <div className="bg-card border border-border rounded-lg p-4 mb-4">
              <p className="text-sm font-medium mb-2">Disponibile nuovamente da:</p>
              <p className="text-lg font-bold text-primary">Lunedì 10 Marzo 2026</p>
            </div>

            <div className="flex gap-3">
              <button className="flex-1 px-4 py-3 bg-muted text-foreground rounded-lg text-sm font-medium hover:bg-muted/80 transition-colors">
                Servizi Alternativi
              </button>
              <button className="flex-1 px-4 py-3 bg-primary text-primary-foreground rounded-lg text-sm font-semibold hover:bg-primary/90 transition-colors shadow-sm">
                Prenota dal 10 Marzo
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// Shared/States/Cart/Item/Unavailable
export function CartItemUnavailableState() {
  return (
    <div className="max-w-2xl mx-auto p-6">
      <div className="bg-error/10 border border-error/30 rounded-xl p-4">
        <div className="flex items-start gap-3">
          <XCircle className="size-5 text-error flex-shrink-0 mt-0.5" />
          <div className="flex-1">
            <h4 className="font-semibold mb-1 text-error">Servizio Rimosso dal Carrello</h4>
            <p className="text-sm text-muted-foreground mb-3">
              <strong>Trattamento Viso Deluxe</strong> non è più disponibile nel nostro listino.
            </p>
            <button 
              onClick={() => toast.info('Visualizzazione servizi alternativi')}
              className="text-sm text-primary hover:underline font-medium"
            >
              Scopri i servizi alternativi →
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

// ===================================
// 5. STAFF AVAILABILITY
// ===================================

// Shared/States/Staff/Unavailable/Sudden
export function StaffSuddenlyUnavailableState() {
  return (
    <div className="max-w-2xl mx-auto p-6">
      <div className="bg-warning/10 border border-warning/30 rounded-xl p-6">
        <div className="flex items-start gap-4">
          <div className="w-12 h-12 bg-warning/20 rounded-full flex items-center justify-center flex-shrink-0">
            <Users className="size-6 text-warning" />
          </div>
          <div className="flex-1">
            <h3 className="font-semibold text-lg mb-2 text-warning">Operatore Non Disponibile</h3>
            <p className="text-sm text-muted-foreground mb-4">
              <strong>Francesca</strong> non è disponibile per il tuo appuntamento del <strong>7 Marzo alle 15:00</strong> per un'emergenza personale.
            </p>

            <div className="bg-card border border-border rounded-lg p-4 mb-4">
              <p className="text-sm font-medium mb-3">Operatori alternativi disponibili:</p>
              <div className="space-y-2">
                {[
                  { name: 'Giulia', specialty: 'Hair Stylist', available: true, time: '15:00' },
                  { name: 'Laura', specialty: 'Hair Stylist Junior', available: true, time: '15:30' },
                  { name: 'Sara', specialty: 'Colorista', available: true, time: '16:00' },
                ].map((staff, i) => (
                  <button
                    key={i}
                    onClick={() => toast.success(`Prenotato con ${staff.name}`)}
                    className="w-full flex items-center justify-between p-3 bg-muted hover:bg-muted/80 rounded-lg transition-colors"
                  >
                    <div className="text-left">
                      <p className="font-medium text-sm">{staff.name}</p>
                      <p className="text-xs text-muted-foreground">{staff.specialty}</p>
                    </div>
                    <div className="text-right">
                      <p className="text-sm font-medium text-primary">{staff.time}</p>
                      <p className="text-xs text-success">Disponibile</p>
                    </div>
                  </button>
                ))}
              </div>
            </div>

            <div className="flex gap-3">
              <button className="flex-1 px-4 py-3 bg-muted text-foreground rounded-lg text-sm font-medium hover:bg-muted/80 transition-colors">
                Annulla Appuntamento
              </button>
              <button className="flex-1 px-4 py-3 bg-primary text-primary-foreground rounded-lg text-sm font-semibold hover:bg-primary/90 transition-colors shadow-sm">
                Accetta Alternative
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// ===================================
// 6. API & CONNECTIVITY
// ===================================

// Shared/States/WhatsApp/API/Disconnected
export function WhatsAppAPIDisconnectedState() {
  return (
    <div className="max-w-2xl mx-auto p-6">
      <div className="bg-error/10 border border-error/30 rounded-xl p-6">
        <div className="flex items-start gap-4">
          <WifiOff className="size-8 text-error flex-shrink-0" />
          <div className="flex-1">
            <h3 className="font-semibold text-lg mb-2 text-error">API WhatsApp Disconnessa</h3>
            <p className="text-sm text-muted-foreground mb-4">
              La connessione con WhatsApp Business API è stata interrotta. I messaggi non possono essere inviati.
            </p>

            <div className="bg-card border border-border rounded-lg p-4 mb-4">
              <p className="text-sm font-medium mb-2">Possibili cause:</p>
              <ul className="space-y-1 text-sm text-muted-foreground">
                <li>• Token API scaduto</li>
                <li>• Business Account sospeso</li>
                <li>• Limite messaggi raggiunto</li>
                <li>• Problemi di rete</li>
              </ul>
            </div>

            <div className="flex gap-3">
              <button className="flex-1 px-4 py-3 bg-muted text-foreground rounded-lg text-sm font-medium hover:bg-muted/80 transition-colors">
                Verifica Configurazione
              </button>
              <button className="flex-1 px-4 py-3 bg-error text-white rounded-lg text-sm font-semibold hover:bg-error/90 transition-colors shadow-sm flex items-center justify-center gap-2">
                <RefreshCw className="size-4" />
                Riconnetti
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// Shared/States/Report/Generation/Failed
export function ReportGenerationFailedState() {
  return (
    <div className="max-w-2xl mx-auto p-6">
      <ErrorState
        title="Generazione Report Fallita"
        message="Si è verificato un errore durante la creazione del report. Verifica i parametri e riprova."
        onRetry={() => toast.info('Rigenerazione report...')}
      />
      <div className="mt-4 p-4 bg-muted rounded-lg">
        <p className="text-sm font-medium mb-2">Suggerimenti:</p>
        <ul className="space-y-1 text-sm text-muted-foreground">
          <li>• Riduci l'intervallo di date selezionato</li>
          <li>• Seleziona meno filtri contemporaneamente</li>
          <li>• Attendi alcuni minuti prima di riprovare</li>
        </ul>
      </div>
    </div>
  );
}

// ===================================
// 7. NETWORK & LOADING STATES
// ===================================

// Shared/States/Network/Offline/Default
export function NetworkOfflineState() {
  return (
    <div className="max-w-2xl mx-auto p-6">
      <div className="bg-error/10 border border-error/30 rounded-xl p-6">
        <div className="flex items-start gap-4">
          <WifiOff className="size-8 text-error flex-shrink-0" />
          <div className="flex-1">
            <h3 className="font-semibold text-lg mb-2 text-error">Nessuna Connessione</h3>
            <p className="text-sm text-muted-foreground mb-4">
              Non sei connesso a Internet. Alcune funzionalità potrebbero non essere disponibili.
            </p>
            <div className="flex items-center gap-2 text-sm text-muted-foreground mb-4">
              <div className="w-2 h-2 bg-error rounded-full animate-pulse"></div>
              <span>Tentativo di riconnessione in corso...</span>
            </div>
            <button className="w-full px-4 py-3 bg-muted text-foreground rounded-lg font-medium hover:bg-muted/80 transition-colors flex items-center justify-center gap-2">
              <RefreshCw className="size-4" />
              Riprova Connessione
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

// Shared/States/Messaging/Send/Failed
export function MessageSendFailedState() {
  return (
    <div className="max-w-2xl mx-auto p-6">
      <div className="bg-error/10 border border-error/30 rounded-xl p-4">
        <div className="flex items-start gap-3">
          <MessageSquare className="size-5 text-error flex-shrink-0 mt-0.5" />
          <div className="flex-1">
            <h4 className="font-semibold mb-1 text-error">Invio Fallito</h4>
            <p className="text-sm text-muted-foreground mb-3">
              La campagna <strong>Promo Marzo</strong> non è stata inviata. 247 destinatari su 342 hanno ricevuto il messaggio.
            </p>
            <div className="flex gap-2">
              <button className="px-4 py-2 bg-muted text-foreground rounded-lg text-sm font-medium hover:bg-muted/80">
                Verifica Destinatari
              </button>
              <button className="px-4 py-2 bg-error text-white rounded-lg text-sm font-semibold hover:bg-error/90">
                Reinvia Mancanti
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// ===================================
// EXPORT ALL STATES
// ===================================

export const CrossModuleStates = {
  // Agenda
  AgendaDoubleBookingState,
  AgendaOverbookingState,
  AppointmentCancelledBySalonState,
  
  // Payment
  PaymentFailedState,
  PaymentPartialState,
  InvoiceOverdueState,
  
  // Packages & Quotes
  PackageExpiredDuringUseState,
  QuoteExpiredState,
  
  // Loyalty & Availability
  InsufficientPointsState,
  ServiceTemporarilyUnavailableState,
  CartItemUnavailableState,
  
  // Staff
  StaffSuddenlyUnavailableState,
  
  // API & Connectivity
  WhatsAppAPIDisconnectedState,
  ReportGenerationFailedState,
  NetworkOfflineState,
  MessageSendFailedState,
};

// Demo Page to showcase all states
export default function CrossModuleStatesPage() {
  return (
    <div className="min-h-screen bg-background p-4 lg:p-8">
      <div className="max-w-6xl mx-auto">
        <div className="mb-8">
          <h1 className="text-4xl font-bold mb-2">40_Cross_Module_States</h1>
          <p className="text-muted-foreground">
            Stati edge case e cross-module per YouBook - Organized by category
          </p>
        </div>

        <div className="space-y-12">
          {/* Agenda Conflicts */}
          <section>
            <h2 className="text-2xl font-bold mb-6">1. Conflitti Agenda</h2>
            <div className="space-y-6">
              <div>
                <h3 className="text-lg font-semibold mb-3">Double Booking</h3>
                <AgendaDoubleBookingState />
              </div>
              <div>
                <h3 className="text-lg font-semibold mb-3">Overbooking</h3>
                <AgendaOverbookingState />
              </div>
              <div>
                <h3 className="text-lg font-semibold mb-3">Cancellato dal Salone</h3>
                <AppointmentCancelledBySalonState />
              </div>
            </div>
          </section>

          {/* Payment States */}
          <section>
            <h2 className="text-2xl font-bold mb-6">2. Stati Pagamento</h2>
            <div className="space-y-6">
              <div>
                <h3 className="text-lg font-semibold mb-3">Pagamento Fallito</h3>
                <PaymentFailedState />
              </div>
              <div>
                <h3 className="text-lg font-semibold mb-3">Pagamento Parziale</h3>
                <PaymentPartialState />
              </div>
              <div>
                <h3 className="text-lg font-semibold mb-3">Fattura Scaduta</h3>
                <InvoiceOverdueState />
              </div>
            </div>
          </section>

          {/* Packages & Quotes */}
          <section>
            <h2 className="text-2xl font-bold mb-6">3. Pacchetti e Preventivi</h2>
            <div className="space-y-6">
              <div>
                <h3 className="text-lg font-semibold mb-3">Pacchetto Scaduto</h3>
                <PackageExpiredDuringUseState />
              </div>
              <div>
                <h3 className="text-lg font-semibold mb-3">Preventivo Scaduto</h3>
                <QuoteExpiredState />
              </div>
            </div>
          </section>

          {/* Loyalty & Availability */}
          <section>
            <h2 className="text-2xl font-bold mb-6">4. Fedeltà e Disponibilità</h2>
            <div className="space-y-6">
              <div>
                <h3 className="text-lg font-semibold mb-3">Punti Insufficienti</h3>
                <InsufficientPointsState />
              </div>
              <div>
                <h3 className="text-lg font-semibold mb-3">Servizio Non Disponibile</h3>
                <ServiceTemporarilyUnavailableState />
              </div>
              <div>
                <h3 className="text-lg font-semibold mb-3">Carrello Item Rimosso</h3>
                <CartItemUnavailableState />
              </div>
            </div>
          </section>

          {/* Staff Availability */}
          <section>
            <h2 className="text-2xl font-bold mb-6">5. Disponibilità Staff</h2>
            <div className="space-y-6">
              <div>
                <h3 className="text-lg font-semibold mb-3">Staff Improvvisamente Non Disponibile</h3>
                <StaffSuddenlyUnavailableState />
              </div>
            </div>
          </section>

          {/* API & Connectivity */}
          <section>
            <h2 className="text-2xl font-bold mb-6">6. API e Connettività</h2>
            <div className="space-y-6">
              <div>
                <h3 className="text-lg font-semibold mb-3">WhatsApp API Disconnessa</h3>
                <WhatsAppAPIDisconnectedState />
              </div>
              <div>
                <h3 className="text-lg font-semibold mb-3">Generazione Report Fallita</h3>
                <ReportGenerationFailedState />
              </div>
              <div>
                <h3 className="text-lg font-semibold mb-3">Network Offline</h3>
                <NetworkOfflineState />
              </div>
              <div>
                <h3 className="text-lg font-semibold mb-3">Invio Messaggi Fallito</h3>
                <MessageSendFailedState />
              </div>
            </div>
          </section>
        </div>
      </div>
    </div>
  );
}
