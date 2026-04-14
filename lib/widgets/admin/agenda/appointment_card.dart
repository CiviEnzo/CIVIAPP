import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/widgets/shared/badge/status_badge.dart';

class AdminAppointmentCard extends StatelessWidget {
  const AdminAppointmentCard({
    super.key,
    required this.id,
    required this.serviceName,
    required this.clientName,
    required this.staffName,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.onTap,
    this.onEdit,
    this.onCancel,
  });

  final String id;
  final String serviceName;
  final String clientName;
  final String staffName;
  final DateTime startTime;
  final DateTime endTime;
  final AppointmentStatus status;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;

  static final DateFormat _timeFormat = DateFormat('HH:mm', 'it_IT');
  static final DateFormat _dayFormat = DateFormat('EEE dd MMM', 'it_IT');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusData = _resolveStatus(status);
    final leadingLetter =
        clientName.trim().isEmpty
            ? '?'
            : clientName.trim().characters.first.toUpperCase();

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.2,
                    ),
                    foregroundColor: theme.colorScheme.onSurface,
                    child: Text(
                      leadingLetter,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          serviceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    status: statusData.badge,
                    label: statusData.label,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_dayFormat.format(startTime)} • ${_timeFormat.format(startTime)}-${_timeFormat.format(endTime)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.badge_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      staffName,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (onEdit != null || onCancel != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (onEdit != null)
                      TextButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Modifica'),
                      ),
                    if (onCancel != null)
                      TextButton.icon(
                        onPressed: onCancel,
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Annulla'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _StatusData _resolveStatus(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.scheduled:
        return const _StatusData('Programmato', BadgeStatus.pending);
      case AppointmentStatus.completed:
        return const _StatusData('Completato', BadgeStatus.success);
      case AppointmentStatus.cancelled:
        return const _StatusData('Annullato', BadgeStatus.cancelled);
      case AppointmentStatus.noShow:
        return const _StatusData('No show', BadgeStatus.inactive);
    }
  }
}

class _StatusData {
  const _StatusData(this.label, this.badge);

  final String label;
  final BadgeStatus badge;
}
