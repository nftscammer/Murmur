# A/B Testing Guide

## Goal

Run ≥ 30 rated sessions across varied contexts before hitting "Reveal" in Settings → Stats.

## Setup

1. Launch Whisperbar
2. Settings → General → enable **Blind A/B test mode**
3. Settings → Model → confirm Whisper model is downloaded (required for Whisper/Hybrid backends to be selected)

## Test Protocol

### Contexts to Cover (aim for ~10 sessions each)

**1. Code comments and technical text**
Dictate things like:
- "TODO: refactor this method to use async await and handle the error case properly"
- "Function takes an optional string parameter and returns a boolean"
- "Import Foundation, import SwiftUI, at-main struct App"

**2. Chat / casual messages**
- "Hey, are you free for a call around 3pm? I wanted to catch up about the project."
- "Thanks so much, that was really helpful. I'll follow up tomorrow."

**3. Long-form / email**
- Full sentences with proper nouns, dates, numbers
- "The meeting is scheduled for Thursday the 15th at 2:30 PM in conference room B"
- "Please send me the Q3 report by end of business Friday"

**4. Technical jargon**
- Domain-specific words your vocabulary uses
- Acronyms (API, WWDC, M4, SwiftUI)
- Names you commonly say

### Rating Guidelines

- **👍 Good**: Transcript is accurate, minimal corrections needed
- **👌 OK**: A few errors but understandable, minor corrections needed
- **👎 Bad**: Significant errors, wrong words, missing content

### What to Watch For

- Proper noun accuracy (names, product names)
- Punctuation behaviour
- Latency feel (perceived responsiveness)
- Accuracy on fast speech vs slow deliberate speech

## Interpreting Results

After 20+ rated sessions, click **"🏆 Reveal Winner"** in Stats.

**Score interpretation (1–3 scale):**
- 2.7+ = Excellent fit for your voice
- 2.3–2.7 = Good, acceptable
- < 2.3 = Suboptimal for your vocabulary

**Typical findings:**
- Apple excels at conversational speech and common phrases
- Whisper excels at technical terms, proper nouns, and unusual vocabulary
- Hybrid typically matches or beats both since it uses Whisper's final pass

## After Testing

1. Settings → Model → set your preferred Default Backend
2. Settings → General → turn off A/B mode
3. Your session data remains in the database for future reference

## Data Export

```bash
# From terminal
make export-sessions > ~/Desktop/whisperbar-results.csv

# Or from the app
Settings → Stats → "Export to CSV…"
```
