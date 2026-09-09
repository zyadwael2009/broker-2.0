import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/geo/egypt.dart';
import '../../../core/image_compressor.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../theme.dart';
import '../../auth/data/models.dart' show AuthException;
import '../data/listings_repository.dart';
import '../data/listings_signal.dart';

/// The five stages of posting a property, in the order a broker
/// actually knows the answers: what it is, where it is, what it has,
/// what it looks like, then one last read-through before it goes live.
enum _Step { type, location, specs, photos, review }

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
  final _districtCtrl = TextEditingController();
  final _customCityCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _floorCtrl = TextEditingController();
  final _compoundCtrl = TextEditingController();

  _Step _step = _Step.type;
  String _propertyType = 'apartment';
  String _listingKind = 'sale'; // 'sale' | 'rent'
  String? _governorate;
  String? _city;              // null + _customCity set = broker typed one
  bool _customCity = false;
  int _bedrooms = 0;          // 0 = not specified
  int _bathrooms = 0;
  bool? _isFurnished;         // tri-state: null = unspecified
  String? _deliveryStatus;    // 'ready' | 'under_construction' | null
  bool _submitting = false;
  bool _fetchingLocation = false;

  final List<_PickedPhoto> _photos = [];
  final _picker = ImagePicker();

  @override
  void dispose() {
    for (final c in [
      _titleCtrl, _descCtrl, _priceCtrl, _areaCtrl, _districtCtrl,
      _customCityCtrl, _latCtrl, _lngCtrl, _floorCtrl, _compoundCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _cityValue =>
      _customCity ? _customCityCtrl.text.trim() : _city;

  Future<void> _useMyLocation() async {
    final t = AppL10n.of(context)!;
    setState(() => _fetchingLocation = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw Exception(t.locationPermissionDenied);
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
        SnackBar(content: Text(t.locationReadFailed('$e'))),
      );
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  Future<void> _pickPhotos() async {
    final t = AppL10n.of(context)!;
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
        SnackBar(content: Text(t.photoPickFailed('$e'))),
      );
    }
  }

  /// Everything the current step needs before we let the broker move on.
  /// Returns null when the step is complete, otherwise the message to
  /// show. Only the current step's fields are mounted, so the shared
  /// form key validates exactly this step.
  String? _blockerFor(_Step step) {
    final t = AppL10n.of(context)!;
    switch (step) {
      case _Step.type:
        return (_formKey.currentState?.validate() ?? false) ? null : '';
      case _Step.location:
        if (_governorate == null) return t.selectGovernorateFirst;
        final city = _cityValue;
        if (city == null || city.isEmpty) return t.selectCityFirst;
        if (!(_formKey.currentState?.validate() ?? false)) return '';
        final lat = double.tryParse(_latCtrl.text.trim());
        final lng = double.tryParse(_lngCtrl.text.trim());
        if (lat == null || lng == null) return t.coordsRequired;
        return null;
      case _Step.specs:
        return (_formKey.currentState?.validate() ?? false) ? null : '';
      case _Step.photos:
        return _photos.isEmpty ? t.atLeastOnePhoto : null;
      case _Step.review:
        return null;
    }
  }

  void _next() {
    final blocker = _blockerFor(_step);
    if (blocker != null) {
      // An empty string means the form already painted its own field
      // errors — a snackbar on top would just repeat them.
      if (blocker.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(blocker)));
      }
      return;
    }
    final i = _Step.values.indexOf(_step);
    if (i < _Step.values.length - 1) {
      setState(() => _step = _Step.values[i + 1]);
    }
  }

  void _back() {
    final i = _Step.values.indexOf(_step);
    if (i > 0) setState(() => _step = _Step.values[i - 1]);
  }

  Future<void> _submit() async {
    final t = AppL10n.of(context)!;
    // Re-check the two things a broker could have walked back and
    // cleared after passing them; the review step has no fields of its
    // own, so nothing else can have changed since.
    if (_photos.isEmpty) {
      setState(() => _step = _Step.photos);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.atLeastOnePhoto)));
      return;
    }
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    if (lat == null || lng == null) {
      setState(() => _step = _Step.location);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.coordsRequired)));
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(listingsRepositoryProvider);
      final floor = int.tryParse(_floorCtrl.text.trim());

      final listing = await repo.create({
        'title': _titleCtrl.text.trim(),
        if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
        'price_egp': _priceCtrl.text.trim(),
        'area_m2': _areaCtrl.text.trim(),
        'governorate': _governorate,
        'city': _cityValue,
        if (_districtCtrl.text.trim().isNotEmpty) 'district': _districtCtrl.text.trim(),
        'lat': lat,
        'lng': lng,
        'property_type': _propertyType,
        'listing_kind': _listingKind,
        if (_bedrooms > 0) 'bedrooms': _bedrooms,
        if (_bathrooms > 0) 'bathrooms': _bathrooms,
        if (floor != null) 'floor_number': floor,
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
    final index = _Step.values.indexOf(_step);
    final isLast = _step == _Step.review;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.newListing,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(
              t.createListingSubtitle,
              style: TextStyle(color: c.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: Row(
          children: [
            if (index > 0) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _submitting ? null : _back,
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: Text(t.stepBack),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _submitting ? null : (isLast ? _submit : _next),
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(isLast ? Icons.publish_rounded : Icons.arrow_forward_rounded,
                        size: 18),
                label: Text(isLast ? t.publishListing : t.stepContinue),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: AbsorbPointer(
          absorbing: _submitting,
          child: Column(
            children: [
              _StepHeader(current: _step),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      switch (_step) {
                        _Step.type => _typeStep(t, c),
                        _Step.location => _locationStep(t, c),
                        _Step.specs => _specsStep(t, c),
                        _Step.photos => _photosStep(t, c),
                        _Step.review => _reviewStep(t, c),
                      },
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step 1: what is it ──────────────────────────────────────────
  Widget _typeStep(AppL10n t, AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(label: t.listingKindLabel),
        _KindToggle(
          value: _listingKind,
          onChanged: (v) => setState(() => _listingKind = v),
        ),
        const SizedBox(height: 18),
        _SectionLabel(label: t.listingPropertyType),
        DropdownButtonFormField<String>(
          initialValue: _propertyType,
          items: [
            DropdownMenuItem(value: 'apartment', child: Text(t.propertyApartment)),
            DropdownMenuItem(value: 'house', child: Text(t.propertyHouse)),
            DropdownMenuItem(value: 'villa', child: Text(t.propertyVilla)),
            DropdownMenuItem(value: 'land', child: Text(t.propertyLand)),
            DropdownMenuItem(value: 'commercial', child: Text(t.propertyCommercial)),
          ],
          onChanged: (v) => setState(() => _propertyType = v ?? 'apartment'),
        ),
        const SizedBox(height: 18),
        _SectionLabel(label: t.listingTitle),
        TextFormField(
          controller: _titleCtrl,
          decoration: InputDecoration(hintText: t.listingTitleHint),
          textCapitalization: TextCapitalization.sentences,
          validator: (v) =>
              (v == null || v.trim().length < 3) ? t.titleMin3 : null,
        ),
        const SizedBox(height: 18),
        _SectionLabel(label: t.listingDescription),
        TextFormField(
          controller: _descCtrl,
          decoration: InputDecoration(hintText: t.listingDescriptionHint),
          textCapitalization: TextCapitalization.sentences,
          maxLines: 4,
        ),
      ],
    );
  }

  // ── Step 2: where is it ─────────────────────────────────────────
  Widget _locationStep(AppL10n t, AppColors c) {
    final cities = citiesFor(_governorate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(label: t.listingGovernorate),
        DropdownButtonFormField<String>(
          initialValue: _governorate,
          isExpanded: true,
          hint: Text(t.selectGovernorate),
          items: [
            for (final g in allGovernorates())
              DropdownMenuItem<String>(value: g, child: Text(g)),
          ],
          // Governorate and city are matched exactly by the browse
          // filters, so they come from the canonical list rather than
          // free text — a typo here would hide the listing from every
          // filtered search.
          onChanged: (v) => setState(() {
            _governorate = v;
            _city = null;
            _customCity = false;
            _customCityCtrl.clear();
          }),
        ),
        const SizedBox(height: 16),
        _SectionLabel(label: t.listingCity),
        DropdownButtonFormField<String>(
          initialValue: _customCity ? '__other__' : _city,
          isExpanded: true,
          hint: Text(t.selectCity),
          items: [
            for (final city in cities)
              DropdownMenuItem<String>(value: city, child: Text(city)),
            DropdownMenuItem<String>(
                value: '__other__', child: Text(t.cityOther)),
          ],
          onChanged: _governorate == null
              ? null
              : (v) => setState(() {
                    if (v == '__other__') {
                      _customCity = true;
                      _city = null;
                    } else {
                      _customCity = false;
                      _city = v;
                    }
                  }),
        ),
        if (_customCity) ...[
          const SizedBox(height: 10),
          TextFormField(
            controller: _customCityCtrl,
            decoration: InputDecoration(hintText: t.cityOtherHint),
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 16),
        _SectionLabel(label: t.listingDistrict),
        TextFormField(
          controller: _districtCtrl,
          decoration: InputDecoration(hintText: t.listingDistrictHint),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.my_location_rounded, size: 18, color: c.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.mapPinTitle,
                      style: TextStyle(
                          color: c.text, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton.icon(
                    icon: _fetchingLocation
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.gps_fixed_rounded, size: 16),
                    label: Text(t.useMyLocation),
                    onPressed: _fetchingLocation ? null : _useMyLocation,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                t.mapPinBody,
                style: TextStyle(color: c.textMuted, fontSize: 11, height: 1.5),
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
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 3: what does it have ───────────────────────────────────
  Widget _specsStep(AppL10n t, AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionLabel(label: t.listingPrice),
                  TextFormField(
                    controller: _priceCtrl,
                    decoration: InputDecoration(
                      suffixText: _listingKind == 'rent'
                          ? t.currencyEgpPerMonth
                          : t.currencyEgp,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').trim());
                      if (n == null || n < 1) return t.priceInvalid;
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionLabel(label: t.areaLabelShort),
                  TextFormField(
                    controller: _areaCtrl,
                    decoration: InputDecoration(suffixText: t.unitM2),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').trim());
                      if (n == null || n < 1) return t.areaRequired;
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _Counter(
                icon: Icons.bed_rounded,
                label: t.listingBedrooms,
                value: _bedrooms,
                onChanged: (v) => setState(() => _bedrooms = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Counter(
                icon: Icons.bathtub_outlined,
                label: t.listingBathrooms,
                value: _bathrooms,
                onChanged: (v) => setState(() => _bathrooms = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionLabel(label: t.listingFloor),
        TextFormField(
          controller: _floorCtrl,
          decoration: InputDecoration(hintText: t.listingFloorHint),
          keyboardType: const TextInputType.numberWithOptions(signed: true),
        ),
        const SizedBox(height: 16),
        _SectionLabel(label: t.listingCompound),
        TextFormField(
          controller: _compoundCtrl,
          decoration: InputDecoration(hintText: t.listingCompoundHint),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 16),
        _SectionLabel(label: t.listingFurnishedLabel),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text(t.listingFurnishedYes),
              selected: _isFurnished == true,
              onSelected: (_) => setState(
                  () => _isFurnished = _isFurnished == true ? null : true),
            ),
            ChoiceChip(
              label: Text(t.listingFurnishedNo),
              selected: _isFurnished == false,
              onSelected: (_) => setState(
                  () => _isFurnished = _isFurnished == false ? null : false),
            ),
            ChoiceChip(
              label: Text(t.listingFurnishedUnspecified),
              selected: _isFurnished == null,
              onSelected: (_) => setState(() => _isFurnished = null),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionLabel(label: t.listingDeliveryLabel),
        DropdownButtonFormField<String?>(
          initialValue: _deliveryStatus,
          items: [
            DropdownMenuItem<String?>(
                value: null, child: Text(t.listingDeliveryUnspecified)),
            DropdownMenuItem<String?>(
                value: 'ready', child: Text(t.listingDeliveryReady)),
            DropdownMenuItem<String?>(
              value: 'under_construction',
              child: Text(t.listingDeliveryUnderConstruction),
            ),
          ],
          onChanged: (v) => setState(() => _deliveryStatus = v),
        ),
      ],
    );
  }

  // ── Step 4: photos ──────────────────────────────────────────────
  Widget _photosStep(AppL10n t, AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(label: t.photosLabel),
        Text(
          t.photosStepHint,
          style: TextStyle(color: c.textMuted, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 12),
        _PhotosPicker(
          photos: _photos,
          onAdd: _pickPhotos,
          onRemove: (i) => setState(() => _photos.removeAt(i)),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.surfaceLow,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: c.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.duplicatePhotoNote,
                  style:
                      TextStyle(color: c.textMuted, fontSize: 11, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Ownership documents attach after the listing exists — they
        // hang off a listing id — so this step points at where that
        // happens rather than pretending to collect them here.
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.verifiedBg,
            border: Border.all(color: c.verifiedLine),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.description_outlined, size: 18, color: c.verified),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.documentsAfterPublishTitle,
                      style: TextStyle(
                          color: c.verified,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.documentsAfterPublishBody,
                      style: TextStyle(
                          color: c.textMuted, fontSize: 11, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 5: read it back ────────────────────────────────────────
  Widget _reviewStep(AppL10n t, AppColors c) {
    String typeLabel() => switch (_propertyType) {
          'apartment' => t.propertyApartment,
          'house' => t.propertyHouse,
          'villa' => t.propertyVilla,
          'land' => t.propertyLand,
          'commercial' => t.propertyCommercial,
          _ => _propertyType,
        };

    final place = [
      _districtCtrl.text.trim(),
      _cityValue ?? '',
      _governorate ?? '',
    ].where((s) => s.isNotEmpty).join('، ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_photos.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.memory(_photos.first.bytes, fit: BoxFit.cover),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                _titleCtrl.text.trim(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _priceCtrl.text.trim(),
                    style: TextStyle(
                        color: c.primary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _listingKind == 'rent'
                        ? t.currencyEgpPerMonth
                        : t.currencyEgp,
                    style: TextStyle(
                        color: c.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _ReviewRow(label: t.typeLabelShort, value: typeLabel()),
              _ReviewRow(label: t.locationLabel, value: place),
              _ReviewRow(
                  label: t.areaLabelShort,
                  value: '${_areaCtrl.text.trim()} ${t.unitM2}'),
              if (_bedrooms > 0)
                _ReviewRow(label: t.listingBedrooms, value: '$_bedrooms'),
              if (_bathrooms > 0)
                _ReviewRow(label: t.listingBathrooms, value: '$_bathrooms'),
              if (_floorCtrl.text.trim().isNotEmpty)
                _ReviewRow(label: t.listingFloor, value: _floorCtrl.text.trim()),
              if (_compoundCtrl.text.trim().isNotEmpty)
                _ReviewRow(
                    label: t.listingCompound, value: _compoundCtrl.text.trim()),
              _ReviewRow(
                  label: t.photosLabel, value: '${_photos.length}'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.surfaceLow,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: c.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.publishExpiryNote,
                  style:
                      TextStyle(color: c.textMuted, fontSize: 11, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Progress bar + the five stop names, so a broker mid-flow can see how
/// much is left and what is still coming.
class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.current});
  final _Step current;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final index = _Step.values.indexOf(current);
    final total = _Step.values.length;

    String name(_Step s) => switch (s) {
          _Step.type => t.stepType,
          _Step.location => t.stepLocation,
          _Step.specs => t.stepSpecs,
          _Step.photos => t.stepPhotos,
          _Step.review => t.stepReview,
        };

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                t.stepCounter(index + 1, total),
                style: TextStyle(
                    color: c.text, fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                name(current),
                style: TextStyle(
                    color: c.primary, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (index + 1) / total,
              minHeight: 6,
              backgroundColor: c.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(c.primary),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 24,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: total,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final done = i < index;
                final active = i == index;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: active
                        ? c.primary.withValues(alpha: 0.15)
                        : (done ? c.verifiedBg : c.surfaceAlt),
                    border: Border.all(
                      color: active
                          ? c.primary
                          : (done ? c.verifiedLine : c.border),
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (done) ...[
                        Icon(Icons.check_rounded, size: 11, color: c.verified),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        name(_Step.values[i]),
                        style: TextStyle(
                          color: active
                              ? c.primary
                              : (done ? c.verified : c.textSubtle),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _KindToggle extends StatelessWidget {
  const _KindToggle({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context)!;
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;

    Widget option(String key, String label, IconData icon) {
      final active = key == value;
      return Expanded(
        child: InkWell(
          onTap: () => onChanged(key),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: active ? c.primary : c.surface,
              border: Border.all(color: active ? c.primary : c.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 16,
                    color: active
                        ? (dark ? c.background : Colors.white)
                        : c.textMuted),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: active
                        ? (dark ? c.background : Colors.white)
                        : c.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        option('sale', t.listingKindSale, Icons.sell_outlined),
        const SizedBox(width: 10),
        option('rent', t.listingKindRent, Icons.vpn_key_outlined),
      ],
    );
  }
}

/// Plus/minus stepper. Zero reads as "not specified" — brokers listing
/// land or a shop shouldn't have to type a bedroom count they don't have.
class _Counter extends StatelessWidget {
  const _Counter({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: c.textMuted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(color: c.textMuted, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _RoundButton(
                icon: Icons.remove_rounded,
                onTap: value <= 0 ? null : () => onChanged(value - 1),
              ),
              Text(
                value == 0 ? '—' : '$value',
                style: TextStyle(
                    color: c.text, fontSize: 17, fontWeight: FontWeight.w700),
              ),
              _RoundButton(
                icon: Icons.add_rounded,
                onTap: value >= 20 ? null : () => onChanged(value + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surfaceAlt,
      shape: CircleBorder(side: BorderSide(color: c.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon,
              size: 16, color: onTap == null ? c.textSubtle : c.text),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(label, style: Theme.of(context).textTheme.labelSmall),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(color: c.textSubtle, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                  color: c.text, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
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
                if (i == 0)
                  PositionedDirectional(
                    bottom: 2,
                    start: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        t.coverPhoto,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700),
                      ),
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
