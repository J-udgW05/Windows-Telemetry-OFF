# Windows Telemetry OFF

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D4.svg)](https://microsoft.com)
[![Script](https://img.shields.io/badge/Language-Batch%20%2F%20CMD-4D5BCE.svg)](Windows-Telemetry-OFF.bat)
[![Architecture](https://img.shields.io/badge/Architecture-x64%20%7C%20ARM64-lightgrey.svg)]()

Interactive Batch utility that reduces background telemetry, diagnostic collection and advertising in Windows 10 and Windows 11.

Designed with system stability in mind: it does not remove core OS components, keeps Microsoft Store, winget and security updates working, records every previous value before changing it, and can put those exact values back.

## Key Features

- **Exact restore**: before every change the previous value is written to a state file, so Restore returns your settings rather than generic Windows defaults.
- **Two levels of enforcement**: Safe and Balanced write ordinary Windows settings, so the matching toggles in Settings stay usable. Pro additionally enforces group policies.
- **Telemetry and diagnostics**: minimum diagnostic level for your edition, no device name, no extra logs or dumps, plus a full upload block for Pro and Home editions (DiagTrack autologger, firewall rules, OneSettings, CEIP).
- **Ads and suggestions**: advertising ID, tailored experiences, Start menu and lock screen suggestions, Settings recommendations, Windows tips.
- **AI features**: Recall, Click to Do, Copilot, Notepad and Paint AI features, Microsoft Edge AI features.
- **Services and scheduled tasks**: DiagTrack, dmwappushservice, WerSvc, CEIP, Compatibility Appraiser, feedback and diagnostic tasks.
- **Application telemetry**: Office, .NET CLI and PowerShell 7.
- **Windows Update**: an optional mode that keeps security updates while blocking feature updates, optional and preview updates, driver updates and Microsoft Store auto-updates.
- **State audit** and **restore verification** with a summary and a log file.

## Configuration Profiles

| Feature / Setting | Safe | Balanced | Pro |
| :--- | :---: | :---: | :---: |
| Minimum diagnostic data level, no device name, no dumps | Yes | Yes | Yes |
| Advertising ID, tips, suggestions, silent app installs | Yes | Yes | Yes |
| Activity history and feedback requests | Yes | Yes | Yes |
| Bing web results, search highlights, search history | Yes | Yes | Yes |
| Widgets and news | Yes | Yes | Yes |
| PowerShell 7, Office and .NET telemetry | Yes | Yes | Yes |
| Group policy enforcement | No | No | Yes |
| DiagTrack and dmwappushservice services | No | Yes | Yes |
| CEIP, Appraiser and diagnostic scheduled tasks | No | Yes | Yes |
| Telemetry cache flush | No | Yes | Yes |
| Full diagnostic data upload block | No | No | Yes |
| Recall, Click to Do, Copilot | No | No | Yes |
| Windows Error Reporting | No | No | Yes |
| Input personalization and online speech | No | No | Yes |
| Microsoft Edge privacy policies | No | No | Yes |
| Location, camera and microphone for apps | No | No | Yes |
| Telemetry endpoints in the hosts file | No | No | Yes |

> [!NOTE]
> **Profile Recommendation**: **Safe** suits everyone and breaks nothing. **Balanced** is the practical choice. **Pro** is the strongest option; its confirmation screen lists every side effect before anything is applied.

## Custom Mode and Extra Options

Option **[8] Custom** lets you pick exactly what to apply — 22 independent groups, a switch for group policy enforcement, and two items that are never part of the profiles:

- **Windows Update: security updates only** — also available as option **[9]** and `/updates`. Pins the current Windows version, disables optional, preview and driver updates, other Microsoft product updates and Store auto-updates, while security updates, winget and the Store keep working.
- **Remove pre-installed apps** — removes 31 clearly optional apps (Clipchamp, Solitaire, Bing apps, Skype, Maps, Widgets and similar). Microsoft Store, App Installer (winget), Terminal, Photos, Calculator, Notepad, Paint, Camera and media codecs are never touched. This cannot be undone by Restore: apps come back only from Store or winget.

Press **[W]** in the Custom menu to save your selection to `Windows-Telemetry-OFF.cfg` and reuse it later with `/config`.

## System Requirements

- **Operating System**: Windows 10 (x64) or Windows 11 (x64 / ARM64).
- **Permissions**: Administrator privileges (the script prompts for elevation automatically).
- **Environment**: Standard Windows Command Processor (`cmd.exe`) with UTF-8 support (`chcp 65001`).

## Quick Start

1. Download `Windows-Telemetry-OFF.bat` from the repository.
2. Right-click it and run as **Administrator**.
3. Pick a profile or open Custom mode, review the confirmation screen and start.
4. Restart the computer after completion.

## Command-line Arguments

| Argument | Action |
| :--- | :--- |
| `/safe`, `/balanced`, `/pro` | Run a profile |
| `/updates` | Windows Update: security updates only |
| `/check` | Audit the current privacy state |
| `/restore` | Restore previous settings |
| `/flush` | Flush telemetry and error report cache |
| `/config FILE` | Apply a selection saved from the Custom menu |
| `/silent` | No prompts or pauses |
| `/en`, `/ru` | Interface language |

Exit codes: `0` — clean, `1` — warnings, `2` — errors.

```
Windows-Telemetry-OFF.bat /pro /silent /en
```

## Logging and State

- `Windows_Telemetry_OFF_Log.txt` — full log of every executed step and its result.
- `Windows_Telemetry_OFF_State.txt` — values captured before they were changed; used by Restore for an exact rollback and renamed to `.bak` once restored.

## Restoring Default Settings

1. Launch `Windows-Telemetry-OFF.bat`.
2. Select option **[5] Restore default settings**.
3. Confirm the operation.

Restore removes the policies and values applied by any version of this utility, returns services, scheduled tasks, the DiagTrack autologger, firewall rules and the hosts file to their previous state, and finishes with a verification pass. Where a state file exists, the exact previous values are put back; otherwise Windows defaults are used.

> [!IMPORTANT]
> Major Windows feature updates can reset group policies back to default values. Use option **[4] Check current state** after such updates.

> [!NOTE]
> Since KB5034765 Windows guards the Widgets and News policy keys against `reg.exe`, `cmd.exe` and `powershell.exe`, so no Batch script can write them. The utility reports this instead of failing silently: switch Widgets off in Settings / Personalization / Taskbar, or remove the Widgets app from the app removal list.

## Disclaimer

Modifications to registry keys, services and scheduled tasks are made at your own risk. A System Restore point is created before every run, and creating your own backup beforehand is still recommended.

## License

Distributed under the [MIT License](LICENSE).
