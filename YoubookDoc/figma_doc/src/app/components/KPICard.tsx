import { LucideIcon } from 'lucide-react';

interface KPICardProps {
  title: string;
  value: string | number;
  subtitle?: string;
  icon: LucideIcon;
  trend?: {
    value: string;
    positive: boolean;
  };
  onClick?: () => void;
}

// Shared/KPI/Card/Default/Default
export default function KPICard({ title, value, subtitle, icon: Icon, trend, onClick }: KPICardProps) {
  const Component = onClick ? 'button' : 'div';

  return (
    <Component
      onClick={onClick}
      className={`bg-card border border-border rounded-xl p-6 ${
        onClick ? 'hover:border-primary cursor-pointer transition-all' : ''
      }`}
    >
      <div className="flex items-start justify-between mb-4">
        <div className="w-12 h-12 bg-primary/10 rounded-lg flex items-center justify-center">
          <Icon className="size-6 text-primary" />
        </div>
        {trend && (
          <span className={`text-sm font-medium px-2 py-1 rounded-full ${
            trend.positive ? 'bg-success/10 text-success' : 'bg-error/10 text-error'
          }`}>
            {trend.value}
          </span>
        )}
      </div>

      <h3 className="text-sm font-medium text-muted-foreground mb-1">{title}</h3>
      <p className="text-3xl font-bold mb-1">{value}</p>
      {subtitle && (
        <p className="text-sm text-muted-foreground">{subtitle}</p>
      )}
    </Component>
  );
}
