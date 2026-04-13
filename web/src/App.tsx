import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { useAuthStore } from '@/store/auth';
import AppLayout from '@/components/AppLayout';
import LoginPage from '@/pages/Login/index';
import MapPage from '@/pages/Map/index';
import FamilyPage from '@/pages/Family/index';
import SharingPage from '@/pages/Sharing/index';
import TrajectoryPage from '@/pages/Trajectory/index';
import NotificationsPage from '@/pages/Notifications/index';
import SettingsPage from '@/pages/Settings/index';

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated } = useAuthStore();
  return isAuthenticated() ? <>{children}</> : <Navigate to="/login" replace />;
}

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/" element={<ProtectedRoute><AppLayout /></ProtectedRoute>}>
          <Route index element={<MapPage />} />
          <Route path="family" element={<FamilyPage />} />
          <Route path="sharing" element={<SharingPage />} />
          <Route path="trajectory" element={<TrajectoryPage />} />
          <Route path="notifications" element={<NotificationsPage />} />
          <Route path="settings" element={<SettingsPage />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
