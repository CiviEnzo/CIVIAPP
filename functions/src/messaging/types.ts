export type MessageChannel = 'push' | 'email' | 'whatsapp';

export type OutboxStatus = 'pending' | 'queued' | 'sent' | 'failed' | 'skipped';

export interface ChannelPreferences {
  push?: boolean;
  email?: boolean;
  whatsapp?: boolean;
  sms?: boolean;
}

export interface OutboxMetadata extends Record<string, unknown> {
  channelPreferences?: ChannelPreferences;
}

export interface OutboxMessage {
  id: string;
  salonId: string;
  clientId: string;
  templateId: string;
  channel: MessageChannel;
  status: OutboxStatus;
  scheduledAt?: Date | null;
  payload: Record<string, unknown>;
  metadata?: OutboxMetadata;
}

export interface ChannelDispatchResult {
  success: boolean;
  providerMessageId?: string;
  errorMessage?: string;
  metadata?: Record<string, unknown>;
}
