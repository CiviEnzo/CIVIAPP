import { ReactNode } from 'react';
import { ChevronDown, ChevronUp } from 'lucide-react';

interface Column<T> {
  key: keyof T | string;
  label: string;
  sortable?: boolean;
  render?: (item: T) => ReactNode;
  className?: string;
}

interface DataTableProps<T> {
  columns: Column<T>[];
  data: T[];
  keyExtractor: (item: T) => string | number;
  onRowClick?: (item: T) => void;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
  onSort?: (key: string) => void;
  emptyMessage?: string;
}

// Shared/DataTable/Table/Responsive/Default
export default function DataTable<T>({
  columns,
  data,
  keyExtractor,
  onRowClick,
  sortBy,
  sortOrder,
  onSort,
  emptyMessage = 'Nessun dato disponibile'
}: DataTableProps<T>) {
  if (data.length === 0) {
    return (
      <div className="bg-card border border-border rounded-xl p-8 text-center">
        <p className="text-muted-foreground">{emptyMessage}</p>
      </div>
    );
  }

  return (
    <div className="bg-card border border-border rounded-xl overflow-hidden">
      {/* Desktop Table */}
      <div className="hidden md:block overflow-x-auto">
        <table className="w-full">
          <thead className="bg-muted border-b border-border">
            <tr>
              {columns.map((column) => (
                <th
                  key={String(column.key)}
                  className={`px-6 py-4 text-left text-sm font-semibold ${column.className || ''}`}
                >
                  {column.sortable && onSort ? (
                    <button
                      onClick={() => onSort(String(column.key))}
                      className="flex items-center gap-2 hover:text-primary transition-colors"
                    >
                      {column.label}
                      {sortBy === column.key && (
                        sortOrder === 'asc' ? 
                          <ChevronUp className="size-4" /> : 
                          <ChevronDown className="size-4" />
                      )}
                    </button>
                  ) : (
                    column.label
                  )}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-border">
            {data.map((item) => (
              <tr
                key={keyExtractor(item)}
                onClick={() => onRowClick?.(item)}
                className={`hover:bg-muted/50 transition-colors ${onRowClick ? 'cursor-pointer' : ''}`}
              >
                {columns.map((column) => (
                  <td
                    key={String(column.key)}
                    className={`px-6 py-4 text-sm ${column.className || ''}`}
                  >
                    {column.render
                      ? column.render(item)
                      : String(item[column.key as keyof T] || '-')}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Mobile Cards */}
      <div className="md:hidden divide-y divide-border">
        {data.map((item) => (
          <div
            key={keyExtractor(item)}
            onClick={() => onRowClick?.(item)}
            className={`p-4 hover:bg-muted/50 transition-colors ${onRowClick ? 'cursor-pointer' : ''}`}
          >
            {columns.map((column) => (
              <div key={String(column.key)} className="flex justify-between py-2">
                <span className="text-sm font-medium text-muted-foreground">
                  {column.label}
                </span>
                <span className="text-sm font-medium">
                  {column.render
                    ? column.render(item)
                    : String(item[column.key as keyof T] || '-')}
                </span>
              </div>
            ))}
          </div>
        ))}
      </div>
    </div>
  );
}
