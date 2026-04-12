---
name: vertex-rag-bridge
description: "Direct Vertex AI RAG bridge for textbook content retrieval"
version: 1.0.0
tier: bridge
triggers:
  - "lookup textbook"
  - "find in textbook"
  - "what does the textbook say"
  - "textbook reference"
author: Nuburo.DIGITAL (PTY) LTD
---

# Vertex RAG Bridge

Direct HTTPS call from Flutter app to Vertex AI RAG pipeline. Returns relevant textbook excerpts with page references.

## Architecture
- No OpenClaw/Paperclip dependency
- Direct API call from mobile app to user's Vertex AI endpoint
- API key stored in flutter_secure_storage
- Query format: { "query": question, "subject": subject, "topK": 3 }

## Usage
When a Subject Tutor needs curriculum-specific content:
1. Tutor identifies the need for textbook reference
2. Calls Vertex RAG Bridge with subject + question
3. Receives relevant excerpts with source references
4. Incorporates excerpts into the tutoring response

## Guidelines
- Always cite the source of retrieved content
- If no relevant content found, say so honestly
- Combine retrieved content with tutor's own explanations
- Use British English throughout
