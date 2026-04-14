# YouBook - MCP Code Connect Mapping Summary

**Objective:** Mapping completo Figma Design System → Flutter per app mobile YouBook  
**Data:** 3 Marzo 2026  
**Status:** ✅ COMPLETATO

---

## Quick Access

- **Web Interface:** `/mcp-code-connect`
- **Naming Audit:** `/NAMING_AUDIT_REPORT.md`
- **States Audit:** `/STATES_AUDIT_REPORT.md`
- **Code File:** `/src/app/pages/MCPCodeConnectMapping.tsx`

---

## Componenti Mappati: 22 Totali

### Priority Breakdown

| Priority | Count | Focus |
|----------|-------|-------|
| **P0** | 5 | Agenda Cards (3) + KPI Cards (2) |
| **P1** | 10 | Drawer Items (2) + Quote/Payment (4) + Notifications (2) + Invoice (1) + Staff TimeOff (1) |
| **P2** | 7 | Shared States (3) + Client Home (2) + Packages (1) + Welcome (1) |

---

## P0 - Critical Priority (5 Components)

### 1. Admin Appointment Card
**Figma:** `Admin Appointment Card`  
**Path:** `Admin/Agenda/AppointmentCard/Grid/Default`  
**Flutter:** `AdminAppointmentCard`  
**File:** `lib/widgets/admin/agenda/appointment_card.dart`

**Props:**
```dart
String id
String serviceName
String clientName
String staffName
DateTime startTime
DateTime endTime
AppointmentStatus status
VoidCallback? onTap
VoidCallback? onEdit
VoidCallback? onCancel
```

**Features:**
- Vista calendario grid
- Hover actions (edit, cancel)
- Status badge (confirmed/pending/cancelled)
- Time range display
- Color coding per status

---

### 2. Staff Appointment Card
**Figma:** `Staff Appointment Card`  
**Path:** `Staff/Agenda/AppointmentCard/Compact/Default`  
**Flutter:** `StaffAppointmentCard`  
**File:** `lib/widgets/staff/agenda/appointment_card.dart`

**Props:**
```dart
String id
String serviceName
String clientName
DateTime startTime
int duration
AppointmentStatus status
VoidCallback? onTap
bool isCompact
```

**Variants:**
- **Day View:** Expanded con full details
- **Week View:** Compact con nome servizio + cliente
- **Selected:** Apre ClientDetailDrawer

---

### 3. Client Appointment Card
**Figma:** `Client Appointment Card`  
**Path:** `Client/Agenda/AppointmentCard/Full/Default`  
**Flutter:** `ClientAppointmentCard`  
**File:** `lib/widgets/client/agenda/appointment_card.dart`

**Props:**
```dart
String id
String serviceName
String staffName
DateTime date
String time
int duration
double price
AppointmentStatus status
VoidCallback? onModify
VoidCallback? onCancel
VoidCallback? onRebook
bool isHistory
```

**Variants:**
- **Upcoming:** Actions modifica/annulla
- **History:** Action "Prenota di nuovo"
- Full details sempre visibili

---

### 4. Admin KPI Card
**Figma:** `Admin KPI Card`  
**Path:** `Admin/Dashboard/KPI/Card/Default`  
**Flutter:** `KPICard`  
**File:** `lib/widgets/shared/dashboard/kpi_card.dart`

**Props:**
```dart
String label
String value
IconData icon
Color color
Trend? trend
VoidCallback? onTap
```

**Instances (4):**
1. Appuntamenti Oggi (Calendar, primary)
2. Ricavi Giorno (Euro, success)
3. Nuovi Clienti (Users, primary)
4. Scorte Basse (AlertTriangle, warning)

**Trend Structure:**
```dart
class Trend {
  final int value;      // +12 or -5
  final bool isPositive;
}
```

---

### 5. Admin KPI Card - With Trend
**Figma:** `Admin KPI Card - With Trend`  
**Path:** `Admin/Dashboard/KPI/Card/Hover`  
**Flutter:** `KPICard`  
**File:** `lib/widgets/shared/dashboard/kpi_card.dart`

**Additional Props:**
```dart
bool isHovered
```

**Features:**
- Elevated shadow on hover
- Animated trend indicator
- Color-coded trend (success/error)

---

## P1 - High Priority (10 Components)

### 6-7. Client Drawer Items
**Figma:** `Client Drawer Item` + `Client Drawer Item - With Badge`  
**Path:** `Client/Dashboard/DrawerItem/Default` & `/WithBadge`  
**Flutter:** `DrawerMenuItem`  
**File:** `lib/widgets/client/drawer/drawer_menu_item.dart`

**Props:**
```dart
IconData icon
String label
String? badge
VoidCallback onTap
bool isActive
```

**7 Instances:**
1. Punti Fedeltà (Award, "420 punti")
2. Pacchetti (Package, "3")
3. Preventivi (FileText, "1")
4. Fatturazione (CreditCard)
5. Questionari (ClipboardList)
6. Le Mie Foto (Image)
7. Impostazioni (Settings)

---

### 8-9. Client Quote Cards
**Figma:** `Client Quote Card` + `Client Quote Card - Expired`  
**Path:** `Client/Quotes/QuoteCard/List/Pending` & `/Expired`  
**Flutter:** `QuoteCard`  
**File:** `lib/widgets/client/quotes/quote_card.dart`

**Props:**
```dart
String id
String name
List<String> services
double total
QuoteStatus status
DateTime date
VoidCallback? onTap
VoidCallback? onPay
```

**States:**
- **Pending:** Warning badge, azione "Paga"
- **Expired:** Error badge, azione "Rigenera"
- **Accepted:** Success badge, read-only

---

### 10-11. Stripe Payment Forms
**Figma:** `Client Stripe Payment Form` + `Loading`  
**Path:** `Client/Payment/StripeForm/Default` & `/Loading`  
**Flutter:** `StripePaymentForm`  
**File:** `lib/widgets/client/payment/stripe_payment_form.dart`

**Props:**
```dart
double amount
Future<void> Function(PaymentData) onSubmit
VoidCallback? onCancel
bool isLoading
```

**Form Fields:**
1. Numero Carta (Luhn validation)
2. Scadenza MM/YY (date validation)
3. CVV (3 digits)

**States:**
- Default: Form editabile
- Loading: Form disabled + spinner
- Success: Redirect (handled by parent)
- Error: Error message + retry

---

### 12. Client Invoice Card
**Figma:** `Client Invoice Card`  
**Path:** `Client/Invoices/InvoiceCard/List/Default`  
**Flutter:** `InvoiceCard`  
**File:** `lib/widgets/client/invoices/invoice_card.dart`

**Props:**
```dart
String id
DateTime date
double amount
InvoiceStatus status
VoidCallback? onDownload
VoidCallback? onCopy
VoidCallback? onPay
```

**States:**
- **Paid:** Success badge, actions download/copy
- **Pending:** Warning badge, action pay
- **Overdue:** Error badge, action pay urgente

---

### 13-14. Notification Cards
**Figma:** `Client Notification Card` + `Read`  
**Path:** `Client/Notifications/NotificationCard/List/Unread` & `/Read`  
**Flutter:** `NotificationCard`  
**File:** `lib/widgets/client/notifications/notification_card.dart`

**Props:**
```dart
String id
NotificationType type
String title
String message
String time
bool isRead
VoidCallback? onTap
VoidCallback? onMarkRead
```

**Visual States:**
- **Unread:** bg-primary/10, border-primary/20, dot primary
- **Read:** bg-card, border-border, dot muted

**Types:**
- appointment (Calendar icon)
- promo (Gift icon)
- loyalty (Award icon)
- system (AlertCircle icon)

---

### 15. Staff Time Off Request Card
**Figma:** `Staff Time Off Request Card`  
**Path:** `Staff/TimeOff/RequestCard/List/Default`  
**Flutter:** `TimeOffRequestCard`  
**File:** `lib/widgets/staff/time_off/request_card.dart`

**Props:**
```dart
String id
TimeOffType type
DateTime startDate
DateTime endDate
int days
RequestStatus status
String? rejectionReason
DateTime createdAt
```

**States:**
- **Pending:** Warning badge, no actions
- **Approved:** Success badge, timeline
- **Rejected:** Error badge, reason displayed

---

## P2 - Standard Priority (7 Components)

### 16. Status Badge (Shared)
**Figma:** `Status Badge`  
**Path:** `Shared/Badge/Status/Chip/Default`  
**Flutter:** `StatusBadge`  
**File:** `lib/widgets/shared/badge/status_badge.dart`

**Props:**
```dart
BadgeStatus status
String label
BadgeSize size
```

**Status Enum:**
```dart
enum BadgeStatus {
  success,    // green
  pending,    // warning
  cancelled,  // error
  info,       // blue
  active,     // success
  inactive    // muted
}

enum BadgeSize {
  sm,
  md
}
```

---

### 17. Data Table (Shared)
**Figma:** `Data Table`  
**Path:** `Shared/Table/Data/Responsive/Default`  
**Flutter:** `DataTable`  
**File:** `lib/widgets/shared/table/data_table.dart`

**Props:**
```dart
List<TableColumn> columns
List<TableRow> rows
bool isSortable
String? sortColumn
SortDirection? sortDirection
bool isResponsive
```

**Responsive:**
- **Desktop:** Table with sortable headers
- **Mobile:** Cards with key info
- **Auto Empty State:** When rows.isEmpty

---

### 18-20. State Components
**Figma:** `Loading State`, `Empty State`, `Error State`  
**Paths:**
- `Shared/States/Loading/Centered/Spinner`
- `Shared/States/Empty/Centered/Icon`
- `Shared/States/Error/Centered/Retry`

**Flutter Widgets:**
- `LoadingState` - `lib/widgets/shared/states/loading_state.dart`
- `EmptyState` - `lib/widgets/shared/states/empty_state.dart`
- `ErrorState` - `lib/widgets/shared/states/error_state.dart`

**Common Pattern:**
```dart
// Loading
LoadingState(
  message: 'Caricamento...',
  color: Colors.primary,
  size: 48.0
)

// Empty
EmptyState(
  icon: Icons.calendar,
  title: 'Nessun appuntamento',
  description: 'Non hai appuntamenti programmati',
  actionLabel: 'Prenota Ora',
  onAction: () => ...
)

// Error
ErrorState(
  title: 'Errore di Caricamento',
  message: 'Si è verificato un errore',
  onRetry: () => ...
)
```

---

### 21. Client Welcome Card
**Figma:** `Client Welcome Card`  
**Path:** `Client/Home/WelcomeCard/Gradient/Default`  
**Flutter:** `WelcomeCard`  
**File:** `lib/widgets/client/home/welcome_card.dart`

**Props:**
```dart
String userName
int loyaltyPoints
VoidCallback? onUsePoints
```

**Features:**
- Gradient background (gold)
- Star icon for loyalty
- Nome utente personalizzato
- Action "Usa i Tuoi Punti"

---

### 22. Client Package Card
**Figma:** `Client Package Card`  
**Path:** `Client/Packages/PackageCard/Default/Active`  
**Flutter:** `PackageCard`  
**File:** `lib/widgets/client/packages/package_card.dart`

**Props:**
```dart
String id
String name
int total
int used
double price
DateTime expiresAt
PackageStatus status
VoidCallback? onUse
```

**Features:**
- Progress bar (used/total)
- Expiry date display
- Status badge (Active/Expired)
- Price in euro
- Action "Usa Servizio" (if active)

---

## Enums & Models Comuni

### AppointmentStatus
```dart
enum AppointmentStatus {
  pending,
  confirmed,
  completed,
  cancelled,
  noShow
}
```

### InvoiceStatus
```dart
enum InvoiceStatus {
  paid,
  pending,
  overdue,
  cancelled
}
```

### QuoteStatus
```dart
enum QuoteStatus {
  pending,
  expired,
  accepted,
  rejected
}
```

### PackageStatus
```dart
enum PackageStatus {
  active,
  expired,
  used
}
```

### RequestStatus
```dart
enum RequestStatus {
  pending,
  approved,
  rejected
}
```

### TimeOffType
```dart
enum TimeOffType {
  vacation,
  sick,
  personal,
  other
}
```

### NotificationType
```dart
enum NotificationType {
  appointment,
  promo,
  loyalty,
  system
}
```

---

## Color System (Palette Oro/Nero/Bianco)

### Brand Colors
```dart
class BrandColors {
  // Primary (Oro)
  static const primary = Color(0xFFD4AF37);
  static const primaryForeground = Color(0xFF000000);
  
  // Background
  static const background = Color(0xFFFFFFFF);
  static const card = Color(0xFFFFFFFF);
  
  // Foreground
  static const foreground = Color(0xFF000000);
  static const mutedForeground = Color(0xFF666666);
  
  // Borders
  static const border = Color(0xFFE5E5E5);
  static const muted = Color(0xFFF5F5F5);
}
```

### Status Colors (Solo Feedback)
```dart
class StatusColors {
  // Success
  static const success = Color(0xFF22C55E);
  static const successForeground = Color(0xFFFFFFFF);
  
  // Warning
  static const warning = Color(0xFFEAB308);
  static const warningForeground = Color(0xFF000000);
  
  // Error
  static const error = Color(0xFFEF4444);
  static const errorForeground = Color(0xFFFFFFFF);
  
  // Info
  static const info = Color(0xFF3B82F6);
  static const infoForeground = Color(0xFFFFFFFF);
}
```

---

## Dependencies Tree

### Root Dependencies
```
flutter_sdk
lucide_icons
stripe_flutter
```

### Component Dependencies

**AppointmentCard** → `StatusBadge`, `Avatar`  
**KPICard** → `TrendIndicator`  
**DrawerMenuItem** → `Badge`  
**QuoteCard** → `StatusBadge`, `ServiceList`, `PriceLabel`  
**StripePaymentForm** → `TextFormField`, `StripeSDK`, `LoadingButton`  
**InvoiceCard** → `StatusBadge`, `IconButton`, `PriceLabel`  
**NotificationCard** → `ReadIndicator`  
**DataTable** → `TableHeader`, `TableCell`, `SortIcon`  
**PackageCard** → `StatusBadge`, `ProgressBar`, `PriceLabel`  
**TimeOffRequestCard** → `StatusBadge`, `Timeline`, `DateRangeLabel`

---

## Implementation Checklist

### Phase 1 - Core (P0)
- [ ] AdminAppointmentCard
- [ ] StaffAppointmentCard
- [ ] ClientAppointmentCard
- [ ] KPICard
- [ ] KPICard (hover variant)

### Phase 2 - High Priority (P1)
- [ ] DrawerMenuItem (2 variants)
- [ ] QuoteCard (2 states)
- [ ] StripePaymentForm (2 states)
- [ ] InvoiceCard
- [ ] NotificationCard (2 states)
- [ ] TimeOffRequestCard

### Phase 3 - Foundation (P2)
- [ ] StatusBadge
- [ ] DataTable
- [ ] LoadingState
- [ ] EmptyState
- [ ] ErrorState
- [ ] WelcomeCard
- [ ] PackageCard

### Phase 4 - Integration
- [ ] Color system setup
- [ ] Enum definitions
- [ ] Model classes
- [ ] API integration
- [ ] State management
- [ ] Navigation flow

---

## Code Connect Integration

### Figma API Setup
```dart
// pubspec.yaml
dependencies:
  figma_api: ^1.0.0
  
// lib/config/figma_config.dart
class FigmaConfig {
  static const apiToken = 'YOUR_FIGMA_API_TOKEN';
  static const fileKey = 'YOUR_FILE_KEY';
}
```

### Code Generation Command
```bash
flutter pub run figma_api:generate \
  --token $FIGMA_API_TOKEN \
  --file-key $FILE_KEY \
  --output lib/generated/figma_components.dart
```

### MCP Server Integration
```typescript
// MCP Server endpoint
POST https://mcp.youbook.app/code-connect/generate

Request:
{
  "figmaComponentId": "agenda-001",
  "targetFramework": "flutter",
  "includeProps": true,
  "includeDocs": true
}

Response:
{
  "code": "...",
  "filePath": "lib/widgets/admin/agenda/appointment_card.dart",
  "dependencies": ["status_badge", "avatar"]
}
```

---

## Testing Strategy

### Unit Tests
```dart
// test/widgets/admin/agenda/appointment_card_test.dart
void main() {
  testWidgets('AdminAppointmentCard renders correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminAppointmentCard(
          id: '1',
          serviceName: 'Taglio',
          clientName: 'Mario Rossi',
          staffName: 'Francesca',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(Duration(hours: 1)),
          status: AppointmentStatus.confirmed,
        ),
      ),
    );
    
    expect(find.text('Taglio'), findsOneWidget);
    expect(find.text('Mario Rossi'), findsOneWidget);
  });
}
```

### Integration Tests
```dart
// integration_test/appointment_flow_test.dart
void main() {
  testWidgets('Booking flow completes successfully', (tester) async {
    // Test full booking flow from service selection to confirmation
  });
}
```

---

## Metrics & KPIs

### Component Coverage
- **Total Components:** 22
- **P0 (Critical):** 5 (23%)
- **P1 (High):** 10 (45%)
- **P2 (Standard):** 7 (32%)

### By Role
- **Admin:** 3 components
- **Staff:** 2 components
- **Client:** 11 components
- **Shared:** 6 components

### Complexity
- **Simple:** 9 components (41%)
- **Medium:** 9 components (41%)
- **Complex:** 4 components (18%)

---

## Support & Documentation

**Documentation:** `/mcp-code-connect` (web interface)  
**Naming Guide:** `/NAMING_AUDIT_REPORT.md`  
**States Guide:** `/STATES_AUDIT_REPORT.md`  
**Cross-Module States:** `/cross-module-states`

**Contact:**  
- Design System Lead: [email]
- Flutter Dev Lead: [email]
- MCP Integration: [email]

---

**Status:** ✅ READY FOR IMPLEMENTATION  
**Last Updated:** 3 Marzo 2026
