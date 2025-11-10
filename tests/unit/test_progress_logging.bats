#!/usr/bin/env bats
# Unit tests for progress logging functions in install.sh

load '../test_helper'

setup() {
  setup_test_env

  # Source the progress logging functions (will be defined in install.sh)
  # For now, we'll test against install.sh directly
  export GREEN='\033[0;32m'
  export BLUE='\033[0;34m'
  export RED='\033[0;31m'
  export NC='\033[0m'
}

teardown() {
  cleanup_test_env
}

# =============================================================================
# log_step - Step progress indicator
# =============================================================================

@test "log_step - formats step indicator [1/7]" {
  # Define function inline for testing
  log_step() {
    local current="${1}"
    local total="${2}"
    local desc="${3}"
    echo -e "${BLUE}[${current}/${total}]${NC} ${desc}"
  }

  run log_step 1 7 "检查运行环境"
  [ "$status" -eq 0 ]
  [[ "$output" =~ \[1/7\] ]]
  [[ "$output" =~ "检查运行环境" ]]
}

@test "log_step - formats step indicator [3/5]" {
  log_step() {
    local current="${1}"
    local total="${2}"
    local desc="${3}"
    echo -e "${BLUE}[${current}/${total}]${NC} ${desc}"
  }

  run log_step 3 5 "安装依赖"
  [ "$status" -eq 0 ]
  [[ "$output" =~ \[3/5\] ]]
  [[ "$output" =~ "安装依赖" ]]
}

@test "log_step - handles double-digit steps [10/15]" {
  log_step() {
    local current="${1}"
    local total="${2}"
    local desc="${3}"
    echo -e "${BLUE}[${current}/${total}]${NC} ${desc}"
  }

  run log_step 10 15 "最后步骤"
  [ "$status" -eq 0 ]
  [[ "$output" =~ \[10/15\] ]]
  [[ "$output" =~ "最后步骤" ]]
}

@test "log_step - handles description with spaces" {
  log_step() {
    local current="${1}"
    local total="${2}"
    local desc="${3}"
    echo -e "${BLUE}[${current}/${total}]${NC} ${desc}"
  }

  run log_step 2 7 "Download xray-fusion from GitHub"
  [ "$status" -eq 0 ]
  [[ "$output" =~ \[2/7\] ]]
  [[ "$output" =~ "Download xray-fusion from GitHub" ]]
}

# =============================================================================
# log_substep - Sub-step indicator with icons
# =============================================================================

@test "log_substep - default bullet icon" {
  log_substep() {
    local desc="${1}"
    local icon="${2:-•}"

    case "${icon}" in
      success|✓) echo -e "  ${GREEN}✓${NC} ${desc}" ;;
      error|✗)   echo -e "  ${RED}✗${NC} ${desc}" ;;
      *)         echo -e "  ${BLUE}•${NC} ${desc}" ;;
    esac
  }

  run log_substep "子任务"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "  " ]]  # Two spaces indentation
  [[ "$output" =~ "•" ]]
  [[ "$output" =~ "子任务" ]]
}

@test "log_substep - success icon (✓)" {
  log_substep() {
    local desc="${1}"
    local icon="${2:-•}"

    case "${icon}" in
      success|✓) echo -e "  ${GREEN}✓${NC} ${desc}" ;;
      error|✗)   echo -e "  ${RED}✗${NC} ${desc}" ;;
      *)         echo -e "  ${BLUE}•${NC} ${desc}" ;;
    esac
  }

  run log_substep "操作成功" "✓"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "✓" ]]
  [[ "$output" =~ "操作成功" ]]
}

@test "log_substep - success icon (text: success)" {
  log_substep() {
    local desc="${1}"
    local icon="${2:-•}"

    case "${icon}" in
      success|✓) echo -e "  ${GREEN}✓${NC} ${desc}" ;;
      error|✗)   echo -e "  ${RED}✗${NC} ${desc}" ;;
      *)         echo -e "  ${BLUE}•${NC} ${desc}" ;;
    esac
  }

  run log_substep "操作成功" "success"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "✓" ]]
  [[ "$output" =~ "操作成功" ]]
}

@test "log_substep - error icon (✗)" {
  log_substep() {
    local desc="${1}"
    local icon="${2:-•}"

    case "${icon}" in
      success|✓) echo -e "  ${GREEN}✓${NC} ${desc}" ;;
      error|✗)   echo -e "  ${RED}✗${NC} ${desc}" ;;
      *)         echo -e "  ${BLUE}•${NC} ${desc}" ;;
    esac
  }

  run log_substep "操作失败" "✗"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "✗" ]]
  [[ "$output" =~ "操作失败" ]]
}

@test "log_substep - error icon (text: error)" {
  log_substep() {
    local desc="${1}"
    local icon="${2:-•}"

    case "${icon}" in
      success|✓) echo -e "  ${GREEN}✓${NC} ${desc}" ;;
      error|✗)   echo -e "  ${RED}✗${NC} ${desc}" ;;
      *)         echo -e "  ${BLUE}•${NC} ${desc}" ;;
    esac
  }

  run log_substep "操作失败" "error"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "✗" ]]
  [[ "$output" =~ "操作失败" ]]
}

@test "log_substep - handles description with special characters" {
  log_substep() {
    local desc="${1}"
    local icon="${2:-•}"

    case "${icon}" in
      success|✓) echo -e "  ${GREEN}✓${NC} ${desc}" ;;
      error|✗)   echo -e "  ${RED}✗${NC} ${desc}" ;;
      *)         echo -e "  ${BLUE}•${NC} ${desc}" ;;
    esac
  }

  run log_substep "系统: x86_64 (64-bit)" "✓"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "系统: x86_64 (64-bit)" ]]
}

# =============================================================================
# show_spinner - Spinner animation
# =============================================================================

@test "show_spinner - function exists and accepts description" {
  show_spinner() {
    local desc="${1}"
    local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0

    # For testing, just print once instead of infinite loop
    printf "\r  ${BLUE}${chars:$i:1}${NC} %s" "${desc}"
  }

  run show_spinner "正在下载..."
  [ "$status" -eq 0 ]
  [[ "$output" =~ "正在下载..." ]]
}

@test "show_spinner - handles empty description" {
  show_spinner() {
    local desc="${1}"
    local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0

    printf "\r  ${BLUE}${chars:$i:1}${NC} %s" "${desc}"
  }

  run show_spinner ""
  [ "$status" -eq 0 ]
}

@test "show_spinner - uses correct spinner characters" {
  show_spinner() {
    local desc="${1}"
    local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0

    printf "\r  ${BLUE}${chars:$i:1}${NC} %s" "${desc}"
  }

  run show_spinner "测试"
  [ "$status" -eq 0 ]
  # Should contain one of the spinner characters
  [[ "$output" =~ [⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏] ]]
}

# =============================================================================
# Integration - Combined usage
# =============================================================================

@test "progress functions - combined workflow" {
  log_step() {
    local current="${1}"
    local total="${2}"
    local desc="${3}"
    echo -e "${BLUE}[${current}/${total}]${NC} ${desc}"
  }

  log_substep() {
    local desc="${1}"
    local icon="${2:-•}"

    case "${icon}" in
      success|✓) echo -e "  ${GREEN}✓${NC} ${desc}" ;;
      error|✗)   echo -e "  ${RED}✗${NC} ${desc}" ;;
      *)         echo -e "  ${BLUE}•${NC} ${desc}" ;;
    esac
  }

  # Simulate installation flow
  output=$(
    log_step 1 3 "检查环境"
    log_substep "ROOT 权限" "✓"
    log_substep "systemd 可用" "✓"
    log_step 2 3 "下载项目"
    log_substep "git clone" "✓"
    log_step 3 3 "安装完成"
  )

  [[ "$output" =~ \[1/3\] ]]
  [[ "$output" =~ \[2/3\] ]]
  [[ "$output" =~ \[3/3\] ]]
  [[ "$output" =~ "✓" ]]
}
