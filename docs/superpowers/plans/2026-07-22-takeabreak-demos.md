# Take a Break HTML Demos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 交付与设计规格一致的可交互 HTML demo：番茄状态机可单测、菜单栏 / 偏好设置 / 全屏休息三屏可双击打开演示，并支持加速时长便于体验闭环。

**Architecture:** 先实现与 UI 无关的纯 JS 番茄引擎（状态迁移、剩余时间、偏好生效规则），用 Node 内置 `node:test` 锁定行为；再做三个自包含 HTML demo（引擎以非 module 脚本挂到 `window.TakeABreak`，保证 `file://` 可打开）。另做 `demos/index.html` 作为入口与说明。旧 demo 文件归档或删除，避免与规格冲突。

**Tech Stack:** 原生 HTML / CSS / JS；Node.js `node:test` + `node:assert`；无构建工具、无 React、无外部 UI 库。壁纸 demo 使用 CSS 渐变 + 可选 Unsplash URL（外网）及本地 file input。

**规格依据:** `docs/superpowers/specs/2026-07-22-takeabreak-design.md`

---

## File Structure

| 路径 | 职责 |
|------|------|
| `src/timer-engine.js` | 番茄状态机：Idle/Working/Paused/Breaking、tick、pause/resume/stop/skip、偏好与轮次锁定 |
| `tests/timer-engine.test.js` | 引擎单元测试 |
| `demos/index.html` | Demo 入口：三屏链接 + 使用说明 + 加速提示 |
| `demos/menubar.html` | 菜单栏图标 + 下拉面板（Idle/Working/Paused/Breaking 面板态） |
| `demos/preferences.html` | 偏好设置小窗（时长 / 壁纸 / 文案 / 长按跳过） |
| `demos/break-fullscreen.html` | 全屏纯文字叠层 + 2s 长按跳过 |
| `demos/flow.html` | （可选集成）单页串联：菜单栏 → 加速工作结束 → 全屏休息 → 回到工作 |
| `package.json` | `"test": "node --test tests/"` 脚本 |
| `demos/demo_menubar.html` / `demos/demo_fullscreen_break.html` | **删除**（与规格不符的早期稿） |

---

### Task 1: 番茄引擎 + 测试脚手架

**Files:**
- Create: `package.json`
- Create: `src/timer-engine.js`
- Create: `tests/timer-engine.test.js`

- [ ] **Step 1: 写 package.json**

```json
{
  "name": "takeabreak",
  "private": true,
  "version": "0.1.0",
  "description": "macOS rest reminder — design demos",
  "scripts": {
    "test": "node --test tests/"
  }
}
```

- [ ] **Step 2: 写失败测试（引擎尚未实现）**

创建 `tests/timer-engine.test.js`:

```js
const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  createEngine,
  DEFAULT_PREFS,
  formatMmSs,
} = require('../src/timer-engine.js');

describe('formatMmSs', () => {
  it('formats minutes and seconds with padding', () => {
    assert.equal(formatMmSs(0), '00:00');
    assert.equal(formatMmSs(65_000), '01:05');
    assert.equal(formatMmSs(25 * 60 * 1000), '25:00');
  });
});

describe('createEngine', () => {
  it('starts in Idle with default prefs', () => {
    const e = createEngine({ now: () => 0 });
    const s = e.getState();
    assert.equal(s.phase, 'Idle');
    assert.equal(s.workMinutes, DEFAULT_PREFS.workMinutes);
    assert.equal(s.breakMinutes, DEFAULT_PREFS.breakMinutes);
    assert.equal(s.roundIndex, 0);
  });

  it('Idle → Working on start, locks durations', () => {
    const e = createEngine({ now: () => 1_000 });
    e.setPrefs({ workMinutes: 25, breakMinutes: 5 });
    e.start();
    const s = e.getState();
    assert.equal(s.phase, 'Working');
    assert.equal(s.roundIndex, 1);
    assert.equal(s.lockedWorkMinutes, 25);
    assert.equal(s.lockedBreakMinutes, 5);
    assert.equal(s.remainingMs, 25 * 60 * 1000);
  });

  it('Working → Paused → Working', () => {
    let t = 0;
    const e = createEngine({ now: () => t });
    e.setPrefs({ workMinutes: 1, breakMinutes: 1 });
    e.start();
    t = 10_000;
    e.tick();
    e.pause();
    assert.equal(e.getState().phase, 'Paused');
    assert.equal(e.getState().remainingMs, 50_000);
    t = 999_999; // time jumps while paused should not drain
    e.tick();
    assert.equal(e.getState().remainingMs, 50_000);
    e.resume();
    assert.equal(e.getState().phase, 'Working');
    t += 10_000;
    e.tick();
    assert.equal(e.getState().remainingMs, 40_000);
  });

  it('work complete → Breaking, then break complete → Working next round', () => {
    let t = 0;
    const e = createEngine({ now: () => t });
    e.setPrefs({ workMinutes: 1, breakMinutes: 1 });
    e.start();
    t = 60_000;
    e.tick();
    assert.equal(e.getState().phase, 'Breaking');
    assert.equal(e.getState().remainingMs, 60_000);
    assert.equal(e.getState().roundIndex, 1);
    t = 120_000;
    e.tick();
    assert.equal(e.getState().phase, 'Working');
    assert.equal(e.getState().roundIndex, 2);
    assert.equal(e.getState().remainingMs, 60_000);
  });

  it('skipBreak only from Breaking when allowed', () => {
    let t = 0;
    const e = createEngine({ now: () => t });
    e.setPrefs({ workMinutes: 1, breakMinutes: 5, allowLongPressSkip: true });
    e.start();
    t = 60_000;
    e.tick();
    assert.equal(e.getState().phase, 'Breaking');
    e.skipBreak();
    assert.equal(e.getState().phase, 'Working');
    assert.equal(e.getState().roundIndex, 2);
  });

  it('skipBreak is no-op when allowLongPressSkip is false', () => {
    let t = 0;
    const e = createEngine({ now: () => t });
    e.setPrefs({ workMinutes: 1, breakMinutes: 5, allowLongPressSkip: false });
    e.start();
    t = 60_000;
    e.tick();
    e.skipBreak();
    assert.equal(e.getState().phase, 'Breaking');
  });

  it('stop returns to Idle from any phase', () => {
    let t = 0;
    const e = createEngine({ now: () => t });
    e.setPrefs({ workMinutes: 1, breakMinutes: 1 });
    e.start();
    e.stop();
    assert.equal(e.getState().phase, 'Idle');
    e.start();
    t = 60_000;
    e.tick();
    e.stop();
    assert.equal(e.getState().phase, 'Idle');
  });

  it('changing prefs only affects next round lock', () => {
    let t = 0;
    const e = createEngine({ now: () => t });
    e.setPrefs({ workMinutes: 1, breakMinutes: 1 });
    e.start();
    e.setPrefs({ workMinutes: 10, breakMinutes: 3 });
    assert.equal(e.getState().lockedWorkMinutes, 1);
    assert.equal(e.getState().workMinutes, 10);
    t = 60_000;
    e.tick(); // → Breaking with locked break 1
    assert.equal(e.getState().lockedBreakMinutes, 1);
    t = 120_000;
    e.tick(); // → Working round 2 with new locks
    assert.equal(e.getState().lockedWorkMinutes, 10);
    assert.equal(e.getState().remainingMs, 10 * 60 * 1000);
  });

  it('pause is no-op in Breaking', () => {
    let t = 0;
    const e = createEngine({ now: () => t });
    e.setPrefs({ workMinutes: 1, breakMinutes: 1 });
    e.start();
    t = 60_000;
    e.tick();
    e.pause();
    assert.equal(e.getState().phase, 'Breaking');
  });
});
```

- [ ] **Step 3: 运行测试，确认失败**

Run: `node --test tests/timer-engine.test.js`

Expected: FAIL — `Cannot find module '../src/timer-engine.js'` 或类似

- [ ] **Step 4: 实现 `src/timer-engine.js`**

```js
'use strict';

const DEFAULT_PREFS = {
  workMinutes: 25,
  breakMinutes: 5,
  wallpaperId: 'default-1',
  customMessage: '站起来走走，看看远处',
  allowLongPressSkip: true,
};

function clamp(n, min, max) {
  return Math.min(max, Math.max(min, n));
}

function formatMmSs(ms) {
  const totalSec = Math.max(0, Math.ceil(ms / 1000));
  const m = Math.floor(totalSec / 60);
  const s = totalSec % 60;
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

/**
 * @param {{ now?: () => number }} [opts]
 */
function createEngine(opts = {}) {
  const nowFn = opts.now || (() => Date.now());

  let prefs = { ...DEFAULT_PREFS };
  let phase = 'Idle'; // Idle | Working | Paused | Breaking
  let roundIndex = 0;
  let lockedWorkMinutes = prefs.workMinutes;
  let lockedBreakMinutes = prefs.breakMinutes;
  let remainingMs = 0;
  let lastTickAt = 0;

  function snapshot() {
    return {
      phase,
      roundIndex,
      remainingMs,
      lockedWorkMinutes,
      lockedBreakMinutes,
      workMinutes: prefs.workMinutes,
      breakMinutes: prefs.breakMinutes,
      wallpaperId: prefs.wallpaperId,
      customMessage: prefs.customMessage,
      allowLongPressSkip: prefs.allowLongPressSkip,
      progress: progressRatio(),
    };
  }

  function progressRatio() {
    if (phase === 'Working' || phase === 'Paused') {
      const total = lockedWorkMinutes * 60 * 1000;
      return total <= 0 ? 0 : 1 - remainingMs / total;
    }
    if (phase === 'Breaking') {
      const total = lockedBreakMinutes * 60 * 1000;
      return total <= 0 ? 0 : 1 - remainingMs / total;
    }
    return 0;
  }

  function enterWorking(nextRound) {
    phase = 'Working';
    roundIndex = nextRound;
    lockedWorkMinutes = prefs.workMinutes;
    lockedBreakMinutes = prefs.breakMinutes;
    remainingMs = lockedWorkMinutes * 60 * 1000;
    lastTickAt = nowFn();
  }

  function enterBreaking() {
    phase = 'Breaking';
    remainingMs = lockedBreakMinutes * 60 * 1000;
    lastTickAt = nowFn();
  }

  function setPrefs(partial) {
    const next = { ...prefs, ...partial };
    if (partial.workMinutes != null) {
      next.workMinutes = clamp(Number(partial.workMinutes), 5, 90);
    }
    if (partial.breakMinutes != null) {
      next.breakMinutes = clamp(Number(partial.breakMinutes), 1, 30);
    }
    if (partial.customMessage != null) {
      next.customMessage = String(partial.customMessage);
    }
    if (partial.allowLongPressSkip != null) {
      next.allowLongPressSkip = Boolean(partial.allowLongPressSkip);
    }
    if (partial.wallpaperId != null) {
      next.wallpaperId = String(partial.wallpaperId);
    }
    prefs = next;
  }

  function start() {
    if (phase !== 'Idle') return;
    enterWorking(1);
  }

  function pause() {
    if (phase !== 'Working') return;
    tick();
    phase = 'Paused';
  }

  function resume() {
    if (phase !== 'Paused') return;
    phase = 'Working';
    lastTickAt = nowFn();
  }

  function stop() {
    phase = 'Idle';
    remainingMs = 0;
    roundIndex = 0;
    lastTickAt = 0;
  }

  function skipBreak() {
    if (phase !== 'Breaking') return;
    if (!prefs.allowLongPressSkip) return;
    enterWorking(roundIndex + 1);
  }

  function tick() {
    if (phase !== 'Working' && phase !== 'Breaking') return;
    const t = nowFn();
    if (!lastTickAt) {
      lastTickAt = t;
      return;
    }
    const delta = Math.max(0, t - lastTickAt);
    lastTickAt = t;
    remainingMs = Math.max(0, remainingMs - delta);
    if (remainingMs > 0) return;
    if (phase === 'Working') {
      enterBreaking();
    } else if (phase === 'Breaking') {
      enterWorking(roundIndex + 1);
    }
  }

  function getState() {
    return snapshot();
  }

  function getDisplayMessage() {
    const msg = (prefs.customMessage || '').trim();
    return msg || '该休息一下了';
  }

  return {
    setPrefs,
    start,
    pause,
    resume,
    stop,
    skipBreak,
    tick,
    getState,
    getDisplayMessage,
  };
}

// UMD-ish: Node + browser global
const api = { createEngine, DEFAULT_PREFS, formatMmSs };
if (typeof module !== 'undefined' && module.exports) {
  module.exports = api;
}
if (typeof window !== 'undefined') {
  window.TakeABreak = api;
}
```

- [ ] **Step 5: 运行测试，确认通过**

Run: `npm test`

Expected: 全部 PASS

- [ ] **Step 6: Commit**

```bash
git add package.json src/timer-engine.js tests/timer-engine.test.js
git commit -m "feat: add pomodoro timer engine with unit tests"
```

---

### Task 2: 全屏休息 Demo（纯文字 + 长按跳过）

**Files:**
- Create: `demos/break-fullscreen.html`
- Delete: `demos/demo_fullscreen_break.html`（旧稿，Task 5 统一清理亦可）

- [ ] **Step 1: 创建 `demos/break-fullscreen.html`**

要求（对照规格 §3.4）：

1. 引入 `../src/timer-engine.js`（相对路径 script，非 type=module）
2. 页面加载后：`createEngine`，`setPrefs({ workMinutes: 5, breakMinutes: 1 })` 后直接模拟进入 Breaking：可 `start()` 再把引擎拨到 break，或增加 demo 专用入口——**不要改引擎为 demo 开后门**；用加速：`setPrefs({ workMinutes: 5, breakMinutes: 1 })` 不够短。测试用 1 分钟仍长。

**Demo 加速约定（写在 HTML 注释与 UI 角标）：**

- Demo 使用「秒」映射：界面显示的 mm:ss 仍由引擎 ms 驱动
- 启动时 prefs：`workMinutes: 5, breakMinutes: 5` 但 **demo 注入 `now` 墙钟不变**；改用引擎真实 ms，在 demo 里用 **demoSpeed**：

在 demo 中不改引擎的话，最短 break 是 1 分钟。为体验闭环，引擎增加可选 **`durationUnitMs`** 会改 API——**禁止**。

**做法：** demo 页面使用真实引擎，但 prefs 设 `workMinutes: 5, breakMinutes: 1` 仍慢。改为：

在 `createEngine` 的 opts 增加 **`minuteMs`**（默认 `60_000`），仅用于换算 minutes→ms。测试与生产默认 60000；demo 传 `minuteMs: 1000`（1「分」=1 秒真实时间）。

- [ ] **Step 1b: 扩展引擎支持 `minuteMs`（保持默认 60000）**

修改 `src/timer-engine.js` 中所有 `* 60 * 1000` 为 `* minuteMs`：

```js
function createEngine(opts = {}) {
  const nowFn = opts.now || (() => Date.now());
  const minuteMs = opts.minuteMs || 60_000;
  // enterWorking: remainingMs = lockedWorkMinutes * minuteMs;
  // enterBreaking: remainingMs = lockedBreakMinutes * minuteMs;
  // progressRatio totals: locked* * minuteMs
}
```

测试里无需改（默认 60000）。新增一测：

```js
it('supports minuteMs for accelerated demos', () => {
  let t = 0;
  const e = createEngine({ now: () => t, minuteMs: 1000 });
  e.setPrefs({ workMinutes: 2, breakMinutes: 1 });
  e.start();
  assert.equal(e.getState().remainingMs, 2000);
  t = 2000;
  e.tick();
  assert.equal(e.getState().phase, 'Breaking');
  assert.equal(e.getState().remainingMs, 1000);
});
```

Run: `npm test` → PASS

- [ ] **Step 2: 实现 break-fullscreen 页面结构**

关键 UI：

- 全屏壁纸层（CSS 风景渐变作默认；`data-wallpaper` 可切换）
- 暗角 + 约 32% 黑透明层
- 标签「休息中」
- 文案：`engine.getDisplayMessage()`
- 倒计时：`formatMmSs(state.remainingMs)`，字重 200，字距宽松
- 细进度线：`width: state.progress * 100%`
- 底部长按：圆环 2s；`pointerdown` 开始，`pointerup/leave/cancel` 取消；满 2s 调 `engine.skipBreak()`
- 若 `allowLongPressSkip === false`，隐藏跳过 UI
- 角标：「Demo · 1 分 = 1 秒」当 `minuteMs===1000`
- 顶栏小控件（demo only）：「模拟进入休息」「允许跳过开/关」「改文案」便于单独验收本页

页面逻辑骨架：

```js
const engine = TakeABreak.createEngine({ minuteMs: 1000 });
engine.setPrefs({ workMinutes: 5, breakMinutes: 5, customMessage: '站起来走走，看看远处' });
// Force break for this isolated demo:
engine.start();
// drain work instantly via now injection OR start then loop tick with now jump:
// Prefer: create with controllable now
```

**推荐本页专用 now 控制：**

```js
let t = 0;
const engine = TakeABreak.createEngine({ now: () => t, minuteMs: 1000 });
engine.setPrefs({ workMinutes: 1, breakMinutes: 30 }); // 30 demo-seconds break
engine.start();
t = 1000; engine.tick(); // enter Breaking
// rAF/setInterval: t += 100; engine.tick(); render();
```

长按逻辑：

```js
const HOLD_MS = 2000;
let holdStart = null;
let holdRaf = null;

function onHoldStart() {
  if (!engine.getState().allowLongPressSkip) return;
  holdStart = performance.now();
  const step = (now) => {
    const p = Math.min(1, (now - holdStart) / HOLD_MS);
    setRing(p);
    if (p >= 1) {
      engine.skipBreak();
      // if left Breaking, show brief "已跳过 → 工作中" toast then optional reset to break for demo
      return;
    }
    holdRaf = requestAnimationFrame(step);
  };
  holdRaf = requestAnimationFrame(step);
}
function onHoldEnd() {
  holdStart = null;
  if (holdRaf) cancelAnimationFrame(holdRaf);
  setRing(0);
}
```

样式约束：

- **禁止**毛玻璃卡片、圆角大面板承载文案
- 字体：`-apple-system, BlinkMacSystemFont, "SF Pro Display", "PingFang SC", sans-serif`
- 单击与 keydown Escape **不**关闭全屏（规格）

- [ ] **Step 3: 浏览器手测清单**

1. 打开 `demos/break-fullscreen.html`
2. 倒计时每秒减少，进度线增长
3. 短点跳过无效；按住 ≥2s 进入 Working（或 demo toast）
4. 关闭「允许跳过」后圆环消失，长按无效
5. 文案修改后刷新显示（本页即时 `setPrefs` + render）

- [ ] **Step 4: Commit**

```bash
git add src/timer-engine.js tests/timer-engine.test.js demos/break-fullscreen.html
git commit -m "feat: fullscreen break demo with long-press skip"
```

---

### Task 3: 菜单栏面板 Demo

**Files:**
- Create: `demos/menubar.html`

- [ ] **Step 1: 创建页面**

布局：

1. 顶部 28–37px 仿 macOS 菜单栏（右对齐：倒计时图标位 + 时间）
2. 点击图标切换下拉面板（280px，右对齐）
3. 背景为中性桌面色（浅/深用 `prefers-color-scheme`）

引擎：

```js
let t = Date.now();
const engine = TakeABreak.createEngine({
  now: () => t,
  minuteMs: 1000,
});
engine.setPrefs({ workMinutes: 25, breakMinutes: 5 });

setInterval(() => {
  t += 100;
  engine.tick();
  render();
}, 100);
```

**Idle 面板**

- 文案：`工作 {workMinutes} 分 · 休息 {breakMinutes} 分`
- 按钮「开始专注」→ `engine.start()`
- 「偏好设置…」→ `window.location.href = 'preferences.html'`（或新窗口）

**Working 面板**

- 「工作中」+「第 {roundIndex} 轮」
- 大号 `formatMmSs(remainingMs)` + 进度条
- 「暂停」→ `pause()`；「停止」→ `stop()`

**Paused 面板**

- 「继续」→ `resume()`；「停止」

**Breaking 面板**

- 「休息中」+ 剩余
- 仅「停止」
- 旁注：「跳过请在全屏休息页长按」+ 链接 `break-fullscreen.html`

菜单栏图标文字：

- Idle：`☕` 或简洁 SVG 圆环（一个即可，避免 emoji 堆砌也可改用 SF 风格字符「◌」）
- Working/Paused/Breaking：`formatMmSs`；Paused 前缀 `‖ `

视觉：

- 浅色：白半透明面板、`#007AFF` 主按钮
- 深色：`rgba(44,44,46,0.96)` 面板、`#0A84FF`
- 用 `@media (prefers-color-scheme: dark)` 切换

Demo 工具条（页面底部，非产品 UI）：

- 「快进到休息」：将 `t` 增加 `remainingMs` 再 `tick()`
- 「加速 1 分=1 秒」说明

- [ ] **Step 2: 手测**

1. Idle → 开始 → 菜单栏出现倒计时  
2. 暂停 / 继续剩余不变异常（暂停时 t 仍增加但 remaining 不变——注意：demo 的 `t` 若全局递增，pause 时引擎 `tick` 直接 return，remaining 保持。**正确**）  
3. 快进到休息后面板变为休息中  
4. 停止回 Idle  

- [ ] **Step 3: Commit**

```bash
git add demos/menubar.html
git commit -m "feat: menubar panel demo for idle/work/pause/break"
```

---

### Task 4: 偏好设置小窗 Demo

**Files:**
- Create: `demos/preferences.html`

- [ ] **Step 1: 创建页面**

居中 macOS 风格小窗 ~420px：

**时长**

- 工作 Stepper 5–90，默认 25  
- 休息 Stepper 1–30，默认 5  
- `change` → `engine.setPrefs({ workMinutes, breakMinutes })`  
- 提示：「修改将于下一轮生效」

**休息壁纸**

- 4 个缩略图：`default-1`…`default-3` 用不同 CSS 渐变；第 4 个 `+` 用 `<input type="file" accept="image/*">`，读为 ObjectURL，存 `wallpaperId: 'custom:'+url` 或 localStorage 键 `tab.wallpaperDataUrl`
- 选中：2px `#007AFF` 边框

**休息文案**

- `<textarea>`，debounce 200ms `setPrefs({ customMessage })`

**行为**

- Toggle「允许长按跳过休息」→ `setPrefs({ allowLongPressSkip })`

持久化（demo）：

```js
const KEY = 'takeabreak.prefs.v1';
function save(p) {
  localStorage.setItem(KEY, JSON.stringify(p));
}
function load() {
  try { return JSON.parse(localStorage.getItem(KEY) || 'null'); }
  catch { return null; }
}
```

加载时 `engine.setPrefs(load() || {})`。

底栏链接：「打开菜单栏 Demo」「打开全屏休息 Demo」

- [ ] **Step 2: 手测**

1. 改时长刷新后仍在  
2. 选壁纸、改文案、关跳过 → localStorage 有值  
3. 打开 break-fullscreen 时若也读同一 KEY，文案/跳过一致（**break-fullscreen 与 menubar 均应读该 KEY**）

统一约定写入 Task 2/3 补丁：三页均：

```js
const saved = load();
if (saved) engine.setPrefs(saved);
// on any pref change: save(engine.getState() 中的 prefs 字段)
```

抽取 `demos/prefs-storage.js`：

```js
(function (w) {
  const KEY = 'takeabreak.prefs.v1';
  function loadPrefs() { /* ... */ }
  function savePrefs(p) {
    localStorage.setItem(KEY, JSON.stringify({
      workMinutes: p.workMinutes,
      breakMinutes: p.breakMinutes,
      wallpaperId: p.wallpaperId,
      customMessage: p.customMessage,
      allowLongPressSkip: p.allowLongPressSkip,
    }));
  }
  w.TakeABreakPrefs = { loadPrefs, savePrefs, KEY };
})(window);
```

各 demo `<script src="prefs-storage.js">` 后再加载引擎逻辑。

- [ ] **Step 3: Commit**

```bash
git add demos/preferences.html demos/prefs-storage.js demos/break-fullscreen.html demos/menubar.html
git commit -m "feat: preferences demo with localStorage shared prefs"
```

---

### Task 5: 入口页、串联 Flow、清理旧 demo

**Files:**
- Create: `demos/index.html`
- Create: `demos/flow.html`
- Delete: `demos/demo_menubar.html`
- Delete: `demos/demo_fullscreen_break.html`

- [ ] **Step 1: `demos/index.html`**

简洁扁平索引页（系统字体，跟随 `prefers-color-scheme`）：

- 标题：Take a Break · Design Demos  
- 链接卡片：菜单栏 / 偏好设置 / 全屏休息 / **完整流程（推荐）**  
- 说明：规格链接 `../docs/superpowers/specs/2026-07-22-takeabreak-design.md`（file 协议下 md 可能下载，改为短摘要即可）  
- 注明：Demo 默认 `1 分 = 1 秒` 便于体验  

- [ ] **Step 2: `demos/flow.html` 完整闭环**

单页两层：

1. **桌面层**：菜单栏 + 面板（复用 menubar 结构，可内联同一套 render）  
2. **全屏层**：`phase === 'Breaking'` 时 `position:fixed; inset:0; z-index:1000` 显示纯文字休息 UI（与 break-fullscreen 一致）  

同一 engine + `minuteMs: 1000` + prefs storage。

工作结束自动出全屏；长按跳过或倒计时结束回工作态并隐藏全屏。

提供「快进当前阶段」按钮（demo only）。

- [ ] **Step 3: 删除旧 demo**

```bash
rm -f demos/demo_menubar.html demos/demo_fullscreen_break.html
```

- [ ] **Step 4: 全量回归**

```bash
npm test
```

手测 `flow.html`：开始 → 快进工作 → 全屏文案/壁纸 → 长按跳过 → 新一轮工作 → 停止。

- [ ] **Step 5: Commit**

```bash
git add demos/ package.json src/ tests/
git status # ensure old demos deleted
git commit -m "feat: demo hub, integrated flow, remove legacy demos"
```

---

### Task 6: README 与最终核对

**Files:**
- Create: `README.md`

- [ ] **Step 1: 写 README**

```markdown
# Take a Break

macOS 休息提醒（设计阶段）。规格见 `docs/superpowers/specs/2026-07-22-takeabreak-design.md`。

## Demos

用浏览器直接打开：

- `demos/index.html` — 入口
- `demos/flow.html` — 完整流程（推荐）
- `demos/menubar.html` / `preferences.html` / `break-fullscreen.html` — 分屏

Demo 计时默认 **1 分 = 1 秒**，便于体验。

## Tests

```bash
npm test
```
```

- [ ] **Step 2: Spec 覆盖核对（执行者自检）**

| 规格项 | 落点 |
|--------|------|
| Hybrid 形态 | menubar + preferences + flow |
| 纯文字叠层 | break-fullscreen + flow 全屏层 |
| 长按 2s 跳过 | break-fullscreen + flow |
| 番茄循环 | timer-engine + flow |
| N/M 下轮生效 | timer-engine 测试 + preferences 文案提示 |
| 系统浅深色 | CSS `prefers-color-scheme` |
| 无统计/多档案 | 未实现 |

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add README for demos and tests"
```

---

## Self-Review (plan author)

### Spec coverage

| Spec section | Task |
|--------------|------|
| §2 状态模型 | Task 1 |
| §3.1–3.2 菜单栏 | Task 3, 5 |
| §3.3 偏好设置 | Task 4 |
| §3.4 全屏休息 | Task 2, 5 |
| §4 持久化 | Task 4 localStorage（运行时崩溃恢复不做，与规格一致） |
| §5 睡眠冻结 | 引擎 pause 语义覆盖「不滴答」；真睡眠非 demo 范围 |
| §6 不做项 | 未列入任务 |

### Placeholder scan

无 TBD /「适当处理」类步骤；引擎与测试代码完整给出。

### Type consistency

- 相位名：`Idle` | `Working` | `Paused` | `Breaking`（与规格一致）
- API：`createEngine` / `setPrefs` / `start` / `pause` / `resume` / `stop` / `skipBreak` / `tick` / `getState` / `getDisplayMessage` / `formatMmSs` / `DEFAULT_PREFS`
- `minuteMs` 仅 demo 加速，默认 `60000`
- Prefs 字段：`workMinutes`, `breakMinutes`, `wallpaperId`, `customMessage`, `allowLongPressSkip`
- Storage key：`takeabreak.prefs.v1`

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-22-takeabreak-demos.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** — 每个 Task 新开子代理，Task 间做审查，迭代快  
2. **Inline Execution** — 本会话按 executing-plans 连续执行，设检查点  

Which approach?
