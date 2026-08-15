import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/business_submission_service.dart';
import '../services/location_service.dart';
import '../services/things_to_do_service.dart';
import '../theme/firstvue_theme.dart';
import '../theme/live_tokens.dart';
import '../widgets/event_date_time_fields.dart';
import '../widgets/media_picker_sheet.dart';
import '../widgets/network_photo.dart';

enum EditEventMode { create, edit, duplicate }

class EditEventScreen extends StatefulWidget {
  final EditEventMode mode;
  final CommunityEvent? event;

  const EditEventScreen({
    super.key,
    this.mode = EditEventMode.create,
    this.event,
  });

  const EditEventScreen.create({super.key})
      : mode = EditEventMode.create,
        event = null;

  const EditEventScreen.edit({super.key, required CommunityEvent this.event})
      : mode = EditEventMode.edit;

  const EditEventScreen.duplicate({
    super.key,
    required CommunityEvent this.event,
  }) : mode = EditEventMode.duplicate;

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _location;
  DateTime? _eventAt;
  DateTime? _endsAt;
  double? _latitude;
  double? _longitude;
  bool _clearCoordinates = false;
  bool _pinningLocation = false;
  String? _businessId;
  XFile? _coverPhoto;
  bool _clearCover = false;
  bool _submitting = false;
  late Future<List<OwnedBusiness>> _businessesFuture;

  @override
  void initState() {
    super.initState();
    final seed = widget.event;
    final duplicate = widget.mode == EditEventMode.duplicate;
    _title = TextEditingController(
      text: duplicate && seed != null ? 'Copy of ${seed.title}' : seed?.title ?? '',
    );
    _description = TextEditingController(text: seed?.description ?? '');
    _location = TextEditingController(text: seed?.locationLabel ?? '');
    _eventAt = seed?.eventAt;
    _endsAt = seed?.endsAt;
    _latitude = seed?.latitude;
    _longitude = seed?.longitude;
    _businessId = seed?.businessId;
    _businessesFuture = BusinessSubmissionService.fetchMyBusinesses();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  String get _screenTitle => switch (widget.mode) {
        EditEventMode.create => 'CREATE EVENT',
        EditEventMode.edit => 'EDIT EVENT',
        EditEventMode.duplicate => 'DUPLICATE EVENT',
      };

  Future<void> _save({required bool publish}) async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an event title.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      if (widget.mode == EditEventMode.edit && widget.event != null) {
        await ThingsToDoService.updateEvent(
          eventId: widget.event!.id,
          title: _title.text,
          description: _description.text,
          eventAt: _eventAt,
          endsAt: _endsAt,
          locationLabel: _location.text,
          businessId: _businessId,
          latitude: _latitude,
          longitude: _longitude,
          clearCoordinates: _clearCoordinates && _latitude == null,
          coverPhoto: _coverPhoto,
          clearCover: _clearCover && _coverPhoto == null,
          status: publish ? 'approved' : widget.event!.status,
        );
        if (publish) {
          await ThingsToDoService.setEventStatus(
            eventId: widget.event!.id,
            status: 'approved',
          );
        }
      } else {
        if (publish) {
          await ThingsToDoService.publishEvent(
            title: _title.text,
            description: _description.text,
            eventAt: _eventAt,
            endsAt: _endsAt,
            locationLabel: _location.text,
            businessId: _businessId,
            latitude: _latitude,
            longitude: _longitude,
            coverPhoto: _coverPhoto,
          );
        } else {
          await ThingsToDoService.createDraftEvent(
            title: _title.text,
            description: _description.text,
            eventAt: _eventAt,
            endsAt: _endsAt,
            locationLabel: _location.text,
            businessId: _businessId,
            latitude: _latitude,
            longitude: _longitude,
            coverPhoto: _coverPhoto,
          );
        }
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(publish ? 'Event published.' : 'Draft saved.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save event: $error')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancelEvent() async {
    final event = widget.event;
    if (event == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel event?'),
        content: const Text(
          'This marks the event as cancelled. Attendees will still see it in your planner.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('KEEP'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CANCEL EVENT'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      await ThingsToDoService.cancelEvent(event.id);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event cancelled.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to cancel event: $error')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pinCurrentLocation() async {
    setState(() => _pinningLocation = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _clearCoordinates = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Map pin set from your current location.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not set map pin: $error')),
      );
    } finally {
      if (mounted) setState(() => _pinningLocation = false);
    }
  }

  void _clearMapPin() {
    setState(() {
      _latitude = null;
      _longitude = null;
      _clearCoordinates = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final existingCover = widget.event?.coverImageUrl;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        foregroundColor: fv.primaryText,
        title: Text(_screenTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          TextField(
            controller: _title,
            style: TextStyle(color: fv.primaryText),
            decoration: const InputDecoration(labelText: 'Event title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            style: TextStyle(color: fv.primaryText),
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description',
              helperText: 'Add #hashtags in the description when posting updates.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _location,
            style: TextStyle(color: fv.primaryText),
            decoration: const InputDecoration(labelText: 'Location'),
          ),
          const SizedBox(height: 18),
          EventDateTimeFields(
            value: _eventAt,
            onChanged: (next) => setState(() => _eventAt = next),
          ),
          const SizedBox(height: 18),
          EventDateTimeFields(
            sectionLabel: 'ENDS AT (OPTIONAL)',
            allowClear: true,
            value: _endsAt,
            onChanged: (next) => setState(() => _endsAt = next),
          ),
          const SizedBox(height: 18),
          Text(
            'LIVE MAP PIN (OPTIONAL)',
            style: TextStyle(
              color: context.fv.tertiaryText,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _latitude != null && _longitude != null
                ? 'Pinned: ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                : 'No map pin yet. Events without coordinates only appear via a linked business location.',
            style: TextStyle(color: context.fv.secondaryText, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pinningLocation ? null : _pinCurrentLocation,
                  icon: _pinningLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded, size: 18),
                  label: const Text('Use current location'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LiveTokens.bronzeSoft,
                  ),
                ),
              ),
              if (_latitude != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _clearMapPin,
                  child: const Text('Clear'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<OwnedBusiness>>(
            future: _businessesFuture,
            builder: (context, snapshot) {
              final businesses = snapshot.data ?? const [];
              if (businesses.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LINKED BUSINESS (OPTIONAL)',
                    style: TextStyle(
                      color: fv.tertiaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    key: ValueKey(_businessId ?? 'none'),
                    initialValue: _businessId,
                    dropdownColor: fv.surface,
                    style: TextStyle(color: fv.primaryText),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: fv.inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('No linked business'),
                      ),
                      ...businesses.map(
                        (business) => DropdownMenuItem<String?>(
                          value: business.id,
                          child: Text(business.name),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _businessId = value),
                  ),
                  const SizedBox(height: 18),
                ],
              );
            },
          ),
          OutlinedButton.icon(
            onPressed: _submitting
                ? null
                : () async {
                    final files = await showImagePickerSheet(context);
                    if (files == null || files.isEmpty) return;
                    setState(() {
                      _coverPhoto = files.first;
                      _clearCover = false;
                    });
                  },
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              _coverPhoto == null &&
                      (existingCover == null || _clearCover)
                  ? 'Add cover photo'
                  : 'Change cover photo',
            ),
          ),
          if ((_coverPhoto != null ||
                  (existingCover != null && !_clearCover)) &&
              widget.mode != EditEventMode.duplicate)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() {
                          _coverPhoto = null;
                          _clearCover = true;
                        }),
                child: const Text('Remove cover photo'),
              ),
            ),
          if (_coverPhoto != null) ...[
            const SizedBox(height: 10),
            FutureBuilder<Uint8List>(
              future: _coverPhoto!.readAsBytes(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 140,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    snapshot.data!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
          ] else if (existingCover != null &&
              !_clearCover &&
              widget.mode != EditEventMode.duplicate) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: NetworkPhoto(
                url: existingCover,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : () => _save(publish: true),
              child: Text(_submitting ? 'SAVING...' : 'PUBLISH'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _submitting ? null : () => _save(publish: false),
              child: const Text('SAVE DRAFT'),
            ),
          ),
          if (widget.mode == EditEventMode.edit &&
              widget.event != null &&
              !widget.event!.isCancelled) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _submitting ? null : _cancelEvent,
                style: OutlinedButton.styleFrom(
                  foregroundColor: FirstVueColors.mutedRed,
                  side: const BorderSide(color: FirstVueColors.mutedRed),
                ),
                child: const Text('CANCEL EVENT'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
