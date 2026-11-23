import {
  HideMode,
  HdsNavDestination,
  HdsNavDestinationTitleMode
} from '@kit.UIDesignKit';
import {
  AppBodyText,
  AppTypography,
  createAppTitleBarStyle,
  pageContentTop
} from 'anomiconbasic';
import { AboutPageContent } from './SettingsViewContracts';

@Builder
export function AboutPageBuilder(content: AboutPageContent) {
  AboutPage({
    content: content
  })
}

/** Device-independent About page; product identity is supplied by the product shell. */
@ComponentV2
export struct AboutPage {
  @Require @Param content: AboutPageContent;
  private scroller: Scroller = new Scroller();

  @Builder
  private infoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(AppTypography.BODY_L)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font'))
        .layoutWeight(1)
      Text(value)
        .fontSize(AppTypography.BODY_M)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .height(54)
    .padding({ left: 16, right: 16 })
  }

  @Builder
  private divider() {
    Divider()
      .strokeWidth(0.5)
      .color($r('sys.color.comp_divider'))
      .margin({ left: 16, right: 16 })
  }

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 20 }) {
          Column({ space: 8 }) {
            Image(this.content.appIcon)
              .width(84)
              .height(84)
              .borderRadius(22)
            Text(this.content.displayName)
              .fontSize(AppTypography.TITLE_M)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font'))
            Text(this.content.englishName)
              .fontSize(AppTypography.BODY_M)
              .fontColor($r('sys.color.font_secondary'))
          }
          .width('100%')
          .padding({ left: 28, right: 28, bottom: 20 })

          Column() {
            this.infoRow('应用名称', this.content.displayName)
            this.divider()
            this.infoRow('英文名称', this.content.englishName)
            this.divider()
            this.infoRow('版本', this.content.versionName)
          }
          .width('100%')
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(16)
          .clip(true)

          Column({ space: 8 }) {
            Text('非官方应用说明')
              .fontSize(AppTypography.SUBTITLE_M)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font'))
            AppBodyText({
              content: '格异录是一款非官方社区阅读应用，与 SCP Wiki 不存在隶属、合作或认可关系。应用内呈现的条目文本与模型素材均归各自创作者所有。',
              color: $r('sys.color.font_secondary')
            })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(20)
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(16)
        }
        .width('100%')
        .constraintSize({ maxWidth: 680 })
        .padding({ left: 16, right: 16, top: pageContentTop(), bottom: 32 })
      }
      .width('100%')
      .height('100%')
      .clip(false)
      .backgroundColor($r('sys.color.background_secondary'))
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Off)
    }
    .titleBar({
      avoidLayoutSafeArea: false,
      enableComponentSafeArea: false,
      content: {
        title: { mainTitle: `关于${this.content.displayName}` },
        backIcon: { label: '返回', componentId: 'aboutBackButton' }
      },
      style: createAppTitleBarStyle()
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .backgroundColor($r('sys.color.background_secondary'))
    .bindToScrollable([this.scroller])
    .dynamicHideTitleBar({
      hideTitleArea: true,
      hideStatusBar: false,
      mode: HideMode.SCROLL_UP,
      hideRatio: 1.5
    })
    .ignoreLayoutSafeArea(
      [LayoutSafeAreaType.SYSTEM],
      [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM]
    )
  }
}
