import { router } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';

@Entry
@Component
struct Index {
  aboutToAppear(): void {
    this.checkAuth();
  }

  async checkAuth(): Promise<void> {
    try {
      const store = await preferences.getPreferences(getContext(this), 'auth');
      const token = await store.get('token', '') as string;
      if (token) {
        router.replaceUrl({ url: 'pages/MapPage' });
      } else {
        router.replaceUrl({ url: 'pages/LoginPage' });
      }
    } catch (e) {
      router.replaceUrl({ url: 'pages/LoginPage' });
    }
  }

  build() {
    Column() {
      LoadingProgress().width(48).height(48)
      Text('定位共享').fontSize(20).margin({ top: 16 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
