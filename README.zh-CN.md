<div align="center">

# 🌌 Claude Code 状态栏主题

**赛博朋克风格 · 24-bit 真彩色 · 科技图标**

English | [中文](README.zh-CN.md)

![预览](assets/screenshot.png)

</div>

---

## ✨ 组件说明

### 第一行

| 模块 | 说明 |
|:----:|------|
| ⏰ **时间** | 当前时间，HH:MM 格式 |
| 🤖 **模型** | 当前 Claude 模型（Sonnet / Opus / Haiku） |
| 🌿 **分支** | 当前 git 分支名 |
| 📊 **Git 统计** | `Xm Xs Xu Xp` — 未暂存修改 / 已暂存 / 未跟踪 / 未推送，颜色为青色 / 品红 / 黄绿 / 珊瑚红 |
| 🔋 **电池** | macOS 电量百分比，含充电 / 低电量 / 满电图标 |
| 🟢 **Node.js** | 当前 Node.js 版本 |
| 📂 **目录** | 工作目录路径（home 目录显示 `~`） |

### 第二行

| 模块 | 说明 |
|:----:|------|
| 📈 **上下文窗口** | 进度条 + 剩余百分比 |
| 🔄 **Token** | 输入 / 输出，带 k/M 后缀 |
| 🔌 **MCP** | 已连接的 MCP 服务器数量 |
| 🪝 **Hooks** | 活跃的 hooks 数量（全局 + 项目） |

---

## 🚀 使用方法

```bash
# 1. 复制脚本
cp statusline-nerd.sh ~/.claude/statusline-nerd.sh
chmod +x ~/.claude/statusline-nerd.sh
```

在 `~/.claude/settings.json` 中添加：

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline-nerd.sh"
  }
}
```

重启 Claude Code 即可 ✨

---

## 📋 环境要求

- `jq` — JSON 解析器
- **Nerd Font** 字体（如 MesloLGS NF、JetBrains Mono Nerd Font）
- 支持真彩色的终端（`COLORTERM=truecolor`）

---

## 📄 许可证

MIT
