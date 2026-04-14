import { useState } from 'react';
import { Link, useNavigate } from 'react-router';
import { Mail, ArrowLeft, Send } from 'lucide-react';
import { toast } from 'sonner';

// Auth/PasswordReset/Form/Default/Default
export default function PasswordReset() {
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [sent, setSent] = useState(false);
  const navigate = useNavigate();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    try {
      await new Promise(resolve => setTimeout(resolve, 1000));
      setSent(true);
      toast.success('Link di recupero inviato alla tua email');
    } catch (error) {
      toast.error('Errore durante l\'invio del link');
    } finally {
      setLoading(false);
    }
  };

  if (sent) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background p-4">
        <div className="w-full max-w-md">
          <div className="bg-card border border-border rounded-xl p-8 shadow-sm text-center">
            <div className="w-16 h-16 bg-primary/10 rounded-full flex items-center justify-center mx-auto mb-6">
              <Mail className="size-8 text-primary" />
            </div>

            <h2 className="text-2xl font-medium mb-4">Email inviata!</h2>
            <p className="text-muted-foreground mb-8">
              Controlla la tua casella di posta. Ti abbiamo inviato un link per reimpostare la password.
            </p>

            <Link
              to="/"
              className="inline-flex items-center gap-2 px-6 py-3 bg-secondary text-secondary-foreground rounded-lg hover:bg-secondary/90 transition-colors"
            >
              <ArrowLeft className="size-5" />
              Torna al Login
            </Link>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-background p-4">
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <h1 className="text-4xl font-bold text-primary mb-2">YouBook</h1>
          <p className="text-muted-foreground">Recupera la tua password</p>
        </div>

        <div className="bg-card border border-border rounded-xl p-8 shadow-sm">
          <h2 className="text-2xl font-medium mb-2">Recupera password</h2>
          <p className="text-sm text-muted-foreground mb-6">
            Inserisci il tuo indirizzo email e ti invieremo un link per reimpostare la password
          </p>

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label htmlFor="email" className="block text-sm font-medium mb-2">
                Email
              </label>
              <div className="relative">
                <Mail className="absolute left-3 top-1/2 -translate-y-1/2 size-5 text-muted-foreground" />
                <input
                  id="email"
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="nome@esempio.it"
                  required
                  className="w-full pl-11 pr-4 py-3 bg-input-background border border-border rounded-lg focus:outline-none focus:ring-2 focus:ring-ring"
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full flex items-center justify-center gap-2 px-6 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              <Send className="size-5" />
              {loading ? 'Invio in corso...' : 'Invia link di recupero'}
            </button>
          </form>

          <div className="mt-6 text-center">
            <Link
              to="/"
              className="inline-flex items-center gap-2 text-sm text-primary hover:underline"
            >
              <ArrowLeft className="size-4" />
              Torna al login
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
