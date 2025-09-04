import { AppStorageV2 } from '@kit.ArkUI'
import { Title } from 'uicomponents';
import { FontSizeData, FontSizeManager, FontSizeViewModel, VibrationUtils } from 'utils';
import CommonConstants from 'utils/src/main/ets/constants/CommonConstants';
import { bundleManager } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';

/**
 * 设置页面组件 - 显示应用信息和版权声明
 * 包含应用版本、数据来源、开发者信息等内容
 */
@ComponentV2
export struct Settings {
  @Local fontSizeData: FontSizeData =
    AppStorageV2.connect(FontSizeData, 'globalFontSize', () => new FontSizeData(CommonConstants.SET_SIZE_NORMAL))!
  @Local isInitialized: boolean = false
  @Local versionInfo: string = "获取版本中...";
  /** 滚动控制器 */
  private scroller: Scroller = new Scroller()

  async aboutToAppear(): Promise<void> {
    // 初始化字体大小管理器
    await FontSizeManager.initialize(getContext(this));
    // 获取字体大小数据对象
    this.fontSizeData = FontSizeManager.getFontSizeData()!;
    this.isInitialized = true;
    try {
      const bundleInfo = await bundleManager.getBundleInfoForSelf(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      );
      this.versionInfo = bundleInfo.versionName; // 获取版本名称，如 "1.0.0"
    } catch (error) {
      console.error('获取版本号失败:', (error as BusinessError).message);
    }
  }

  build() {
    Column() {
      Title({ str: "设置", scroller: this.scroller })

      Scroll(this.scroller) {
        Column({ space: 20 }) {

          Column({ space: 15 }) {
            Row({ space: 10 }) {
              Image($r("app.media.type"))
                .width(18)
              Text('字体大小设置')
                .fontSize(FontSizeManager.getScaledFontSize(16))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .width('100%')
                .textAlign(TextAlign.Start)
            }

            Column({ space: 10 }) {
              Text('预览文本')
                .fontSize(this.fontSizeData.fontSize)
                .fontColor($r('app.color.text_primary'))
                .width('100%')
                .textAlign(TextAlign.Start)

              Text(`当前字体大小: ${FontSizeViewModel.getFontSizeDescription(this.fontSizeData.fontSize)} (${this.fontSizeData.fontSize}px)`)
                .fontSize(FontSizeManager.getScaledFontSize(12))
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
                .textAlign(TextAlign.Start)
            }
            .width('100%')
            .padding({
              left: 15,
              right: 15,
              top: 10,
              bottom: 10
            })
            .backgroundColor($r('app.color.border_secondary'))
            .borderRadius(8)

            if (this.isInitialized) {
              Column({ space: 10 }) {
                Row() {
                  Text('小')
                    .fontSize(FontSizeManager.getScaledFontSize(12))
                    .fontColor($r('app.color.text_secondary'))
                  Blank()
                  Text('大')
                    .fontSize(FontSizeManager.getScaledFontSize(12))
                    .fontColor($r('app.color.text_secondary'))
                }
                .width('100%')

                Slider({
                  value: this.fontSizeData.fontSize,
                  min: CommonConstants.SET_SLIDER_MIN,
                  max: CommonConstants.SET_SLIDER_MAX,
                  step: CommonConstants.SET_SLIDER_STEP,
                  style: SliderStyle.OutSet
                })
                  .blockColor($r('app.color.text_primary'))
                  .trackColor($r('app.color.border_secondary'))
                  .selectedColor($r('app.color.text_primary'))
                  .showSteps(true)
                  .showTips(false)
                  .onChange((value: number) => {
                    VibrationUtils.lightTap()
                    this.onFontSizeChange(value);
                  })
              }
              .width('100%')
            }
          }
          .border({ width: 0.5, color: $r('app.color.border_primary'), radius: 10 })
          .width('100%')
          .backgroundColor($r('app.color.background_secondary'))
          .justifyContent(FlexAlign.Start)
          .padding(25)

          Column({ space: 15 }) {
            Row({ space: 10 }) {
              // 信息图标
              Image($r("app.media.circle_alert"))
                .width(18)
              // .fillColor($r('app.color.text_secondary'))
              // .border({ width: 1, color: $r('app.color.border_primary'), radius: 9 })
              // 关于应用标题文本
              Text('关于应用')
                .fontSize(FontSizeManager.getScaledFontSize(16))
                .fontColor($r('app.color.text_primary'))
                .fontWeight(FontWeight.Bold)
            }
            .width('100%')
            .margin({ bottom: 10 })

            Row() {
              // 版本标签文本
              Text('应用版本:')
                .fontColor($r('app.color.text_secondary'))
                .fontSize(FontSizeManager.getScaledFontSize(14))
              // 动态版本号显示
              Text(this.versionInfo)
                .fontColor($r('app.color.text_primary'))
                .fontSize(FontSizeManager.getScaledFontSize(14))
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)

            Row() {
              // 数据来源标签文本
              Text('数据来源:')
                .fontColor($r('app.color.text_secondary'))
                .fontSize(FontSizeManager.getScaledFontSize(14))
              // 官方数据来源名称
              Text('SCP基金会 Wiki')
                .fontColor($r('app.color.text_primary'))
                .fontSize(FontSizeManager.getScaledFontSize(14))
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)

            Row() {
              // 开发者标签文本
              Text('开发者')
                .fontColor($r('app.color.text_secondary'))
                .fontSize(FontSizeManager.getScaledFontSize(14))
              // 开发者名称显示
              Text('祟芯')
                .fontColor($r('app.color.text_primary'))
                .fontSize(FontSizeManager.getScaledFontSize(14))
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
            .border({ width: { bottom: 0.5 }, color: $r('app.color.border_primary') })
            .padding({ bottom: 10 })

            Row() {
              Text() {
                Span('本应用所有SCP内容均来自')
                Span('SCP基金会官方Wiki')
                  .fontColor('#007AFF')
                  .decoration({ type: TextDecorationType.Underline })
                  .onClick(() => {
                    const context = getContext(this) as common.UIAbilityContext;
                    context.openLink('https://scp-wiki-cn.wikidot.com').catch((error: BusinessError) => {
                      console.error('Failed to open link:', error.message);
                    });
                  })
                Span('， 遵循创作共用协议 (')
                Span('CC BY-SA 3.0')
                  .fontColor('#007AFF')
                  .decoration({ type: TextDecorationType.Underline })
                  .onClick(() => {
                    const context = getContext(this) as common.UIAbilityContext;
                    context.openLink('https://creativecommons.org/licenses/by-sa/3.0/deed.en#ref-appropriate-credit').catch((error: BusinessError) => {
                      console.error('Failed to open link:', error.message);
                    });
                  })
                Span(')。 SCP基金会是一个创作共同体项目。（将来为符合应用市场审核要求，部分内容可能会被修改。如若修改将给出明确说明)')
              }
                .fontSize(FontSizeManager.getScaledFontSize(12))
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.JUSTIFY)
            }
            .width('100%')
          }
          .border({ width: 0.5, color: $r('app.color.border_primary'), radius: 10 })
          .width('100%')
          .backgroundColor($r('app.color.background_secondary'))
          .justifyContent(FlexAlign.Start)
          .padding(25)
        }
        .padding({ left: 25, right: 25, bottom: 35 })
        .width('100%')
      }
      .edgeEffect(EdgeEffect.Spring)
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .width('100%')
    }
    .height('100%')
    .width('100%')
  }

  /**
   * 处理字体大小变化
   */
  private onFontSizeChange = (value: number) => {
    FontSizeManager.updateFontSize(value);
  }
}