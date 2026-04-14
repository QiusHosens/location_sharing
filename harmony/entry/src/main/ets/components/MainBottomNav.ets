import { router } from '@kit.ArkUI';
import { AppTheme } from '../common/AppTheme';

/** 与移动端 HomeShell 一致：地图、家庭、足迹、设置 */
@Component
export struct MainBottomNav {
  @Prop currentIndex: number = 0;

  build() {
    Row() {
      this.tabItem('地图', 0, 'pages/MapPage')
      this.tabItem('家庭', 1, 'pages/FamilyPage')
      this.tabItem('足迹', 2, 'pages/TrajectoryPage')
      this.tabItem('设置', 3, 'pages/SettingsPage')
    }
    .width('100%')
    .height(56)
    .padding({ bottom: 4 })
    .justifyContent(FlexAlign.SpaceAround)
    .backgroundColor(Color.White)
    .borderWidth({ top: 1 })
    .borderColor(AppTheme.border)
  }

  @Builder
  tabItem(label: string, index: number, url: string) {
    Column() {
      Text(label)
        .fontSize(12)
        .fontWeight(this.currentIndex === index ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.currentIndex === index ? AppTheme.brandBlue : AppTheme.textSecondary)
    }
    .width('25%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      if (this.currentIndex !== index) {
        router.replaceUrl({ url: url });
      }
    })
  }
}
