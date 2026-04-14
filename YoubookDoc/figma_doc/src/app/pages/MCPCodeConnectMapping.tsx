import { 
  Calendar, Euro, Users, Package, CreditCard, Bell,
  TrendingUp, ShoppingCart, FileText, Award, Settings,
  CheckCircle, Clock, XCircle, ChevronRight, Copy, Code
} from 'lucide-react';
import { useState } from 'react';
import { toast } from 'sonner';

/**
 * 50_MCP_Code_Connect_Mapping
 * 
 * Mapping completo tra componenti Figma Design System YouBook
 * e destinazione prevista in codice Flutter per implementazione mobile.
 * 
 * Priorità: Agenda, AppointmentCard, KPI, Drawer Items, Quote/Payment, Notifications
 */

interface ComponentMapping {
  id: string;
  figmaName: string;
  role: 'Admin' | 'Staff' | 'Client' | 'Shared';
  area: string;
  component: string;
  variant: string;
  state: string;
  fullPath: string;
  flutterWidget: string;
  flutterFile: string;
  props: string[];
  priority: 'P0' | 'P1' | 'P2';
  complexity: 'Simple' | 'Medium' | 'Complex';
  dependencies: string[];
  notes?: string;
}

const componentMappings: ComponentMapping[] = [
  // =====================================
  // PRIORITY 0 - AGENDA COMPONENTS
  // =====================================
  {
    id: 'agenda-001',
    figmaName: 'Admin Appointment Card',
    role: 'Admin',
    area: 'Agenda',
    component: 'AppointmentCard',
    variant: 'Grid',
    state: 'Default',
    fullPath: 'Admin/Agenda/AppointmentCard/Grid/Default',
    flutterWidget: 'AdminAppointmentCard',
    flutterFile: 'lib/widgets/admin/agenda/appointment_card.dart',
    props: [
      'String id',
      'String serviceName',
      'String clientName',
      'String staffName',
      'DateTime startTime',
      'DateTime endTime',
      'AppointmentStatus status',
      'VoidCallback? onTap',
      'VoidCallback? onEdit',
      'VoidCallback? onCancel'
    ],
    priority: 'P0',
    complexity: 'Medium',
    dependencies: ['StatusBadge', 'Avatar'],
    notes: 'Vista calendario grid con hover actions'
  },
  {
    id: 'agenda-002',
    figmaName: 'Staff Appointment Card',
    role: 'Staff',
    area: 'Agenda',
    component: 'AppointmentCard',
    variant: 'Compact',
    state: 'Default',
    fullPath: 'Staff/Agenda/AppointmentCard/Compact/Default',
    flutterWidget: 'StaffAppointmentCard',
    flutterFile: 'lib/widgets/staff/agenda/appointment_card.dart',
    props: [
      'String id',
      'String serviceName',
      'String clientName',
      'DateTime startTime',
      'int duration',
      'AppointmentStatus status',
      'VoidCallback? onTap',
      'bool isCompact'
    ],
    priority: 'P0',
    complexity: 'Medium',
    dependencies: ['StatusBadge', 'ClientAvatar'],
    notes: 'Vista giorno (expanded) vs settimana (compact)'
  },
  {
    id: 'agenda-003',
    figmaName: 'Client Appointment Card',
    role: 'Client',
    area: 'Agenda',
    component: 'AppointmentCard',
    variant: 'Full',
    state: 'Default',
    fullPath: 'Client/Agenda/AppointmentCard/Full/Default',
    flutterWidget: 'ClientAppointmentCard',
    flutterFile: 'lib/widgets/client/agenda/appointment_card.dart',
    props: [
      'String id',
      'String serviceName',
      'String staffName',
      'DateTime date',
      'String time',
      'int duration',
      'double price',
      'AppointmentStatus status',
      'VoidCallback? onModify',
      'VoidCallback? onCancel',
      'VoidCallback? onRebook',
      'bool isHistory'
    ],
    priority: 'P0',
    complexity: 'Complex',
    dependencies: ['StatusBadge', 'IconButton', 'PriceLabel'],
    notes: 'Full details con actions (modifica/annulla) o "Prenota di nuovo"'
  },

  // =====================================
  // PRIORITY 0 - KPI CARDS
  // =====================================
  {
    id: 'kpi-001',
    figmaName: 'Admin KPI Card',
    role: 'Admin',
    area: 'Dashboard',
    component: 'KPI',
    variant: 'Card',
    state: 'Default',
    fullPath: 'Admin/Dashboard/KPI/Card/Default',
    flutterWidget: 'KPICard',
    flutterFile: 'lib/widgets/shared/dashboard/kpi_card.dart',
    props: [
      'String label',
      'String value',
      'IconData icon',
      'Color color',
      'Trend? trend',
      'VoidCallback? onTap'
    ],
    priority: 'P0',
    complexity: 'Simple',
    dependencies: ['TrendIndicator'],
    notes: 'Usato in Admin Dashboard per 4 KPI principali. Trend opzionale con +/- e colore'
  },
  {
    id: 'kpi-002',
    figmaName: 'Admin KPI Card - With Trend',
    role: 'Admin',
    area: 'Dashboard',
    component: 'KPI',
    variant: 'Card',
    state: 'Hover',
    fullPath: 'Admin/Dashboard/KPI/Card/Hover',
    flutterWidget: 'KPICard',
    flutterFile: 'lib/widgets/shared/dashboard/kpi_card.dart',
    props: ['Same as kpi-001', 'bool isHovered'],
    priority: 'P1',
    complexity: 'Simple',
    dependencies: ['TrendIndicator'],
    notes: 'Hover state con shadow aumentata e trend animato'
  },

  // =====================================
  // PRIORITY 1 - DRAWER ITEMS
  // =====================================
  {
    id: 'drawer-001',
    figmaName: 'Client Drawer Item',
    role: 'Client',
    area: 'Dashboard',
    component: 'DrawerItem',
    variant: 'Default',
    state: 'Default',
    fullPath: 'Client/Dashboard/DrawerItem/Default',
    flutterWidget: 'DrawerMenuItem',
    flutterFile: 'lib/widgets/client/drawer/drawer_menu_item.dart',
    props: [
      'IconData icon',
      'String label',
      'String? badge',
      'VoidCallback onTap',
      'bool isActive'
    ],
    priority: 'P1',
    complexity: 'Simple',
    dependencies: ['Badge'],
    notes: 'Usato 7 volte: Loyalty, Packages, Quotes, Invoices, Surveys, Photos, Settings'
  },
  {
    id: 'drawer-002',
    figmaName: 'Client Drawer Item - With Badge',
    role: 'Client',
    area: 'Dashboard',
    component: 'DrawerItem',
    variant: 'WithBadge',
    state: 'Default',
    fullPath: 'Client/Dashboard/DrawerItem/WithBadge',
    flutterWidget: 'DrawerMenuItem',
    flutterFile: 'lib/widgets/client/drawer/drawer_menu_item.dart',
    props: ['Same as drawer-001'],
    priority: 'P1',
    complexity: 'Simple',
    dependencies: ['Badge'],
    notes: 'Badge può essere numero (es. "3") o testo (es. "420 punti")'
  },

  // =====================================
  // PRIORITY 1 - QUOTE & PAYMENT CARDS
  // =====================================
  {
    id: 'quote-001',
    figmaName: 'Client Quote Card',
    role: 'Client',
    area: 'Quotes',
    component: 'QuoteCard',
    variant: 'List',
    state: 'Pending',
    fullPath: 'Client/Quotes/QuoteCard/List/Pending',
    flutterWidget: 'QuoteCard',
    flutterFile: 'lib/widgets/client/quotes/quote_card.dart',
    props: [
      'String id',
      'String name',
      'List<String> services',
      'double total',
      'QuoteStatus status',
      'DateTime date',
      'VoidCallback? onTap',
      'VoidCallback? onPay'
    ],
    priority: 'P1',
    complexity: 'Medium',
    dependencies: ['StatusBadge', 'ServiceList', 'PriceLabel'],
    notes: 'Stati: Pending (warning), Expired (error), Accepted (success)'
  },
  {
    id: 'quote-002',
    figmaName: 'Client Quote Card - Expired',
    role: 'Client',
    area: 'Quotes',
    component: 'QuoteCard',
    variant: 'List',
    state: 'Expired',
    fullPath: 'Client/Quotes/QuoteCard/List/Expired',
    flutterWidget: 'QuoteCard',
    flutterFile: 'lib/widgets/client/quotes/quote_card.dart',
    props: ['Same as quote-001'],
    priority: 'P1',
    complexity: 'Medium',
    dependencies: ['StatusBadge', 'ServiceList', 'PriceLabel'],
    notes: 'Action: "Rigenera Preventivo" invece di "Paga"'
  },
  {
    id: 'payment-001',
    figmaName: 'Client Stripe Payment Form',
    role: 'Client',
    area: 'Payment',
    component: 'StripeForm',
    variant: 'Default',
    state: 'Default',
    fullPath: 'Client/Payment/StripeForm/Default',
    flutterWidget: 'StripePaymentForm',
    flutterFile: 'lib/widgets/client/payment/stripe_payment_form.dart',
    props: [
      'double amount',
      'Future<void> Function(PaymentData) onSubmit',
      'VoidCallback? onCancel'
    ],
    priority: 'P1',
    complexity: 'Complex',
    dependencies: ['TextFormField', 'StripeSDK', 'LoadingButton'],
    notes: 'Form con validazione Luhn per carta, MM/YY per scadenza, 3 digit per CVV'
  },
  {
    id: 'payment-002',
    figmaName: 'Client Stripe Payment Form - Loading',
    role: 'Client',
    area: 'Payment',
    component: 'StripeForm',
    variant: 'Default',
    state: 'Loading',
    fullPath: 'Client/Payment/StripeForm/Loading',
    flutterWidget: 'StripePaymentForm',
    flutterFile: 'lib/widgets/client/payment/stripe_payment_form.dart',
    props: ['Same as payment-001', 'bool isLoading'],
    priority: 'P1',
    complexity: 'Complex',
    dependencies: ['TextFormField', 'StripeSDK', 'LoadingButton', 'CircularProgressIndicator'],
    notes: 'Form disabilitato con loading spinner nel button'
  },
  {
    id: 'invoice-001',
    figmaName: 'Client Invoice Card',
    role: 'Client',
    area: 'Invoices',
    component: 'InvoiceCard',
    variant: 'List',
    state: 'Default',
    fullPath: 'Client/Invoices/InvoiceCard/List/Default',
    flutterWidget: 'InvoiceCard',
    flutterFile: 'lib/widgets/client/invoices/invoice_card.dart',
    props: [
      'String id',
      'DateTime date',
      'double amount',
      'InvoiceStatus status',
      'VoidCallback? onDownload',
      'VoidCallback? onCopy',
      'VoidCallback? onPay'
    ],
    priority: 'P1',
    complexity: 'Medium',
    dependencies: ['StatusBadge', 'IconButton', 'PriceLabel'],
    notes: 'Stati: Paid (success), Pending (warning), Overdue (error)'
  },

  // =====================================
  // PRIORITY 1 - NOTIFICATION CARDS
  // =====================================
  {
    id: 'notification-001',
    figmaName: 'Client Notification Card',
    role: 'Client',
    area: 'Notifications',
    component: 'NotificationCard',
    variant: 'List',
    state: 'Unread',
    fullPath: 'Client/Notifications/NotificationCard/List/Unread',
    flutterWidget: 'NotificationCard',
    flutterFile: 'lib/widgets/client/notifications/notification_card.dart',
    props: [
      'String id',
      'NotificationType type',
      'String title',
      'String message',
      'String time',
      'bool isRead',
      'VoidCallback? onTap',
      'VoidCallback? onMarkRead'
    ],
    priority: 'P1',
    complexity: 'Simple',
    dependencies: ['ReadIndicator'],
    notes: 'Unread: bg-primary/10, border-primary/20, dot primary'
  },
  {
    id: 'notification-002',
    figmaName: 'Client Notification Card - Read',
    role: 'Client',
    area: 'Notifications',
    component: 'NotificationCard',
    variant: 'List',
    state: 'Read',
    fullPath: 'Client/Notifications/NotificationCard/List/Read',
    flutterWidget: 'NotificationCard',
    flutterFile: 'lib/widgets/client/notifications/notification_card.dart',
    props: ['Same as notification-001'],
    priority: 'P1',
    complexity: 'Simple',
    dependencies: ['ReadIndicator'],
    notes: 'Read: bg-card, border-border, dot muted'
  },

  // =====================================
  // PRIORITY 2 - SHARED COMPONENTS
  // =====================================
  {
    id: 'shared-001',
    figmaName: 'Status Badge',
    role: 'Shared',
    area: 'Badge',
    component: 'Status',
    variant: 'Chip',
    state: 'Default',
    fullPath: 'Shared/Badge/Status/Chip/Default',
    flutterWidget: 'StatusBadge',
    flutterFile: 'lib/widgets/shared/badge/status_badge.dart',
    props: [
      'BadgeStatus status',
      'String label',
      'BadgeSize size'
    ],
    priority: 'P2',
    complexity: 'Simple',
    dependencies: [],
    notes: 'Stati: success (green), pending (warning), cancelled (error), info (blue)'
  },
  {
    id: 'shared-002',
    figmaName: 'Data Table',
    role: 'Shared',
    area: 'Table',
    component: 'Data',
    variant: 'Responsive',
    state: 'Default',
    fullPath: 'Shared/Table/Data/Responsive/Default',
    flutterWidget: 'DataTable',
    flutterFile: 'lib/widgets/shared/table/data_table.dart',
    props: [
      'List<TableColumn> columns',
      'List<TableRow> rows',
      'bool isSortable',
      'String? sortColumn',
      'SortDirection? sortDirection',
      'bool isResponsive'
    ],
    priority: 'P2',
    complexity: 'Complex',
    dependencies: ['TableHeader', 'TableCell', 'SortIcon'],
    notes: 'Desktop: table, Mobile: cards. Auto-empty state.'
  },
  {
    id: 'shared-003',
    figmaName: 'Loading State',
    role: 'Shared',
    area: 'States',
    component: 'Loading',
    variant: 'Centered',
    state: 'Spinner',
    fullPath: 'Shared/States/Loading/Centered/Spinner',
    flutterWidget: 'LoadingState',
    flutterFile: 'lib/widgets/shared/states/loading_state.dart',
    props: [
      'String? message',
      'Color? color',
      'double? size'
    ],
    priority: 'P2',
    complexity: 'Simple',
    dependencies: ['CircularProgressIndicator'],
    notes: 'Centered spinner con messaggio opzionale sotto'
  },
  {
    id: 'shared-004',
    figmaName: 'Empty State',
    role: 'Shared',
    area: 'States',
    component: 'Empty',
    variant: 'Centered',
    state: 'Icon',
    fullPath: 'Shared/States/Empty/Centered/Icon',
    flutterWidget: 'EmptyState',
    flutterFile: 'lib/widgets/shared/states/empty_state.dart',
    props: [
      'IconData icon',
      'String title',
      'String description',
      'String? actionLabel',
      'VoidCallback? onAction'
    ],
    priority: 'P2',
    complexity: 'Simple',
    dependencies: ['ElevatedButton'],
    notes: 'Icon + title + description + optional action button'
  },
  {
    id: 'shared-005',
    figmaName: 'Error State',
    role: 'Shared',
    area: 'States',
    component: 'Error',
    variant: 'Centered',
    state: 'Retry',
    fullPath: 'Shared/States/Error/Centered/Retry',
    flutterWidget: 'ErrorState',
    flutterFile: 'lib/widgets/shared/states/error_state.dart',
    props: [
      'String title',
      'String message',
      'VoidCallback? onRetry'
    ],
    priority: 'P2',
    complexity: 'Simple',
    dependencies: ['ElevatedButton'],
    notes: 'Error icon + title + message + retry button'
  },

  // =====================================
  // PRIORITY 2 - ADDITIONAL COMPONENTS
  // =====================================
  {
    id: 'client-001',
    figmaName: 'Client Welcome Card',
    role: 'Client',
    area: 'Home',
    component: 'WelcomeCard',
    variant: 'Gradient',
    state: 'Default',
    fullPath: 'Client/Home/WelcomeCard/Gradient/Default',
    flutterWidget: 'WelcomeCard',
    flutterFile: 'lib/widgets/client/home/welcome_card.dart',
    props: [
      'String userName',
      'int loyaltyPoints',
      'VoidCallback? onUsePoints'
    ],
    priority: 'P2',
    complexity: 'Simple',
    dependencies: ['GradientContainer', 'StarIcon'],
    notes: 'Gradient gold con nome utente e punti fedeltà'
  },
  {
    id: 'client-002',
    figmaName: 'Client Next Appointment Card',
    role: 'Client',
    area: 'Home',
    component: 'NextAppointment',
    variant: 'Card',
    state: 'Default',
    fullPath: 'Client/Home/NextAppointment/Card/Default',
    flutterWidget: 'NextAppointmentCard',
    flutterFile: 'lib/widgets/client/home/next_appointment_card.dart',
    props: [
      'String serviceName',
      'String staffName',
      'DateTime date',
      'String time',
      'VoidCallback? onModify'
    ],
    priority: 'P2',
    complexity: 'Simple',
    dependencies: ['CalendarIcon', 'Button'],
    notes: 'Card con icona calendario e CTA "Modifica"'
  },
  {
    id: 'client-003',
    figmaName: 'Client Package Card',
    role: 'Client',
    area: 'Packages',
    component: 'PackageCard',
    variant: 'Default',
    state: 'Active',
    fullPath: 'Client/Packages/PackageCard/Default/Active',
    flutterWidget: 'PackageCard',
    flutterFile: 'lib/widgets/client/packages/package_card.dart',
    props: [
      'String id',
      'String name',
      'int total',
      'int used',
      'double price',
      'DateTime expiresAt',
      'PackageStatus status',
      'VoidCallback? onUse'
    ],
    priority: 'P2',
    complexity: 'Medium',
    dependencies: ['StatusBadge', 'ProgressBar', 'PriceLabel'],
    notes: 'Progress bar per utilizzo, stati: Active (success), Expired (cancelled)'
  },
  {
    id: 'staff-001',
    figmaName: 'Staff Time Off Request Card',
    role: 'Staff',
    area: 'TimeOff',
    component: 'RequestCard',
    variant: 'List',
    state: 'Default',
    fullPath: 'Staff/TimeOff/RequestCard/List/Default',
    flutterWidget: 'TimeOffRequestCard',
    flutterFile: 'lib/widgets/staff/time_off/request_card.dart',
    props: [
      'String id',
      'TimeOffType type',
      'DateTime startDate',
      'DateTime endDate',
      'int days',
      'RequestStatus status',
      'String? rejectionReason',
      'DateTime createdAt'
    ],
    priority: 'P2',
    complexity: 'Medium',
    dependencies: ['StatusBadge', 'Timeline', 'DateRangeLabel'],
    notes: 'Stati: Pending (warning), Approved (success), Rejected (error con motivo)'
  },
];

// =====================================
// MAIN COMPONENT
// =====================================

export default function MCPCodeConnectMapping() {
  const [filter, setFilter] = useState<'all' | 'P0' | 'P1' | 'P2'>('all');
  const [roleFilter, setRoleFilter] = useState<string>('all');
  const [selectedComponent, setSelectedComponent] = useState<ComponentMapping | null>(null);

  const filteredMappings = componentMappings.filter(m => {
    if (filter !== 'all' && m.priority !== filter) return false;
    if (roleFilter !== 'all' && m.role !== roleFilter) return false;
    return true;
  });

  const copyFlutterCode = (mapping: ComponentMapping) => {
    const code = generateFlutterCode(mapping);
    navigator.clipboard.writeText(code);
    toast.success('Codice Flutter copiato!');
  };

  return (
    <div className="min-h-screen bg-background p-4 lg:p-8">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-4xl font-bold mb-2">50_MCP_Code_Connect_Mapping</h1>
          <p className="text-muted-foreground">
            Mapping completo Figma → Flutter per YouBook Design System
          </p>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <div className="bg-card border border-border rounded-xl p-4">
            <p className="text-sm text-muted-foreground mb-1">Totale Componenti</p>
            <p className="text-3xl font-bold text-primary">{componentMappings.length}</p>
          </div>
          <div className="bg-card border border-border rounded-xl p-4">
            <p className="text-sm text-muted-foreground mb-1">Priority P0</p>
            <p className="text-3xl font-bold text-error">
              {componentMappings.filter(m => m.priority === 'P0').length}
            </p>
          </div>
          <div className="bg-card border border-border rounded-xl p-4">
            <p className="text-sm text-muted-foreground mb-1">Priority P1</p>
            <p className="text-3xl font-bold text-warning">
              {componentMappings.filter(m => m.priority === 'P1').length}
            </p>
          </div>
          <div className="bg-card border border-border rounded-xl p-4">
            <p className="text-sm text-muted-foreground mb-1">Priority P2</p>
            <p className="text-3xl font-bold text-info">
              {componentMappings.filter(m => m.priority === 'P2').length}
            </p>
          </div>
        </div>

        {/* Filters */}
        <div className="bg-card border border-border rounded-xl p-6 mb-6">
          <h3 className="font-semibold mb-4">Filtri</h3>
          <div className="flex flex-wrap gap-3">
            <div className="flex gap-2">
              <button
                onClick={() => setFilter('all')}
                className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                  filter === 'all'
                    ? 'bg-primary text-primary-foreground'
                    : 'bg-muted text-foreground hover:bg-muted/80'
                }`}
              >
                Tutte ({componentMappings.length})
              </button>
              <button
                onClick={() => setFilter('P0')}
                className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                  filter === 'P0'
                    ? 'bg-error text-white'
                    : 'bg-muted text-foreground hover:bg-muted/80'
                }`}
              >
                P0 ({componentMappings.filter(m => m.priority === 'P0').length})
              </button>
              <button
                onClick={() => setFilter('P1')}
                className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                  filter === 'P1'
                    ? 'bg-warning text-white'
                    : 'bg-muted text-foreground hover:bg-muted/80'
                }`}
              >
                P1 ({componentMappings.filter(m => m.priority === 'P1').length})
              </button>
              <button
                onClick={() => setFilter('P2')}
                className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                  filter === 'P2'
                    ? 'bg-info text-white'
                    : 'bg-muted text-foreground hover:bg-muted/80'
                }`}
              >
                P2 ({componentMappings.filter(m => m.priority === 'P2').length})
              </button>
            </div>

            <div className="border-l border-border pl-3 flex gap-2">
              <button
                onClick={() => setRoleFilter('all')}
                className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                  roleFilter === 'all'
                    ? 'bg-primary text-primary-foreground'
                    : 'bg-muted text-foreground hover:bg-muted/80'
                }`}
              >
                Tutti i Ruoli
              </button>
              <button
                onClick={() => setRoleFilter('Admin')}
                className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                  roleFilter === 'Admin'
                    ? 'bg-primary text-primary-foreground'
                    : 'bg-muted text-foreground hover:bg-muted/80'
                }`}
              >
                Admin
              </button>
              <button
                onClick={() => setRoleFilter('Staff')}
                className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                  roleFilter === 'Staff'
                    ? 'bg-primary text-primary-foreground'
                    : 'bg-muted text-foreground hover:bg-muted/80'
                }`}
              >
                Staff
              </button>
              <button
                onClick={() => setRoleFilter('Client')}
                className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                  roleFilter === 'Client'
                    ? 'bg-primary text-primary-foreground'
                    : 'bg-muted text-foreground hover:bg-muted/80'
                }`}
              >
                Client
              </button>
              <button
                onClick={() => setRoleFilter('Shared')}
                className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                  roleFilter === 'Shared'
                    ? 'bg-primary text-primary-foreground'
                    : 'bg-muted text-foreground hover:bg-muted/80'
                }`}
              >
                Shared
              </button>
            </div>
          </div>
        </div>

        {/* Mappings Table */}
        <div className="space-y-3">
          {filteredMappings.map((mapping) => (
            <ComponentMappingCard
              key={mapping.id}
              mapping={mapping}
              onSelect={() => setSelectedComponent(mapping)}
              onCopyCode={() => copyFlutterCode(mapping)}
            />
          ))}
        </div>

        {filteredMappings.length === 0 && (
          <div className="text-center py-12">
            <p className="text-muted-foreground">Nessun componente trovato con questi filtri</p>
          </div>
        )}

        {/* Detail Modal */}
        {selectedComponent && (
          <ComponentDetailModal
            mapping={selectedComponent}
            onClose={() => setSelectedComponent(null)}
            onCopyCode={() => copyFlutterCode(selectedComponent)}
          />
        )}
      </div>
    </div>
  );
}

// =====================================
// COMPONENT MAPPING CARD
// =====================================

interface ComponentMappingCardProps {
  mapping: ComponentMapping;
  onSelect: () => void;
  onCopyCode: () => void;
}

function ComponentMappingCard({ mapping, onSelect, onCopyCode }: ComponentMappingCardProps) {
  const priorityColors = {
    P0: 'bg-error/10 text-error border-error/30',
    P1: 'bg-warning/10 text-warning border-warning/30',
    P2: 'bg-info/10 text-info border-info/30'
  };

  const complexityColors = {
    Simple: 'text-success',
    Medium: 'text-warning',
    Complex: 'text-error'
  };

  return (
    <div className="bg-card border border-border rounded-xl p-6 hover:border-primary transition-colors">
      <div className="flex items-start justify-between mb-4">
        <div className="flex-1">
          <div className="flex items-center gap-3 mb-2">
            <h3 className="font-semibold text-lg">{mapping.figmaName}</h3>
            <span className={`text-xs px-2 py-1 rounded-full border ${priorityColors[mapping.priority]}`}>
              {mapping.priority}
            </span>
            <span className={`text-xs font-medium ${complexityColors[mapping.complexity]}`}>
              {mapping.complexity}
            </span>
          </div>
          <p className="text-sm text-muted-foreground font-mono">
            {mapping.fullPath}
          </p>
        </div>
        <div className="flex gap-2">
          <button
            onClick={(e) => {
              e.stopPropagation();
              onCopyCode();
            }}
            className="p-2 hover:bg-muted rounded-lg transition-colors"
            title="Copia codice Flutter"
          >
            <Copy className="size-4" />
          </button>
          <button
            onClick={onSelect}
            className="p-2 hover:bg-muted rounded-lg transition-colors"
            title="Vedi dettagli"
          >
            <ChevronRight className="size-4" />
          </button>
        </div>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 text-sm">
        <div>
          <p className="text-muted-foreground mb-1">Ruolo</p>
          <p className="font-medium">{mapping.role}</p>
        </div>
        <div>
          <p className="text-muted-foreground mb-1">Flutter Widget</p>
          <p className="font-medium font-mono text-primary">{mapping.flutterWidget}</p>
        </div>
        <div>
          <p className="text-muted-foreground mb-1">File Path</p>
          <p className="font-mono text-xs truncate">{mapping.flutterFile}</p>
        </div>
        <div>
          <p className="text-muted-foreground mb-1">Dependencies</p>
          <p className="font-medium">{mapping.dependencies.length} deps</p>
        </div>
      </div>

      {mapping.notes && (
        <div className="mt-4 p-3 bg-muted/50 rounded-lg">
          <p className="text-sm text-muted-foreground">{mapping.notes}</p>
        </div>
      )}
    </div>
  );
}

// =====================================
// COMPONENT DETAIL MODAL
// =====================================

interface ComponentDetailModalProps {
  mapping: ComponentMapping;
  onClose: () => void;
  onCopyCode: () => void;
}

function ComponentDetailModal({ mapping, onClose, onCopyCode }: ComponentDetailModalProps) {
  const flutterCode = generateFlutterCode(mapping);

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div className="bg-card border border-border rounded-xl max-w-4xl w-full max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="sticky top-0 bg-card border-b border-border p-6 flex items-center justify-between">
          <div>
            <h2 className="text-2xl font-bold mb-1">{mapping.figmaName}</h2>
            <p className="text-sm text-muted-foreground font-mono">{mapping.fullPath}</p>
          </div>
          <button
            onClick={onClose}
            className="p-2 hover:bg-muted rounded-lg transition-colors"
          >
            <XCircle className="size-5" />
          </button>
        </div>

        {/* Content */}
        <div className="p-6 space-y-6">
          {/* Meta Info */}
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            <div className="bg-muted/50 rounded-lg p-4">
              <p className="text-sm text-muted-foreground mb-1">Ruolo</p>
              <p className="font-semibold">{mapping.role}</p>
            </div>
            <div className="bg-muted/50 rounded-lg p-4">
              <p className="text-sm text-muted-foreground mb-1">Priority</p>
              <p className="font-semibold">{mapping.priority}</p>
            </div>
            <div className="bg-muted/50 rounded-lg p-4">
              <p className="text-sm text-muted-foreground mb-1">Complexity</p>
              <p className="font-semibold">{mapping.complexity}</p>
            </div>
            <div className="bg-muted/50 rounded-lg p-4">
              <p className="text-sm text-muted-foreground mb-1">Dependencies</p>
              <p className="font-semibold">{mapping.dependencies.length}</p>
            </div>
          </div>

          {/* Flutter Info */}
          <div>
            <h3 className="font-semibold mb-3">Flutter Implementation</h3>
            <div className="space-y-2">
              <div className="flex items-center justify-between p-3 bg-muted/50 rounded-lg">
                <span className="text-sm text-muted-foreground">Widget Name</span>
                <span className="font-mono font-medium">{mapping.flutterWidget}</span>
              </div>
              <div className="flex items-center justify-between p-3 bg-muted/50 rounded-lg">
                <span className="text-sm text-muted-foreground">File Path</span>
                <span className="font-mono text-sm">{mapping.flutterFile}</span>
              </div>
            </div>
          </div>

          {/* Props */}
          <div>
            <h3 className="font-semibold mb-3">Properties ({mapping.props.length})</h3>
            <div className="bg-muted/50 rounded-lg p-4 space-y-1">
              {mapping.props.map((prop, i) => (
                <code key={i} className="block text-sm font-mono">
                  {prop}
                </code>
              ))}
            </div>
          </div>

          {/* Dependencies */}
          {mapping.dependencies.length > 0 && (
            <div>
              <h3 className="font-semibold mb-3">Dependencies</h3>
              <div className="flex flex-wrap gap-2">
                {mapping.dependencies.map((dep, i) => (
                  <span key={i} className="px-3 py-1 bg-primary/10 text-primary rounded-full text-sm font-medium">
                    {dep}
                  </span>
                ))}
              </div>
            </div>
          )}

          {/* Notes */}
          {mapping.notes && (
            <div>
              <h3 className="font-semibold mb-3">Note</h3>
              <p className="text-sm text-muted-foreground p-4 bg-info/10 border border-info/30 rounded-lg">
                {mapping.notes}
              </p>
            </div>
          )}

          {/* Flutter Code */}
          <div>
            <div className="flex items-center justify-between mb-3">
              <h3 className="font-semibold">Flutter Code</h3>
              <button
                onClick={onCopyCode}
                className="flex items-center gap-2 px-4 py-2 bg-primary text-primary-foreground rounded-lg text-sm font-semibold hover:bg-primary/90 transition-colors"
              >
                <Copy className="size-4" />
                Copia Codice
              </button>
            </div>
            <pre className="bg-muted/50 rounded-lg p-4 overflow-x-auto">
              <code className="text-sm font-mono">{flutterCode}</code>
            </pre>
          </div>
        </div>
      </div>
    </div>
  );
}

// =====================================
// FLUTTER CODE GENERATOR
// =====================================

function generateFlutterCode(mapping: ComponentMapping): string {
  return `// ${mapping.fullPath}
// Generated from Figma Design System via MCP Code Connect

import 'package:flutter/material.dart';
${mapping.dependencies.map(dep => `import 'package:youbook/widgets/${dep.toLowerCase()}.dart';`).join('\n')}

class ${mapping.flutterWidget} extends StatelessWidget {
  ${mapping.props.map(prop => {
    const [type, name] = prop.split(' ');
    return `final ${type} ${name};`;
  }).join('\n  ')}

  const ${mapping.flutterWidget}({
    Key? key,
    ${mapping.props.map(prop => {
      const [, name] = prop.split(' ');
      return `required this.${name}`;
    }).join(',\n    ')},
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      // TODO: Implement ${mapping.figmaName} design
      // Refer to Figma: ${mapping.fullPath}
      child: Text('${mapping.flutterWidget}'),
    );
  }
}`;
}
