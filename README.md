# Limiter

macOS menu bar app that shows your Claude Code usage limits at a glance.

## Features

- Color-coded menu bar icon (green/yellow/red) based on current usage
- Session (daily) and weekly limits with progress bars
- Time until reset (countdown or day+time for >24h)
- Auto-refresh every 5 minutes
- Launch at login support
- Reads OAuth token from macOS Keychain (same as Claude Code)

## Requirements

- macOS 14+
- Xcode Command Line Tools (`xcode-select --install`)
- Claude Code with active Pro/Max subscription (authenticated via `claude auth login`)

## Install

```bash
git clone https://github.com/user/Limiter.git
cd Limiter
make install
```

This builds the app and copies it to `/Applications/Limiter.app`.

## Usage

The app runs as a menu bar icon. Click it to see your usage breakdown.

| Command | Description |
|---------|-------------|
| `make build` | Build the app |
| `make run` | Build and run locally |
| `make install` | Build and install to /Applications |
| `make uninstall` | Remove from /Applications |
| `make clean` | Remove build artifacts |

## How it works

Limiter calls the Anthropic OAuth usage API (`/api/oauth/usage`) using the same credentials that Claude Code stores in your macOS Keychain. No additional authentication needed.

## Uninstall

```bash
cd Limiter
make uninstall
```
