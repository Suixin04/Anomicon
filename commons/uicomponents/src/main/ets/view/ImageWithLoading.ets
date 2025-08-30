// 带加载状态的图片组件
@ComponentV2
export struct ImageWithLoadingView {
  // 图片的URL，通过@Prop接收
  @Param @Require src: string;
  // 宽度，支持百分比或固定值
  @Param @Require imgWidth: string | number;
  // 高度，支持百分比或固定值
  @Param @Require imgHeight: string | number;
  // 图片圆角
  @Param imgRadius: BorderRadiuses = {
    topLeft: 0,
    topRight: 0,
    bottomLeft: 0,
    bottomRight: 0
  };
  // 图片填充模式
  @Param objectFit: ImageFit = ImageFit.Cover;
  // 加载状态，初始为true
  @Local private isLoading: boolean = true;
  // 加载失败状态
  @Local private isError: boolean = false;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 当图片加载中时显示加载动画
      if (this.isLoading) {
        LoadingProgress()
          .width(60)
          .height(60);
      }

      // 当图片加载失败时显示一个占位符
      if (!this.isLoading && this.isError) {
        Image($r('app.media.SCP_icon'))
          .width(this.imgWidth)
          .height(this.imgHeight)
          .borderRadius(this.imgRadius)
          .objectFit(ImageFit.Cover)
          .backgroundColor(Color.Gray);
      }

      // Image组件，绑定src并监听加载完成和失败事件
      Image(this.src)
        .width(this.imgWidth)
        .height(this.imgHeight)
        .borderRadius(this.imgRadius)
        .objectFit(this.objectFit)
        .onComplete(() => {
          this.isLoading = false;
        })
        .onError(() => {
          this.isLoading = false;
          this.isError = true;
          console.error('图片加载失败:', this.src);
        })
        // 在加载中或加载失败时，让图片完全透明
        .opacity(this.isLoading || this.isError ? 0 : 1);
    }
    .width(this.width)
    .height(this.height);
  }
}