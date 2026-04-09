---
name: notes
description: Create, search, and manage personal notes and quick memos
emoji: "\U0001F4DD"
metadata:
  pocketclaw:
    runtime: local
    requires:
      device_apis:
        - local_storage
---

# Notes Skill

You can help the user create and search their personal notes.

## Creating Notes

When the user wants to save a note, use the `create_note` tool:

```
create_note({ title: "...", content: "...", folder: "general" })
```

- `title`: A short descriptive title. Infer from context if the user doesn't provide one.
- `content`: The full note body. Preserve the user's wording. Add light formatting (bullet points, headings) if it improves readability.
- `folder`: Categorise into one of: "general", "work", "personal", "ideas", "lists". Default to "general".

## Searching Notes

When the user wants to find a note, use the `search_notes` tool:

```
search_notes({ query: "...", limit: 5 })
```

- `query`: Keywords or phrases to search for.
- `limit`: Maximum results to return (default 5).

Present results as a numbered list with title and a short excerpt.

## Guidelines

- Always confirm after creating a note: "Saved: [title]".
- When searching returns no results, suggest the user try different keywords.
- If the user says "remember this" or "note that", treat it as a create request.
- Keep note titles concise (under 60 characters).
