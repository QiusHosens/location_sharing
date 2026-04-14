import { createTheme } from '@mui/material/styles';

/** 与 Flutter 登录/设置页品牌色一致 */
export const brandBlue = '#1976D2';
export const pageBg = '#F3F4F6';

const theme = createTheme({
  palette: {
    primary: { main: brandBlue },
    secondary: { main: '#22C55E' },
    background: { default: pageBg, paper: '#FFFFFF' },
    text: { primary: '#111827', secondary: '#6B7280' },
  },
  shape: { borderRadius: 14 },
  typography: {
    fontFamily: '"Segoe UI", "PingFang SC", "Microsoft YaHei", "Helvetica Neue", Arial, sans-serif',
    h4: { fontWeight: 800, letterSpacing: -0.5 },
    h5: { fontWeight: 800 },
    h6: { fontWeight: 700 },
    button: { fontWeight: 600, textTransform: 'none' as const },
  },
  components: {
    MuiButton: {
      styleOverrides: {
        root: { borderRadius: 14, textTransform: 'none', fontWeight: 600 },
      },
    },
    MuiCard: {
      styleOverrides: {
        root: {
          borderRadius: 16,
          boxShadow: '0 2px 12px rgba(0,0,0,0.06)',
        },
      },
    },
    MuiTextField: {
      defaultProps: { variant: 'outlined', size: 'small' },
    },
    MuiBottomNavigation: {
      styleOverrides: {
        root: {
          borderTop: '1px solid',
          borderColor: 'rgba(0,0,0,0.08)',
          minHeight: 56,
        },
      },
    },
  },
});

export default theme;
