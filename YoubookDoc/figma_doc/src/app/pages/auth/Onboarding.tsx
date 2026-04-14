import { useState } from 'react';
import { useNavigate } from 'react-router';
import { Building, Check, Clock } from 'lucide-react';
import { toast } from 'sonner';

// Auth/Onboarding/SalonSelection/Default/Default
export default function Onboarding() {
  const [selectedSalon, setSelectedSalon] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [requestStatus, setRequestStatus] = useState<'idle' | 'pending' | 'approved'>('idle');
  const navigate = useNavigate();

  // Mock salons
  const salons = [
    { id: '1', name: 'Salone Bellezza Milano', address: 'Via Roma 10, Milano', isOpen: true },
    { id: '2', name: 'Hair Studio Roma', address: 'Via del Corso 45, Roma', isOpen: false },
    { id: '3', name: 'Beauty Center Firenze', address: 'Piazza Duomo 3, Firenze', isOpen: true },
  ];

  const handleSelectSalon = async () => {
    if (!selectedSalon) return;

    setLoading(true);

    try {
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      const salon = salons.find(s => s.id === selectedSalon);
      
      if (salon?.isOpen) {
        toast.success('Accesso al salone consentito!');
        setRequestStatus('approved');
        setTimeout(() => navigate('/client/dashboard'), 1500);
      } else {
        setRequestStatus('pending');
        toast.info('Richiesta inviata al salone');
      }
    } catch (error) {
      toast.error('Errore durante la richiesta');
    } finally {
      setLoading(false);
    }
  };

  if (requestStatus === 'pending') {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background p-4">
        <div className="w-full max-w-md">
          <div className="bg-card border border-border rounded-xl p-8 shadow-sm text-center">
            <div className="w-16 h-16 bg-warning/10 rounded-full flex items-center justify-center mx-auto mb-6">
              <Clock className="size-8 text-warning" />
            </div>

            <h2 className="text-2xl font-medium mb-4">Richiesta in attesa</h2>
            <p className="text-muted-foreground mb-8">
              La tua richiesta di accesso al salone è in attesa di approvazione. Riceverai una notifica quando verrà elaborata.
            </p>

            <button
              onClick={() => navigate('/')}
              className="px-6 py-3 bg-secondary text-secondary-foreground rounded-lg hover:bg-secondary/90 transition-colors"
            >
              Torna alla Home
            </button>
          </div>
        </div>
      </div>
    );
  }

  if (requestStatus === 'approved') {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background p-4">
        <div className="w-full max-w-md">
          <div className="bg-card border border-border rounded-xl p-8 shadow-sm text-center">
            <div className="w-16 h-16 bg-success/10 rounded-full flex items-center justify-center mx-auto mb-6">
              <Check className="size-8 text-success" />
            </div>

            <h2 className="text-2xl font-medium mb-4">Benvenuto!</h2>
            <p className="text-muted-foreground mb-8">
              Il tuo account è stato configurato con successo. Stai per essere reindirizzato...
            </p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-background p-4">
      <div className="w-full max-w-2xl">
        <div className="text-center mb-8">
          <h1 className="text-4xl font-bold text-primary mb-2">YouBook</h1>
          <p className="text-muted-foreground">Completa il tuo profilo</p>
        </div>

        <div className="bg-card border border-border rounded-xl p-8 shadow-sm">
          <h2 className="text-2xl font-medium mb-2">Scegli il tuo salone</h2>
          <p className="text-sm text-muted-foreground mb-6">
            Seleziona il salone a cui vuoi accedere
          </p>

          <div className="space-y-3 mb-6">
            {salons.map((salon) => (
              <button
                key={salon.id}
                onClick={() => setSelectedSalon(salon.id)}
                className={`w-full text-left p-4 rounded-lg border-2 transition-all ${
                  selectedSalon === salon.id
                    ? 'border-primary bg-primary/5'
                    : 'border-border hover:border-primary/50'
                }`}
              >
                <div className="flex items-start gap-3">
                  <div className={`w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0 ${
                    salon.isOpen ? 'bg-success/10' : 'bg-warning/10'
                  }`}>
                    <Building className={`size-5 ${
                      salon.isOpen ? 'text-success' : 'text-warning'
                    }`} />
                  </div>

                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                      <h3 className="font-medium">{salon.name}</h3>
                      <span className={`text-xs px-2 py-0.5 rounded-full ${
                        salon.isOpen
                          ? 'bg-success/10 text-success'
                          : 'bg-warning/10 text-warning'
                      }`}>
                        {salon.isOpen ? 'Accesso libero' : 'Su approvazione'}
                      </span>
                    </div>
                    <p className="text-sm text-muted-foreground">{salon.address}</p>
                  </div>

                  {selectedSalon === salon.id && (
                    <Check className="size-5 text-primary flex-shrink-0" />
                  )}
                </div>
              </button>
            ))}
          </div>

          <button
            onClick={handleSelectSalon}
            disabled={!selectedSalon || loading}
            className="w-full px-6 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            {loading ? 'Invio richiesta...' : 'Continua'}
          </button>
        </div>
      </div>
    </div>
  );
}
