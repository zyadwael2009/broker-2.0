/// Canonical Egyptian governorates + top cities.
///
/// Mirror of `backend/app/geo/egypt.py` — MUST stay in sync (spelling
/// especially: backend filters are exact-string, so `Cairo` here must
/// match `Cairo` in the DB row).
///
/// Ordered population-descending for the useful ones brokers actually
/// work with. Cities under each governorate are the ones brokers list
/// against — buyers can still enter arbitrary strings.
class EgyptGovernorate {
  const EgyptGovernorate({
    required this.key,
    required this.en,
    required this.ar,
    required this.cities,
  });

  final String key;
  final String en;
  final String ar;
  final List<String> cities;
}

const List<EgyptGovernorate> egyptGovernorates = <EgyptGovernorate>[
  EgyptGovernorate(
    key: 'cairo', en: 'Cairo', ar: 'القاهرة',
    cities: [
      'Cairo', 'New Cairo', 'Nasr City', 'Maadi', 'Heliopolis',
      'Zamalek', 'Downtown', 'Shubra', 'Ain Shams', 'El Marg',
      'Helwan', 'El Rehab', 'Madinaty', 'Katameya', 'El Mokattam',
    ],
  ),
  EgyptGovernorate(
    key: 'giza', en: 'Giza', ar: 'الجيزة',
    cities: [
      'Giza', '6th of October', 'Sheikh Zayed', 'Dokki', 'Mohandessin',
      'Haram', 'Faisal', 'Imbaba', 'El Warraq', 'Boulaq El Dakrour',
    ],
  ),
  EgyptGovernorate(
    key: 'alexandria', en: 'Alexandria', ar: 'الإسكندرية',
    cities: [
      'Alexandria', 'Smouha', 'Sidi Gaber', 'Miami', 'Sidi Bishr',
      'Montaza', 'Stanley', 'Roushdy', 'Kafr Abdo', 'Agami',
    ],
  ),
  EgyptGovernorate(
    key: 'qalyubia', en: 'Qalyubia', ar: 'القليوبية',
    cities: ['Banha', 'Shubra El Kheima', 'Qalyub', 'Qaha', 'El Khanka'],
  ),
  EgyptGovernorate(
    key: 'gharbia', en: 'Gharbia', ar: 'الغربية',
    cities: ['Tanta', 'El Mahalla El Kubra', 'Kafr El Zayat', 'Zefta', 'Samannoud'],
  ),
  EgyptGovernorate(
    key: 'menoufia', en: 'Menoufia', ar: 'المنوفية',
    cities: ['Shibin El Kom', 'Ashmoun', 'Menouf', 'Sadat City', 'Quesna'],
  ),
  EgyptGovernorate(
    key: 'dakahlia', en: 'Dakahlia', ar: 'الدقهلية',
    cities: ['Mansoura', 'Talkha', 'Mit Ghamr', 'Aga', 'Belqas'],
  ),
  EgyptGovernorate(
    key: 'sharqia', en: 'Sharqia', ar: 'الشرقية',
    cities: ['Zagazig', '10th of Ramadan', 'Bilbeis', 'Minya El Qamh', 'Faqous'],
  ),
  EgyptGovernorate(
    key: 'kafr-el-sheikh', en: 'Kafr El Sheikh', ar: 'كفر الشيخ',
    cities: ['Kafr El Sheikh', 'Desouk', 'Foh', 'Baltim', 'Metoubes'],
  ),
  EgyptGovernorate(
    key: 'damietta', en: 'Damietta', ar: 'دمياط',
    cities: ['Damietta', 'New Damietta', 'Ras El Bar', 'Faraskur', 'Kafr Saad'],
  ),
  EgyptGovernorate(
    key: 'port-said', en: 'Port Said', ar: 'بورسعيد',
    cities: ['Port Said', 'Port Fouad'],
  ),
  EgyptGovernorate(
    key: 'ismailia', en: 'Ismailia', ar: 'الإسماعيلية',
    cities: ['Ismailia', 'Fayed', 'Qantara', 'Abu Suwir'],
  ),
  EgyptGovernorate(
    key: 'suez', en: 'Suez', ar: 'السويس',
    cities: ['Suez', 'Ataqa', 'Ain Sokhna'],
  ),
  EgyptGovernorate(
    key: 'north-sinai', en: 'North Sinai', ar: 'شمال سيناء',
    cities: ['Arish', 'Bir El Abd', 'Rafah', 'Sheikh Zuweid'],
  ),
  EgyptGovernorate(
    key: 'south-sinai', en: 'South Sinai', ar: 'جنوب سيناء',
    cities: ['Sharm El Sheikh', 'Dahab', 'Nuweiba', 'Taba', 'El Tor'],
  ),
  EgyptGovernorate(
    key: 'red-sea', en: 'Red Sea', ar: 'البحر الأحمر',
    cities: ['Hurghada', 'El Gouna', 'Sahl Hasheesh', 'Marsa Alam', 'Safaga'],
  ),
  EgyptGovernorate(
    key: 'matrouh', en: 'Matrouh', ar: 'مطروح',
    cities: [
      'Marsa Matrouh', 'Sidi Abdel Rahman', 'El Alamein',
      'New Alamein', 'North Coast',
    ],
  ),
  EgyptGovernorate(
    key: 'beheira', en: 'Beheira', ar: 'البحيرة',
    cities: ['Damanhur', 'Kafr El Dawwar', 'Rashid', 'Edku', 'Abu El Matamir'],
  ),
  EgyptGovernorate(
    key: 'fayoum', en: 'Fayoum', ar: 'الفيوم',
    cities: ['Fayoum', 'Tamiya', 'Sinnuris', 'Ibshaway', 'Yousef El Seddik'],
  ),
  EgyptGovernorate(
    key: 'beni-suef', en: 'Beni Suef', ar: 'بني سويف',
    cities: ['Beni Suef', 'New Beni Suef', 'Nasser', 'Ihnasia', 'Biba'],
  ),
  EgyptGovernorate(
    key: 'minya', en: 'Minya', ar: 'المنيا',
    cities: ['Minya', 'Mallawi', 'Beni Mazar', 'Samalut', 'New Minya'],
  ),
  EgyptGovernorate(
    key: 'assiut', en: 'Assiut', ar: 'أسيوط',
    cities: ['Assiut', 'New Assiut', 'Manfalut', 'Abnub', 'Dayrout'],
  ),
  EgyptGovernorate(
    key: 'sohag', en: 'Sohag', ar: 'سوهاج',
    cities: ['Sohag', 'New Sohag', 'Akhmim', 'Girga', 'Tahta'],
  ),
  EgyptGovernorate(
    key: 'qena', en: 'Qena', ar: 'قنا',
    cities: ['Qena', 'New Qena', 'Nag Hammadi', 'Qus', 'Deshna'],
  ),
  EgyptGovernorate(
    key: 'luxor', en: 'Luxor', ar: 'الأقصر',
    cities: ['Luxor', 'New Luxor', 'Esna', 'Armant'],
  ),
  EgyptGovernorate(
    key: 'aswan', en: 'Aswan', ar: 'أسوان',
    cities: ['Aswan', 'New Aswan', 'Kom Ombo', 'Edfu', 'Daraw'],
  ),
  EgyptGovernorate(
    key: 'new-valley', en: 'New Valley', ar: 'الوادي الجديد',
    cities: ['Kharga', 'Dakhla', 'Farafra', 'Balat'],
  ),
];

/// English names, in canonical order — for dropdowns.
List<String> allGovernorates() =>
    egyptGovernorates.map((g) => g.en).toList(growable: false);

/// Cities under a given governorate. Empty when the name doesn't match
/// any canonical entry (broker typed a custom value pre-A3-tail).
List<String> citiesFor(String? governorateEn) {
  if (governorateEn == null || governorateEn.isEmpty) return const [];
  final lower = governorateEn.trim().toLowerCase();
  for (final g in egyptGovernorates) {
    if (g.en.toLowerCase() == lower) return g.cities;
  }
  return const [];
}
