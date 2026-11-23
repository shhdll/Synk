// Badge names for the push text. Keep in step with
// lib/core/constants/badges.dart and the l10n files.

const names: Record<string, [string, string]> = {
  attend_1: ["First Step", "أول طلعة"],
  attend_10: ["Regular", "صار لك اسم"],
  attend_25: ["Synk Star", "نجم سينك"],
  attend_50: ["Legend", "أسطورة سينك"],
  host_1: ["First Host", "أول عزيمة"],
  host_10: ["Go-To Host", "عزايمك ما تنرد"],
  host_25: ["Open House", "بيتك مفتوح"],
  full_house: ["Full House", "ما بقى مكان"],
  variety_5: ["Explorer", "حب التجربة"],
  variety_10: ["Adventurer", "ما يفوتك شي"],
  variety_20: ["All-Rounder", "جربت كل شي"],
  variety_30: ["Tried It All", "ما خليت شي"],
  friends_5: ["Friendly", "صار لك أصدقاء"],
  friends_15: ["Well Known", "الكل يعرفك"],
  friends_30: ["Heart of the Group", "روح الجمعة"],
  together_5: ["Better Together", "مع صديقك"],
  streak_3: ["Warming Up", "بدأت تولع"],
  streak_8: ["On Fire", "ولعت"],
  streak_20: ["Unstoppable", "نار ما تنطفي"],
  streak_52: ["Full Year", "سنة كاملة"],
  five_star: ["Rising Star", "أول خمس نجوم"],
  rated_4_5: ["Trusted", "تقييمك يشرف"],
  rated_4_8: ["Golden Company", "رفقتك ذهب"],
  rater_10: ["Fair Say", "كلمة حق"],
  early_bird: ["Early Bird", "من أول الصبح"],
  night_owl: ["Night Owl", "أهل السهر"],
  lucky_spot: ["Lucky Spot", "الحظ معك"],
  weekend: ["Weekend Mode", "ويكند على أصوله"],
};

// "من أهل ..." needs the category with al-.
const categoriesAr: Record<string, string> = {
  "Padel": "البادل",
  "Tennis": "التنس",
  "Badminton": "الريشة الطائرة",
  "Table Tennis": "تنس الطاولة",
  "Football": "كرة القدم",
  "Basketball": "كرة السلة",
  "Volleyball": "الكرة الطائرة",
  "Golf": "الغولف",
  "Bowling": "البولينغ",
  "Karting": "الكارتينغ",
  "Martial Arts": "الفنون القتالية",
  "Paintball": "البينت بول",
  "Cycling": "الدراجات",
  "Running": "الجري",
  "Hiking": "الهايكنغ",
  "Climbing": "التسلق",
  "Camping": "التخييم",
  "Desert Trips": "الرحلات البرية",
  "Picnic": "النزهات",
  "Fitness": "اللياقة",
  "Yoga": "اليوغا",
  "Swimming": "السباحة",
  "Diving": "الغوص",
  "Skating": "التزلج",
  "Dance": "الرقص",
  "Coffee": "القهوة",
  "Cooking": "الطبخ",
  "Food": "الأكل",
  "Board Games": "الألعاب اللوحية",
  "Chess": "الشطرنج",
  "Escape Room": "غرف الهروب",
  "Trivia": "المسابقات",
  "Gaming": "ألعاب الفيديو",
  "Movies": "الأفلام",
  "Comedy": "الكوميديا",
  "Karaoke": "الكاريوكي",
  "Music": "الموسيقى",
  "Art": "الفن",
  "Pottery": "الفخار",
  "Museums": "المتاحف",
  "Books": "الكتب",
  "Photography": "التصوير",
  "Learning": "التعلم",
  "Volunteering": "التطوع",
  "Shopping": "التسوق",
};

export function badgeName(id: string, ar: boolean): string {
  if (id.startsWith("fan:")) {
    const category = id.slice(4);
    return ar
      ? `من أهل ${categoriesAr[category] ?? category}`
      : `${category} Fan`;
  }
  const name = names[id];
  if (!name) return ar ? "شارة جديدة" : "a new badge";
  return ar ? name[1] : name[0];
}
