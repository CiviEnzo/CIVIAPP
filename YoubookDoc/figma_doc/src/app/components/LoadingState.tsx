import { Loader2 } from 'lucide-react';

interface LoadingStateProps {
  message?: string;
}

// Shared/LoadingState/Spinner/Default/Default
export default function LoadingState({ message = 'Caricamento...' }: LoadingStateProps) {
  return (
    <div className="flex flex-col items-center justify-center py-12">
      <Loader2 className="size-8 text-primary animate-spin mb-4" />
      <p className="text-muted-foreground">{message}</p>
    </div>
  );
}
