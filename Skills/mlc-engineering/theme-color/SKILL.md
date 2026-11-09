---
name: theme-color
description: 当进行 Web 或 iOS UI、主题、组件配色、颜色 token、深浅色模式或品牌视觉设计时使用，统一遵循 MLC 主题色彩规范。
---

# React Web 统一主题色设计规范（生产工程版）

根据你提供的全部颜色，我建议最终采用 冰川科技蓝为主色、明媚电光蓝为强调色、晴空科技蓝为辅助色、星云蓝紫为 AI 专属色、深海蓝为深色模式基础色。

整体设计目标：

淡雅、明媚、灵动、机智、科幻，同时适合长时间使用。

## 一、最终保留的核心色彩

冰川科技蓝

\#4294E0

全站主品牌色 · 第一优先

明媚电光蓝

\#28B4F5

强动作 · 动态 · 科技高光

晴空科技蓝

\#438BFA

品牌展示 · 活动 · 运营

星云蓝紫

\#8185F4

AI · 智能推荐 · 创新

深海智能蓝

\#1A3B66

深色模式 · 企业级容器

冰川浅蓝

\#89C8FF

柔和背景 · 悬浮 · 装饰

另外保留 `#5FA8FF` 作为浅蓝辅助色，`#F0F7FF` 作为浅色页面背景，`#FFFFFF` 作为卡片背景。

你写的 `#CPF0FF` 不是合法的 HEX 色值，因为 `P` 不属于十六进制字符。如果原本想表达非常浅的冰蓝色，建议改成 `#CFF0FF`。

### 中信红色系（场景内优先使用）

全站主品牌色仍为冰川科技蓝；涉及价格、金额、上涨行情、警示、活动及相关操作按钮时，优先从以下红色系中按语义选色，不要用蓝色代替这些场景色。色值保留原始 HEX，不把近似红合并为同一种颜色。

| 颜色名称 | HEX | 建议用途 / 主题 token |
| --- | --- | --- |
| 中信主题红 | `#EA494A` | 品牌或活动展示；`zhongxinBrandRed` |
| 背景主题红 02 | `#E8423A` | 活动背景、红色主题容器；`zhongxinBackgroundRed` |
| 中信红 2 | `#EC6767` | 柔和的图标、强调与装饰；`zhongxinAccentRed` |
| K 红线 | `#C53225` | 上涨 K 线和行情线条；`kLineRed` |
| 按钮背景红 | `#E64642` | 场景化红色操作按钮；`buttonRed` |
| 按钮背景红（深） | `#DA332A` | 白色小字按钮优先选用；`buttonRedStrong` |
| 按钮背景红（柔和） | `#EB5B55` | 辅助按钮或弱强调；`buttonRedSoft` |
| 按钮背景红（鲜明） | `#E84038` | 重点操作或高亮按钮；`buttonRedBright` |
| 价格 / 金额 / 警示红 | `#E83E36` | 价格、金额和警示文字；`priceRed` |
| 上证指数红 | `#D65E53` | 指数上涨数字及标签；`indexRiseRed` |

React 工程通过 `HGThemeUtils.getCssVar(token)` 或 `var(--hg-color-...)` 引用对应 token，不在业务组件里重复写 HEX。红色按钮的白字、红色文字在背景上的对比度需按字号与明暗主题分别校验；浅红色不直接承担小字号白字，危险操作仍需明确的语义和确认机制。避免把红色用于成功状态、普通导航或所有按钮，以保留价格与警示的辨识度。

## 二、统一颜色使用规则

| 组件 / 场景         | 默认颜色      | 交互规则            |
| --------------- | --------- | --------------- |
| 页面背景            | `#F0F7FF` | 全站统一            |
| 卡片、Modal、Drawer | `#FFFFFF` | 白色容器            |
| 主按钮 Primary     | `#2674C7` | Hover `#195FA8` |
| 主品牌色 / Logo     | `#4294E0` | 品牌展示            |
| 次级蓝色按钮          | `#438BFA` | Hover `#2674E8` |
| AI 生成按钮         | `#176D9B` | Hover `#10577E` |
| AI 动效 / 高光      | `#28B4F5` | 少量使用            |
| AI 推荐模块         | `#8185F4` | 配浅紫背景           |
| 价格 / 金额 / 警示文字 | `#E83E36` | 优先红色语义 token，校验对比度 |
| 上涨 K 线 / 指数     | `#C53225` / `#D65E53` | 按图表和数字场景区分 |
| 活动 / 红色场景按钮   | `#EA494A` / `#DA332A` | 品牌展示与可读按钮分别选用 |
| 导航选中            | `#4294E0` | 浅蓝背景 + 深蓝文字     |
| 普通链接            | `#2166AE` | Hover `#19518E` |
| 输入框 Focus       | `#4294E0` | 浅蓝聚焦光环          |
| Switch 开启       | `#4294E0` | 电光蓝可用于动态点缀      |
| 进度条             | `#28B4F5` | 轨道使用浅蓝          |
| 表格选中行           | `#EAF4FF` | Hover `#F2F8FF` |
| 成功 / 警告 / 错误    | 独立语义色     | 不用蓝色代替          |
| 深色侧边栏           | `#1A3B66` | 白色文字            |
| 正文文字            | `#172B4D` | 保证可读性           |
| 边框 / 分割线        | `#D6E7F9` | 低对比度            |

这里有一个重要的工程设计原则：品牌色不一定等于按钮背景色。 `#4294E0`、`#28B4F5` 很漂亮，但配白色小字时对比度不足。因此在生产环境中，保留原色用于品牌、图标、光效，另设深一档的交互色用于白字按钮。

## 三、React 工程推荐目录结构

采用 CSS Variables + React ThemeProvider + 组件语义类名，不需要引入额外的主题库。可以兼容 React、Umi、Ant Design、Ant Design Pro。

```
src/
├── theme/
│   ├── tokens.css          # 颜色、间距、圆角、阴影
│   ├── components.css      # 通用组件样式
│   ├── ThemeProvider.jsx   # 明暗主题切换
│   └── index.js            # 统一导出
│
├── components/
│   └── ThemeDemo.jsx       # JSX 使用示例
│
└── App.jsx
```

### 1. tokens.css — 全站主题变量

将颜色分成三个层次：

- 品牌原色：保持你喜欢的颜色不变。
- 语义色：告诉组件这个颜色用于什么功能。
- 交互状态色：处理 hover、active、disabled、focus。

```

/* src/theme/tokens.css */

:root,
[data-theme="light"] {
  color-scheme: light;

  /* ===== 1. 品牌基础色 ===== */
  --brand-glacier: #4294E0;
  --brand-electric: #28B4F5;
  --brand-sky: #438BFA;
  --brand-nebula: #8185F4;
  --brand-ocean: #1A3B66;

  /* ===== 2. 柔和辅助色 ===== */
  --brand-ice: #89C8FF;
  --brand-sky-light: #5FA8FF;
  --brand-frost: #CFF0FF;

  /* ===== 3. 主交互 ===== */
  --color-primary: #2674C7;
  --color-primary-hover: #195FA8;
  --color-primary-active: #124B86;
  --color-primary-soft: #EAF4FF;

  /* ===== 4. 次级交互 ===== */
  --color-secondary: #438BFA;
  --color-secondary-hover: #2674E8;
  --color-secondary-soft: #EDF4FF;

  /* ===== 5. 电光强调 ===== */
  --color-accent: #28B4F5;
  --color-accent-hover: #17A2E0;
  --color-accent-soft: #E6F8FF;
  --color-accent-action: #176D9B;
  --color-accent-action-hover: #10577E;

  /* ===== 6. AI 专属 ===== */
  --color-ai: #8185F4;
  --color-ai-hover: #6569D8;
  --color-ai-soft: #F0F0FF;
  --color-ai-action: #565AC4;

  /* ===== 7. 页面背景 ===== */
  --color-bg-page: #F0F7FF;
  --color-bg-surface: #FFFFFF;
  --color-bg-subtle: #F6FAFF;
  --color-bg-hover: #F2F8FF;
  --color-bg-selected: #EAF4FF;
  --color-bg-disabled: #F1F5F9;

  /* ===== 8. 文本 ===== */
  --color-text: #172B4D;
  --color-text-title: #0F2440;
  --color-text-secondary: #61758E;
  --color-text-muted: #71849B;
  --color-text-inverse: #FFFFFF;
  --color-link: #2166AE;
  --color-link-hover: #19518E;

  /* ===== 9. 边框 ===== */
  --color-border: #D6E7F9;
  --color-border-strong: #B5D0ED;
  --color-border-focus: #4294E0;

  /* ===== 10. 状态语义 ===== */
  --color-success: #16835D;
  --color-success-soft: #E8F8F0;
  --color-warning: #AD6800;
  --color-warning-soft: #FFF7E6;
  --color-danger: #C9364B;
  --color-danger-soft: #FFF0F2;
  --color-info: #2674C7;
  --color-info-soft: #EAF4FF;

  /* ===== 11. 深海色 ===== */
  --color-ocean: #1A3B66;
  --color-ocean-hover: #20487C;
  --color-ocean-border: #274C80;

  /* ===== 12. 渐变 ===== */
  --gradient-brand: linear-gradient(
    120deg,
    #4294E0 0%,
    #28B4F5 55%,
    #8185F4 100%
  );

  --gradient-ai: linear-gradient(
    120deg,
    #438BFA 0%,
    #8185F4 100%
  );

  --gradient-soft: linear-gradient(
    135deg,
    #F0F7FF 0%,
    #E6F8FF 60%,
    #F0F0FF 100%
  );

  /* ===== 13. 视觉系统 ===== */
  --radius-sm: 6px;
  --radius-md: 10px;
  --radius-lg: 14px;
  --radius-xl: 20px;

  --shadow-card:
    0 4px 18px rgb(26 59 102 / 6%);

  --shadow-popover:
    0 12px 32px rgb(26 59 102 / 12%);

  --focus-ring:
    0 0 0 3px rgb(66 148 224 / 22%);

  --transition-fast: 150ms ease;
  --transition-normal: 220ms ease;
}

/* ===== 深色模式 ===== */

[data-theme="dark"] {
  color-scheme: dark;

  --color-primary: #89C8FF;
  --color-primary-hover: #A5D5FF;
  --color-primary-active: #5FA8FF;
  --color-primary-soft: #203F61;

  --color-secondary: #8DAEFF;
  --color-secondary-hover: #A7C2FF;
  --color-secondary-soft: #24395E;

  --color-accent: #50C8FA;
  --color-accent-hover: #82DAFF;
  --color-accent-soft: #173F57;
  --color-accent-action: #50C8FA;
  --color-accent-action-hover: #82DAFF;

  --color-ai: #AAA8FF;
  --color-ai-hover: #C1BEFF;
  --color-ai-soft: #302D58;
  --color-ai-action: #AAA8FF;

  --color-bg-page: #0E1D30;
  --color-bg-surface: #1A3B66;
  --color-bg-subtle: #162E4C;
  --color-bg-hover: #244A76;
  --color-bg-selected: #244F7E;
  --color-bg-disabled: #26394F;

  --color-text: #E0EDFB;
  --color-text-title: #F4F8FF;
  --color-text-secondary: #B8CBE1;
  --color-text-muted: #A8BCD4;
  --color-text-inverse: #10243C;

  --color-link: #89C8FF;
  --color-link-hover: #B1DDFF;

  --color-border: #35577F;
  --color-border-strong: #4D7199;
  --color-border-focus: #89C8FF;

  --color-success: #65D9A4;
  --color-success-soft: #173F37;
  --color-warning: #FFD078;
  --color-warning-soft: #463920;
  --color-danger: #FF8D9B;
  --color-danger-soft: #4A293A;
  --color-info: #89C8FF;
  --color-info-soft: #203F61;

  --shadow-card:
    0 4px 18px rgb(0 0 0 / 18%);

  --shadow-popover:
    0 12px 32px rgb(0 0 0 / 30%);

  --focus-ring:
    0 0 0 3px rgb(137 200 255 / 30%);
}

```

深色模式不是简单把白色替换为深蓝，而是要同时调整文字、边框、选中态和交互色。这样能保持组件层级清晰。

### 2. components.css — 通用组件样式

```

/* src/theme/components.css */

.hg-page {
  min-height: 100vh;
  background: var(--color-bg-page);
  color: var(--color-text);
}

.hg-card {
  padding: 20px;
  background: var(--color-bg-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-card);
}

.hg-button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  min-height: 40px;
  padding: 0 16px;
  border: 1px solid transparent;
  border-radius: var(--radius-md);
  font: inherit;
  font-weight: 500;
  cursor: pointer;
  transition:
    background-color var(--transition-fast),
    border-color var(--transition-fast),
    color var(--transition-fast);
}

.hg-button:focus-visible,
.hg-input:focus-visible {
  outline: none;
  box-shadow: var(--focus-ring);
}

.hg-button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* 主按钮 */
.hg-button--primary {
  color: #FFFFFF;
  background: var(--color-primary);
}

.hg-button--primary:hover:not(:disabled) {
  background: var(--color-primary-hover);
}

.hg-button--primary:active:not(:disabled) {
  background: var(--color-primary-active);
}

/* 次级按钮 */
.hg-button--secondary {
  color: var(--color-primary);
  background: var(--color-primary-soft);
}

.hg-button--secondary:hover:not(:disabled) {
  background: var(--color-bg-selected);
}

/* AI 行动按钮 */
.hg-button--ai {
  color: #FFFFFF;
  background: var(--color-ai-action);
}

.hg-button--ai:hover:not(:disabled) {
  background: var(--color-ai-hover);
}

/* 电光行动按钮 */
.hg-button--accent {
  color: #FFFFFF;
  background: var(--color-accent-action);
}

.hg-button--accent:hover:not(:disabled) {
  background: var(--color-accent-action-hover);
}

/* 输入框 */
.hg-input {
  box-sizing: border-box;
  width: 100%;
  min-height: 40px;
  padding: 8px 12px;
  color: var(--color-text);
  background: var(--color-bg-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  font: inherit;
  transition: border-color var(--transition-fast);
}

.hg-input:focus {
  border-color: var(--color-border-focus);
}

.hg-input:focus-visible {
  outline: none;
  box-shadow: var(--focus-ring);
}

/* 标签 */
.hg-tag {
  display: inline-flex;
  align-items: center;
  padding: 4px 10px;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 500;
}

.hg-tag--info {
  color: var(--color-info);
  background: var(--color-info-soft);
}

.hg-tag--ai {
  color: var(--color-ai-action);
  background: var(--color-ai-soft);
}

.hg-tag--success {
  color: var(--color-success);
  background: var(--color-success-soft);
}

.hg-tag--danger {
  color: var(--color-danger);
  background: var(--color-danger-soft);
}

/* 导航 */
.hg-nav-item {
  display: flex;
  align-items: center;
  padding: 10px 14px;
  color: var(--color-text-secondary);
  border-radius: var(--radius-md);
  text-decoration: none;
}

.hg-nav-item:hover {
  background: var(--color-bg-hover);
}

.hg-nav-item--active {
  color: var(--color-primary);
  background: var(--color-primary-soft);
  font-weight: 600;
}

/* 表格 */
.hg-table {
  width: 100%;
  border-collapse: collapse;
  color: var(--color-text);
}

.hg-table th,
.hg-table td {
  padding: 12px 16px;
  border-bottom: 1px solid var(--color-border);
  text-align: left;
}

.hg-table th {
  background: var(--color-bg-subtle);
}

.hg-table tbody tr:hover {
  background: var(--color-bg-hover);
}

.hg-table tbody tr.is-selected {
  background: var(--color-bg-selected);
}

/* AI 卡片 */
.hg-ai-card {
  background: var(--color-bg-surface);
  border: 1px solid var(--color-ai);
  border-radius: var(--radius-lg);
  padding: 20px;
}

/* 科技进度条 */
.hg-progress {
  height: 6px;
  overflow: hidden;
  border-radius: 999px;
  background: var(--color-primary-soft);
}

.hg-progress__bar {
  height: 100%;
  background: var(--color-accent);
  border-radius: inherit;
  transition: width var(--transition-normal);
}

/* 深色模式下按钮反转文字色 */
[data-theme="dark"] .hg-button--primary,
[data-theme="dark"] .hg-button--ai,
[data-theme="dark"] .hg-button--accent {
  color: var(--color-text-inverse);
}

@media (prefers-reduced-motion: reduce) {
  .hg-button,
  .hg-input,
  .hg-progress__bar {
    transition: none;
  }
}

```

### 3. ThemeProvider.jsx — 统一主题切换

支持浅色、深色、跟随系统三种模式。

```

import React, {
  createContext,
  useContext,
  useEffect,
  useState,
} from "react";

import "./tokens.css";
import "./components.css";

const ThemeContext = createContext(null);

const THEME_KEY = "hg-theme-mode";

export function ThemeProvider({ children }) {
  const [mode, setMode] = useState(() => {
    try {
      const saved = localStorage.getItem(THEME_KEY);
      return ["light", "dark", "system"].includes(saved)
        ? saved
        : "system";
    } catch {
      return "system";
    }
  });

  const [systemDark, setSystemDark] = useState(() =>
    window.matchMedia?.("(prefers-color-scheme: dark)")
      .matches ?? false
  );

  useEffect(() => {
    const media = window.matchMedia(
      "(prefers-color-scheme: dark)"
    );

    const update = (event) => setSystemDark(event.matches);

    setSystemDark(media.matches);
    media.addEventListener("change", update);

    return () => media.removeEventListener("change", update);
  }, []);

  const resolvedTheme =
    mode === "system"
      ? systemDark ? "dark" : "light"
      : mode;

  useEffect(() => {
    document.documentElement.dataset.theme = resolvedTheme;
  }, [resolvedTheme]);

  function changeMode(nextMode) {
    if (!["light", "dark", "system"].includes(nextMode)) {
      return;
    }

    setMode(nextMode);

    try {
      localStorage.setItem(THEME_KEY, nextMode);
    } catch {
      // 存储不可用时仍允许本次切换
    }
  }

  return (
    <ThemeContext.Provider
      value={{ mode, resolvedTheme, setMode: changeMode }}
    >
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  const context = useContext(ThemeContext);

  if (!context) {
    throw new Error("useTheme must be used in ThemeProvider");
  }

  return context;
}

```

### 4. JSX 组件直接使用

```

import React from "react";
import { useTheme } from "../theme/ThemeProvider";

export default function ThemeDemo() {
  const { mode, setMode } = useTheme();

  return (
    <main className="hg-page" style={{ padding: 24 }}>
      <div className="hg-card">
        <h2>智能管理平台</h2>
        <p>冰川科技蓝主题系统</p>

        <label htmlFor="theme-mode">主题模式</label>
        <select
          id="theme-mode"
          value={mode}
          onChange={(e) => setMode(e.target.value)}
        >
          <option value="light">浅色</option>
          <option value="dark">深色</option>
          <option value="system">跟随系统</option>
        </select>

        <div style={{
          display: "flex",
          flexWrap: "wrap",
          gap: 12,
          marginTop: 20
        }}>
          <button className="hg-button hg-button--primary">
            保存设置
          </button>

          <button className="hg-button hg-button--secondary">
            查看详情
          </button>

          <button className="hg-button hg-button--accent">
            开始生成
          </button>

          <button className="hg-button hg-button--ai">
            AI 智能推荐
          </button>
        </div>

        <div style={{ marginTop: 20 }}>
          <input
            className="hg-input"
            placeholder="请输入搜索内容"
          />
        </div>

        <div style={{
          display: "flex",
          gap: 8,
          marginTop: 20
        }}>
          <span className="hg-tag hg-tag--info">
            进行中
          </span>
          <span className="hg-tag hg-tag--ai">
            AI 生成
          </span>
          <span className="hg-tag hg-tag--success">
            已完成
          </span>
        </div>

        <div className="hg-progress" style={{ marginTop: 24 }}>
          <div
            className="hg-progress__bar"
            style={{ width: "68%" }}
          />
        </div>
      </div>
    </main>
  );
}

```

在 `App.jsx` 中：

```
import { ThemeProvider } from "./theme/ThemeProvider";
import ThemeDemo from "./components/ThemeDemo";

export default function App() {
  return (
    <ThemeProvider>
      <ThemeDemo />
    </ThemeProvider>
  );
}
```

## 四、在 Ant Design / Ant Design Pro 中使用

如果你的 React 工程使用 `antd` 的 Button、Form、Table、Modal、Select、Switch、Menu 等组件，建议通过 `ConfigProvider` 统一注入颜色，不要逐个组件手动设置 `style={{ color: ... }}`。

```

import React from "react";
import {
  ConfigProvider,
  theme as antdTheme,
} from "antd";

import { useTheme } from "./ThemeProvider";

export default function HGAntdThemeProvider({ children }) {
  const { resolvedTheme } = useTheme();
  const isDark = resolvedTheme === "dark";

  return (
    <ConfigProvider
      theme={{
        algorithm: isDark
          ? antdTheme.darkAlgorithm
          : antdTheme.defaultAlgorithm,

        token: {
          colorPrimary: isDark ? "#89C8FF" : "#2674C7",
          colorInfo: isDark ? "#89C8FF" : "#2674C7",
          colorSuccess: isDark ? "#65D9A4" : "#16835D",
          colorWarning: isDark ? "#FFD078" : "#AD6800",
          colorError: isDark ? "#FF8D9B" : "#C9364B",

          colorBgBase: isDark ? "#0E1D30" : "#FFFFFF",
          colorTextBase: isDark ? "#E0EDFB" : "#172B4D",

          borderRadius: 10,
          controlHeight: 40,
          fontSize: 14,
        },

        components: {
          Button: {
            primaryShadow: "none",
            borderRadius: 10,
          },
          Card: {
            borderRadiusLG: 14,
          },
          Input: {
            activeShadow: isDark
              ? "0 0 0 3px rgb(137 200 255 / 30%)"
              : "0 0 0 3px rgb(66 148 224 / 22%)",
          },
          Table: {
            headerBg: isDark ? "#162E4C" : "#F6FAFF",
          },
        },
      }}
    >
      {children}
    </ConfigProvider>
  );
}

```

在应用根组件中，将 `HGAntdThemeProvider` 放在 `ThemeProvider` 内部即可。这里的 Ant Design `colorPrimary` 使用更深的交互蓝，以保证主按钮的白字可读性。对于 ProLayout，还需要将其主题配置与 `resolvedTheme` 同步，避免侧边栏和内容区使用不同的明暗模式。

## 五、组件颜色效果预览

组件主题预览

浅色深色

智能控制台

统一主题组件展示

主要操作

次要操作

开始生成

AI 推荐

搜索设备、用户或内容...

运行正常

AI 智能

进行中

异常告警

任务处理进度

68%

## 六、生产工程需要遵守的 5 条规则

1. 组件不直接写品牌 HEX。 业务组件使用 `var(--color-primary)` 等语义变量，避免后续换肤时全工程修改。
2. 全站只有一套主交互体系。 冰川科技蓝负责品牌，深一档蓝负责按钮；电光蓝只用于特殊动作和动效，避免按钮层级混乱。
3. AI 模块统一使用星云蓝紫。 AI 图标、智能推荐、AI 卡片采用紫色，必要时使用蓝紫渐变，形成独立识别体系。
4. 深色模式必须单独校验。 特别是按钮 hover、disabled、文字对比度、表格、弹窗和图表；不要直接反转颜色。
5. CSS 变量是唯一颜色来源。 Ant Design 的主题 Token、业务组件 CSS 和图表颜色配置都应从统一的主题配置映射，避免维护多套不一致的色值。

还有两个工程细节：上面的 `ThemeProvider` 使用浏览器 API，适合客户端渲染的 React 工程；如果以后引入 SSR，需要增加服务端安全判断及首屏主题初始化。对于深色模式，建议把 `.hg-button--ai:hover` 等状态进一步拆成语义变量，确保悬停色始终比默认色具有明确的视觉反馈。

最终确定的品牌体系：

这套主题最适合统一到你的 React Web 前台、后台管理系统、AI 社区及智能设备管理页面中。后续扩展移动端时，保留相同的品牌色和语义命名，再分别映射到 iOS、Android 的原生主题系统即可。
