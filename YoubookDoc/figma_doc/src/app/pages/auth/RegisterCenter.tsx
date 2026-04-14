import { useState } from 'react';
import { Link, useNavigate } from 'react-router';
import { Building, User, Mail, Phone, Lock, UserPlus } from 'lucide-react';
import { toast } from 'sonner';

// Auth/RegisterCenter/Form/Default/Default
export default function RegisterCenter() {
  const [formData, setFormData] = useState({
    salonName: '',
    salonEmail: '',
    salonPhone: '',
    adminName: '',
    adminEmail: '',
    password: '',
  });
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    try {
      await new Promise(resolve => setTimeout(resolve, 1000));
      toast.success('Richiesta inviata! Il tuo account sarà abilitato dopo verifica');
      navigate('/');
    } catch (error) {
      toast.error('Errore durante la registrazione');
    } finally {
      setLoading(false);
    }
  };

  const handleChange = (field: string, value: string) => {
    setFormData(prev => ({ ...prev, [field]: value }));
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-background p-4">
      <div className="w-full max-w-2xl">
        <div className="text-center mb-8">
          <h1 className="text-4xl font-bold text-primary mb-2">YouBook</h1>
          <p className="text-muted-foreground">Registrazione Centro</p>
        </div>

        <div className="bg-card border border-border rounded-xl p-8 shadow-sm">
          <h2 className="text-2xl font-medium mb-2">Registra il tuo centro</h2>
          <p className="text-sm text-muted-foreground mb-6">
            La registrazione creerà un account in attesa di abilitazione
          </p>

          <form onSubmit={handleSubmit} className="space-y-6">
            {/* Salon Information */}
            <div className="space-y-4">
              <h3 className="text-lg font-medium">Informazioni Salone</h3>

              <div>
                <label htmlFor="salonName" className="block text-sm font-medium mb-2">
                  Nome Salone *
                </label>
                <div className="relative">
                  <Building className="absolute left-3 top-1/2 -translate-y-1/2 size-5 text-muted-foreground" />
                  <input
                    id="salonName"
                    type="text"
                    value={formData.salonName}
                    onChange={(e) => handleChange('salonName', e.target.value)}
                    required
                    className="w-full pl-11 pr-4 py-3 bg-input-background border border-border rounded-lg focus:outline-none focus:ring-2 focus:ring-ring"
                  />
                </div>
              </div>

              <div className="grid md:grid-cols-2 gap-4">
                <div>
                  <label htmlFor="salonEmail" className="block text-sm font-medium mb-2">
                    Email Salone *
                  </label>
                  <div className="relative">
                    <Mail className="absolute left-3 top-1/2 -translate-y-1/2 size-5 text-muted-foreground" />
                    <input
                      id="salonEmail"
                      type="email"
                      value={formData.salonEmail}
                      onChange={(e) => handleChange('salonEmail', e.target.value)}
                      required
                      className="w-full pl-11 pr-4 py-3 bg-input-background border border-border rounded-lg focus:outline-none focus:ring-2 focus:ring-ring"
                    />
                  </div>
                </div>

                <div>
                  <label htmlFor="salonPhone" className="block text-sm font-medium mb-2">
                    Telefono Salone *
                  </label>
                  <div className="relative">
                    <Phone className="absolute left-3 top-1/2 -translate-y-1/2 size-5 text-muted-foreground" />
                    <input
                      id="salonPhone"
                      type="tel"
                      value={formData.salonPhone}
                      onChange={(e) => handleChange('salonPhone', e.target.value)}
                      required
                      className="w-full pl-11 pr-4 py-3 bg-input-background border border-border rounded-lg focus:outline-none focus:ring-2 focus:ring-ring"
                    />
                  </div>
                </div>
              </div>
            </div>

            {/* Admin Information */}
            <div className="space-y-4">
              <h3 className="text-lg font-medium">Informazioni Amministratore</h3>

              <div>
                <label htmlFor="adminName" className="block text-sm font-medium mb-2">
                  Nome Amministratore *
                </label>
                <div className="relative">
                  <User className="absolute left-3 top-1/2 -translate-y-1/2 size-5 text-muted-foreground" />
                  <input
                    id="adminName"
                    type="text"
                    value={formData.adminName}
                    onChange={(e) => handleChange('adminName', e.target.value)}
                    required
                    className="w-full pl-11 pr-4 py-3 bg-input-background border border-border rounded-lg focus:outline-none focus:ring-2 focus:ring-ring"
                  />
                </div>
              </div>

              <div>
                <label htmlFor="adminEmail" className="block text-sm font-medium mb-2">
                  Email Amministratore *
                </label>
                <div className="relative">
                  <Mail className="absolute left-3 top-1/2 -translate-y-1/2 size-5 text-muted-foreground" />
                  <input
                    id="adminEmail"
                    type="email"
                    value={formData.adminEmail}
                    onChange={(e) => handleChange('adminEmail', e.target.value)}
                    required
                    className="w-full pl-11 pr-4 py-3 bg-input-background border border-border rounded-lg focus:outline-none focus:ring-2 focus:ring-ring"
                  />
                </div>
              </div>

              <div>
                <label htmlFor="password" className="block text-sm font-medium mb-2">
                  Password *
                </label>
                <div className="relative">
                  <Lock className="absolute left-3 top-1/2 -translate-y-1/2 size-5 text-muted-foreground" />
                  <input
                    id="password"
                    type="password"
                    value={formData.password}
                    onChange={(e) => handleChange('password', e.target.value)}
                    required
                    className="w-full pl-11 pr-4 py-3 bg-input-background border border-border rounded-lg focus:outline-none focus:ring-2 focus:ring-ring"
                  />
                </div>
              </div>
            </div>

            {/* Info Box */}
            <div className="bg-muted border border-border rounded-lg p-4">
              <p className="text-sm text-muted-foreground">
                <strong className="text-foreground">Nota:</strong> La registrazione non abilita automaticamente
                l'account. Riceverai una notifica via email quando il tuo account sarà abilitato.
              </p>
            </div>

            {/* Submit Button */}
            <button
              type="submit"
              disabled={loading}
              className="w-full flex items-center justify-center gap-2 px-6 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              <UserPlus className="size-5" />
              {loading ? 'Invio richiesta...' : 'Invia Richiesta'}
            </button>
          </form>

          <div className="mt-6 text-center text-sm">
            <span className="text-muted-foreground">Hai già un account? </span>
            <Link to="/" className="text-primary hover:underline font-medium">
              Accedi
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
