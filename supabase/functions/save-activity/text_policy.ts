// Synk's own text rule, checked before OpenAI. The moderation model judges
// context, so a lone word such as "sex" can come back clean; for activity
// titles, descriptions and locations, obvious sexual or explicit terms are
// never acceptable. Only whole words match, so "Sussex", "Essex", "unisex"
// or "الجنسين" stay fine.
//
// The handler only learns true or false: the matched word never leaves this
// file, and the app just gets the usual "rejected" with the field name.

const INVISIBLE = /[­͏؜ᅟᅠ឴឵᠎​-‏‪-‮⁠-⁤⁦-⁯ㅤ︀-️﻿ﾠ]/gu;
const HARAKAT = /[ؐ-ًؚ-ٰٟۖ-ۜ۟-۪ۨ-ۭ]/gu;
const TATWEEL = /ـ/gu;

// English terms, lower case. Words with common innocent uses (e.g. "naked
// eye", "tits" the bird, "threesome" in golf) are left to the model.
const ENGLISH = [
  "sex",
  "sexy",
  "sexting",
  "seks",
  "secks",
  "seggs",
  "porn",
  "porno",
  "pornography",
  "pornographic",
  "pornhub",
  "xvideos",
  "xnxx",
  "nsfw",
  "nudes",
  "nudity",
  "erotic",
  "erotica",
  "fetish",
  "bdsm",
  "orgy",
  "orgasm",
  "horny",
  "slut",
  "whore",
  "hentai",
  "milf",
  "onlyfans",
  "camgirl",
  "blowjob",
  "handjob",
  "cumshot",
  "boobs",
  "dildo",
];

// Arabic terms, after the letter normalization below (أإآ→ا, ة→ه, ى→ي).
// "جنس" alone isn't listed: it also means gender, as in "الجنسين".
const ARABIC = [
  "سكس",
  "سكسي",
  "سكسيه",
  "اباحي",
  "اباحيه",
  "اباحيات",
  "بورنو",
  "عاريه",
  "عاريات",
  "عراه",
  "جماع",
  "شرموطه",
  "شراميط",
  "قحبه",
  "عاهره",
  "دعاره",
  "نياكه",
  "منيوك",
];

// Short Arabic terms that only match as the whole word: with a prefix
// removed they'd hit innocent words (e.g. "بنيك", your sons).
const ARABIC_EXACT = ["نيك", "كس", "زب"];

// Two-word phrases, normalized.
const PHRASES: [string, string][] = [
  ["ممارسه", "الجنس"],
  ["ممارسه", "جنس"],
];

// Arabic prefixes that attach to a word: and, by, the, for, like.
const ARABIC_PREFIX = /^(?:وبال|وال|بال|فال|كال|لل|ال|و|ف|ب|ل|ك)/u;

// Look-alike letters from other scripts (Cyrillic) that NFKC keeps.
const CONFUSABLES: Record<string, string> = {
  "а": "a",
  "е": "e",
  "о": "o",
  "р": "p",
  "с": "c",
  "х": "x",
  "ѕ": "s",
  "і": "i",
  "у": "y",
  "к": "k",
  "м": "m",
  "т": "t",
};

// Digits and symbols used for letters: s3x, p0rn, $ex, pr0n.
const LEET: Record<string, string> = {
  "0": "o",
  "1": "i",
  "3": "e",
  "4": "a",
  "5": "s",
  "7": "t",
  "@": "a",
  "$": "s",
};

const ENGLISH_SET = new Set(ENGLISH);
const ARABIC_SET = new Set(ARABIC);
const ARABIC_EXACT_SET = new Set(ARABIC_EXACT);
const ALL_TERMS = [...ENGLISH, ...ARABIC, ...ARABIC_EXACT];

// The spellings to compare for one word: as written, letters repeated 3+
// times cut to 2 ("boooobs"), and every repeat cut to 1 ("sexxx", "seexx").
// Only the user's word is shortened, never the terms, so "Bob's" can't
// become "boobs".
const spellings = (word: string) =>
  new Set([
    word,
    word.replace(/(.)\1{2,}/gu, "$1$1"),
    word.replace(/(.)\1+/gu, "$1"),
  ]);

function normalizeArabic(text: string): string {
  return text
    .replace(/[أإآٱ]/gu, "ا")
    .replace(/ة/gu, "ه")
    .replace(/ى/gu, "ي");
}

// Lower case, compatibility forms folded, invisible characters, harakat
// and stretched letters removed, look-alike letters replaced.
function base(value: string): string {
  return normalizeArabic(
    value
      .normalize("NFKC")
      .toLowerCase()
      .replace(INVISIBLE, "")
      .replace(HARAKAT, "")
      .replace(TATWEEL, ""),
  ).replace(/./gu, (char) => CONFUSABLES[char] ?? char);
}

// "s e x" → "sex": single letters separated by single spaces are joined.
function joinSpacedLetters(text: string): string {
  let previous: string;
  do {
    previous = text;
    text = text.replace(
      /(?<![\p{L}\p{N}])(\p{L}) (?=\p{L}(?![\p{L}\p{N}]))/gu,
      "$1",
    );
  } while (text !== previous);
  return text;
}

const words = (text: string) =>
  joinSpacedLetters(text.replace(/\s+/gu, " ").trim())
    .split(" ")
    .filter((word) => word.length > 0);

function isTerm(word: string): boolean {
  for (const candidate of spellings(word)) {
    if (ENGLISH_SET.has(candidate) || ARABIC_SET.has(candidate)) return true;
    if (ARABIC_EXACT_SET.has(candidate)) return true;
    if (/^x{3,}$/u.test(candidate)) return true;
    const stripped = candidate.replace(ARABIC_PREFIX, "");
    if (stripped !== candidate && ARABIC_SET.has(stripped)) return true;
  }
  return false;
}

// "s*x", "p*rn": a star stands for one letter or none.
function matchesStarred(word: string): boolean {
  if (!word.includes("*") || word.replace(/\*/gu, "").length < 2) return false;
  const pattern = new RegExp(
    "^" +
      word
        .split("*")
        .map((part) => part.replace(/[.*+?^${}()|[\]\\]/gu, "\\$&"))
        .join("\\p{L}?") +
      "$",
    "u",
  );
  return ALL_TERMS.some((term) => pattern.test(term));
}

function hasPhrase(list: string[]): boolean {
  for (let i = 0; i + 1 < list.length; i++) {
    const first = list[i].replace(/^و/u, "");
    if (PHRASES.some(([a, b]) => first === a && list[i + 1] === b)) {
      return true;
    }
  }
  return false;
}

// True when the text contains an obvious sexual or explicit term, as a
// whole word, including spaced, stretched, repeated, look-alike, leetspeak
// and punctuated spellings.
export function violatesTextPolicy(value: string | null): boolean {
  if (value === null || value.trim().length === 0) return false;
  const text = base(value);
  const leet = text.replace(/[013457@$]/gu, (char) => LEET[char]);

  // Starred spellings, before the stars are dropped as punctuation.
  for (const word of text.split(/[^\p{L}\p{N}*$@]+/u)) {
    if (matchesStarred(word.replace(/[013457@$]/gu, (c) => LEET[c]))) {
      return true;
    }
  }

  for (const source of new Set([text, leet])) {
    const variants = [
      // Punctuation splits words: "sex-party" → "sex party", "s.e.x" → "s e x".
      source.replace(/[^\p{L}\p{N}\s]/gu, " "),
      // Punctuation dropped: "se.x" → "sex".
      source.replace(/[^\p{L}\p{N}\s]/gu, ""),
    ];
    for (const variant of variants) {
      const list = words(variant);
      if (list.some(isTerm) || hasPhrase(list)) return true;
    }
  }
  return false;
}
