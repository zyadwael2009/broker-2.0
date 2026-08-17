"""Canonical Egyptian governorates + top cities.

Ordering: population-descending among the ones brokers actually work
with, so the dropdown defaults show the useful options first.

CRITICAL: the English spellings here MUST match the strings the
seed-demo already wrote to the DB — `Listing.governorate == "Cairo"`
would silently exclude rows if we renamed to "Cairo Governorate" or
similar. If you touch a name, grep `seed_demo` in `app/cli.py` first.

Cities under each governorate are the ones brokers list against, not
every administrative division. Buyers can still enter arbitrary cities
via free-text (backward compat); the dropdown is a UX guide.
"""
from __future__ import annotations

from typing import Optional


GOVERNORATES: list[dict] = [
    {
        "key": "cairo", "en": "Cairo", "ar": "القاهرة",
        "cities": [
            "Cairo", "New Cairo", "Nasr City", "Maadi", "Heliopolis",
            "Zamalek", "Downtown", "Shubra", "Ain Shams", "El Marg",
            "Helwan", "El Rehab", "Madinaty", "Katameya", "El Mokattam",
        ],
    },
    {
        "key": "giza", "en": "Giza", "ar": "الجيزة",
        "cities": [
            "Giza", "6th of October", "Sheikh Zayed", "Dokki", "Mohandessin",
            "Haram", "Faisal", "Imbaba", "El Warraq", "Boulaq El Dakrour",
        ],
    },
    {
        "key": "alexandria", "en": "Alexandria", "ar": "الإسكندرية",
        "cities": [
            "Alexandria", "Smouha", "Sidi Gaber", "Miami", "Sidi Bishr",
            "Montaza", "Stanley", "Roushdy", "Kafr Abdo", "Agami",
        ],
    },
    {
        "key": "qalyubia", "en": "Qalyubia", "ar": "القليوبية",
        "cities": ["Banha", "Shubra El Kheima", "Qalyub", "Qaha", "El Khanka"],
    },
    {
        "key": "gharbia", "en": "Gharbia", "ar": "الغربية",
        "cities": ["Tanta", "El Mahalla El Kubra", "Kafr El Zayat", "Zefta", "Samannoud"],
    },
    {
        "key": "menoufia", "en": "Menoufia", "ar": "المنوفية",
        "cities": ["Shibin El Kom", "Ashmoun", "Menouf", "Sadat City", "Quesna"],
    },
    {
        "key": "dakahlia", "en": "Dakahlia", "ar": "الدقهلية",
        "cities": ["Mansoura", "Talkha", "Mit Ghamr", "Aga", "Belqas"],
    },
    {
        "key": "sharqia", "en": "Sharqia", "ar": "الشرقية",
        "cities": ["Zagazig", "10th of Ramadan", "Bilbeis", "Minya El Qamh", "Faqous"],
    },
    {
        "key": "kafr-el-sheikh", "en": "Kafr El Sheikh", "ar": "كفر الشيخ",
        "cities": ["Kafr El Sheikh", "Desouk", "Foh", "Baltim", "Metoubes"],
    },
    {
        "key": "damietta", "en": "Damietta", "ar": "دمياط",
        "cities": ["Damietta", "New Damietta", "Ras El Bar", "Faraskur", "Kafr Saad"],
    },
    {
        "key": "port-said", "en": "Port Said", "ar": "بورسعيد",
        "cities": ["Port Said", "Port Fouad"],
    },
    {
        "key": "ismailia", "en": "Ismailia", "ar": "الإسماعيلية",
        "cities": ["Ismailia", "Fayed", "Qantara", "Abu Suwir"],
    },
    {
        "key": "suez", "en": "Suez", "ar": "السويس",
        "cities": ["Suez", "Ataqa", "Ain Sokhna"],
    },
    {
        "key": "north-sinai", "en": "North Sinai", "ar": "شمال سيناء",
        "cities": ["Arish", "Bir El Abd", "Rafah", "Sheikh Zuweid"],
    },
    {
        "key": "south-sinai", "en": "South Sinai", "ar": "جنوب سيناء",
        "cities": ["Sharm El Sheikh", "Dahab", "Nuweiba", "Taba", "El Tor"],
    },
    {
        "key": "red-sea", "en": "Red Sea", "ar": "البحر الأحمر",
        "cities": ["Hurghada", "El Gouna", "Sahl Hasheesh", "Marsa Alam", "Safaga"],
    },
    {
        "key": "matrouh", "en": "Matrouh", "ar": "مطروح",
        "cities": [
            "Marsa Matrouh", "Sidi Abdel Rahman", "El Alamein",
            "New Alamein", "North Coast",
        ],
    },
    {
        "key": "beheira", "en": "Beheira", "ar": "البحيرة",
        "cities": ["Damanhur", "Kafr El Dawwar", "Rashid", "Edku", "Abu El Matamir"],
    },
    {
        "key": "fayoum", "en": "Fayoum", "ar": "الفيوم",
        "cities": ["Fayoum", "Tamiya", "Sinnuris", "Ibshaway", "Yousef El Seddik"],
    },
    {
        "key": "beni-suef", "en": "Beni Suef", "ar": "بني سويف",
        "cities": ["Beni Suef", "New Beni Suef", "Nasser", "Ihnasia", "Biba"],
    },
    {
        "key": "minya", "en": "Minya", "ar": "المنيا",
        "cities": ["Minya", "Mallawi", "Beni Mazar", "Samalut", "New Minya"],
    },
    {
        "key": "assiut", "en": "Assiut", "ar": "أسيوط",
        "cities": ["Assiut", "New Assiut", "Manfalut", "Abnub", "Dayrout"],
    },
    {
        "key": "sohag", "en": "Sohag", "ar": "سوهاج",
        "cities": ["Sohag", "New Sohag", "Akhmim", "Girga", "Tahta"],
    },
    {
        "key": "qena", "en": "Qena", "ar": "قنا",
        "cities": ["Qena", "New Qena", "Nag Hammadi", "Qus", "Deshna"],
    },
    {
        "key": "luxor", "en": "Luxor", "ar": "الأقصر",
        "cities": ["Luxor", "New Luxor", "Esna", "Armant"],
    },
    {
        "key": "aswan", "en": "Aswan", "ar": "أسوان",
        "cities": ["Aswan", "New Aswan", "Kom Ombo", "Edfu", "Daraw"],
    },
    {
        "key": "new-valley", "en": "New Valley", "ar": "الوادي الجديد",
        "cities": ["Kharga", "Dakhla", "Farafra", "Balat"],
    },
]


def all_governorates() -> list[str]:
    """English names, in canonical order — for dropdowns."""
    return [g["en"] for g in GOVERNORATES]


def cities_for(governorate_en: str) -> list[str]:
    """Cities under a governorate. Empty list if the governorate name
    isn't in the canonical set (e.g. broker typed a custom value)."""
    g = governorate_by_en(governorate_en)
    return list(g["cities"]) if g else []


def governorate_by_en(en: str) -> Optional[dict]:
    """Case-insensitive lookup by English name."""
    if not en:
        return None
    low = en.strip().lower()
    for g in GOVERNORATES:
        if g["en"].lower() == low:
            return g
    return None


def is_valid_governorate(en: str) -> bool:
    return governorate_by_en(en) is not None
