#!/bin/bash

# 颜色定义 - 使用 256 色模式适配 iTerm2
COLOR_RESET=$'\033[0m'
COLOR_TIME=$'\033[38;5;38m'        # 青色 - 时间
COLOR_MODEL=$'\033[38;5;141m'      # 紫色 - 模型
COLOR_GIT=$'\033[38;5;71m'         # 绿色 - Git 分支
COLOR_GIT_STAGED=$'\033[38;2;255;0;255m'  # 品红 - 已暂存
COLOR_GIT_MODIFIED=$'\033[38;2;0;255;255m' # 青色 - 已修改
COLOR_GIT_UNTRACKED=$'\033[38;2;0;255;128m' # 黄绿 - 未跟踪
COLOR_GIT_UNPUSHED=$'\033[38;2;255;100;100m'  # 珊瑚红 - 未推送
COLOR_CONTEXT=$'\033[38;5;39m'     # 蓝色 - Token 使用量
COLOR_TOKENS=$'\033[38;5;75m'      # 浅蓝 - Token 详情
COLOR_BATTERY=$'\033[38;5;226m'    # 黄色 - 电池
COLOR_BATTERY_LOW=$'\033[38;5;203m' # 红色 - 低电量
COLOR_NODE=$'\033[38;5;34m'        # 绿色 - Node.js
COLOR_MCP=$'\033[38;5;213m'       # 粉色 - MCP
COLOR_HOOKS=$'\033[38;5;216m'     # 淡橙 - Hooks
COLOR_DIR=$'\033[38;5;117m'        # 天蓝色 - 目录
COLOR_SEPARATOR=$'\033[38;5;240m'  # 深灰 - 分隔符

# Read JSON input from stdin
input=$(cat)

# Extract all fields from JSON input in a single jq call
eval "$(echo "$input" | jq -r '
  "model=\(.model.display_name // "Claude" | @sh)",
  "current_dir=\(.workspace.current_dir // "" | @sh)",
  "remaining=\(.context_window.remaining_percentage // "" | @sh)",
  "used=\(.context_window.used_percentage // "" | @sh)",
  "input_tokens=\(.context_window.current_usage.input_tokens // 0)",
  "output_tokens=\(.context_window.current_usage.output_tokens // 0)"
' 2>/dev/null)"

# Build status components
components=()

# 1. Add time
current_time=$(date +"%H:%M" 2>/dev/null)
if [ -n "$current_time" ]; then
  components+=("${COLOR_TIME}󰥔 ${current_time}${COLOR_RESET}")
fi

# 2. Add model
if [ -n "$model" ] && [ "$model" != "null" ]; then
  case "$model" in
    *Sonnet*) model_display="Sonnet" ;;
    *Opus*) model_display="Opus" ;;
    *Haiku*) model_display="Haiku" ;;
    *) model_display="$model" ;;
  esac
  components+=("${COLOR_MODEL} ${model_display}${COLOR_RESET}")
fi

# Get git branch and status (single subshell, single cd)
git_info=""
in_git_repo=false
modified_count=0
staged_count=0
untracked_count=0
unpushed_count=0
if [ -n "$current_dir" ] && [ -d "$current_dir" ]; then
  # Single subshell: cd once, run all git commands
  git_output=$(cd "$current_dir" 2>/dev/null && {
    git branch --show-current 2>/dev/null
    git status --porcelain 2>/dev/null
    echo "---UNPUSHED---"
    git rev-list --count --left-right @{u}...HEAD 2>/dev/null | awk '{print $1}'
  } 2>/dev/null)

  git_branch=$(echo "$git_output" | head -1)
  if [ -n "$git_branch" ]; then
    in_git_repo=true
    git_info="${COLOR_GIT} ${git_branch}${COLOR_RESET}"

    # Parse git_output with awk: branch is line 1, status lines before ---UNPUSHED---, unpushed after
    eval "$(echo "$git_output" | awk '
      NR == 1 { next }
      /^---UNPUSHED---$/ { in_unpushed=1; next }
      in_unpushed { unpushed=$0; next }
      { status[++n] = $0 }
      END {
        # Count from status lines
        mod=0; stg=0; unt=0
        for (i=1; i<=n; i++) {
          if (substr(status[i],1,2) == "??") unt++
          else {
            if (substr(status[i],1,1) ~ /[A-Z]/) stg++
            if (substr(status[i],2,1) == "M") mod++
          }
        }
        printf "modified_count=%d staged_count=%d untracked_count=%d unpushed_count=%s\n", mod, stg, unt, (unpushed+0)
      }
    ')"
  fi
fi

if [ -n "$git_info" ]; then
  components+=("$git_info")
fi

# Add modified (unstaged) and staged file counts combined into one component (no separator)
if [ "$in_git_repo" = true ]; then
  components+=("${COLOR_GIT_MODIFIED} ${modified_count}m ${COLOR_GIT_STAGED} ${staged_count}s ${COLOR_GIT_UNTRACKED} ${untracked_count}u ${COLOR_GIT_UNPUSHED} ${unpushed_count}p${COLOR_RESET}")
fi

# Add context window percentage (always show)
context_info=""
if [ -n "$remaining" ] && [ "$remaining" != "null" ] && [ "$remaining" != "" ]; then
  remaining_int=${remaining%.*}
  used_pct=$((100 - remaining_int))
  bar_filled=$((used_pct * 8 / 100))
  bar_empty=$((8 - bar_filled))
  bar=$(printf '%0.s■' $(seq 1 $bar_filled 2>/dev/null) ; printf '%0.s□' $(seq 1 $bar_empty 2>/dev/null))
  context_info="${COLOR_CONTEXT} ${bar} ${remaining}%${COLOR_RESET}"
elif [ -n "$used" ] && [ "$used" != "null" ] && [ "$used" != "" ]; then
  used_int=${used%.*}
  bar_filled=$((used_int * 8 / 100))
  bar_empty=$((8 - bar_filled))
  bar=$(printf '%0.s■' $(seq 1 $bar_filled 2>/dev/null) ; printf '%0.s□' $(seq 1 $bar_empty 2>/dev/null))
  context_info="${COLOR_CONTEXT} ${bar} ${used}%${COLOR_RESET}"
else
  bar=$(printf '%0.s■' $(seq 1 1 2>/dev/null) ; printf '%0.s□' $(seq 1 7 2>/dev/null))
  context_info="${COLOR_CONTEXT} ${bar} --%${COLOR_RESET}"
fi
line2_components=("$context_info")

# Add token usage (always show)
format_number() {
  local num=$1
  if [ "$num" -ge 1000000 ]; then
    echo "$((num / 1000000))M"
  elif [ "$num" -ge 1000 ]; then
    echo "$((num / 1000))k"
  else
    echo "$num"
  fi
}
input_display=$(format_number "${input_tokens:-0}")
output_display=$(format_number "${output_tokens:-0}")
line2_components+=("${COLOR_TOKENS}↑${input_display}/↓${output_display}${COLOR_RESET}")

# Add battery status for macOS
if command -v pmset &> /dev/null; then
  batt_info=$(pmset -g batt 2>/dev/null)
  battery_percent=$(echo "$batt_info" | grep -Eo '\d+%' | sed 's/%//')
  battery_status=$(echo "$batt_info" | grep -o 'charging')

  if [ -n "$battery_percent" ]; then
    if [ "$battery_status" = "charging" ]; then
      battery_icon=""
      battery_color="$COLOR_BATTERY"
    elif [ "$battery_percent" -lt 20 ]; then
      battery_icon=""
      battery_color="$COLOR_BATTERY_LOW"
    elif [ "$battery_percent" -lt 50 ]; then
      battery_icon=""
      battery_color="$COLOR_BATTERY_LOW"
    elif [ "$battery_percent" -lt 80 ]; then
      battery_icon=""
      battery_color="$COLOR_BATTERY"
    else
      battery_icon=""
      battery_color="$COLOR_BATTERY"
    fi
    components+=("${battery_color}${battery_icon} ${battery_percent}%${COLOR_RESET}")
  fi
fi

# Add MCP servers count
mcp_count=0
if [ -f "$HOME/.claude.json" ] && command -v jq &> /dev/null; then
  mcp_count=$(jq '.mcpServers | length' "$HOME/.claude.json" 2>/dev/null)
  mcp_count=${mcp_count:-0}
fi
if [ "$mcp_count" -gt 0 ]; then
  line2_components+=("${COLOR_MCP}󰯲 ${mcp_count}${COLOR_RESET}")
fi

# Add hooks count
hooks_count=0
if command -v jq &> /dev/null; then
  global_hooks=$(jq '[.hooks // {} | to_entries[] | .value | length] | add // 0' "$HOME/.claude/settings.json" 2>/dev/null)
  hooks_count=$((hooks_count + ${global_hooks:-0}))
  if [ -n "$current_dir" ]; then
    proj_settings="$current_dir/.claude/settings.json"
    proj_local="$current_dir/.claude/settings.local.json"
    for sf in "$proj_settings" "$proj_local"; do
      if [ -f "$sf" ]; then
        ph=$(jq '[.hooks // {} | to_entries[] | .value | length] | add // 0' "$sf" 2>/dev/null)
        hooks_count=$((hooks_count + ${ph:-0}))
      fi
    done
  fi
fi
if [ "$hooks_count" -gt 0 ]; then
  line2_components+=("${COLOR_HOOKS}󰛢 ${hooks_count}${COLOR_RESET}")
else
  line2_components+=("${COLOR_HOOKS}󰛢 0${COLOR_RESET}")
fi

# Add Node.js version
node_info=""
if command -v node &> /dev/null; then
  node_version=$(node --version 2>/dev/null)
  if [ -n "$node_version" ]; then
    node_info="${COLOR_NODE}󰎙 ${node_version}${COLOR_RESET}"
  fi
fi

if [ -n "$node_info" ]; then
  components+=("$node_info")
fi

# Add directory path
if [ -n "$current_dir" ] && [ -d "$current_dir" ]; then
  if [[ "$current_dir" == "$HOME"* ]]; then
    display_path="~${current_dir#$HOME}"
  else
    display_path="$current_dir"
  fi
  components+=("${COLOR_DIR} ${display_path}${COLOR_RESET}")
fi

# Join components with separator
if [ ${#components[@]} -gt 0 ]; then
  status_line=$(printf "%s${COLOR_SEPARATOR} │ ${COLOR_RESET}" "${components[@]}")
  status_line="${status_line%${COLOR_SEPARATOR} │ ${COLOR_RESET}}"
fi

# Join line2 components
line2=""
if [ ${#line2_components[@]} -gt 0 ]; then
  line2=$(printf "%s${COLOR_SEPARATOR} │ ${COLOR_RESET}" "${line2_components[@]}")
  line2="${line2%${COLOR_SEPARATOR} │ ${COLOR_RESET}}"
fi

# Output the status line
if [ -n "$status_line" ]; then
  if [ -n "$line2" ]; then
    printf "%s\n%s" "$status_line" "$line2"
  else
    printf "%s" "$status_line"
  fi
else
  printf "Claude Code"
fi
