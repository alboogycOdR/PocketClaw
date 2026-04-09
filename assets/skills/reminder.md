---
name: reminder
description: Set timed reminders, alarms, and follow-up notifications
emoji: "\U000023F0"
metadata:
  pocketclaw:
    runtime: local
    requires:
      device_apis:
        - notifications
---

# Reminder Skill

You can set reminders and timed notifications for the user.

## Usage

Use the `create_reminder` tool:

```
create_reminder({ title: "...", datetime: "2026-04-09T15:30:00" })
```

- `title`: A short description of what to remember (max 120 characters).
- `datetime`: An ISO 8601 datetime string for when the reminder should fire.

## Parsing User Input

Users express times in many ways. Convert them to absolute ISO 8601 datetimes:

| User says                        | Interpretation                                |
|----------------------------------|-----------------------------------------------|
| "in 5 minutes"                   | now + 5 minutes                               |
| "in an hour"                     | now + 60 minutes                              |
| "at 3pm"                         | today at 15:00 (or tomorrow if already past)  |
| "tomorrow morning"               | tomorrow at 08:00                             |
| "tomorrow at 14:00"              | tomorrow at 14:00                             |
| "next Monday at 9am"             | the coming Monday at 09:00                    |
| "in 2 hours and 30 minutes"      | now + 2h30m                                   |

When the time is ambiguous, make a reasonable assumption and tell the user:
"I've set the reminder for [datetime]. Let me know if you'd like to adjust it."

## Guidelines

- Always confirm the reminder was set, including the exact date and time.
- If the requested time is in the past, inform the user and ask for a new time.
- For recurring reminders, explain that single reminders are supported and suggest setting the next occurrence.
- Keep reminder titles actionable: prefer "Call dentist" over "Dentist".
- If the user says "remind me to..." extract the action as the title.
- If no time is given, ask: "When would you like to be reminded?"

## Examples

User: "Remind me to take my medication in 30 minutes"
Action: create_reminder({ title: "Take medication", datetime: "<now + 30min ISO>" })
Response: "Done! I'll remind you to take your medication at [time]."

User: "Set an alarm for 6am tomorrow"
Action: create_reminder({ title: "Alarm", datetime: "<tomorrow 06:00 ISO>" })
Response: "Reminder set for tomorrow at 06:00."
