import { create } from 'zustand';

interface AuthState {
  token: string | null;
  refreshToken: string | null;
  userId: string | null;
  phone: string | null;
  nickname: string | null;
  /** 登录/注册成功后写入 access + refresh */
  setAuth: (accessToken: string, refreshToken: string, userId: string, phone?: string) => void;
  setProfile: (nickname: string | null) => void;
  logout: () => void;
  isAuthenticated: () => boolean;
}

export const useAuthStore = create<AuthState>((set, get) => ({
  token: localStorage.getItem('token'),
  refreshToken: localStorage.getItem('refresh_token'),
  userId: localStorage.getItem('user_id'),
  phone: localStorage.getItem('phone'),
  nickname: localStorage.getItem('nickname'),
  setAuth: (accessToken, refreshToken, userId, phone) => {
    localStorage.setItem('token', accessToken);
    localStorage.setItem('refresh_token', refreshToken);
    localStorage.setItem('user_id', userId);
    if (phone) localStorage.setItem('phone', phone);
    set({
      token: accessToken,
      refreshToken,
      userId,
      phone: phone || get().phone,
    });
  },
  setProfile: (nickname) => {
    if (nickname) localStorage.setItem('nickname', nickname);
    set({ nickname });
  },
  logout: () => {
    localStorage.clear();
    set({ token: null, refreshToken: null, userId: null, phone: null, nickname: null });
  },
  isAuthenticated: () => !!get().token,
}));
