import { getMapConfig } from '@/api/config';

declare global {
  interface Window {
    AMap: any;
    _AMapSecurityConfig?: { securityJsCode: string };
  }
}

let loadPromise: Promise<void> | null = null;

/** 从后台拉取 Key/安全密钥后加载高德 JS API 2.0，全局仅加载一次 */
export function loadAmapScript(): Promise<void> {
  if (loadPromise) return loadPromise;
  if (typeof window !== 'undefined' && window.AMap) {
    return Promise.resolve();
  }
  loadPromise = (async () => {
    const cfg = await getMapConfig();
    const key = cfg.web_key?.trim();
    if (!key) {
      console.warn('amap_web_key 未配置，请在管理后台系统配置中填写');
    }
    if (cfg.web_security_secret) {
      window._AMapSecurityConfig = { securityJsCode: cfg.web_security_secret };
    }
    await new Promise<void>((resolve, reject) => {
      const script = document.createElement('script');
      script.src = `https://webapi.amap.com/maps?v=2.0&key=${encodeURIComponent(key || 'YOUR_AMAP_KEY')}`;
      script.async = true;
      script.onload = () => resolve();
      script.onerror = () => reject(new Error('高德地图脚本加载失败'));
      document.head.appendChild(script);
    });
  })();
  return loadPromise;
}
