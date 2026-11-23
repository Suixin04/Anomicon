/** Shared object-class semantic colors. */
export function objectClassColor(objectClass: string): ResourceColor {
  const lower = objectClass.toLowerCase();
  if (lower.includes('keter')) {
    return $r('app.color.class_keter');
  }
  if (lower.includes('euclid')) {
    return $r('app.color.class_euclid');
  }
  if (lower.includes('safe')) {
    return $r('app.color.class_safe');
  }
  if (lower.includes('thaumiel')) {
    return $r('app.color.class_thaumiel');
  }
  return $r('sys.color.font_secondary');
}

/** Dual-theme translucent card surface so blurred cards never dissolve into #000000. */
export function materialCardSurfaceColor(materialEnabled: boolean): ResourceColor {
  return materialEnabled ?
    $r('app.color.material_card_surface') : $r('sys.color.comp_background_primary');
}

/** Dual-theme hairline border paired with translucent card surfaces. */
export function materialCardBorderColor(materialEnabled: boolean): ResourceColor {
  return materialEnabled ?
    $r('app.color.material_card_border') : $r('sys.color.comp_divider');
}

/** Dual-theme fallback background for recommendation card preview placeholders. */
export function recommendationFallbackBackgroundColor(): ResourceColor {
  return $r('app.color.recommendation_fallback_bg');
}

/** Dual-theme semantic foreground for informational status badges and action pills. */
export function badgeInfoForegroundColor(): ResourceColor {
  return $r('app.color.badge_info_fg');
}

/** Dual-theme semantic background for informational status badges and action pills. */
export function badgeInfoBackgroundColor(): ResourceColor {
  return $r('app.color.badge_info_bg');
}

/** Dual-theme semantic foreground for warning status badges and notices. */
export function badgeWarningForegroundColor(): ResourceColor {
  return $r('app.color.badge_warning_fg');
}

/** Dual-theme semantic background for warning status badges. */
export function badgeWarningBackgroundColor(): ResourceColor {
  return $r('app.color.badge_warning_bg');
}

/** Dual-theme semantic foreground for destructive/error badges and actions. */
export function badgeDangerForegroundColor(): ResourceColor {
  return $r('app.color.badge_danger_fg');
}

/** Dual-theme semantic background for destructive/error badges and actions. */
export function badgeDangerBackgroundColor(): ResourceColor {
  return $r('app.color.badge_danger_bg');
}

/** Dual-theme active accent pill background color. */
export function accentPillBackgroundColor(): ResourceColor {
  return $r('app.color.accent_pill_bg');
}

/** Dual-theme active accent pill foreground color. */
export function accentPillForegroundColor(): ResourceColor {
  return $r('app.color.accent_pill_fg');
}
