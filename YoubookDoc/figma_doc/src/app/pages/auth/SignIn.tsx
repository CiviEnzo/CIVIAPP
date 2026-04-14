import { useState } from 'react';
import { Link, useNavigate } from 'react-router';
import { Mail, Lock, LogIn } from 'lucide-react';
import { toast } from 'sonner';

// Auth/SignIn/Form/Default/Default
export default function SignIn() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    try {
      // Simulate login - replace with actual Supabase auth
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      // Mock routing based on user role
      const mockRole = email.includes('admin') ? 'admin' : email.includes('staff') ? 'staff' : 'client';
      
      toast.success('Accesso effettuato con successo');
      
      if (mockRole === 'admin') {
        navigate('/admin');
      } else if (mockRole === 'staff') {
        navigate('/staff');
      } else {
        navigate('/client');
      }
    } catch (error) {
      toast.error('Errore durante l\'accesso');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-background p-4">
      <div className="w-full max-w-md">
        {/* Logo/Brand */}
        <div className="text-center mb-8">
          <h1 className="text-4xl font-bold text-primary mb-2">YouBook</h1>
          <p className="text-muted-foreground">Gestione professionale per il tuo salone</p>
        </div>

        {/* Sign In Card */}
        <div className="bg-card border border-border rounded-xl p-8 shadow-sm">
          <h2 className="text-2xl font-medium mb-6">Accedi</h2>

          <form onSubmit={handleSubmit} className="space-y-4">
            {/* Email Input */}
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

            {/* Password Input */}
            <div>
              <label htmlFor="password" className="block text-sm font-medium mb-2">
                Password
              </label>
              <div className="relative">
                <Lock className="absolute left-3 top-1/2 -translate-y-1/2 size-5 text-muted-foreground" />
                <input
                  id="password"
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  required
                  className="w-full pl-11 pr-4 py-3 bg-input-background border border-border rounded-lg focus:outline-none focus:ring-2 focus:ring-ring"
                />
              </div>
            </div>

            {/* Forgot Password Link */}
            <div className="text-right">
              <Link
                to="/password-reset"
                className="text-sm text-primary hover:underline"
              >
                Hai dimenticato la password?
              </Link>
            </div>

            {/* Submit Button */}
            <button
              type="submit"
              disabled={loading}
              className="w-full flex items-center justify-center gap-2 px-6 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              <LogIn className="size-5" />
              {loading ? 'Accesso in corso...' : 'Accedi'}
            </button>
          </form>

          {/* Divider */}
          <div className="relative my-6">
            <div className="absolute inset-0 flex items-center">
              <div className="w-full border-t border-border"></div>
            </div>
            <div className="relative flex justify-center text-sm">
              <span className="px-4 bg-card text-muted-foreground">oppure</span>
            </div>
          </div>

          {/* Register Links */}
          <div className="space-y-2 text-center text-sm">
            <div>
              <span className="text-muted-foreground">Non hai un account? </span>
              <Link to="/register" className="text-primary hover:underline font-medium">
                Registrati come cliente
              </Link>
            </div>
            <div>
              <Link to="/register-center" className="text-primary hover:underline font-medium">
                Registrati come centro
              </Link>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
