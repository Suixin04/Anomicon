/**
 * Shared tactile press-feedback modifier for clickable cards and list rows.
 *
 * Callers must chain `.animation({ duration: 120, curve: Curve.FastOutSlowIn })`
 * directly after `.attributeModifier(...)` before layout modifiers such as
 * `.width` or `.padding`, because ArkUI forbids calling `animation` inside
 * `AttributeModifier` callbacks.
 */
export class PressFeedbackModifier implements AttributeModifier<CommonAttribute> {
  private readonly pressedScale: number;
  private readonly pressedOpacity: number;

  constructor(pressedScale: number = 0.985, pressedOpacity: number = 0.9) {
    this.pressedScale = pressedScale;
    this.pressedOpacity = pressedOpacity;
  }

  applyNormalAttribute(instance: CommonAttribute): void {
    instance.scale({ x: 1, y: 1 });
    instance.opacity(1);
  }

  applyPressedAttribute(instance: CommonAttribute): void {
    instance.scale({ x: this.pressedScale, y: this.pressedScale });
    instance.opacity(this.pressedOpacity);
  }
}

export const CARD_PRESS_MODIFIER: PressFeedbackModifier = new PressFeedbackModifier(0.982, 0.92);
export const ROW_PRESS_MODIFIER: PressFeedbackModifier = new PressFeedbackModifier(0.992, 0.82);
