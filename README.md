# asm-agent

`asm-agent` is a personal learning project: an Apple Silicon assembly CLI that delegates AI API calls to standard Unix tools.

The assembly program owns the command entrypoint, argument handling, help output, executable-path lookup, and process launch. A small POSIX shell helper uses `curl` for HTTPS and `jq` for JSON.

## Requirements

- macOS on Apple Silicon
- Xcode Command Line Tools
- `curl`
- `jq`
- An OpenAI API key for real AI responses

## Build

```sh
npm run build
```

## Run

```sh
export OPENAI_API_KEY="your_api_key"
./bin/asm-agent "explain recursion in two sentences"
./bin/asm-agent "what was my previous question?"
```

You can override the model:

```sh
OPENAI_MODEL="gpt-5.4-mini" ./bin/asm-agent "give me one shell productivity tip"
```

Offline smoke test:

```sh
ASM_AGENT_MOCK_RESPONSE="offline helper ok" ./bin/asm-agent "hello"
```

Each real API response prints token usage when the API returns it:

```text
The answer appears here.

[tokens: 123]
```

Assistant responses and the interactive chat prompt are colored in a terminal. Disable color with:

```sh
NO_COLOR=1 asm-agent "hello"
ASM_AGENT_COLOR=never asm-agent chat
```

Configure colors with 6- or 8-digit hex values:

```sh
ASM_AGENT_PROMPT_COLOR=b84367fc asm-agent chat
ASM_AGENT_ASSISTANT_COLOR=00ffff asm-agent "hello"
```

Interactive chat:

```sh
./bin/asm-agent chat
```

Inside chat, type `/exit` or press return on an empty prompt to quit.

`asm-agent` remembers previous messages across separate commands by saving a local transcript at `~/.config/asm-agent/conversation.txt`.

```sh
asm-agent history
asm-agent reset
```

## Local Install

From this directory:

```sh
npm run build
npm link
asm-agent "what does argc mean?"
```

After publishing the repo to GitHub, another Apple Silicon Mac can install it directly:

```sh
npm install -g github:CherifD/asm-agent
asm-agent "what is a syscall?"
```

## What This Demonstrates

- macOS ARM64 assembly with C library calls
- CLI argument parsing in assembly
- Finding the executable path with `_NSGetExecutablePath`
- Launching another process with `execvp`
- Separating low-level CLI mechanics from API/network concerns
- A GitHub-ready project that can be demoed without publishing to npm

## Environment

| Variable | Purpose |
| --- | --- |
| `OPENAI_API_KEY` | API key used by the helper |
| `AI_API_KEY` | Alternate API key variable |
| `OPENAI_MODEL` | Optional model override |
| `OPENAI_BASE_URL` | Optional OpenAI-compatible base URL |
| `OPENAI_MAX_OUTPUT_TOKENS` | Optional response length cap |
| `ASM_AGENT_INSTRUCTIONS` | Optional assistant instructions |
| `ASM_AGENT_STATE` | Optional memory file path |
| `ASM_AGENT_MAX_HISTORY_LINES` | Optional max saved transcript lines |
| `ASM_AGENT_COLOR` | Set to `never` to disable color |
| `ASM_AGENT_PROMPT_COLOR` | Optional prompt/input color as hex |
| `ASM_AGENT_ASSISTANT_COLOR` | Optional assistant response color as hex |
| `ASM_AGENT_MOCK_RESPONSE` | Offline test response |
| `ASM_AGENT_MOCK_TOTAL_TOKENS` | Optional mock token count for tests |

## LinkedIn Summary

I built a macOS Apple Silicon CLI in assembly that connects to an AI helper. The assembly binary handles terminal UX and process launching, while standard Unix tools like `curl` and `jq` handle the API request and JSON response. It was a learning project focused on low-level systems programming, native CLI design, and practical AI integration.

## License

This project is open source and available under the MIT License.
