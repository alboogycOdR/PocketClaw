/// Facet Coach — the six axes the Life Architect can specialise into for
/// a session. Per SPEC-LifeArchitect-v1.0 §4. Pure enum; UI consumes the
/// `displayName`/`icon`/`triggerHint` getters for chips and tooltips.
library;

enum FacetCoach {
  fitness,
  health,
  mind,
  business,
  learning,
  habit;

  String get displayName => switch (this) {
        FacetCoach.fitness => 'Fitness & Movement',
        FacetCoach.health => 'Health & Bio',
        FacetCoach.mind => 'Mind & Emotional',
        FacetCoach.business => 'Business & Career',
        FacetCoach.learning => 'Learning & Growth',
        FacetCoach.habit => 'Habit & Discipline',
      };

  String get icon => switch (this) {
        FacetCoach.fitness => '💪',
        FacetCoach.health => '🩺',
        FacetCoach.mind => '🧠',
        FacetCoach.business => '💼',
        FacetCoach.learning => '📚',
        FacetCoach.habit => '⚡',
      };

  String get triggerHint => switch (this) {
        FacetCoach.fitness => 'Say: "fitness plan" or "workout help"',
        FacetCoach.health => 'Say: "nutrition advice" or "sleep"',
        FacetCoach.mind => 'Say: "mindset" or "stress"',
        FacetCoach.business => 'Say: "career strategy" or "productivity"',
        FacetCoach.learning => 'Say: "learning plan" or "reading list"',
        FacetCoach.habit => 'Say: "habit tracker" or "daily routine"',
      };
}
