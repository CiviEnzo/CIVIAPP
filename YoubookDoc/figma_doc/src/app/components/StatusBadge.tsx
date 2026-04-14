import { CheckCircle, Clock, XCircle, AlertCircle, Package } from 'lucide-react';

type StatusType = 'success' | 'pending' | 'cancelled' | 'warning' | 'info' | 'active' | 'inactive';

interface StatusBadgeProps {
  status: StatusType;
  label: string;
  size?: 'sm' | 'md';
}

const statusConfig = {
  success: {
    bg: 'bg-success/10',
    text: 'text-success',
    icon: CheckCircle
  },
  pending: {
    bg: 'bg-warning/10',
    text: 'text-warning',
    icon: Clock
  },
  cancelled: {
    bg: 'bg-error/10',
    text: 'text-error',
    icon: XCircle
  },
  warning: {
    bg: 'bg-warning/10',
    text: 'text-warning',
    icon: AlertCircle
  },
  info: {
    bg: 'bg-info/10',
    text: 'text-info',
    icon: AlertCircle
  },
  active: {
    bg: 'bg-success/10',
    text: 'text-success',
    icon: Package
  },
  inactive: {
    bg: 'bg-muted',
    text: 'text-muted-foreground',
    icon: Package
  }
};

// Shared/StatusBadge/Badge/Default/Default
export default function StatusBadge({ status, label, size = 'md' }: StatusBadgeProps) {
  const config = statusConfig[status];
  const Icon = config.icon;
  
  const sizeClasses = size === 'sm' 
    ? 'px-2 py-1 text-xs gap-1' 
    : 'px-3 py-1.5 text-sm gap-2';

  return (
    <span className={`inline-flex items-center rounded-full font-medium ${config.bg} ${config.text} ${sizeClasses}`}>
      <Icon className={size === 'sm' ? 'size-3' : 'size-4'} />
      {label}
    </span>
  );
}
