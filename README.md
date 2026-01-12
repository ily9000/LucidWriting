# LucidWriting

LucidWriting is a small macOS menu bar app that helps you polish messages before you send them. It takes a quick screenshot of your current chat window, asks Claude AI to rewrite your draft, and gives you a cleaner version you can edit and copy.

## What it does (in plain language)

- **Makes your message clearer**: Rewrite a draft so it sounds more natural and professional.
- **Works in any app**: Use it with iMessage, Slack, Signal, email in a browser, and more.
- **You stay in control**: Edit the AI’s suggestion before you copy it.
- **Ask for a different tone**: Add instructions like “shorter,” “more polite,” or “more direct.”

## How it works (simple version)

1. You write a message in any app.
2. Press **Cmd + Shift + L**.
3. The app reads the on-screen context and asks Claude to refine your text.
4. You review, edit, and copy the result.

## Getting started

1. Open the project in Xcode and run it.
2. Click the LucidWriting icon in the menu bar.
3. Paste in your Claude API key.
4. When macOS asks for **Screen Recording** permission, allow it (needed to read on-screen text).

## Usage

1. Open any chat or email app.
2. Type your draft message.
3. Press **Cmd + Shift + L**.
4. Review the refined message.
5. Optionally add instructions and refine again.
6. Click **Copy to Clipboard** and paste it where you need it.

## Optional: Add your personal writing context

You can give the app more background about how you write by creating this file:

```
~/LucidWriting/UserContext.txt
```

Example:

```
Role: Product manager
Communication contexts:
- Customers
- Internal team
Tone preferences:
- Clear
- Friendly
- Direct
```

## Requirements

- macOS 13.0 or later
- A Claude API key from Anthropic
- Screen Recording permission

## License

MIT
