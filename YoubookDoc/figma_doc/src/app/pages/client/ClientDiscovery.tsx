import { useState } from 'react';
import { useNavigate } from 'react-router';
import { Search, MapPin, Star, ArrowRight } from 'lucide-react';
import { toast } from 'sonner';

// Client/Discovery/SalonList/Mobile/Default
export default function ClientDiscovery() {
  const [searchQuery, setSearchQuery] = useState('');
  const navigate = useNavigate();

  const salons = [
    {
      id: '1',
      name: 'Salone Bellezza Milano',
      address: 'Via Roma 10, Milano',
      rating: 4.8,
      reviews: 124,
      distance: '0.5 km'
    },
    {
      id: '2',
      name: 'Hair Studio Roma',
      address: 'Via del Corso 45, Roma',
      rating: 4.6,
      reviews: 89,
      distance: '1.2 km'
    },
    {
      id: '3',
      name: 'Beauty Center Firenze',
      address: 'Piazza Duomo 3, Firenze',
      rating: 4.9,
      reviews: 156,
      distance: '2.1 km'
    },
  ];

  const filteredSalons = salons.filter(salon =>
    salon.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    salon.address.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const handleSelectSalon = (salonId: string) => {
    toast.success('Salone selezionato');
    navigate('/client/dashboard');
  };

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="bg-card border-b border-border">
        <div className="px-4 py-6">
          <h1 className="text-3xl font-bold text-primary mb-2">YouBook</h1>
          <p className="text-muted-foreground">Scegli il tuo salone preferito</p>
        </div>
      </header>

      {/* Search */}
      <div className="p-4">
        <div className="relative mb-6">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 size-5 text-muted-foreground" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Cerca salone..."
            className="w-full pl-11 pr-4 py-3 bg-input-background border border-border rounded-lg focus:outline-none focus:ring-2 focus:ring-ring"
          />
        </div>

        {/* Salons List */}
        <div className="space-y-4 max-w-2xl mx-auto">
          {filteredSalons.map((salon) => (
            <button
              key={salon.id}
              onClick={() => handleSelectSalon(salon.id)}
              className="w-full bg-card border border-border rounded-xl p-5 hover:border-primary transition-all text-left"
            >
              <div className="flex items-start justify-between gap-4 mb-3">
                <div className="flex-1 min-w-0">
                  <h3 className="font-medium text-lg mb-2">{salon.name}</h3>
                  <div className="flex items-start gap-2 text-sm text-muted-foreground mb-2">
                    <MapPin className="size-4 flex-shrink-0 mt-0.5" />
                    <span>{salon.address}</span>
                  </div>
                  <div className="flex items-center gap-4 text-sm">
                    <div className="flex items-center gap-1">
                      <Star className="size-4 fill-primary text-primary" />
                      <span className="font-medium">{salon.rating}</span>
                      <span className="text-muted-foreground">({salon.reviews})</span>
                    </div>
                    <span className="text-muted-foreground">{salon.distance}</span>
                  </div>
                </div>
                <ArrowRight className="size-5 text-muted-foreground flex-shrink-0" />
              </div>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
