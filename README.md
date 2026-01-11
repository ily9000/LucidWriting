# LucidWriting

A macOS menu bar app that uses Claude AI to refine your messages before you send them.

## Features

- **Global Hotkey (Cmd+Shift+L)**: Capture any messaging window and refine your draft
- **AI-Powered Refinement**: Uses Claude to analyze context and improve your message
- **Editable Results**: Edit the refined message before copying
- **Re-refine with Instructions**: Give Claude specific instructions like "make it shorter" or "more formal"
- **Screenshot History**: View past captures in the settings window
- **User Context**: Customize with your role and communication preferences

## Setup

1. Build and run the app in Xcode
2. Click the menu bar icon to open settings
3. Enter your Claude API key
4. Grant Screen Recording permission when prompted

## Usage

1. Open any messaging app (iMessage, Slack, Signal, Chrome, etc.)
2. Start typing your message
3. Press **Cmd+Shift+L**
4. Review the refined message, edit if needed
5. Optionally add instructions and re-refine
6. Click "Copy to Clipboard"
7. Paste into your message

## User Context

Create a file at `~/LucidWriting/UserContext.txt` with your context:

```
Role: Your title/role
Communication contexts:
- Who you communicate with
Tone preferences:
- Your preferred tone
```

## Requirements

- macOS 13.0+
- Claude API key from Anthropic
- Screen Recording permission

## License

MIT
