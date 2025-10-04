import { ChannelPreferences, MessageChannel } from '../messaging/types';

export function canUseChannel(
  channel: MessageChannel,
  preferences?: ChannelPreferences,
): boolean {
  if (!preferences) {
    return true;
  }
  switch (channel) {
    case 'push':
      return preferences.push ?? true;
    case 'email':
      return preferences.email ?? false;
    case 'whatsapp':
      return preferences.whatsapp ?? false;
    default:
      return false;
  }
}
