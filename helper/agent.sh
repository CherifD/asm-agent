#!/bin/sh

default_model="gpt-5.4-mini"
default_instructions="You are a concise terminal assistant. Answer directly, avoid markdown tables unless useful, and keep responses practical."
state_file="${ASM_AGENT_STATE:-$HOME/.config/asm-agent/conversation.txt}"

use_color() {
  [ -t 1 ] || return 1
  [ "${NO_COLOR:-}" ] && return 1
  [ "${ASM_AGENT_COLOR:-auto}" = "never" ] && return 1
  return 0
}

color_sequence() {
  color="${1#\#}"
  fallback="$2"

  case "$color" in
    ??????|????????) ;;
    *) color="$fallback" ;;
  esac

  case "$color" in
    *[!0123456789abcdefABCDEF]*) color="$fallback" ;;
  esac

  red="$(printf '%d' "0x$(printf '%.2s' "$color")")"
  rest="${color#??}"
  green="$(printf '%d' "0x$(printf '%.2s' "$rest")")"
  rest="${rest#??}"
  blue="$(printf '%d' "0x$(printf '%.2s' "$rest")")"

  printf '\033[38;2;%s;%s;%sm' "$red" "$green" "$blue"
}

assistant_color() {
  color_sequence "${ASM_AGENT_ASSISTANT_COLOR:-00ffff}" "00ffff"
}

prompt_color() {
  color_sequence "${ASM_AGENT_PROMPT_COLOR:-b84367fc}" "b84367"
}

fail() {
  printf 'asm-agent: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

state_dir() {
  dirname "$state_file"
}

ensure_state_dir() {
  mkdir -p "$(state_dir)" || fail "Could not create memory directory: $(state_dir)"
}

read_memory() {
  if [ -s "$state_file" ]; then
    cat "$state_file"
  fi
}

trim_memory() {
  max_lines="${ASM_AGENT_MAX_HISTORY_LINES:-240}"
  case "$max_lines" in
    ''|*[!0-9]*) max_lines=240 ;;
  esac

  tmp_file="$(mktemp "${TMPDIR:-/tmp}/asm-agent-memory.XXXXXX")" || fail "Could not create memory temp file"
  tail -n "$max_lines" "$state_file" > "$tmp_file" 2>/dev/null || true
  mv "$tmp_file" "$state_file" || fail "Could not update memory file"
}

save_exchange() {
  transcript="$1"
  answer="$2"

  ensure_state_dir
  {
    printf '%s\n\n' "$transcript"
    printf 'Assistant: %s\n\n' "$answer"
  } > "$state_file" || fail "Could not write memory file: $state_file"

  trim_memory
}

build_transcript() {
  message="$1"
  existing="$(read_memory)"

  if [ "$existing" ]; then
    printf '%s\n\nUser: %s' "$existing" "$message"
  else
    printf 'User: %s' "$message"
  fi
}

ask_agent() {
  input_text="$1"

  if [ "${ASM_AGENT_MOCK_RESPONSE:-}" ]; then
    if [ "${ASM_AGENT_TOKEN_FILE:-}" ] && [ "${ASM_AGENT_MOCK_TOTAL_TOKENS:-}" ]; then
      printf '%s\n' "$ASM_AGENT_MOCK_TOTAL_TOKENS" > "$ASM_AGENT_TOKEN_FILE"
    fi
    printf '%s\n' "$ASM_AGENT_MOCK_RESPONSE"
    return 0
  fi

  require_command curl
  require_command jq

  api_key="${OPENAI_API_KEY:-${AI_API_KEY:-}}"
  [ "$api_key" ] || fail "Missing OPENAI_API_KEY. Set it before calling the AI helper."

  model="${OPENAI_MODEL:-$default_model}"
  base_url="${OPENAI_BASE_URL:-https://api.openai.com/v1}"
  base_url="${base_url%/}"
  instructions="${ASM_AGENT_INSTRUCTIONS:-$default_instructions}"
  max_output_tokens="${OPENAI_MAX_OUTPUT_TOKENS:-800}"

  case "$max_output_tokens" in
    ''|*[!0-9]*) fail "OPENAI_MAX_OUTPUT_TOKENS must be a positive integer." ;;
  esac

  request_file="$(mktemp "${TMPDIR:-/tmp}/asm-agent-request.XXXXXX")" || fail "Could not create request temp file"
  response_file="$(mktemp "${TMPDIR:-/tmp}/asm-agent-response.XXXXXX")" || fail "Could not create response temp file"

  if ! jq -n \
    --arg model "$model" \
    --arg instructions "$instructions" \
    --arg input "$input_text" \
    --argjson max_output_tokens "$max_output_tokens" \
    '{model: $model, instructions: $instructions, input: $input, max_output_tokens: $max_output_tokens}' \
    > "$request_file"; then
    rm -f "$request_file" "$response_file"
    fail "Could not build JSON request."
  fi

  if ! status_code="$(curl -sS -o "$response_file" -w '%{http_code}' \
    "$base_url/responses" \
    -H "Authorization: Bearer $api_key" \
    -H "Content-Type: application/json" \
    --data-binary "@$request_file")"; then
    rm -f "$request_file" "$response_file"
    fail "OpenAI request failed before receiving a response."
  fi

  rm -f "$request_file"

  case "$status_code" in
    2*) ;;
    *)
      error_message="$(jq -r '.error.message // .message // empty' "$response_file" 2>/dev/null)"
      [ "$error_message" ] || error_message="$(cat "$response_file" 2>/dev/null)"
      rm -f "$response_file"
      fail "OpenAI request failed ($status_code): $error_message"
      ;;
  esac

  answer="$(jq -r '
    if (.output_text // "") != "" then
      .output_text
    else
      ([.output[]? | select(.type == "message") | .content[]? | select(.type == "output_text") | .text] | join("\n"))
    end
  ' "$response_file" 2>/dev/null)"

  total_tokens="$(jq -r '.usage.total_tokens // empty' "$response_file" 2>/dev/null)"
  if [ "${ASM_AGENT_TOKEN_FILE:-}" ] && [ "$total_tokens" ]; then
    printf '%s\n' "$total_tokens" > "$ASM_AGENT_TOKEN_FILE"
  fi

  rm -f "$response_file"

  [ "$answer" ] && [ "$answer" != "null" ] || fail "OpenAI response did not include text output."
  printf '%s\n' "$answer"
}

print_response() {
  answer="$1"
  token_file="$2"

  if use_color; then
    printf '%s%s\033[0m\n' "$(assistant_color)" "$answer"
  else
    printf '%s\n' "$answer"
  fi

  if [ -s "$token_file" ]; then
    if use_color; then
      printf '\n\033[2m[tokens: %s]\033[0m\n' "$(cat "$token_file")"
    else
      printf '\n[tokens: %s]\n' "$(cat "$token_file")"
    fi
  fi
}

run_prompt() {
  prompt="$*"
  [ "$prompt" ] || fail "No prompt provided. Try: asm-agent \"explain pointers simply\""

  transcript="$(build_transcript "$prompt")"
  token_file="$(mktemp "${TMPDIR:-/tmp}/asm-agent-tokens.XXXXXX")" || fail "Could not create token temp file"
  export ASM_AGENT_TOKEN_FILE="$token_file"
  answer="$(ask_agent "$transcript")" || exit 1
  save_exchange "$transcript" "$answer"
  print_response "$answer" "$token_file"
  rm -f "$token_file"
}

run_chat() {
  printf 'asm-agent chat. Type /exit to quit.\n'

  while :; do
    if use_color; then
      printf '%s> ' "$(prompt_color)"
    else
      printf '> '
    fi
    IFS= read -r message || {
      use_color && printf '\033[0m'
      break
    }
    use_color && printf '\033[0m'
    [ "$message" ] || break

    case "$message" in
      /exit|/quit) break ;;
    esac

    transcript="$(build_transcript "$message")"
    token_file="$(mktemp "${TMPDIR:-/tmp}/asm-agent-tokens.XXXXXX")" || fail "Could not create token temp file"
    export ASM_AGENT_TOKEN_FILE="$token_file"
    answer="$(ask_agent "$transcript")" || exit 1
    save_exchange "$transcript" "$answer"
    print_response "$answer" "$token_file"
    rm -f "$token_file"
  done
}

case "${1:-}" in
  reset)
    ensure_state_dir
    : > "$state_file" || fail "Could not reset memory file: $state_file"
    printf 'asm-agent memory reset.\n'
    ;;
  history)
    if [ -s "$state_file" ]; then
      cat "$state_file"
    else
      printf 'asm-agent memory is empty.\n'
    fi
    ;;
  chat)
    shift
    run_chat
    ;;
  *)
    run_prompt "$@"
    ;;
esac
