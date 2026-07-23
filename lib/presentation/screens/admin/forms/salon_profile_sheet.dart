import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:flutter/material.dart';
import 'package:you_book/presentation/common/app_notice.dart';
import 'package:you_book/services/salons/salon_geocoding_service.dart';

class SalonProfileSheet extends StatefulWidget {
  const SalonProfileSheet({super.key, required this.salon});

  final Salon salon;

  @override
  State<SalonProfileSheet> createState() => _SalonProfileSheetState();
}

class _SalonProfileSheetState extends State<SalonProfileSheet> {
  late TextEditingController _name;
  late TextEditingController _phone;
  late TextEditingController _email;
  late TextEditingController _address;
  late TextEditingController _city;
  late TextEditingController _postalCode;
  late TextEditingController _bookingLink;
  late TextEditingController _googlePlaceId;
  late TextEditingController _latitude;
  late TextEditingController _longitude;
  late TextEditingController _description;
  bool _isGeocoding = false;

  @override
  void initState() {
    super.initState();
    final salon = widget.salon;
    _name = TextEditingController(text: salon.name);
    _phone = TextEditingController(text: salon.phone);
    _email = TextEditingController(text: salon.email);
    _address = TextEditingController(text: salon.address);
    _city = TextEditingController(text: salon.city);
    _postalCode = TextEditingController(text: salon.postalCode ?? '');
    _bookingLink = TextEditingController(text: salon.bookingLink ?? '');
    _googlePlaceId = TextEditingController(text: salon.googlePlaceId ?? '');
    _latitude = TextEditingController(
      text: salon.latitude == null ? '' : salon.latitude!.toStringAsFixed(6),
    );
    _longitude = TextEditingController(
      text: salon.longitude == null ? '' : salon.longitude!.toStringAsFixed(6),
    );
    _description = TextEditingController(text: salon.description ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _city.dispose();
    _postalCode.dispose();
    _bookingLink.dispose();
    _googlePlaceId.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _showError('Inserisci il nome del salone.');
      return;
    }

    final email = _email.text.trim();
    if (email.isNotEmpty && !_isValidEmail(email)) {
      _showError('Inserisci un indirizzo email valido.');
      return;
    }

    final bookingLink = _bookingLink.text.trim();
    if (bookingLink.isNotEmpty && !_isValidWebUrl(bookingLink)) {
      _showError(
        'Inserisci un link prenotazioni valido, completo di https://.',
      );
      return;
    }

    double? latitude;
    if (_latitude.text.trim().isNotEmpty) {
      latitude = double.tryParse(_latitude.text.trim().replaceAll(',', '.'));
      if (latitude == null) {
        _showError('Inserisci una latitudine valida (es. 45.464203).');
        return;
      }
    }

    double? longitude;
    if (_longitude.text.trim().isNotEmpty) {
      longitude = double.tryParse(_longitude.text.trim().replaceAll(',', '.'));
      if (longitude == null) {
        _showError('Inserisci una longitudine valida (es. 9.189982).');
        return;
      }
    }

    final updated = widget.salon.copyWith(
      name: name,
      phone: _phone.text.trim(),
      email: email,
      address: _address.text.trim(),
      city: _city.text.trim(),
      postalCode:
          _postalCode.text.trim().isEmpty ? null : _postalCode.text.trim(),
      bookingLink: bookingLink.isEmpty ? null : bookingLink,
      googlePlaceId:
          _googlePlaceId.text.trim().isEmpty
              ? null
              : _googlePlaceId.text.trim(),
      latitude: latitude,
      longitude: longitude,
      description:
          _description.text.trim().isEmpty ? null : _description.text.trim(),
    );

    Navigator.of(context).pop(updated);
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  bool _isValidWebUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showAppSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _geocodeAddress() async {
    final address = _address.text.trim();
    final city = _city.text.trim();
    if (address.isEmpty || city.isEmpty) {
      _showError('Inserisci indirizzo e città prima di trovare le coordinate.');
      return;
    }
    setState(() => _isGeocoding = true);
    try {
      final service = SalonGeocodingService();
      final candidates = await service.geocodeAddress(
        salonId: widget.salon.id,
        address: address,
        city: city,
        postalCode: _postalCode.text.trim(),
      );
      if (!mounted) {
        return;
      }
      if (candidates.isEmpty) {
        _showError(
          'Coordinate non trovate. Il salone resterà ricercabile per nome o telefono.',
        );
        return;
      }
      final selected =
          candidates.length == 1
              ? candidates.first
              : await _selectGeocodingCandidate(candidates);
      if (selected == null || !mounted) {
        return;
      }
      _applyGeocodingCandidate(selected);
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      _showError('Geocoding non riuscito: $error');
    } finally {
      if (mounted) {
        setState(() => _isGeocoding = false);
      }
    }
  }

  Future<SalonGeocodingCandidate?> _selectGeocodingCandidate(
    List<SalonGeocodingCandidate> candidates,
  ) {
    return showDialog<SalonGeocodingCandidate>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('Seleziona indirizzo'),
          children:
              candidates.map((candidate) {
                return SimpleDialogOption(
                  onPressed: () => Navigator.of(dialogContext).pop(candidate),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(candidate.formattedAddress),
                      const SizedBox(height: 4),
                      Text(
                        '${candidate.latitude.toStringAsFixed(6)}, ${candidate.longitude.toStringAsFixed(6)}',
                        style: Theme.of(dialogContext).textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              }).toList(),
        );
      },
    );
  }

  void _applyGeocodingCandidate(SalonGeocodingCandidate candidate) {
    setState(() {
      _latitude.text = candidate.latitude.toStringAsFixed(6);
      _longitude.text = candidate.longitude.toStringAsFixed(6);
      final placeId = candidate.placeId?.trim();
      if (placeId != null &&
          placeId.isNotEmpty &&
          _googlePlaceId.text.trim().isEmpty) {
        _googlePlaceId.text = placeId;
      }
    });
    ScaffoldMessenger.of(context).showAppSnackBar(
      const SnackBar(content: Text('Coordinate aggiornate dall’indirizzo.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DialogActionLayout(
      title: 'Profilo salone',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nome salone'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            decoration: const InputDecoration(labelText: 'Telefono'),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            textCapitalization: TextCapitalization.none,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            decoration: const InputDecoration(
              labelText: 'Indirizzo',
              helperText: 'Via e numero civico',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _city,
            decoration: const InputDecoration(labelText: 'Città'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _postalCode,
            decoration: const InputDecoration(labelText: 'CAP'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bookingLink,
            decoration: const InputDecoration(
              labelText: 'Link prenotazioni',
              hintText: 'https://example.com/prenota',
              helperText: 'Link aperto dai clienti per prenotare online',
            ),
            keyboardType: TextInputType.url,
            textCapitalization: TextCapitalization.none,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          _buildGoogleLocationSection(context),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            decoration: const InputDecoration(
              labelText: 'Descrizione',
              helperText: 'Testo mostrato nelle card pubbliche',
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Annulla'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Salva')),
      ],
    );
  }

  Widget _buildGoogleLocationSection(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Google e coordinate',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Dati usati per mostrare il salone nella lista vicini.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _googlePlaceId,
            decoration: const InputDecoration(
              labelText: 'Google Place ID / link recensioni',
              helperText:
                  'Il Place ID può essere compilato automaticamente dal geocoding',
            ),
            keyboardType: TextInputType.url,
            textCapitalization: TextCapitalization.none,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _isGeocoding ? null : _geocodeAddress,
              icon:
                  _isGeocoding
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.travel_explore_rounded),
              label: Text(
                _isGeocoding ? 'Ricerca coordinate...' : 'Trova coordinate',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _latitude,
                  decoration: const InputDecoration(labelText: 'Latitudine'),
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _longitude,
                  decoration: const InputDecoration(labelText: 'Longitudine'),
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
