import React from 'react';
import { useQuery } from '@tanstack/react-query';
import { Activity, TrendingUp, AlertTriangle, DollarSign } from 'lucide-react';
import { api } from '../services/api';
import { LineChart, Line, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';

interface DashboardStats {
  totalTranslations: number;
  totalWords: number;
  criticalBlocks: number;
  avgLatencyMs: number;
  costSavedCents: number;
  trend: string;
}

interface DailyData {
  date: string;
  translations: number;
  words: number;
}

export const Dashboard: React.FC = () => {
  const { data: stats, isLoading: statsLoading } = useQuery<DashboardStats>({
    queryKey: ['dashboard-stats'],
    queryFn: () => api.get('/analytics/dashboard').then(res => res.data),
    refetchInterval: 30000,
  });

  const { data: dailyData } = useQuery<DailyData[]>({
    queryKey: ['daily-stats'],
    queryFn: () => api.get('/analytics/daily?days=7').then(res => res.data),
  });

  const { data: countryRisk } = useQuery({
    queryKey: ['country-risk'],
    queryFn: () => api.get('/analytics/risk-by-country').then(res => res.data),
  });

  const statsCards = [
    { title: 'Total Translations', value: stats?.totalTranslations?.toLocaleString() || '0', icon: Activity, color: 'bg-blue-500' },
    { title: 'Words Processed', value: stats?.totalWords?.toLocaleString() || '0', icon: TrendingUp, color: 'bg-green-500' },
    { title: 'Critical Blocks', value: stats?.criticalBlocks?.toString() || '0', icon: AlertTriangle, color: 'bg-red-500' },
    { title: 'Cost Saved', value: `$${((stats?.costSavedCents || 0) / 100).toFixed(2)}`, icon: DollarSign, color: 'bg-purple-500' },
  ];

  const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#8884d8'];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-white">Dashboard Overview</h1>
        <p className="text-slate-400 mt-1">Real-time cultural translation intelligence</p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {statsCards.map((card, idx) => (
          <div key={idx} className="bg-slate-900 rounded-xl border border-slate-800 p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-slate-400 text-sm">{card.title}</p>
                <p className="text-2xl font-bold text-white mt-1">{card.value}</p>
              </div>
              <div className={`${card.color} p-3 rounded-lg`}>
                <card.icon className="w-5 h-5 text-white" />
              </div>
            </div>
            {stats?.trend && (
              <p className="text-xs text-green-400 mt-3">{stats.trend}</p>
            )}
          </div>
        ))}
      </div>

      {/* Charts Row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Daily Translations Chart */}
        <div className="bg-slate-900 rounded-xl border border-slate-800 p-6">
          <h3 className="text-white font-semibold mb-4">Daily Translation Volume</h3>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={dailyData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
              <XAxis dataKey="date" stroke="#94A3B8" />
              <YAxis stroke="#94A3B8" />
              <Tooltip
                contentStyle={{ backgroundColor: '#1E293B', border: '1px solid #334155' }}
                labelStyle={{ color: '#F1F5F9' }}
              />
              <Legend />
              <Line type="monotone" dataKey="translations" stroke="#3B82F6" strokeWidth={2} dot={false} />
              <Line type="monotone" dataKey="words" stroke="#10B981" strokeWidth={2} dot={false} />
            </LineChart>
          </ResponsiveContainer>
        </div>

        {/* Country Risk Distribution */}
        <div className="bg-slate-900 rounded-xl border border-slate-800 p-6">
          <h3 className="text-white font-semibold mb-4">Risk Distribution by Country</h3>
          <ResponsiveContainer width="100%" height={300}>
            <PieChart>
              <Pie
                data={countryRisk}
                cx="50%"
                cy="50%"
                labelLine={false}
                label={(entry) => `${entry.country}: ${entry.riskRate}%`}
                outerRadius={100}
                fill="#8884d8"
                dataKey="riskRate"
              >
                {countryRisk?.map((entry: any, index: number) => (
                  <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                ))}
              </Pie>
              <Tooltip />
            </PieChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Recent Alerts */}
      <div className="bg-slate-900 rounded-xl border border-slate-800 p-6">
        <h3 className="text-white font-semibold mb-4">Recent Critical Alerts</h3>
        <div className="space-y-3">
          {[1, 2, 3].map((_, idx) => (
            <div key={idx} className="flex items-center justify-between p-3 bg-red-950/30 border border-red-800/50 rounded-lg">
              <div className="flex items-center gap-3">
                <AlertTriangle className="w-4 h-4 text-red-400" />
                <div>
                  <p className="text-sm text-white">High-risk slang detected for Saudi Arabia</p>
                  <p className="text-xs text-slate-400">2 minutes ago</p>
                </div>
              </div>
              <button className="text-xs text-red-400 hover:text-red-300">View Details</button>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};
