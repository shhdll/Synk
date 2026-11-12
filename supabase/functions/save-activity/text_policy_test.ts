import { assert, assertEquals } from "@std/assert";
import { violatesTextPolicy } from "./text_policy.ts";

Deno.test("text policy: a standalone 'sex' is rejected in any case", () => {
  for (const text of ["sex", "Sex", "SEX", "  sex  ", "Sex night"]) {
    assert(violatesTextPolicy(text), text);
  }
});

Deno.test("text policy: innocent words containing the letters are allowed", () => {
  for (
    const text of [
      "Sussex padel",
      "Essex football",
      "Middlesex cricket club",
      "Unisex yoga class",
      "Sextet rehearsal",
      "Sextant workshop",
      "Bob's padel",
      "Padel x Tennis",
      "3 x 3 basketball",
      "5 a side, 7 pm",
      "Pornic beach walk",
      "Mixed doubles for both genders",
      "مباراة مفتوحة للجنسين",
      "حسب الجنس",
      "الجنسية السعودية",
      "جماعة القهوة",
      "نشاط جماعي",
      "اجتماع الفريق",
      "كسرة خبز وقهوة",
      "زبدة الفول السوداني",
      "نيكول تنظم بادل",
      "تعال مع بنيك",
      "سكسوكة ولحية",
      "ليلة بادل",
    ]
  ) {
    assertEquals(violatesTextPolicy(text), false, text);
  }
  assertEquals(violatesTextPolicy(null), false);
  assertEquals(violatesTextPolicy(""), false);
});

Deno.test("text policy: English explicit terms and obfuscated spellings", () => {
  for (
    const text of [
      "sexy night",
      "s e x",
      "s.e.x party",
      "s-e-x",
      "se.x",
      "sexxx",
      "seeex",
      "s3x",
      "$ex party",
      "5ex",
      "s*x",
      "p*rn",
      "p0rn night",
      "PORN",
      "ｓｅｘ",
      "ѕех",
      "s​ex",
      "sex-party",
      "xxx",
      "XXXX movies",
      "boooobs",
      "nsfw meetup",
      "nudes",
      "OnlyFans shoot",
      "seggs",
    ]
  ) {
    assert(violatesTextPolicy(text), text);
  }
});

Deno.test("text policy: Arabic explicit terms and variations", () => {
  for (
    const text of [
      "سكس",
      "ليلة سكس",
      "والسكس",
      "سكسي",
      "س ك س",
      "سكسسس",
      "سـكـس",
      "سَكْس",
      "أفلام إباحية",
      "افلام اباحيه",
      "بورنو",
      "ممارسة الجنس",
      "وممارسة الجنس",
      "نيك",
      "شرموطة",
      "قحبة",
      "Padel وسكس",
    ]
  ) {
    assert(violatesTextPolicy(text), text);
  }
});
