import { create } from 'zustand';

interface AuthState {
  token: string | null;
  userId: string | null;
  phone: string | null;
  nickname: string | null;
  setAuth: (token: string, userId: string, phone?: string) => void;
  setProfile: (nickname: string | null) => void;
  logout: () => void;
  isAuthenticated: () => boolean;
}

export const useAuthStore = create<AuthState>((set, get) => ({
  token: localStorage.getItem('token'),
  userId: localStorage.getItem('user_id'),
  phone: localStorage.getItem('phone'),
  nickname: localStorage.getItem('nickname'),
  setAuth: (token, userId, phone) => {
    localStorage.setItem('token', token);
    localStorage.setItem('user_id', userId);
    if (phone) localStorage.setItem('phone', phone);
    set({ token, userId, phone: phone || get().phone });
  },
  setProfile: (nickname) => {
    if (nickname) localStorage.setItem('nickname', nickname);
    set({ nickname });
  },
  logout: () => {
    localStorage.clear();
    set({ token: null, userId: null, phone: null, nickname: null });
  },
  isAuthenticated: () => !!get().token,
}));
