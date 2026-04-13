import { create } from 'zustand';

interface AuthState {
  token: string | null;
  adminId: string | null;
  username: string | null;
  setAuth: (token: string, adminId: string, username: string) => void;
  logout: () => void;
  isAuthenticated: () => boolean;
}

export const useAuthStore = create<AuthState>((set, get) => ({
  token: localStorage.getItem('admin_token'),
  adminId: localStorage.getItem('admin_id'),
  username: localStorage.getItem('admin_username'),
  setAuth: (token, adminId, username) => {
    localStorage.setItem('admin_token', token);
    localStorage.setItem('admin_id', adminId);
    localStorage.setItem('admin_username', username);
    set({ token, adminId, username });
  },
  logout: () => {
    localStorage.removeItem('admin_token');
    localStorage.removeItem('admin_id');
    localStorage.removeItem('admin_username');
    set({ token: null, adminId: null, username: null });
  },
  isAuthenticated: () => !!get().token,
}));
