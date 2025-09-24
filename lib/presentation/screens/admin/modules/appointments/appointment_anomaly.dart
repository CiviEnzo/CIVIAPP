import 'package:flutter/material.dart';

enum AppointmentAnomalyType {
  noShift,
  breakOverlap,
  absenceOverlap,
  outdatedStatus,
}

extension AppointmentAnomalyTypeX on AppointmentAnomalyType {
  String get label {
    switch (this) {
      case AppointmentAnomalyType.noShift:
        return 'Orario senza turno';
      case AppointmentAnomalyType.breakOverlap:
        return 'Sovrapposto a pausa';
      case AppointmentAnomalyType.absenceOverlap:
        return 'Operatore assente';
      case AppointmentAnomalyType.outdatedStatus:
        return 'Stato da aggiornare';
    }
  }

  String get description {
    switch (this) {
      case AppointmentAnomalyType.noShift:
        return 'Appuntamento pianificato fuori da un turno attivo.';
      case AppointmentAnomalyType.breakOverlap:
        return 'L\'appuntamento ricade durante una pausa programmata.';
      case AppointmentAnomalyType.absenceOverlap:
        return 'Operatore assente (ferie, permesso o malattia).';
      case AppointmentAnomalyType.outdatedStatus:
        return 'Appuntamento nel passato con stato "Programmato" o "Confermato".';
    }
  }

  IconData get icon => Icons.warning_amber_rounded;
}
