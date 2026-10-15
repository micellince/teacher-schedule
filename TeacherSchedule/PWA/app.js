const STORAGE_KEY = "teacher-schedule-pwa.v1";
const WEEKDAYS = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"];
const WEEKDAY_LABELS = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"];
const DEFAULT_PERIODS = [
  { number: 1, startMinute: 480, endMinute: 520 },
  { number: 2, startMinute: 555, endMinute: 595 },
  { number: 3, startMinute: 610, endMinute: 655 },
  { number: 4, startMinute: 670, endMinute: 720 },
  { number: 5, startMinute: 840, endMinute: 880 },
  { number: 6, startMinute: 895, endMinute: 935 },
  { number: 7, startMinute: 950, endMinute: 990 },
  { number: 8, startMinute: 1005, endMinute: 1045 },
  { number: 9, startMinute: 1060, endMinute: 1100 },
];
const DEFAULT_COURSE_ROWS = [
  [2, 1, 460, 475, "6班", "早读"], [3, 1, 460, 475, "2班", "早读"],
  [4, 1, 460, 475, "6班", "早读"], [5, 1, 460, 475, "2班", "早读"], [6, 1, 460, 475, "6班", "早读"],
  [2, 1, 480, 520, "2班", ""], [4, 1, 480, 520, "6班", ""], [5, 1, 480, 520, "2班", ""], [6, 1, 480, 520, "6班", ""],
  [3, 2, 555, 595, "6班", ""],
  [2, 5, 820, 835, "2班", "午读"], [3, 5, 820, 835, "6班", "午读"],
  [4, 5, 820, 835, "2班", "午读"], [5, 5, 820, 835, "6班", "午读"], [6, 5, 820, 835, "2班", "午读"],
  [4, 5, 840, 880, "2班", ""],
  [2, 7, 950, 990, "6班", ""], [3, 7, 950, 990, "2班", ""], [5, 7, 950, 990, "6班", ""], [6, 7, 950, 990, "2班", ""],
  [2, 8, 1005, 1045, "6班", ""], [3, 8, 1005, 1045, "2班", ""], [5, 8, 1005, 1045, "6班", ""], [6, 8, 1005, 1045, "2班", ""],
];
const DEFAULT_DATA = () => ({
  courses: DEFAULT_COURSE_ROWS.map(([weekday, period, startMinute, endMinute, classroom, label], index) => ({
    id: `default-${index + 1}`, weekday, period, startMinute, endMinute, classroom,
    subject: "语文", label, note: "",
  })),
  periods: structuredClone(DEFAULT_PERIODS),
  settings: {
    classes: ["2班", "6班"], subjects: ["语文"], widgetBackground: { red: 0.12, green: 0.13, blue: 0.17, opacity: 1 },
    widgetTextColor: { red: 1, green: 1, blue: 1, opacity: 1 },
  },
  overrides: [], isConfigured: true, usesAlternatingWeeks: false,
});

const app = document.querySelector("#app");
const view = document.querySelector("#view");
const dialog = document.querySelector("#course-dialog");
const form = document.querySelector("#course-form");
const toastElement = document.querySelector("#toast");
let data = loadData();
let tab = "today";
let selectedWeekday = new Date().getDay() + 1;
let weekOffset = 0;
let toastTimer;

function loadData() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY));
    if (saved && Array.isArray(saved.courses)) return normalizeData(saved);
  } catch (error) { console.warn("Unable to read saved schedule", error); }
  return DEFAULT_DATA();
}

function normalizeData(value) {
  const defaults = DEFAULT_DATA();
  return {
    ...defaults, ...value,
    courses: (value.courses || []).map(course => ({
      id: course.id || crypto.randomUUID(), weekday: Number(course.weekday) || 2,
      period: Number(course.period) || 1, startMinute: Number(course.startMinute) || 0,
      endMinute: Number(course.endMinute) || 0, classroom: course.classroom || "",
      subject: course.subject || "", label: course.label || "", note: course.note || "",
    })),
    periods: Array.isArray(value.periods) && value.periods.length ? value.periods : defaults.periods,
    settings: { ...defaults.settings, ...(value.settings || {}) },
    overrides: Array.isArray(value.overrides) ? value.overrides : [],
  };
}

function persist(message) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
  syncNativeSchedule();
  if (message) showToast(message);
}

function syncNativeSchedule() {
  if (window.TeacherScheduleAndroid) {
    TeacherScheduleAndroid.syncSchedule(JSON.stringify(data));
  }
}

function notificationsEnabled() {
  return !!window.TeacherScheduleAndroid?.notificationsEnabled();
}

window.onNotificationPermissionChanged = enabled => {
  const button = document.querySelector("[data-action='toggle-notifications']");
  if (button) {
    button.textContent = enabled ? "关闭上课提醒" : "开启上课提醒";
    button.classList.toggle("enabled", enabled);
  }
  showToast(enabled ? "上课提醒已开启" : "未开启上课提醒");
};

function pad(number) { return String(number).padStart(2, "0"); }
function minuteOf(date) { return date.getHours() * 60 + date.getMinutes(); }
function clockTime(date = new Date()) { return `${pad(date.getHours())}:${pad(date.getMinutes())}`; }
function formatMinute(value) { return `${pad(Math.floor(value / 60))}:${pad(value % 60)}`; }
function dateKey(date) { return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`; }
function weekdayOf(date) { return date.getDay() + 1; }
function escapeHTML(value = "") {
  return String(value).replace(/[&<>"']/g, char => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[char]);
}
function sorted(courses) { return [...courses].sort((a, b) => a.startMinute - b.startMinute || a.period - b.period); }
function periodTitle(course) { return course.label || `第 ${course.period} 节`; }

function coursesForDate(date) {
  const key = dateKey(date);
  const override = data.overrides.find(item => item.dateKey === key);
  if (override) return sorted(override.courses);
  return sorted(data.courses.filter(course => course.weekday === weekdayOf(date)));
}

function nextCourseFollowingDays(date) {
  for (let offset = 1; offset <= 7; offset++) {
    const nextDate = new Date(date.getFullYear(), date.getMonth(), date.getDate() + offset);
    const first = coursesForDate(nextDate)[0];
    if (first) return { course: first, date: nextDate };
  }
  return null;
}

function getDayState(date) {
  const courses = coursesForDate(date);
  const minute = minuteOf(date);
  const current = courses.find(course => minute >= course.startMinute && minute < course.endMinute);
  const next = courses.find(course => course.startMinute > minute);
  if (current) return { kind: "current", course: current, courses };
  if (next) return { kind: "break", course: next, courses };
  if (courses.length) return { kind: "finished", last: courses.at(-1), following: nextCourseFollowingDays(date), courses };
  return { kind: "empty", following: nextCourseFollowingDays(date), courses };
}

function remainingTime(endMinute, date) {
  const end = new Date(date.getFullYear(), date.getMonth(), date.getDate(), Math.floor(endMinute / 60), endMinute % 60, 0);
  return Math.max(0, Math.ceil((end.getTime() - date.getTime()) / 1000));
}

function countdown(seconds) {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor(seconds % 3600 / 60);
  const s = seconds % 60;
  return h ? `${pad(h)}:${pad(m)}:${pad(s)}` : `${pad(m)}:${pad(s)}`;
}

function rgbaToHex(color, fallback) {
  if (!color || typeof color.red !== "number") return fallback;
  return `#${[color.red, color.green, color.blue].map(value => Math.round(Math.min(1, Math.max(0, value)) * 255).toString(16).padStart(2, "0")).join("")}`;
}

function applyTheme() {
  document.documentElement.style.setProperty("--card-bg", rgbaToHex(data.settings.widgetBackground, "#252d3a"));
  document.documentElement.style.setProperty("--card-text", rgbaToHex(data.settings.widgetTextColor, "#ffffff"));
}

function render() {
  applyTheme();
  document.querySelectorAll(".tab").forEach(button => button.classList.toggle("active", button.dataset.tab === tab));
  if (tab === "today") renderToday();
  if (tab === "schedule") renderSchedule();
  if (tab === "settings") renderSettings();
}

function renderToday() {
  const now = new Date();
  const state = getDayState(now);
  const dateLabel = now.toLocaleDateString("zh-CN", { weekday: "long", month: "long", day: "numeric" });
  view.innerHTML = `
    <div class="clock-block"><div id="clock" class="clock">${clockTime(now)}</div><div class="date-line">${dateLabel}</div></div>
    ${heroMarkup(state, now)}
    ${state.kind === "empty" ? emptyMarkup() : ""}
    <div class="section-heading"><h2>今日课程</h2><span>${state.courses.length} 节</span></div>
    ${state.courses.length ? `<div class="course-list">${state.courses.map(course => courseRow(course, now)).join("")}</div>` : ""}
    ${state.courses.length ? `<button class="button secondary full" data-action="add-course">＋ 添加今天的课程</button>` : ""}`;
}

function heroMarkup(state, now) {
  if (state.kind === "current") {
    const course = state.course;
    const span = Math.max(1, course.endMinute - course.startMinute);
    const progress = Math.min(100, Math.max(0, (minuteOf(now) - course.startMinute) / span * 100));
    return `<section class="hero current" id="status-card">
      <div class="hero-label"><i class="status-dot"></i>${escapeHTML(periodTitle(course))} · 正在上课</div>
      <div class="lesson-class">${escapeHTML(course.classroom)}</div><div class="lesson-subject">${escapeHTML(course.subject)}</div>
      <div class="lesson-period">${formatMinute(course.startMinute)} — ${formatMinute(course.endMinute)}</div>
      <div class="progress-row"><span>${formatMinute(course.startMinute)}</span><div class="progress-track"><div class="progress-fill" style="width:${progress}%"></div></div><span>${formatMinute(course.endMinute)}</span></div>
      <div class="countdown-row"><span>下课倒计时</span><strong class="countdown" data-countdown-end="${course.endMinute}">${countdown(remainingTime(course.endMinute, now))}</strong></div>
    </section>${nextCard(state.courses.find(item => item.startMinute > course.endMinute))}`;
  }
  if (state.kind === "break") {
    const course = state.course;
    const isBeforeFirst = state.courses[0] && minuteOf(now) < state.courses[0].startMinute;
    const seconds = Math.max(0, Math.ceil((new Date(now.getFullYear(), now.getMonth(), now.getDate(), Math.floor(course.startMinute / 60), course.startMinute % 60).getTime() - now.getTime()) / 1000));
    return `<section class="hero break" id="status-card"><div class="hero-label"><i class="status-dot"></i>${isBeforeFirst ? "今天的第一节课快开始了" : "课间休息"}</div>
      <div class="break-title">下一节 · ${escapeHTML(periodTitle(course))}</div><div class="break-detail">${escapeHTML(course.classroom)} · ${escapeHTML(course.subject)}</div>
      <div class="break-meta"><span>${formatMinute(course.startMinute)} 开始</span>${course.note ? `<span>· ${escapeHTML(course.note)}</span>` : ""}</div>
      <div class="break-count">距离上课<strong data-countdown-start="${course.startMinute}">${countdown(seconds)}</strong></div></section>
      ${nextCard(state.courses.find(item => item.startMinute > course.startMinute))}`;
  }
  if (state.kind === "finished") {
    const following = state.following;
    return `<section class="hero finished" id="status-card"><div class="hero-label"><i class="status-dot"></i>今天的课程已结束</div>
      <div class="break-title">收工啦</div><div class="break-detail">今天共 ${state.courses.length} 节课</div>
      ${state.last ? `<div class="break-meta">最后一节 · ${escapeHTML(state.last.classroom)} · ${escapeHTML(state.last.subject)}</div>` : ""}</section>
      ${following ? nextCard(following.course, following.date) : ""}`;
  }
  return `<section class="hero empty" id="status-card"><div class="hero-label"><i class="status-dot"></i>轻松的一天</div>
      <div class="break-title">今天没有课程</div><div class="break-detail">整理好下周的安排，打开就能看到每节课。</div></section>
      ${state.following ? nextCard(state.following.course, state.following.date) : ""}`;
}

function nextCard(course, date) {
  if (!course) return "";
  const datePrefix = date ? `${WEEKDAYS[date.getDay()]} · ` : "";
  return `<div class="next-card"><div class="next-time">${formatMinute(course.startMinute)}</div><div class="next-info"><div class="next-caption">${datePrefix}下一节</div><div class="next-name">${escapeHTML(course.classroom)} · ${escapeHTML(course.subject)}</div></div><div class="next-period">${escapeHTML(periodTitle(course))}</div></div>`;
}

function emptyMarkup() {
  return `<div class="empty-state"><div class="empty-symbol">＋</div><strong>先把自己的课表填进来</strong><p>可以逐节添加，也能导入原生 App 导出的 JSON 文件。</p><button class="button primary" data-action="add-course">添加第一节课</button></div>`;
}

function courseRow(course, now) {
  const current = minuteOf(now) >= course.startMinute && minuteOf(now) < course.endMinute;
  const ended = minuteOf(now) >= course.endMinute;
  return `<button class="course-row ${current ? "active" : ""}" data-action="edit-course" data-id="${escapeHTML(course.id)}"><span class="course-index">${ended ? "✓" : escapeHTML(course.label ? course.label.slice(0, 1) : `0${course.period}`)}</span><span class="course-info"><strong>${escapeHTML(course.classroom)} · ${escapeHTML(course.subject)}</strong><small>${escapeHTML(periodTitle(course))}${course.note ? `　·　${escapeHTML(course.note)}` : ""}</small></span><span class="course-time">${formatMinute(course.startMinute)}</span></button>`;
}

function mondayOf(date) {
  const result = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const offset = (result.getDay() + 6) % 7;
  result.setDate(result.getDate() - offset + weekOffset * 7);
  return result;
}

function renderSchedule() {
  const monday = mondayOf(new Date());
  const weekDays = Array.from({ length: 7 }, (_, index) => new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + index));
  const selected = weekDays.find(day => weekdayOf(day) === selectedWeekday) || weekDays[0];
  const courses = coursesForDate(selected);
  view.innerHTML = `<div class="page-title">周课表</div><p class="page-subtitle">按星期整理，点开课程即可编辑</p>
    <div class="weekday-strip"><button class="weekday-chip" data-action="week-back" aria-label="上一周">‹<small>上周</small></button>
    ${weekDays.map(day => `<button class="weekday-chip ${weekdayOf(day) === selectedWeekday ? "selected" : ""}" data-action="select-day" data-weekday="${weekdayOf(day)}"><span class="day-num">${day.getDate()}</span><small>${WEEKDAYS[day.getDay()]}</small></button>`).join("")}
    <button class="weekday-chip" data-action="week-forward" aria-label="下一周">›<small>下周</small></button></div>
    <div class="schedule-date">${selected.toLocaleDateString("zh-CN", { year: "numeric", month: "long", day: "numeric", weekday: "long" })}${weekOffset === 0 && dateKey(selected) === dateKey(new Date()) ? " · 今天" : ""}</div>
    ${courses.length ? courses.map(course => `<button class="schedule-course" data-action="edit-course" data-id="${escapeHTML(course.id)}"><span class="schedule-period">${escapeHTML(periodTitle(course))}</span><span><span class="schedule-title">${escapeHTML(course.classroom)} · ${escapeHTML(course.subject)}</span><span class="schedule-meta">${course.note ? `${escapeHTML(course.note)} · ` : ""}${formatMinute(course.startMinute)} – ${formatMinute(course.endMinute)}</span></span><span class="schedule-time">›</span></button>`).join("") : `<div class="empty-state"><div class="empty-symbol">☼</div><strong>${WEEKDAYS[selected.getDay()]}还没安排课程</strong><p>按你的实际班级和学科添加，不预设任何示例选项。</p><button class="button primary" data-action="add-course">添加课程</button></div>`}
    ${courses.length ? `<button class="button secondary full" data-action="add-course">＋ 添加课程</button>` : ""}`;
}

function colorInput(label, key, fallback) {
  return `<div class="setting-line"><span>${label}</span><input aria-label="${label}" type="color" data-action="color-setting" data-key="${key}" value="${rgbaToHex(data.settings[key], fallback)}"></div>`;
}

function choicesMarkup(title, key) {
  const choices = data.settings[key] || [];
  return `<div class="setting-card"><h3>${title}</h3><p>添加后可在课程编辑时快速选择。</p><div class="chips">${choices.map((choice, index) => `<span class="chip">${escapeHTML(choice)}<button type="button" data-action="remove-choice" data-key="${key}" data-index="${index}" aria-label="删除${escapeHTML(choice)}">×</button></span>`).join("") || `<span class="muted" style="font-size:11px">还没有常用选项</span>`}</div><div class="add-choice"><input data-choice-input="${key}" placeholder="添加${title}"><button type="button" data-action="add-choice" data-key="${key}" aria-label="添加${title}">＋</button></div></div>`;
}

function renderSettings() {
  const isAndroid = !!window.TeacherScheduleAndroid;
  view.innerHTML = `<div class="page-title">设置</div><p class="page-subtitle">${isAndroid ? "数据保存在这台手机 · 离线可用" : "数据仅保存在这台设备"}</p>
    ${isAndroid ? `<section class="setting-card notification-card"><div class="setting-card-heading"><span class="setting-icon">♧</span><div><h3>上课提醒</h3><p>课程开始前 5 分钟提醒你，包括早读和午读。</p></div></div><button class="button ${notificationsEnabled() ? "secondary enabled" : "primary"} full" data-action="toggle-notifications">${notificationsEnabled() ? "关闭上课提醒" : "开启上课提醒"}</button><div class="permission-note">开启后请在系统弹窗中允许通知。</div></section>
    <section class="setting-card widget-card"><div class="setting-card-heading"><span class="setting-icon">▦</span><div><h3>桌面组件</h3><p>把“教师课表”小组件添加到手机桌面，快速查看当前和下一节课。</p></div></div><div class="widget-preview"><span>教师课表 <i>● 实时课表</i></span><strong>语文 · 2班</strong><small>下一节　09:15 — 09:55</small></div><div class="permission-note">长按桌面空白处 → 小组件 → 教师课表</div></section>` : ""}
    ${choicesMarkup("常用班级", "classes")}${choicesMarkup("常用学科", "subjects")}
    ${isAndroid ? "" : `<section class="setting-card"><h3>桌面卡片颜色</h3><p>调整课程卡片的底色和文字颜色。</p>${colorInput("背景颜色", "widgetBackground", "#252d3a")}${colorInput("文字颜色", "widgetTextColor", "#ffffff")}</section>`}
    <section class="setting-card"><h3>每节课默认时间</h3><p>新建课程时可套用这里的节次和时间；课程保存后仍可单独修改。</p>${data.periods.slice().sort((a,b) => a.number-b.number).map(period => `<div class="setting-line"><span>第 ${period.number} 节</span><span class="muted"><input aria-label="第${period.number}节开始时间" type="time" data-period="${period.number}" data-bound="startMinute" value="${formatMinute(period.startMinute)}">　–　<input aria-label="第${period.number}节结束时间" type="time" data-period="${period.number}" data-bound="endMinute" value="${formatMinute(period.endMinute)}"></span></div>`).join("")}<button class="button secondary full" data-action="add-period">＋ 添加节次</button></section>
    <section class="setting-card"><h3>备份与迁移</h3><p>导出 JSON 可备份课表；也可导入原生 iOS App 导出的文件。PWA 与原生 App 各自保存数据，导入文件后不会自动互相同步。</p><div class="setting-actions"><button data-action="export-data">导出课表 JSON</button><button data-action="import-data">导入课表 JSON</button></div></section>
    <section class="setting-card"><h3>其他</h3><p>恢复示例课表用于体验；清空操作不可撤销，请先导出备份。</p><div class="setting-actions"><button data-action="sample-data">恢复示例课表</button><button data-action="clear-data">清空本机课表</button></div></section>
    <div class="storage-note">离线可用 · 不需要账号 · 课表数据仅保存在此设备<br>添加到主屏幕后，打开“教师课表”图标即可查看</div>`;
}

function openCourse(course) {
  form.reset();
  const defaultWeekday = tab === "schedule" ? selectedWeekday : weekdayOf(new Date());
  const days = WEEKDAY_LABELS.map((label, index) => `<option value="${index + 1}">${label}</option>`).join("");
  form.elements.weekday.innerHTML = days;
  form.elements.weekday.value = String(course?.weekday || defaultWeekday);
  const defaultPeriod = data.periods.slice().sort((a,b)=>a.number-b.number)[0] || DEFAULT_PERIODS[0];
  form.elements.id.value = course?.id || "";
  form.elements.label.value = course?.label || "";
  form.elements.period.value = String(course?.period || defaultPeriod.number);
  form.elements.classroom.value = course?.classroom || "";
  form.elements.subject.value = course?.subject || "";
  form.elements.start.value = formatMinute(course?.startMinute ?? defaultPeriod.startMinute);
  form.elements.end.value = formatMinute(course?.endMinute ?? defaultPeriod.endMinute);
  form.elements.note.value = course?.note || "";
  document.querySelector("#course-dialog-title").textContent = course ? "编辑课程" : "添加课程";
  document.querySelector("#delete-course").classList.toggle("hidden", !course);
  document.querySelector("#class-options").innerHTML = (data.settings.classes || []).map(item => `<option value="${escapeHTML(item)}"></option>`).join("");
  document.querySelector("#subject-options").innerHTML = (data.settings.subjects || []).map(item => `<option value="${escapeHTML(item)}"></option>`).join("");
  dialog.showModal();
}

function saveCourse() {
  const fields = new FormData(form);
  const startMinute = parseTime(fields.get("start"));
  const endMinute = parseTime(fields.get("end"));
  const classroom = String(fields.get("classroom") || "").trim();
  const subject = String(fields.get("subject") || "").trim();
  if (!classroom || !subject) return showToast("请填写班级和学科");
  if (endMinute <= startMinute) return showToast("结束时间要晚于开始时间");
  const course = {
    id: fields.get("id") || crypto.randomUUID(), weekday: Number(fields.get("weekday")),
    period: Number(fields.get("period")), startMinute, endMinute, classroom, subject,
    label: String(fields.get("label") || "").trim(), note: String(fields.get("note") || "").trim(),
  };
  const index = data.courses.findIndex(item => item.id === course.id);
  if (index >= 0) data.courses[index] = course; else data.courses.push(course);
  for (const [key, value] of [["classes", classroom], ["subjects", subject]]) {
    if (!data.settings[key].includes(value)) data.settings[key].push(value);
  }
  if (tab === "schedule") selectedWeekday = course.weekday;
  dialog.close();
  persist(index >= 0 ? "课程已保存" : "课程已添加");
  render();
}

function parseTime(value) {
  const [hours, minutes] = String(value || "0:0").split(":").map(Number);
  return hours * 60 + minutes;
}

function removeCourse(id) {
  data.courses = data.courses.filter(course => course.id !== id);
  data.overrides = data.overrides.map(item => ({ ...item, courses: item.courses.filter(course => course.id !== id) }));
  persist("课程已删除");
  render();
}

function showToast(message) {
  toastElement.textContent = message;
  toastElement.classList.add("visible");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toastElement.classList.remove("visible"), 1900);
}

function hexToRGBA(hex) {
  const value = hex.replace("#", "");
  return { red: parseInt(value.slice(0,2),16)/255, green: parseInt(value.slice(2,4),16)/255, blue: parseInt(value.slice(4,6),16)/255, opacity: 1 };
}

function downloadData() {
  if (window.TeacherScheduleAndroid) {
    TeacherScheduleAndroid.saveBackup(JSON.stringify(data, null, 2), `教师课表-${dateKey(new Date())}.json`);
    return;
  }
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = `教师课表-${dateKey(new Date())}.json`;
  document.body.append(anchor);
  anchor.click();
  anchor.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
  showToast("课表 JSON 已导出");
}

function validateImport(candidate) {
  if (!candidate || !Array.isArray(candidate.courses) || !Array.isArray(candidate.periods)) throw new Error("文件格式不正确");
  const normalized = normalizeData(candidate);
  for (const course of normalized.courses) {
    if (course.weekday < 1 || course.weekday > 7 || course.startMinute < 0 || course.endMinute > 1440 || course.endMinute <= course.startMinute) throw new Error("课程时间或星期数据有误");
  }
  return normalized;
}

function importFile(file) {
  if (!file) return;
  const reader = new FileReader();
  reader.onload = () => {
    try {
      const incoming = validateImport(JSON.parse(String(reader.result)));
      if (!confirm(`导入将替换当前课表（${data.courses.length} 节）。建议先导出备份。继续吗？`)) return;
      data = incoming;
      persist("课表已导入");
      render();
    } catch (error) { showToast(error.message || "无法读取这个课表文件"); }
  };
  reader.onerror = () => showToast("读取文件失败");
  reader.readAsText(file);
}

function loadSample() {
  if (!confirm("恢复示例课表会替换当前数据。建议先导出备份。继续吗？")) return;
  const sample = DEFAULT_DATA();
  sample.isConfigured = true;
  sample.courses = [
    [2,1,480,520,"五年级2班","数学"],[2,2,540,580,"五年级2班","语文"],
    [2,3,600,640,"三年级1班","英语"],[2,4,660,700,"四年级3班","英语"],
    [2,5,840,880,"五年级2班","数学"],[2,6,900,940,"六年级1班","班会"],
  ].map(([weekday,period,startMinute,endMinute,classroom,subject]) => ({ id: crypto.randomUUID(), weekday, period, startMinute, endMinute, classroom, subject, note: "" }));
  sample.settings.classes = [...new Set(sample.courses.map(course => course.classroom))];
  sample.settings.subjects = [...new Set(sample.courses.map(course => course.subject))];
  data = sample;
  persist("示例课表已恢复");
  render();
}

function handleAction(action, target) {
  if (action === "add-course") return openCourse();
  if (action === "edit-course") return openCourse(data.courses.find(course => course.id === target.dataset.id));
  if (action === "select-day") { selectedWeekday = Number(target.dataset.weekday); return render(); }
  if (action === "week-back") { weekOffset--; return render(); }
  if (action === "week-forward") { weekOffset++; return render(); }
  if (action === "add-choice") {
    const key = target.dataset.key;
    const input = document.querySelector(`[data-choice-input="${key}"]`);
    const value = input.value.trim();
    if (value && !data.settings[key].includes(value)) { data.settings[key].push(value); persist(); render(); }
    input.value = "";
    return;
  }
  if (action === "remove-choice") {
    const key = target.dataset.key;
    data.settings[key].splice(Number(target.dataset.index), 1);
    persist(); return render();
  }
  if (action === "add-period") {
    const number = Math.max(0, ...data.periods.map(period => Number(period.number))) + 1;
    data.periods.push({ number, startMinute: 480, endMinute: 520 });
    persist(); return render();
  }
  if (action === "export-data") return downloadData();
  if (action === "toggle-notifications" && window.TeacherScheduleAndroid) {
    if (notificationsEnabled()) TeacherScheduleAndroid.setNotificationsEnabled(false);
    else TeacherScheduleAndroid.requestNotificationPermission();
    return;
  }
  if (action === "import-data") return document.querySelector("#import-file").click();
  if (action === "sample-data") return loadSample();
  if (action === "clear-data") {
    if (!confirm("确定删除这台设备上的全部课表数据？此操作不可撤销。")) return;
    data = DEFAULT_DATA(); persist("课表已清空"); return render();
  }
}

app.addEventListener("click", event => {
  const tabButton = event.target.closest("[data-tab]");
  if (tabButton) { tab = tabButton.dataset.tab; render(); return; }
  const actionButton = event.target.closest("[data-action]");
  if (actionButton) handleAction(actionButton.dataset.action, actionButton);
});

form.addEventListener("submit", event => { event.preventDefault(); saveCourse(); });
document.querySelector("#delete-course").addEventListener("click", () => {
  const id = form.elements.id.value;
  if (id && confirm("删除这节课程？")) { dialog.close(); removeCourse(id); }
});

document.querySelector("#import-file").addEventListener("change", event => {
  importFile(event.target.files?.[0]);
  event.target.value = "";
});

view.addEventListener("input", event => {
  const target = event.target;
  if (target.matches("[data-action='color-setting']")) {
    data.settings[target.dataset.key] = hexToRGBA(target.value);
    persist(); applyTheme();
  }
});

view.addEventListener("change", event => {
  const target = event.target;
  if (target.matches("[data-period]")) {
    const period = data.periods.find(item => item.number === Number(target.dataset.period));
    if (!period) return;
    period[target.dataset.bound] = parseTime(target.value);
    if (period.endMinute <= period.startMinute) {
      period.endMinute = Math.min(1440, period.startMinute + 40);
      showToast("结束时间已调整为晚于开始时间");
      render();
    }
    persist("课次时间已更新");
  }
});

function tick() {
  if (tab === "today") {
    const clock = document.querySelector("#clock");
    if (!clock) { renderToday(); return; }
    const now = new Date();
    clock.textContent = clockTime(now);
    const state = getDayState(now);
    const kind = document.querySelector("#status-card")?.classList.contains("current") ? "current"
      : document.querySelector("#status-card")?.classList.contains("break") ? "break"
      : document.querySelector("#status-card")?.classList.contains("finished") ? "finished" : "empty";
    if (kind !== state.kind) { renderToday(); return; }
    const timer = document.querySelector("[data-countdown-end]");
    if (timer) timer.textContent = countdown(remainingTime(Number(timer.dataset.countdownEnd), now));
    const startTimer = document.querySelector("[data-countdown-start]");
    if (startTimer) {
      const start = Number(startTimer.dataset.countdownStart);
      const startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), Math.floor(start/60), start%60);
      startTimer.textContent = countdown(Math.max(0, Math.ceil((startDate.getTime()-now.getTime())/1000)));
    }
    const fill = document.querySelector(".progress-fill");
    if (fill && state.kind === "current") {
      const course = state.course;
      const percent = Math.min(100, Math.max(0, (minuteOf(now) - course.startMinute + now.getSeconds()/60) / Math.max(1, course.endMinute - course.startMinute) * 100));
      fill.style.width = `${percent}%`;
    }
  }
}

render();
syncNativeSchedule();
setInterval(tick, 1000);

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => navigator.serviceWorker.register("./service-worker.js").catch(error => console.warn("Offline support unavailable", error)));
}
