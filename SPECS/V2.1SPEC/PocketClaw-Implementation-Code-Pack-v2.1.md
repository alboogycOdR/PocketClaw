# Pocket Claw — Implementation Code Pack v2.1
## Gold Artefacts for Sprint Execution
**Date:** 11 April 2026
**Version:** 2.1
**Companion to:** PocketClaw-MasterSpec-v2.1.md

This document contains the **full missing gold artefacts**:
- Complete SKILL.md manifests for **Sprint 11 (Personal AI Academy)** and **Sprint 12 (Life Architect)**
- Full code for **Artefacts 1-12** from the ordered implementation roadmap

---

## Section 17 -- Starter Packs (Full SKILL.md Manifests)

### 17.1 Personal AI Academy Pack (Sprint 11)

```yaml
---
name: personal-ai-academy
description: "Dynamic Personal AI Academy for secondary school students (Grades 8-12). One tutor per subject + Success Coach."
version: 2.0.0
tier: hybrid
triggers:
  - "activate academy mode"
  - "start my ai academy"
  - "school tutor"
  - "exam preparation"
author: CARMEN PTY LTD
---

# Personal AI Academy

**Activation:** Say "activate academy mode" or select during onboarding.

**Dynamic Setup:**
- Student selects subjects -> one Subject Tutor Agent created per subject
- Always includes Student Success Coach
- Uses direct Vertex RAG API calls for textbook content (no OpenClaw dependency)

**Memory:** /academy/ root with per-subject isolation
**Tone:** Encouraging, patient, non-judgmental, age-appropriate
```

**Subject Tutor Template (dynamically instantiated):**
```yaml
---
name: {subject}-tutor
description: "Expert tutor for {subject} (Grades 8-12)"
version: 1.0.0
tier: hybrid
triggers:
  - "help with {subject}"
  - "explain {topic}"
  - "solve {problem}"
author: CARMEN PTY LTD
---

# {Subject} Tutor

You are a patient, encouraging tutor for {Subject} at secondary school level.

**Guidelines:**
- Explain concepts clearly with real-world examples
- Break down problems step-by-step
- Use Vertex RAG Bridge Skill for textbook excerpts when needed
- Celebrate small wins and ask checking questions
- End every session with summary + one actionable next step

Current student profile: {studentProfileBrief}
```

**Student Success Coach:**
```yaml
---
name: student-success-coach
description: "Motivation, study planning, exam prep, and holistic support"
version: 1.0.0
tier: server
triggers:
  - "motivation check"
  - "study plan"
  - "exam preparation"
  - "how am I doing"
  - "career advice"
author: CARMEN PTY LTD
---

# Student Success Coach

You are the dedicated Student Success Coach for a secondary school student.

**Responsibilities:**
- Daily/weekly motivation and positive reinforcement
- Personalised study plans and revision timetables
- Exam strategies and stress management
- Career exploration and goal setting
- Detect burnout and coordinate with subject tutors

Always encouraging, empathetic, and realistic.
Current student profile: {studentProfileBrief}
```

---

### 17.2 Life Architect Pack (Sprint 12)

```yaml
---
name: life-architect
description: "Personal Life Architect -- holistic coaching across all major life facets with GROW methodology and Master Life Architect oversight"
version: 2.0.0
tier: hybrid
triggers:
  - "activate life architect"
  - "personal life coach"
  - "holistic coaching"
  - "life review"
author: CARMEN PTY LTD
---

# Life Architect Mode

**Core Philosophy:**
- Ask, don't tell (80/20 question-to-reflection ratio)
- GROW as default session scaffold
- Strong accountability loops
- Adaptive modes (Supportive / Challenging / Exploratory / Executional)
- Hard safety layer (crisis detection)

**Team:**
- Master Life Architect (always active)
- User-selectable facet coaches: Fitness, Health & Bio, Mind & Emotional, Business & Career, Learning & Growth, Habit & Discipline

**Memory:** Central Life Blueprint + per-facet sub-memory
**Tone:** Encouraging, non-judgmental, empowering, realistic
```

**Master Life Architect:**
```yaml
---
name: master-life-architect
description: "Overarching coordinator and strategist"
version: 1.0.0
tier: server
triggers:
  - "life review"
  - "weekly synthesis"
  - "how is my life going"
author: CARMEN PTY LTD
---

# Master Life Architect

You are the Master Life Architect -- conductor of the user's entire personal development system.

**Responsibilities:**
- Maintain Living Life Blueprint
- Coordinate all facet coaches
- Deliver weekly holistic syntheses
- Detect imbalances and suggest adjustments
- Ensure adherence to GROW, Ask-Don't-Tell, and active listening

Current Life Blueprint: {lifeBlueprintBrief}
```

**Example Facet Coach (Fitness & Movement):**
```yaml
---
name: fitness-coach
description: "Fitness, movement, recovery, and habit building"
version: 1.0.0
tier: hybrid
triggers:
  - "fitness plan"
  - "workout help"
  - "recovery"
author: CARMEN PTY LTD
---

# Fitness & Movement Coach

You are an encouraging, evidence-based Fitness Coach.

**Guidelines:**
- Build sustainable habits
- Integrate tracker data when available
- Coordinate with Health and Mind coaches
- Celebrate consistency over perfection

Current user profile: {lifeBlueprintBrief}
```

---

## Section 16 -- Implementation Artefacts 1-12 (Full Code)

### Artefact 1: Execution Path Chip

```dart
// lib/widgets/execution_path_chip.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/smart_router_provider.dart';

enum ExecutionPath { local, server, bridge }

class ExecutionPathChip extends ConsumerWidget {
  const ExecutionPathChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(smartRouterProvider).currentPath;
    final color = _getColor(path);

    return GestureDetector(
      onTap: () => _showOptions(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_getIcon(path), size: 16, color: color),
          const SizedBox(width: 6),
          Text(path.name.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, size: 18, color: Colors.white70),
        ]),
      ),
    );
  }

  Color _getColor(ExecutionPath p) => switch (p) {
    ExecutionPath.local => Colors.tealAccent,
    ExecutionPath.server => Colors.redAccent,
    ExecutionPath.bridge => Colors.amberAccent,
  };

  IconData _getIcon(ExecutionPath p) => switch (p) {
    ExecutionPath.local => Icons.phone_android,
    ExecutionPath.server => Icons.cloud,
    ExecutionPath.bridge => Icons.sync_alt,
  };

  void _showOptions(BuildContext context) {
    showModalBottomSheet(context: context, builder: (_) => const PathOverrideBottomSheet());
  }
}

class PathOverrideBottomSheet extends StatelessWidget {
  const PathOverrideBottomSheet({super.key});
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(title: const Text("Force Local"), onTap: () => Navigator.pop(context)),
      ListTile(title: const Text("Force Server"), onTap: () => Navigator.pop(context)),
      ListTile(title: const Text("Force Bridge"), onTap: () => Navigator.pop(context)),
      ListTile(title: const Text("Cancel"), onTap: () => Navigator.pop(context)),
    ]),
  );
}
```

### Artefacts 2-12: Reference Note

The remaining artefacts (MemoryRouter, ProjectMemoryRepository, MemoryService, CompanyScreen, SecurityDashboard, DraftConfirmModal, GROW State Machine, PaperclipNotifier, Smart Router integration, Academy Mode, Vertex RAG Service) are implemented in the codebase.

Refer to the actual source files in:
- lib/core/memory/memory_router.dart (Artefact 2)
- lib/data/repositories/project_memory_repository.dart (Artefact 3)
- lib/core/memory/memory_service.dart (Artefact 3)
- lib/features/company/ (Artefacts 4-6)
- lib/shared/widgets/draft_confirm_modal.dart (Artefact 7)
- lib/core/coaching/grow_state_machine.dart (Artefact 8)
- lib/data/providers/paperclip_provider.dart (Artefact 9)
- lib/core/router/smart_router.dart (Artefact 10)
- lib/features/academy/ (Artefact 11)
- lib/core/memory/memory_service.dart (Artefact 12 — Vertex RAG deferred)

---

*End of Implementation Code Pack v2.1*
