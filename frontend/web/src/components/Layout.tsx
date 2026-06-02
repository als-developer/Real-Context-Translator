import React from 'react';
import { Outlet, NavLink, useNavigate } from 'react-router-dom';
import { 
  LayoutDashboard, Languages, CreditCard, BarChart3, Bell, 
  LogOut, Settings, Globe, Sun, Moon, User 
} from 'lucide-react';
import { useAuth } from '../hooks/useAuth';

const navItems = [
  { path: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { path: '/translate', label: 'Translator', icon: Languages },
  { path: '/billing', label: 'Billing', icon: CreditCard },
  { path: '/analytics', label: 'Analytics', icon: BarChart3 },
  { path: '/alerts', label: 'Alerts', icon: Bell },
];

export const Layout: React.FC = () => {
  const { logout, user } = useAuth();
  const navigate = useNavigate();
  const [darkMode, setDarkMode] = React.useState(true);

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  return (
    <div className="min-h-screen bg-slate-950">
      {/* Sidebar */}
      <aside className="fixed left-0 top-0 h-full w-64 bg-slate-900 border-r border-slate-800 z-50">
        <div className="flex flex-col h-full">
          {/* Logo */}
          <div className="flex items-center gap-2 px-6 py-6 border-b border-slate-800">
            <div className="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center">
              <Globe className="w-4 h-4 text-white" />
            </div>
            <span className="text-white font-bold text-lg">RCT Engine</span>
          </div>
          
          {/* Navigation */}
          <nav className="flex-1 px-4 py-6 space-y-1">
            {navItems.map((item) => (
              <NavLink
                key={item.path}
                to={item.path}
                className={({ isActive }) =>
                  `flex items-center gap-3 px-4 py-3 rounded-lg transition-colors ${
                    isActive
                      ? 'bg-blue-600 text-white'
                      : 'text-slate-400 hover:bg-slate-800 hover:text-white'
                  }`
                }
              >
                <item.icon className="w-5 h-5" />
                <span>{item.label}</span>
              </NavLink>
            ))}
          </nav>
          
          {/* User Section */}
          <div className="border-t border-slate-800 p-4 space-y-3">
            <div className="flex items-center gap-3 px-2">
              <div className="w-8 h-8 bg-slate-700 rounded-full flex items-center justify-center">
                <User className="w-4 h-4 text-slate-400" />
              </div>
              <div className="flex-1">
                <p className="text-white text-sm font-medium">{user?.email || 'Admin User'}</p>
                <p className="text-slate-400 text-xs">Enterprise Plan</p>
              </div>
            </div>
            
            <div className="flex items-center justify-between px-2">
              <button
                onClick={() => setDarkMode(!darkMode)}
                className="p-2 hover:bg-slate-800 rounded-lg transition-colors"
              >
                {darkMode ? <Sun className="w-4 h-4 text-slate-400" /> : <Moon className="w-4 h-4 text-slate-400" />}
              </button>
              <button
                onClick={handleLogout}
                className="flex items-center gap-2 px-3 py-2 text-red-400 hover:bg-red-950 rounded-lg transition-colors text-sm"
              >
                <LogOut className="w-4 h-4" />
                Logout
              </button>
            </div>
          </div>
        </div>
      </aside>
      
      {/* Main Content */}
      <main className="ml-64">
        <Outlet />
      </main>
    </div>
  );
};
