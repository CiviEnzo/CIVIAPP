import { WhatsAppTemplateComponent } from '../wa/sendTemplate';

function extractPlaceholdersInOrder(template: string): string[] {
  if (!template.trim().length) {
    return [];
  }
  const placeholders = new Set<string>();
  const ordered: string[] = [];
  const regex = /\{\{\s*([^}]+)\s*\}\}/g;
  for (const match of template.matchAll(regex)) {
    const raw = match[1]?.trim() ?? '';
    if (!raw.length || placeholders.has(raw)) {
      continue;
    }
    placeholders.add(raw);
    ordered.push(raw);
  }
  return ordered;
}

export type PlaceholderResolver = (placeholder: string) => string;

export function buildWhatsappTemplateComponents(params: {
  body: string;
  bodyPlaceholderOrder?: string[];
  headerBindings?: string[];
  headerFormat?: string;
  resolveValue: PlaceholderResolver;
}): {
  components?: WhatsAppTemplateComponent[];
  unresolvedPlaceholders: string[];
} {
  const {
    body,
    bodyPlaceholderOrder,
    headerBindings,
    headerFormat,
    resolveValue,
  } = params;
  const components: WhatsAppTemplateComponent[] = [];
  const unresolvedPlaceholders: string[] = [];
  const normalizedHeaderFormat = (headerFormat ?? '').trim().toUpperCase();
  const hasImageHeader = normalizedHeaderFormat === 'IMAGE';
  const firstHeaderBinding =
    headerBindings && headerBindings.length > 0
      ? headerBindings[0]?.trim() ?? ''
      : '';

  if (hasImageHeader) {
    if (!firstHeaderBinding.length) {
      unresolvedPlaceholders.push('header:image');
    } else {
      const resolved = resolveValue(firstHeaderBinding).trim();
      if (!resolved.length || !/^https?:\/\//i.test(resolved)) {
        unresolvedPlaceholders.push(firstHeaderBinding);
      } else {
        components.push({
          type: 'header',
          parameters: [
            {
              type: 'image',
              image: { link: resolved },
            },
          ],
        });
      }
    }
  } else if (firstHeaderBinding.length) {
    const resolved = resolveValue(firstHeaderBinding).trim();
    if (!resolved.length) {
      unresolvedPlaceholders.push(firstHeaderBinding);
    } else {
      components.push({
        type: 'header',
        parameters: [
          {
            type: 'text',
            text: resolved,
          },
        ],
      });
    }
  }

  const placeholders =
    bodyPlaceholderOrder && bodyPlaceholderOrder.length
      ? bodyPlaceholderOrder
      : extractPlaceholdersInOrder(body);
  if (placeholders.length) {
    const parameters = placeholders.map((placeholder) => {
      const resolved = resolveValue(placeholder).trim();
      if (!resolved.length) {
        unresolvedPlaceholders.push(placeholder);
      }
      return {
        type: 'text' as const,
        text: resolved,
      };
    });
    components.push({
      type: 'body',
      parameters,
    });
  }

  return {
    components: components.length > 0 ? components : undefined,
    unresolvedPlaceholders,
  };
}
