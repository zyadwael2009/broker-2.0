import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/image_compressor.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../theme.dart';
import '../../auth/data/models.dart' show AuthException;
import '../data/listings_repository.dart';
import '../data/listings_signal.dart';

class CreateListingScreen extends ConsumerStatefulWidget {
  const CreateListingScreen({super.key});

  @override
  ConsumerState<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends ConsumerState<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _govCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  // Phase A1 richer fields
  final _bedroomsCtrl = TextEditingController();
  final _bathroomsCtrl = TextEditingController();
  final _floorCtrl = TextEditingController();
  final _compoundCtrl = TextEditingController();

  String _propertyType = 'apartment';
  String _listingKind = 'sale'; // 'sale' | 'rent'
  bool? _isFurnished; // tri-state: null=unspecified
  String? _deliveryStatus; // 'ready' | 'under_construction' | null
  bool _submitting = false;
  bool _fetchingLocation = false;

  final List<_PickedPhoto> _photos = [];
  final _picker = ImagePicker();

  @override
  void dispose() {
    for (final c in [
      _titleCtrl, _descCtrl, _priceCtrl, _areaCtrl,
      _govCtrl, _cityCtrl, _districtCtrl, _latCtrl, _lngCtrl,
      _bedroomsCtrl, _bathroomsCtrl, _floorCtrl, _compoundCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    setState(() => _fetchingLocation = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw Exception('Location permission denied.');
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _latCtrl.text = pos.latitude.toStringAsFixed(6);
        _lngCtrl.text = pos.longitude.toStringAsFixed(6);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not read location: $e')),
      );
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  Future<void> _pickPhotos() async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 85);
      if (picked.isEmpty) return;
      final loaded = <_PickedPhoto>[];
      for (final x in picked) {
        final raw = await x.readAsBytes();
        // Shrink before we even hold it in state — the preview grid
        // then renders the compressed bytes, which is what actually
        // gets uploaded (no double-encoding surprise).
        final bytes = await compressImage(raw);
        loaded.add(_PickedPhoto(name: x.name, bytes: bytes));
      }
      if (!mounted) return;
      setState(() => _photos.addAll(loaded));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick photos: $e')),
      );
    }
  }

  Future<void> _submit() async {
    final t = AppL10n.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.atLeastOnePhoto)),
      );
      return;
    }
    final lat = double.tryParse(_latCtrl.text);
    final lng = double.tryParse(_lngCtrl.text);
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.coordsRequired)),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(listingsRepositoryProvider);
      // Optional int parser — returns null for empty / non-numeric.
      int? asInt(TextEditingController c) {
        final v = c.text.trim();
        if (v.isEmpty) return null;
        return int.tryParse(v);
      }

      final listing = await repo.create({
        'title': _titleCtrl.text.trim(),
        if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
        'price_egp': _priceCtrl.text.trim(),
        'area_m2': _areaCtrl.text.trim(),
        'governorate': _govCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        if (_districtCtrl.text.trim().isNotEmpty) 'district': _districtCtrl.text.trim(),
        'lat': lat,
        'lng': lng,
        'property_type': _propertyType,
        'listing_kind': _listingKind,
        if (asInt(_bedroomsCtrl) != null) 'bedrooms': asInt(_bedroomsCtrl),
        if (asInt(_bathroomsCtrl) != null) 'bathrooms': asInt(_bathroomsCtrl),
        if (asInt(_floorCtrl) != null) 'floor_number': asInt(_floorCtrl),
        if (_isFurnished != null) 'is_furnished': _isFurnished,
        if (_compoundCtrl.text.trim().isNotEmpty) 'compound_name': _compoundCtrl.text.trim(),
        if (_deliveryStatus != null) 'delivery_status': _deliveryStatus,
      });

      int uploaded = 0;
      Object? photoErr;
      for (final p in _photos) {
        try {
          await repo.uploadPhoto(
            listingId: listing.id,
            filename: p.name,
            bytes: p.bytes,
          );
          uploaded++;
        } catch (e) {
          photoErr = e;
          break;
        }
      }

      if (!mounted) return;
      bumpListingsRev(ref);
      final msg = photoErr == null
          ? t.listingCreated
          : t.listingCreatedPartial(
              uploaded,
              _photos.length,
              photoErr is AuthException ? photoErr.message : '$photoErr',
            );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      context.pop<bool>(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is AuthException ? e.message : t.createFailed('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(t.newListing)),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _submitting,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: InputDecoration(labelText: t.listingTitle),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? t.titleMin3 : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descCtrl,
                      decoration: InputDecoration(labelText: t.listingDescription),
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceCtrl,
                            decoration: InputDecoration(labelText: t.listingPrice),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              final n = double.tryParse((v ?? '').trim());
                              if (n == null || n < 1) return t.priceInvalid;
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _areaCtrl,
                            decoration: InputDecoration(labelText: t.listingArea),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              final n = double.tryParse((v ?? '').trim());
                              if (n == null || n < 1) return t.areaRequired;
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _propertyType,
                      decoration: InputDecoration(labelText: t.listingPropertyType),
                      items: [
                        DropdownMenuItem(value: 'apartment', child: Text(t.propertyApartment)),
                        DropdownMenuItem(value: 'house', child: Text(t.propertyHouse)),
                        DropdownMenuItem(value: 'villa', child: Text(t.propertyVilla)),
                        DropdownMenuItem(value: 'land', child: Text(t.propertyLand)),
                        DropdownMenuItem(value: 'commercial', child: Text(t.propertyCommercial)),
                      ],
                      onChanged: (v) => setState(() => _propertyType = v ?? 'apartment'),
                    ),
                    const SizedBox(height: 20),
                    // ── Phase A1 fields ─────────────────────────────
                    Text(t.listingKindLabel,
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(value: 'sale', label: Text(t.listingKindSale)),
                        ButtonSegment(value: 'rent', label: Text(t.listingKindRent)),
                      ],
                      selected: {_listingKind},
                      onSelectionChanged: (s) => setState(() => _listingKind = s.first),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _bedroomsCtrl,
                            decoration: InputDecoration(labelText: t.listingBedrooms),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _bathroomsCtrl,
                            decoration: InputDecoration(labelText: t.listingBathrooms),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _floorCtrl,
                            decoration: InputDecoration(labelText: t.listingFloor),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _compoundCtrl,
                      decoration: InputDecoration(
                        labelText: t.listingCompound,
                        hintText: t.listingCompoundHint,
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    Text(t.listingFurnishedLabel,
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(t.listingFurnishedYes),
                          selected: _isFurnished == true,
                          onSelected: (_) => setState(() =>
                              _isFurnished = _isFurnished == true ? null : true),
                        ),
                        ChoiceChip(
                          label: Text(t.listingFurnishedNo),
                          selected: _isFurnished == false,
                          onSelected: (_) => setState(() =>
                              _isFurnished = _isFurnished == false ? null : false),
                        ),
                        ChoiceChip(
                          label: Text(t.listingFurnishedUnspecified),
                          selected: _isFurnished == null,
                          onSelected: (_) => setState(() => _isFurnished = null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: _deliveryStatus,
                      decoration: InputDecoration(labelText: t.listingDeliveryLabel),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(t.listingDeliveryUnspecified),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'ready',
                          child: Text(t.listingDeliveryReady),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'under_construction',
                          child: Text(t.listingDeliveryUnderConstruction),
                        ),
                      ],
                      onChanged: (v) => setState(() => _deliveryStatus = v),
                    ),
                    const SizedBox(height: 20),
                    Text(t.locationLabel,
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _govCtrl,
                      decoration: InputDecoration(labelText: t.listingGovernorate),
                      validator: (v) => (v == null || v.trim().length < 2)
                          ? t.required : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cityCtrl,
                            decoration: InputDecoration(labelText: t.listingCity),
                            validator: (v) => (v == null || v.trim().length < 2)
                                ? t.required : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _districtCtrl,
                            decoration: InputDecoration(labelText: t.listingDistrict),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latCtrl,
                            decoration: InputDecoration(labelText: t.listingLat),
                            keyboardType: const TextInputType.numberWithOptions(
                                signed: true, decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _lngCtrl,
                            decoration: InputDecoration(labelText: t.listingLng),
                            keyboardType: const TextInputType.numberWithOptions(
                                signed: true, decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        icon: _fetchingLocation
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location_rounded, size: 18),
                        label: Text(t.useMyLocation),
                        onPressed: _fetchingLocation ? null : _useMyLocation,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(t.photosLabel,
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 8),
                    _PhotosPicker(
                      photos: _photos,
                      onAdd: _pickPhotos,
                      onRemove: (i) => setState(() => _photos.removeAt(i)),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(t.publishListing),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      t.duplicatePhotoNote,
                      style: TextStyle(color: c.textSubtle, fontSize: 11, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickedPhoto {
  _PickedPhoto({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

class _PhotosPicker extends StatelessWidget {
  const _PhotosPicker({
    required this.photos,
    required this.onAdd,
    required this.onRemove,
  });
  final List<_PickedPhoto> photos;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < photos.length; i++)
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox.expand(
                    child: Image.memory(photos[i].bytes, fit: BoxFit.cover),
                  ),
                ),
                PositionedDirectional(
                  top: 2, end: 2,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => onRemove(i),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_rounded, color: c.textMuted, size: 22),
                const SizedBox(height: 4),
                Text(t.addPhoto, style: TextStyle(color: c.textMuted, fontSize: 11)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
