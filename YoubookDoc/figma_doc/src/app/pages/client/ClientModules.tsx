import { useState } from 'react';
import {
  Calendar, Check, X, ChevronRight, Clock, User, Euro, ArrowLeft,
  CheckCircle, XCircle, Copy, Download, Camera, Lock, Bell, Mail,
  Star, Award, Package, FileText, CreditCard, Image, Plus, Minus,
  Filter, Search, Sparkles, Gift, TrendingUp, AlertCircle, Phone
} from 'lucide-react';
import { toast } from 'sonner';
import StatusBadge from '../../components/StatusBadge';
import LoadingState from '../../components/LoadingState';
import EmptyState from '../../components/EmptyState';

// ===================================
// 2. AGENDA TAB
// ===================================
// Client/Agenda/List/Responsive/Default
export function AgendaTab() {
  const [filter, setFilter] = useState<'upcoming' | 'history'>('upcoming');
  const [loading] = useState(false);

  const upcomingAppointments = [
    { 
      id: '1', 
      service: 'Taglio e Piega', 
      date: '2026-03-07', 
      time: '15:00', 
      staff: 'Francesca', 
      price: 45,
      duration: 90,
      status: 'confirmed' as const 
    },
    { 
      id: '2', 
      service: 'Colore Completo', 
      date: '2026-03-18', 
      time: '10:00', 
      staff: 'Giulia', 
      price: 85,
      duration: 120,
      status: 'confirmed' as const 
    },
  ];

  const historyAppointments = [
    { 
      id: '3', 
      service: 'Manicure', 
      date: '2026-02-15', 
      time: '14:00', 
      staff: 'Laura', 
      price: 30,
      duration: 45,
      status: 'completed' as const 
    },
    { 
      id: '4', 
      service: 'Trattamento Viso', 
      date: '2026-02-01', 
      time: '11:00', 
      staff: 'Francesca', 
      price: 55,
      duration: 60,
      status: 'completed' as const 
    },
  ];

  const appointments = filter === 'upcoming' ? upcomingAppointments : historyAppointments;

  if (loading) {
    return <LoadingState message="Caricamento appuntamenti..." />;
  }

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      <div>
        <h2 className="text-3xl font-bold mb-2">I Miei Appuntamenti</h2>
        <p className="text-muted-foreground">Gestisci le tue prenotazioni</p>
      </div>

      {/* Filter Tabs */}
      <div className="flex gap-2">
        <button
          onClick={() => setFilter('upcoming')}
          className={`px-6 py-3 rounded-lg text-sm font-medium transition-colors ${
            filter === 'upcoming'
              ? 'bg-primary text-primary-foreground shadow-sm'
              : 'bg-muted text-foreground hover:bg-muted/80'
          }`}
        >
          Prossimi ({upcomingAppointments.length})
        </button>
        <button
          onClick={() => setFilter('history')}
          className={`px-6 py-3 rounded-lg text-sm font-medium transition-colors ${
            filter === 'history'
              ? 'bg-primary text-primary-foreground shadow-sm'
              : 'bg-muted text-foreground hover:bg-muted/80'
          }`}
        >
          Storico ({historyAppointments.length})
        </button>
      </div>

      {/* Appointments List */}
      {appointments.length === 0 ? (
        <EmptyState
          icon={Calendar}
          title="Nessun appuntamento"
          description={filter === 'upcoming' ? 'Non hai appuntamenti programmati' : 'Nessuno storico disponibile'}
        />
      ) : (
        <div className="space-y-3">
          {appointments.map((apt) => (
            <div key={apt.id} className="bg-card border border-border rounded-xl p-4 hover:border-primary transition-colors">
              <div className="flex items-start justify-between mb-4">
                <div className="flex-1">
                  <h3 className="font-semibold text-lg mb-2">{apt.service}</h3>
                  <div className="space-y-1">
                    <div className="flex items-center gap-2 text-sm text-muted-foreground">
                      <User className="size-4" />
                      <span>Con {apt.staff}</span>
                    </div>
                    <div className="flex items-center gap-2 text-sm text-muted-foreground">
                      <Calendar className="size-4" />
                      <span>{new Date(apt.date).toLocaleDateString('it-IT', { weekday: 'long', day: 'numeric', month: 'long' })}</span>
                    </div>
                    <div className="flex items-center gap-2 text-sm text-muted-foreground">
                      <Clock className="size-4" />
                      <span>{apt.time} ({apt.duration} min)</span>
                    </div>
                  </div>
                </div>
                <div className="flex flex-col items-end gap-2">
                  <StatusBadge
                    status={apt.status === 'confirmed' ? 'success' : 'info'}
                    label={apt.status === 'confirmed' ? 'Confermato' : 'Completato'}
                    size="sm"
                  />
                  <span className="text-lg font-bold text-primary">€{apt.price}</span>
                </div>
              </div>

              {filter === 'upcoming' && (
                <div className="flex gap-2">
                  <button className="flex-1 px-4 py-2 bg-muted text-foreground rounded-lg text-sm font-medium hover:bg-muted/80 transition-colors">
                    Modifica
                  </button>
                  <button className="flex-1 px-4 py-2 bg-error/10 text-error rounded-lg text-sm font-medium hover:bg-error/20 transition-colors">
                    Annulla
                  </button>
                </div>
              )}

              {filter === 'history' && (
                <button className="w-full px-4 py-2 bg-primary text-primary-foreground rounded-lg text-sm font-semibold hover:bg-primary/90 transition-colors shadow-sm">
                  Prenota di Nuovo
                </button>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// ===================================
// 3. PRENOTA TAB (BOOKING FLOW)
// ===================================
// Client/Booking/Flow/Responsive/Default
export function PrenotaTab() {
  const [bookingStep, setBookingStep] = useState<'service' | 'datetime' | 'staff' | 'confirm'>('service');
  const [selectedService, setSelectedService] = useState<any>(null);
  const [selectedDate, setSelectedDate] = useState<string>('');
  const [selectedTime, setSelectedTime] = useState<string>('');
  const [selectedStaff, setSelectedStaff] = useState<any>(null);

  const services = [
    { id: '1', name: 'Taglio Donna', price: 35, duration: 45, category: 'Capelli' },
    { id: '2', name: 'Piega', price: 25, duration: 30, category: 'Capelli' },
    { id: '3', name: 'Colore Completo', price: 85, duration: 120, category: 'Capelli' },
    { id: '4', name: 'Trattamento Viso', price: 55, duration: 60, category: 'Viso' },
    { id: '5', name: 'Manicure', price: 30, duration: 45, category: 'Mani' },
    { id: '6', name: 'Pedicure', price: 35, duration: 50, category: 'Piedi' },
  ];

  const availableSlots = [
    '09:00', '09:30', '10:00', '10:30', '11:00', '11:30',
    '14:00', '14:30', '15:00', '15:30', '16:00', '16:30', '17:00'
  ];

  const staff = [
    { id: '1', name: 'Francesca', role: 'Hair Stylist Senior', rating: 4.9, reviews: 124 },
    { id: '2', name: 'Giulia', role: 'Colorista Esperta', rating: 4.8, reviews: 98 },
    { id: '3', name: 'Laura', role: 'Estetista', rating: 5.0, reviews: 87 },
  ];

  const handleServiceSelect = (service: any) => {
    setSelectedService(service);
    setBookingStep('datetime');
  };

  const handleDateTimeSelect = () => {
    if (selectedDate && selectedTime) {
      setBookingStep('staff');
    } else {
      toast.error('Seleziona data e ora');
    }
  };

  const handleStaffSelect = (staffMember: any) => {
    setSelectedStaff(staffMember);
    setBookingStep('confirm');
  };

  const handleConfirmBooking = () => {
    toast.success('Prenotazione confermata!');
    // Reset flow
    setBookingStep('service');
    setSelectedService(null);
    setSelectedDate('');
    setSelectedTime('');
    setSelectedStaff(null);
  };

  const handleBack = () => {
    if (bookingStep === 'datetime') setBookingStep('service');
    else if (bookingStep === 'staff') setBookingStep('datetime');
    else if (bookingStep === 'confirm') setBookingStep('staff');
  };

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      {/* Header with Back Button */}
      <div className="flex items-center gap-4">
        {bookingStep !== 'service' && (
          <button
            onClick={handleBack}
            className="p-2 hover:bg-muted rounded-lg transition-colors"
          >
            <ArrowLeft className="size-5" />
          </button>
        )}
        <div className="flex-1">
          <h2 className="text-3xl font-bold mb-2">
            {bookingStep === 'service' && 'Scegli il Servizio'}
            {bookingStep === 'datetime' && 'Data e Ora'}
            {bookingStep === 'staff' && 'Seleziona Operatore'}
            {bookingStep === 'confirm' && 'Conferma Prenotazione'}
          </h2>
          <p className="text-muted-foreground">
            {bookingStep === 'service' && 'Seleziona il servizio che desideri prenotare'}
            {bookingStep === 'datetime' && 'Quando preferisci il tuo appuntamento?'}
            {bookingStep === 'staff' && 'Con chi vuoi prenotare?'}
            {bookingStep === 'confirm' && 'Verifica i dettagli della tua prenotazione'}
          </p>
        </div>
      </div>

      {/* Step Indicator */}
      <div className="flex items-center gap-2">
        <div className={`flex-1 h-1 rounded-full ${bookingStep !== 'service' ? 'bg-primary' : 'bg-muted'}`} />
        <div className={`flex-1 h-1 rounded-full ${bookingStep === 'staff' || bookingStep === 'confirm' ? 'bg-primary' : 'bg-muted'}`} />
        <div className={`flex-1 h-1 rounded-full ${bookingStep === 'confirm' ? 'bg-primary' : 'bg-muted'}`} />
      </div>

      {/* STEP 1: Service Selection */}
      {bookingStep === 'service' && (
        <div className="grid gap-3">
          {services.map((service) => (
            <button
              key={service.id}
              onClick={() => handleServiceSelect(service)}
              className="bg-card border border-border rounded-xl p-4 hover:border-primary transition-colors text-left group"
            >
              <div className="flex items-center justify-between">
                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-1">
                    <h3 className="font-semibold text-lg">{service.name}</h3>
                    <span className="text-xs px-2 py-1 bg-muted rounded-full">{service.category}</span>
                  </div>
                  <p className="text-sm text-muted-foreground">
                    €{service.price} • {service.duration} min
                  </p>
                </div>
                <ChevronRight className="size-5 text-muted-foreground group-hover:text-primary transition-colors" />
              </div>
            </button>
          ))}
        </div>
      )}

      {/* STEP 2: Date & Time Selection */}
      {bookingStep === 'datetime' && (
        <div className="space-y-6">
          {/* Selected Service Summary */}
          <div className="bg-primary/10 border border-primary/20 rounded-xl p-4">
            <div className="flex items-center justify-between">
              <div>
                <h4 className="font-semibold">{selectedService?.name}</h4>
                <p className="text-sm text-muted-foreground">
                  €{selectedService?.price} • {selectedService?.duration} min
                </p>
              </div>
            </div>
          </div>

          {/* Date Selection */}
          <div>
            <label className="block text-sm font-medium mb-3">Seleziona Data</label>
            <input
              type="date"
              value={selectedDate}
              onChange={(e) => setSelectedDate(e.target.value)}
              min={new Date().toISOString().split('T')[0]}
              className="w-full px-4 py-3 bg-input-background border border-border rounded-lg focus:outline-none focus:ring-2 focus:ring-ring"
            />
          </div>

          {/* Time Selection */}
          {selectedDate && (
            <div>
              <label className="block text-sm font-medium mb-3">Seleziona Orario</label>
              <div className="grid grid-cols-3 sm:grid-cols-4 lg:grid-cols-5 gap-2">
                {availableSlots.map((slot) => (
                  <button
                    key={slot}
                    onClick={() => setSelectedTime(slot)}
                    className={`px-4 py-3 rounded-lg text-sm font-medium transition-colors ${
                      selectedTime === slot
                        ? 'bg-primary text-primary-foreground shadow-sm'
                        : 'bg-card border border-border hover:border-primary'
                    }`}
                  >
                    {slot}
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* Continue Button */}
          {selectedDate && selectedTime && (
            <button
              onClick={handleDateTimeSelect}
              className="w-full px-6 py-4 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors font-semibold shadow-lg"
            >
              Continua
            </button>
          )}
        </div>
      )}

      {/* STEP 3: Staff Selection */}
      {bookingStep === 'staff' && (
        <div className="space-y-4">
          {staff.map((member) => (
            <button
              key={member.id}
              onClick={() => handleStaffSelect(member)}
              className="w-full bg-card border border-border rounded-xl p-4 hover:border-primary transition-colors text-left group"
            >
              <div className="flex items-center gap-4">
                <div className="w-16 h-16 bg-muted rounded-full flex items-center justify-center flex-shrink-0">
                  <User className="size-8 text-muted-foreground" />
                </div>
                <div className="flex-1">
                  <h4 className="font-semibold text-lg mb-1">{member.name}</h4>
                  <p className="text-sm text-muted-foreground mb-2">{member.role}</p>
                  <div className="flex items-center gap-2">
                    <div className="flex items-center gap-1">
                      <Star className="size-4 fill-warning text-warning" />
                      <span className="text-sm font-medium">{member.rating}</span>
                    </div>
                    <span className="text-sm text-muted-foreground">
                      ({member.reviews} recensioni)
                    </span>
                  </div>
                </div>
                <ChevronRight className="size-5 text-muted-foreground group-hover:text-primary transition-colors" />
              </div>
            </button>
          ))}
        </div>
      )}

      {/* STEP 4: Confirmation */}
      {bookingStep === 'confirm' && (
        <div className="space-y-6">
          {/* Booking Summary */}
          <div className="bg-card border border-border rounded-xl p-6 space-y-4">
            <h3 className="font-semibold text-lg mb-4">Riepilogo Prenotazione</h3>
            
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <span className="text-muted-foreground">Servizio</span>
                <span className="font-medium">{selectedService?.name}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-muted-foreground">Data</span>
                <span className="font-medium">
                  {new Date(selectedDate).toLocaleDateString('it-IT', { weekday: 'long', day: 'numeric', month: 'long' })}
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-muted-foreground">Orario</span>
                <span className="font-medium">{selectedTime}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-muted-foreground">Durata</span>
                <span className="font-medium">{selectedService?.duration} min</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-muted-foreground">Operatore</span>
                <span className="font-medium">{selectedStaff?.name}</span>
              </div>
              <div className="border-t border-border pt-3 flex items-center justify-between">
                <span className="font-semibold">Totale</span>
                <span className="text-2xl font-bold text-primary">€{selectedService?.price}</span>
              </div>
            </div>
          </div>

          {/* Notes */}
          <div>
            <label className="block text-sm font-medium mb-2">Note aggiuntive (opzionale)</label>
            <textarea
              rows={3}
              placeholder="Hai richieste particolari?"
              className="w-full px-4 py-3 bg-input-background border border-border rounded-lg resize-none focus:outline-none focus:ring-2 focus:ring-ring"
            />
          </div>

          {/* Confirm Button */}
          <button
            onClick={handleConfirmBooking}
            className="w-full px-6 py-4 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors font-semibold shadow-lg"
          >
            Conferma Prenotazione
          </button>
        </div>
      )}
    </div>
  );
}

// ===================================
// 4. CARRELLO TAB
// ===================================
// Client/Cart/Summary/Responsive/Default
export function CarrelloTab() {
  const [cartItems, setCartItems] = useState([
    { id: '1', name: 'Taglio e Piega', price: 45, duration: 90 }
  ]);
  const [useLoyaltyPoints, setUseLoyaltyPoints] = useState(false);

  const subtotal = cartItems.reduce((sum, item) => sum + item.price, 0);
  const loyaltyDiscount = useLoyaltyPoints ? 5 : 0;
  const total = subtotal - loyaltyDiscount;

  const removeItem = (id: string) => {
    setCartItems(cartItems.filter(item => item.id !== id));
    toast.success('Servizio rimosso dal carrello');
  };

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      <div>
        <h2 className="text-3xl font-bold mb-2">Carrello</h2>
        <p className="text-muted-foreground">Rivedi i tuoi servizi prima di procedere</p>
      </div>

      {cartItems.length === 0 ? (
        <EmptyState
          icon={Package}
          title="Carrello vuoto"
          description="Aggiungi servizi per procedere con la prenotazione"
        />
      ) : (
        <>
          {/* Cart Items */}
          <div className="space-y-3">
            {cartItems.map((item) => (
              <div key={item.id} className="bg-card border border-border rounded-xl p-4">
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <h3 className="font-semibold mb-1">{item.name}</h3>
                    <p className="text-sm text-muted-foreground">{item.duration} minuti</p>
                  </div>
                  <div className="text-right">
                    <p className="font-semibold text-lg text-primary mb-2">€{item.price}</p>
                    <button
                      onClick={() => removeItem(item.id)}
                      className="text-sm text-error hover:underline"
                    >
                      Rimuovi
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>

          {/* Loyalty Points */}
          <div className="bg-muted rounded-xl p-4">
            <div className="flex items-center gap-3">
              <input
                type="checkbox"
                id="loyalty"
                checked={useLoyaltyPoints}
                onChange={(e) => setUseLoyaltyPoints(e.target.checked)}
                className="w-5 h-5 rounded border-border"
              />
              <label htmlFor="loyalty" className="flex-1 cursor-pointer">
                <div className="flex items-center gap-2">
                  <Award className="size-5 text-primary" />
                  <span className="font-medium">Usa 100 punti fedeltà</span>
                </div>
                <p className="text-sm text-muted-foreground">Risparmia €5 su questo ordine</p>
              </label>
              {useLoyaltyPoints && (
                <span className="font-semibold text-success">-€5</span>
              )}
            </div>
          </div>

          {/* Summary */}
          <div className="bg-card border border-border rounded-xl p-6">
            <h3 className="font-semibold mb-4">Riepilogo</h3>
            <div className="space-y-3">
              <div className="flex items-center justify-between text-muted-foreground">
                <span>Subtotale</span>
                <span className="font-medium">€{subtotal}</span>
              </div>
              {useLoyaltyPoints && (
                <div className="flex items-center justify-between text-success">
                  <span>Sconto punti fedeltà</span>
                  <span className="font-medium">-€{loyaltyDiscount}</span>
                </div>
              )}
              <div className="border-t border-border pt-3 flex items-center justify-between">
                <span className="font-semibold text-lg">Totale</span>
                <span className="text-2xl font-bold text-primary">€{total}</span>
              </div>
            </div>
          </div>

          {/* Proceed Button */}
          <button className="w-full px-6 py-4 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors font-semibold shadow-lg">
            Procedi al Pagamento
          </button>
        </>
      )}
    </div>
  );
}

// Continue with InfoTab and Drawer content in parent file...
