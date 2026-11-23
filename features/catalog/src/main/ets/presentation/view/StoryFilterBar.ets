import { uiMaterial } from '@kit.ArkUI';
import { TaleFilterState } from '../TaleFilterState';
import {
  accentPillBackgroundColor,
  accentPillForegroundColor,
  AppTypography
} from 'anomiconbasic';

const ALPHABET: string[] = [
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'
];

/** 故事页标题栏筛选工具：即时搜索标题/路径，并按路径首字母收窄结果。 */
@ComponentV2
export struct StoryFilterBar {
  @Require @Param state: TaleFilterState;
  @Require @Param hapticEnabled: boolean;
  @Param materialEnabled: boolean = true;
  @Param onHaptic: ((enabled: boolean) => void) | undefined = undefined;
  private readonly letterScroller: Scroller = new Scroller();
  private readonly searchMaterial: uiMaterial.ImmersiveMaterial = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.THIN,
    applyShadow: false
  });
  private readonly chipMaterial: uiMaterial.ImmersiveMaterial = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.THIN,
    applyShadow: false,
    interactive: true
  });

  private selectLetter(value: string): void {
    if (this.state.letter === value) {
      return;
    }
    this.onHaptic?.(this.hapticEnabled);
    this.state.setLetter(value);
  }

  private isLetterSelected(value: string): boolean {
    return this.state.letter === value;
  }

  @Builder
  private letterItem(label: string, value: string) {
    Text(label)
      .fontSize(AppTypography.CAPTION_L)
      .fontWeight(this.isLetterSelected(value) ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.isLetterSelected(value) ?
        accentPillForegroundColor() : $r('sys.color.font_secondary'))
      .textAlign(TextAlign.Center)
      .constraintSize({ minWidth: value.length === 0 ? 48 : 30 })
      .height(30)
      .padding({ left: value.length === 0 ? 12 : 8, right: value.length === 0 ? 12 : 8 })
      .borderRadius(15)
      .backgroundColor(this.isLetterSelected(value) ?
        accentPillBackgroundColor() :
        (this.materialEnabled ? Color.Transparent : $r('sys.color.comp_background_tertiary')))
      .systemMaterial(!this.isLetterSelected(value) && this.materialEnabled ?
        this.chipMaterial : undefined)
      .onClick(() => this.selectLetter(value))
  }

  build() {
    Column({ space: 8 }) {
      Search({ placeholder: '搜索故事标题或别名', value: this.state.query })
        .height(40)
        .margin({ left: 16, right: 16 })
        .backgroundColor(this.materialEnabled ?
          Color.Transparent : $r('sys.color.comp_background_primary'))
        .systemMaterial(this.materialEnabled ? this.searchMaterial : undefined)
        .placeholderColor($r('sys.color.font_secondary'))
        .accessibilityText('搜索故事标题或别名')
        .onChange((value: string) => this.state.setQuery(value))

      Scroll(this.letterScroller) {
        Row({ space: 6 }) {
          this.letterItem('全部', '')
          ForEach(ALPHABET, (letter: string) => {
            this.letterItem(letter, letter)
          }, (letter: string) => letter)
        }
        .padding({ left: 16, right: 16 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .width('100%')
    }
    .width('100%')
  }
}
