import { AlertCircle, RefreshCw } from 'lucide-react';

interface ErrorStateProps {
  title?: string;
  message: string;
  onRetry?: () => void;
}

// Shared/ErrorState/Alert/Default/Default
export default function ErrorState({ 
  title = 'Si è verificato un errore', 
  message,
  onRetry 
}: ErrorStateProps) {
  return (
    <div className="flex flex-col items-center justify-center py-12 px-4 text-center">
      <div className="w-16 h-16 bg-error/10 rounded-full flex items-center justify-center mb-4">
        <AlertCircle className="size-8 text-error" />
      </div>
      <h3 className="text-lg font-medium mb-2">{title}</h3>
      <p className="text-muted-foreground mb-6 max-w-sm">{message}</p>
      {onRetry && (
        <button
          onClick={onRetry}
          className="flex items-center gap-2 px-6 py-3 bg-secondary text-secondary-foreground rounded-lg hover:bg-secondary-hover transition-colors"
        >
          <RefreshCw className="size-4" />
          Riprova
        </button>
      )}
    </div>
  );
}
