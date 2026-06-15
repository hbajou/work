const KANA_ROMaji = {
  あ: "a", い: "i", う: "u", え: "e", お: "o",
  か: "ka", き: "ki", く: "ku", け: "ke", こ: "ko",
  さ: "sa", し: "shi", す: "su", せ: "se", そ: "so",
  た: "ta", ち: "chi", つ: "tsu", て: "te", と: "to",
  な: "na", に: "ni", ぬ: "nu", ね: "ne", の: "no",
  は: "ha", ひ: "hi", ふ: "fu", へ: "he", ほ: "ho",
  ま: "ma", み: "mi", む: "mu", め: "me", も: "mo",
  や: "ya", ゆ: "yu", よ: "yo",
  ら: "ra", り: "ri", る: "ru", れ: "re", ろ: "ro",
  わ: "wa", を: "wo", ん: "n",
  が: "ga", ぎ: "gi", ぐ: "gu", げ: "ge", ご: "go",
  ざ: "za", じ: "ji", ず: "zu", ぜ: "ze", ぞ: "zo",
  だ: "da", ぢ: "ji", づ: "zu", で: "de", ど: "do",
  ば: "ba", び: "bi", ぶ: "bu", べ: "be", ぼ: "bo",
  ぱ: "pa", ぴ: "pi", ぷ: "pu", ぺ: "pe", ぽ: "po",
  ぁ: "a", ぃ: "i", ぅ: "u", ぇ: "e", ぉ: "o",
};

const SMALL_Y = { ゃ: "a", ゅ: "u", ょ: "o" };

/** ひらがな → ヘボン式ローマ字 */
function hiraganaToRomaji(hira) {
  let result = "";
  for (let i = 0; i < hira.length; i++) {
    const ch = hira[i];

    if (ch === "っ") {
      const next = hira[i + 1];
      const rom = next ? kanaToRomajiAt(hira, i + 1) : "";
      if (rom) result += rom[0];
      continue;
    }

    if (ch === "ん") {
      result += "n";
      continue;
    }

    if (ch === "ー") continue;

    const smallY = hira[i + 1];
    if (SMALL_Y[smallY] && KANA_ROMaji[ch]) {
      const base = KANA_ROMaji[ch];
      const c = base.slice(0, -1);
      result += c + SMALL_Y[smallY];
      i++;
      continue;
    }

    const rom = KANA_ROMaji[ch];
    if (rom) result += rom;
  }
  return result;
}

function kanaToRomajiAt(hira, i) {
  const ch = hira[i];
  const smallY = hira[i + 1];
  if (SMALL_Y[smallY] && KANA_ROMaji[ch]) {
    const base = KANA_ROMaji[ch];
    return base.slice(0, -1) + SMALL_Y[smallY];
  }
  return KANA_ROMaji[ch] || "";
}

/** 入力正規化（小文字・スペース除去） */
function normalizeInput(str) {
  return str.toLowerCase().replace(/\s/g, "");
}

/** ローマ字の別表記を生成（ヘボン式・訓令式など） */
function romajiVariants(romaji) {
  const pairs = [
    ["chou", "tyou"], ["shou", "syou"],
    ["chuu", "tyuu"], ["shuu", "syuu"],
    ["cha", "tya"], ["chu", "tyu"], ["cho", "tyo"], ["che", "tye"],
    ["sha", "sya"], ["shu", "syu"], ["sho", "syo"],
    ["shi", "si"], ["chi", "ti"], ["tsu", "tu"],
    ["fu", "hu"], ["ji", "zi"],
  ].sort((a, b) => b[0].length - a[0].length);

  const variants = new Set([romaji]);
  let grew;
  do {
    grew = false;
    for (const v of [...variants]) {
      for (const [a, b] of pairs) {
        if (v.includes(a)) {
          const next = v.replaceAll(a, b);
          if (!variants.has(next)) { variants.add(next); grew = true; }
        }
        if (v.includes(b)) {
          const next = v.replaceAll(b, a);
          if (!variants.has(next)) { variants.add(next); grew = true; }
        }
      }
    }
  } while (grew);
  return [...variants];
}

/** 読み（ひらがな配列）から受け入れるローマ字一覧 */
function acceptedRomaji(readings) {
  const set = new Set();
  for (const hira of readings) {
    const base = hiraganaToRomaji(hira);
    for (const v of romajiVariants(base)) set.add(v);
  }
  return set;
}

/** 入力が正解か（前方一致でタイピング中判定にも使う） */
function matchesReading(input, readings) {
  const norm = normalizeInput(input);
  const accepted = acceptedRomaji(readings);
  for (const rom of accepted) {
    if (rom === norm || rom.startsWith(norm)) return { complete: rom === norm, prefix: true };
  }
  return { complete: false, prefix: false };
}

function isCompleteMatch(input, readings) {
  const norm = normalizeInput(input);
  return acceptedRomaji(readings).has(norm);
}
