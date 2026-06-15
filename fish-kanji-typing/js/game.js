const SCREENS = { TITLE: "title", PLAY: "play", RESULT: "result" };

const DEFAULTS = {
  questionCount: 40,
  timeLimit: 60,
  showFish: true,
  soundEnabled: true,
  readingMode: "hidden", // "hidden" | "always"
  poolMode: "all", // "all" | "single" | "multi"
};

const POOL_MODE_LABELS = { all: "すべて", single: "1字のみ", multi: "複合のみ" };

let state = {
  screen: SCREENS.TITLE,
  settings: { ...DEFAULTS },
  questions: [],
  currentIndex: 0,
  input: "",
  timeLeft: 0,
  timerId: null,
  hintsUsed: 0,
  correctCount: 0,
  hintVisible: false,
  startedAt: 0,
  stats: { correctKeys: 0, mistypes: 0 },
};

const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => document.querySelectorAll(sel);

let audioCtx = null;

function getAudioCtx() {
  if (!audioCtx) {
    audioCtx = new (window.AudioContext || window.webkitAudioContext)();
  }
  if (audioCtx.state === "suspended") audioCtx.resume();
  return audioCtx;
}

function playMistypeSound() {
  if (!state.settings.soundEnabled) return;
  try {
    const ctx = getAudioCtx();
    const t = ctx.currentTime;

    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sine";
    osc.frequency.setValueAtTime(300, t);
    osc.frequency.exponentialRampToValueAtTime(200, t + 0.09);
    gain.gain.setValueAtTime(0.04, t);
    gain.gain.exponentialRampToValueAtTime(0.001, t + 0.1);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start(t);
    osc.stop(t + 0.1);

    const low = ctx.createOscillator();
    const lowGain = ctx.createGain();
    low.type = "sine";
    low.frequency.setValueAtTime(130, t);
    lowGain.gain.setValueAtTime(0.02, t);
    lowGain.gain.exponentialRampToValueAtTime(0.001, t + 0.08);
    low.connect(lowGain);
    lowGain.connect(ctx.destination);
    low.start(t);
    low.stop(t + 0.085);
  } catch (_) { /* 音声不可環境は無視 */ }
}

/** 静音キー風のコトコト音 */
function playTypeSound() {
  if (!state.settings.soundEnabled) return;
  try {
    const ctx = getAudioCtx();
    const t = ctx.currentTime;

    const tick = ctx.createOscillator();
    const tickGain = ctx.createGain();
    tick.type = "sine";
    const freq = 480 + Math.random() * 100;
    tick.frequency.setValueAtTime(freq, t);
    tickGain.gain.setValueAtTime(0.03, t);
    tickGain.gain.exponentialRampToValueAtTime(0.001, t + 0.028);
    tick.connect(tickGain);
    tickGain.connect(ctx.destination);
    tick.start(t);
    tick.stop(t + 0.03);

    const thud = ctx.createOscillator();
    const thudGain = ctx.createGain();
    thud.type = "sine";
    thud.frequency.setValueAtTime(85 + Math.random() * 25, t);
    thudGain.gain.setValueAtTime(0.022, t);
    thudGain.gain.exponentialRampToValueAtTime(0.001, t + 0.022);
    thud.connect(thudGain);
    thudGain.connect(ctx.destination);
    thud.start(t);
    thud.stop(t + 0.025);
  } catch (_) { /* 音声不可環境は無視 */ }
}

function shuffle(arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function activePool() {
  return getKanjiPool(state.settings.poolMode);
}

function activePoolSize() {
  return activePool().length;
}

function pickQuestions(count) {
  const pool = shuffle(activePool());
  const n = count === 0 || count >= pool.length ? pool.length : count;
  return pool.slice(0, n);
}

function calcDefaultTime(count) {
  return Math.max(30, Math.round(count * 1.5));
}

function isEscape(e) {
  return e.key === "Escape" || e.code === "Escape";
}

function focusGame() {
  const area = $("#game-area");
  if (area) area.focus({ preventScroll: true });
}

function showScreen(name) {
  state.screen = name;
  $$(".screen").forEach((el) => el.classList.remove("active"));
  $(`#screen-${name}`).classList.add("active");
  if (name === SCREENS.PLAY) focusGame();
}

function updateSettingsUI() {
  const poolLen = activePoolSize();
  setSettingValue("pool", POOL_MODE_LABELS[state.settings.poolMode]);
  setSettingValue("questions", state.settings.questionCount === 0
    ? `すべて（${poolLen}問）`
    : `${state.settings.questionCount}問`);
  setSettingValue("time", `${state.settings.timeLimit}秒`);
  setSettingValue("fish", state.settings.showFish ? "ON" : "OFF");
  setSettingValue("sound", state.settings.soundEnabled ? "ON" : "OFF");
  setSettingValue("reading", state.settings.readingMode === "always" ? "常時表示" : "なし");
  $("#pool-size").textContent = poolLen;
}

function setSettingValue(name, text) {
  const el = $(`#setting-${name} .setting-value`);
  if (el) el.textContent = text;
}

function isReadingVisible() {
  return state.settings.readingMode === "always" || state.hintVisible;
}

function updatePlayFooter() {
  const footer = $("#play-footer-text");
  if (!footer) return;
  footer.textContent = state.settings.readingMode === "always"
    ? "読み仮名表示中 ／ Esc＝やめる"
    : "Enter＝ヒント（-5秒） ／ Esc＝やめる";
}

function cycleSetting(key, options) {
  const idx = options.indexOf(state.settings[key]);
  state.settings[key] = options[(idx + 1) % options.length];
  if (key === "questionCount" || key === "poolMode") {
    const n = state.settings.questionCount === 0
      ? activePoolSize()
      : state.settings.questionCount;
    state.settings.timeLimit = calcDefaultTime(n);
  }
  updateSettingsUI();
}

function startGame() {
  const poolLen = activePoolSize();
  const count = state.settings.questionCount === 0 ? poolLen : state.settings.questionCount;
  state.questions = pickQuestions(count);
  state.currentIndex = 0;
  state.input = "";
  state.hintsUsed = 0;
  state.correctCount = 0;
  state.hintVisible = state.settings.readingMode === "always";
  state.timeLeft = state.settings.timeLimit;
  state.startedAt = Date.now();
  state.stats = { correctKeys: 0, mistypes: 0 };

  clearInterval(state.timerId);
  state.timerId = setInterval(tick, 1000);

  if (state.settings.soundEnabled) getAudioCtx();

  renderPlay();
  showScreen(SCREENS.PLAY);
}

function tick() {
  state.timeLeft--;
  updateTimerDisplay();
  if (state.timeLeft <= 0) endGame(false);
}

function updateTimerDisplay() {
  const el = $("#timer");
  el.textContent = state.timeLeft;
  el.classList.toggle("warning", state.timeLeft <= 10);
}

function currentQuestion() {
  return state.questions[state.currentIndex];
}

function renderPlay() {
  const q = currentQuestion();
  const showReading = isReadingVisible();
  $("#hint-text").textContent = showReading ? q.reading[0] : "";
  $("#hint-text").classList.toggle("visible", showReading);
  const display = $("#kanji-display");
  const len = [...q.kanji].length;
  display.textContent = q.kanji;
  display.classList.remove("len-2", "len-3", "len-4");
  if (len >= 4) display.classList.add("len-4");
  else if (len === 3) display.classList.add("len-3");
  else if (len === 2) display.classList.add("len-2");
  $("#progress").textContent = `${state.currentIndex + 1} / ${state.questions.length}`;
  $("#typed-input").textContent = state.input;
  updateTimerDisplay();
  updatePlayFooter();
  renderFish();
}

function renderFish() {
  const container = $("#fish-container");
  container.innerHTML = "";
  if (!state.settings.showFish) return;

  const count = Math.min(state.correctCount + 1, 20);
  for (let i = 0; i < count; i++) {
    const fish = document.createElement("div");
    fish.className = "fish";
    fish.textContent = "🐟";
    fish.style.top = `${10 + (i * 17) % 80}%`;
    fish.style.animationDuration = `${4 + (i % 5)}s`;
    fish.style.animationDelay = `${-i * 0.7}s`;
    container.appendChild(fish);
  }
}

function nextQuestion() {
  state.correctCount++;
  state.currentIndex++;
  state.input = "";
  state.hintVisible = state.settings.readingMode === "always";

  if (state.currentIndex >= state.questions.length) {
    endGame(true);
    return;
  }
  renderPlay();
}

function calcTypingStats() {
  const elapsedSec = Math.max(1, Math.round((Date.now() - state.startedAt) / 1000));
  const { correctKeys, mistypes } = state.stats;
  const avgKps = (correctKeys / elapsedSec).toFixed(1);
  return { elapsedSec, correctKeys, mistypes, avgKps };
}

function endGame(cleared) {
  clearInterval(state.timerId);
  state.timerId = null;

  const { elapsedSec, correctKeys, mistypes, avgKps } = calcTypingStats();
  $("#result-title").textContent = cleared ? "クリア！" : "タイムアップ";
  $("#result-title").className = cleared ? "result-clear" : "result-over";
  $("#result-detail").innerHTML = [
    `正解: <strong>${state.correctCount}</strong> / ${state.questions.length}問`,
    state.settings.readingMode === "hidden"
      ? `ヒント使用: ${state.hintsUsed}回`
      : `モード: 読み仮名常時表示`,
    `プレイ時間: ${elapsedSec}秒`,
    `<span class="result-stats">正しく打ったキー: <strong>${correctKeys}</strong></span>`,
    `<span class="result-stats">ミスタイプ: <strong>${mistypes}</strong></span>`,
    `<span class="result-stats">平均キータイプ: <strong>${avgKps}</strong> 回/秒</span>`,
  ].join("<br>");
  showScreen(SCREENS.RESULT);
}

function handleKeydown(e) {
  if (state.screen === SCREENS.TITLE) {
    if (e.code === "Space") { e.preventDefault(); startGame(); }
    return;
  }
  if (state.screen === SCREENS.RESULT) {
    if (e.code === "Space") { e.preventDefault(); startGame(); }
    if (isEscape(e)) { e.preventDefault(); e.stopPropagation(); goTitle(); }
    return;
  }
  if (state.screen !== SCREENS.PLAY) return;

  if (isEscape(e)) {
    e.preventDefault();
    e.stopPropagation();
    clearInterval(state.timerId);
    goTitle();
    return;
  }

  if (e.code === "Enter") {
    e.preventDefault();
    if (state.settings.readingMode !== "hidden") return;
    if (!state.hintVisible) {
      state.hintVisible = true;
      state.hintsUsed++;
      state.timeLeft = Math.max(0, state.timeLeft - 5);
      updateTimerDisplay();
      $("#hint-text").textContent = currentQuestion().reading[0];
      $("#hint-text").classList.add("visible");
      if (state.timeLeft <= 0) endGame(false);
    }
    return;
  }

  if (e.code === "Backspace") {
    e.preventDefault();
    state.input = state.input.slice(0, -1);
    $("#typed-input").textContent = state.input;
    return;
  }

  if (e.key.length === 1 && /[a-zA-Z]/.test(e.key)) {
    e.preventDefault();
    const next = state.input + e.key.toLowerCase();
    const q = currentQuestion();
    const match = matchesReading(next, q.reading);

    if (!match.prefix && next.length > 0) {
      state.stats.mistypes++;
      playMistypeSound();
      $("#typed-input").classList.add("mistype");
      setTimeout(() => $("#typed-input").classList.remove("mistype"), 200);
      return;
    }

    state.stats.correctKeys++;
    playTypeSound();
    state.input = next;
    $("#typed-input").textContent = state.input;

    if (isCompleteMatch(state.input, q.reading)) {
      $("#kanji-display").classList.add("correct-flash");
      setTimeout(() => {
        $("#kanji-display").classList.remove("correct-flash");
        nextQuestion();
      }, 150);
    }
  }
}

function goTitle() {
  clearInterval(state.timerId);
  state.timerId = null;
  showScreen(SCREENS.TITLE);
  updateSettingsUI();
}

function init() {
  state.settings.timeLimit = calcDefaultTime(state.settings.questionCount);

  $("#btn-start").addEventListener("click", startGame);
  $("#btn-quit").addEventListener("click", () => {
    clearInterval(state.timerId);
    goTitle();
  });
  $("#btn-back-title").addEventListener("click", goTitle);

  // capture: true で IME や子要素より先に Esc を拾う
  window.addEventListener("keydown", handleKeydown, true);
  $("#game-area").addEventListener("click", focusGame);
  $("#app").addEventListener("click", () => {
    if (state.screen === SCREENS.PLAY) focusGame();
  });

  $("#setting-pool").addEventListener("click", () => {
    cycleSetting("poolMode", ["all", "single", "multi"]);
  });
  $("#setting-questions").addEventListener("click", () => {
    cycleSetting("questionCount", [10, 20, 40, 60, 80, 0]);
  });
  $("#setting-time").addEventListener("click", () => {
    cycleSetting("timeLimit", [30, 45, 60, 90, 120, 180]);
  });
  $("#setting-fish").addEventListener("click", () => {
    cycleSetting("showFish", [true, false]);
  });
  $("#setting-sound").addEventListener("click", () => {
    cycleSetting("soundEnabled", [true, false]);
  });
  $("#setting-reading").addEventListener("click", () => {
    cycleSetting("readingMode", ["hidden", "always"]);
  });

  updateSettingsUI();
  showScreen(SCREENS.TITLE);
}

document.addEventListener("DOMContentLoaded", init);
