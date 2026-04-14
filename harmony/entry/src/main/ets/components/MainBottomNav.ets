import { router } from '@kit.ArkUI';
import { AppTheme } from '../common/AppTheme';

/** 与移动端 HomeShell 一致：地图、家庭、足迹、设置；选中态为蓝底圆角块 + 白字 */
@Component
export struct MainBottomNav {
  @Prop currentIndex: number = 0;

  build() {
    Row() {
      this.tabItem('🗺', '地图', 0, 'pages/MapPage')
      this.tabItem('👥', '家庭', 1, 'pages/FamilyPage')
      this.tabItem('👣', '足迹', 2, 'pages/TrajectoryPage')
      this.tabItem('⚙', '设置', 3, 'pages/SettingsPage')
    }
    .width('100%')
    .height(60)
    .padding({ left: 8, right: 8, bottom: 6, top: 4 })
    .justifyContent(FlexAlign.SpaceAround)
    .backgroundColor(Color.White)
    .borderWidth({ top: 1 })
    .borderColor(AppTheme.border)
  }

  @Builder
  tabItem(icon: string, label: string, index: number, url: string) {
    Column() {
      Column() {
        Text(icon)
          .fontSize(20)
          .fontColor(this.currentIndex === index ? Color.White : AppTheme.textSecondary)
        Text(label)
          .fontSize(11)
          .fontWeight(this.currentIndex === index ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(this.currentIndex === index ? Color.White : AppTheme.textSecondary)
          .margin({ top: 2 })
      }
      .padding({ left: 18, right: 18, top: 8, bottom: 8 })
      .borderRadius(16)
      .backgroundColor(this.currentIndex === index ? AppTheme.brandBlue : Color.Transparent)
    }
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      if (this.currentIndex !== index) {
        router.replaceUrl({ url: url });
      }
    })
  }
}
