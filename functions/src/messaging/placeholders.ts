export interface TemplateContext {
  firstName?: string;
  lastName?: string;
  clientName?: string;
  salonName?: string;
  serviceName?: string;
  date?: string;
  time?: string;
  appointmentLabel?: string;
  reminderOffsetLabel?: string;
  [key: string]: string | undefined;
}

const KEY_ALIASES: Record<string, string> = {
  nome: 'firstname',
  name: 'firstname',
  cognome: 'lastname',
  surname: 'lastname',
  cliente: 'clientname',
  client: 'clientname',
  salone: 'salonname',
  salon: 'salonname',
  servizio: 'servicename',
  service: 'servicename',
  data: 'date',
  date: 'date',
  giorno: 'date',
  ora: 'time',
  time: 'time',
  orario: 'time',
  appuntamento: 'appointmentlabel',
  appointment: 'appointmentlabel',
  promemoria: 'reminderoffsetlabel',
  reminder: 'reminderoffsetlabel',
  compleanno: 'date',
  birthday: 'date',
};

function normalizeContext(
  context: TemplateContext,
): Record<string, string> {
  const normalized: Record<string, string> = {};
  for (const [key, value] of Object.entries(context)) {
    if (value == null) {
      continue;
    }
    const trimmed = value.toString().trim();
    if (!trimmed) {
      continue;
    }
    normalized[key.trim().toLowerCase()] = trimmed;
  }
  return normalized;
}

export function renderTemplate(
  template: string,
  context: TemplateContext,
): string {
  if (!template || template.trim().length === 0) {
    return template;
  }
  const normalizedContext = normalizeContext(context);
  if (!Object.keys(normalizedContext).length) {
    return template.replace(/\{\{\s*([^}]+)\s*\}\}/g, '');
  }
  return template.replace(/\{\{\s*([^}]+)\s*\}\}/g, (_match, rawKey) => {
    const key = String(rawKey).trim().toLowerCase();
    const canonical = KEY_ALIASES[key] ?? key;
    const value =
      normalizedContext[canonical] ?? normalizedContext[key] ?? '';
    return value;
  });
}
