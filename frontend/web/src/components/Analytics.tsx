import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Download, TrendingUp, TrendingDown, Calendar, Filter } from 'lucide-react';
import { api } from '../services/api';
import {
  LineChart, Line, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer,
  AreaChart, Area, PieChart, Pie, Cell
} from 'recharts';

export const Analytics: React.FC = () => {
  const [days, setDays] = useState(30);
  const [country, setCountry] = useState('all');

  const { data: timeSeries } = useQuery({
    queryKey: ['time-series', days],
    queryFn: () => api.get(`/analytics/time-series?days=${days}`).then(res => res.data),
  });

  const { data: countryBreakdown } = useQuery({
    queryKey: ['country-breakdown'],
    queryFn: () => api.get('/analytics/country-breakdown').then(res => res.data),
  });

  const { data: topSlangs } = useQuery({
    queryKey: ['top-slangs', country],
    queryFn: () => api.get(`/analytics/top-slangs?country=${country}`).then(res => res.data),
  });

  const { data: exportUrl } = useQuery({
    queryKey: ['export-url', days],
    queryFn: () => api.get(`/analytics/export?days=${days}`).then(res => res.data),
    enabled: false,
  });

  const COLORS = ['#3B82F6', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6', '#EC4899'];

  const handleExport = async () => {
    const response = await api.get(`/analytics/export?days=${days}`, { responseType: 'blob' });
    const url = window.URL.createObjectURL(new Blob([response.data]));
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', `rct_analytics_${days}days.csv`);
    document.body.appendChild(link);
    link.click();
    link.remove();
  };

  return (
    <div className="p-6 max-w-7xl mx-auto space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Analytics & Insights</h1>
          <p className="text-slate-400 mt-1">Deep dive into your translation intelligence</p>
        </div>
        
        <div className="flex gap-3">
          <select
            value={days}
            onChange={(e) => setDays(Number(e.target.value))}
            className="bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-white text-sm"
          >
            <option value={7}>Last 7 days</option>
            <option value={30}>Last 30 days</option>
            <option value={90}>Last 90 days</option>
          </select>
          
          <button
            onClick={handleExport}
            className="flex items-center gap-2 px-4 py-2 bg-slate-800 hover:bg-slate-700 rounded-lg text-white transition-colors"
          >
            <Download className="w-4 h-4" />
            Export CSV
          </button>
        </div>
      </div>

      {/* Key Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        {timeSeries?.metrics && (
          <>
            <div className="bg-slate-900 rounded-xl border border-slate-800 p-4">
              <p className="text-slate-400 text-sm">Avg. Translation Latency</p>
              <p className="text-2xl font-bold text-white">{timeSeries.metrics.avgLatency}ms</p>
              <div className="flex items-center gap-1 mt-1">
                {timeSeries.metrics.latencyTrend > 0 ? (
                  <TrendingUp className="w-3 h-3 text-red-400" />
                ) : (
                  <TrendingDown className="w-3 h-3 text-green-400" />
                )}
                <span className={`text-xs ${timeSeries.metrics.latencyTrend > 0 ? 'text-red-400' : 'text-green-400'}`}>
                  {Math.abs(timeSeries.metrics.latencyTrend)}% from last period
                </span>
              </div>
            </div>
            
            <div className="bg-slate-900 rounded-xl border border-slate-800 p-4">
              <p className="text-slate-400 text-sm">Critical Block Rate</p>
              <p className="text-2xl font-bold text-white">{timeSeries.metrics.blockRate}%</p>
              <p className="text-xs text-slate-400 mt-1">{timeSeries.metrics.totalBlocks} total blocks</p>
            </div>
            
            <div className="bg-slate-900 rounded-xl border border-slate-800 p-4">
              <p className="text-slate-400 text-sm">Unique Slangs Detected</p>
              <p className="text-2xl font-bold text-white">{timeSeries.metrics.uniqueSlangs}</p>
              <p className="text-xs text-slate-400 mt-1">Across {timeSeries.metrics.activeCountries} countries</p>
            </div>
            
            <div className="bg-slate-900 rounded-xl border border-slate-800 p-4">
              <p className="text-slate-400 text-sm">Risk Prevention Savings</p>
              <p className="text-2xl font-bold text-white">${timeSeries.metrics.savingsK.toFixed(1)}K</p>
              <p className="text-xs text-green-400 mt-1">Estimated brand risk avoidance</p>
            </div>
          </>
        )}
      </div>

      {/* Time Series Chart */}
      <div className="bg-slate-900 rounded-xl border border-slate-800 p-6">
        <h3 className="text-white font-semibold mb-4">Translation Volume Over Time</h3>
        <ResponsiveContainer width="100%" height={400}>
          <AreaChart data={timeSeries?.daily}>
            <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
            <XAxis dataKey="date" stroke="#94A3B8" />
            <YAxis yAxisId="left" stroke="#94A3B8" />
            <YAxis yAxisId="right" orientation="right" stroke="#94A3B8" />
            <Tooltip
              contentStyle={{ backgroundColor: '#1E293B', border: '1px solid #334155' }}
              labelStyle={{ color: '#F1F5F9' }}
            />
            <Legend />
            <Area yAxisId="left" type="monotone" dataKey="translations" stroke="#3B82F6" fill="#3B82F6" fillOpacity={0.2} name="Translations" />
            <Area yAxisId="right" type="monotone" dataKey="words" stroke="#10B981" fill="#10B981" fillOpacity={0.2} name="Words (thousands)" />
          </AreaChart>
        </ResponsiveContainer>
      </div>

      {/* Two Column Layout */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Risk by Country */}
        <div className="bg-slate-900 rounded-xl border border-slate-800 p-6">
          <h3 className="text-white font-semibold mb-4">Risk Distribution by Country</h3>
          <ResponsiveContainer width="100%" height={300}>
            <PieChart>
              <Pie
                data={countryBreakdown}
                cx="50%"
                cy="50%"
                labelLine={false}
                label={(entry) => `${entry.country} (${entry.riskRate}%)`}
                outerRadius={100}
                dataKey="riskRate"
              >
                {countryBreakdown?.map((entry: any, index: number) => (
                  <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                ))}
              </Pie>
              <Tooltip />
            </PieChart>
          </ResponsiveContainer>
        </div>

        {/* Top Slangs */}
        <div className="bg-slate-900 rounded-xl border border-slate-800 p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-white font-semibold">Most Detected Slangs</h3>
            <select
              value={country}
              onChange={(e) => setCountry(e.target.value)}
              className="bg-slate-800 border border-slate-700 rounded-lg px-2 py-1 text-white text-xs"
            >
              <option value="all">All Countries</option>
              <option value="KE">Kenya</option>
              <option value="SA">Saudi Arabia</option>
              <option value="CN">China</option>
            </select>
          </div>
          
          <div className="space-y-3">
            {topSlangs?.map((slang: any, idx: number) => (
              <div key={idx}>
                <div className="flex items-center justify-between text-sm mb-1">
                  <span className="text-slate-300">{slang.term}</span>
                  <span className="text-slate-400">{slang.count} times</span>
                </div>
                <div className="w-full bg-slate-800 rounded-full h-2">
                  <div
                    className="bg-blue-600 rounded-full h-2"
                    style={{ width: `${(slang.count / topSlangs[0].count) * 100}%` }}
                  />
                </div>
                <p className="text-xs text-slate-500 mt-1">{slang.meaning}</p>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Latency Distribution */}
      <div className="bg-slate-900 rounded-xl border border-slate-800 p-6">
        <h3 className="text-white font-semibold mb-4">Latency Distribution (P50, P90, P99)</h3>
        <ResponsiveContainer width="100%" height={300}>
          <BarChart data={timeSeries?.latencyPercentiles}>
            <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
            <XAxis dataKey="name" stroke="#94A3B8" />
            <YAxis stroke="#94A3B8" label={{ value: 'Milliseconds', angle: -90, position: 'insideLeft', fill: '#94A3B8' }} />
            <Tooltip
              contentStyle={{ backgroundColor: '#1E293B', border: '1px solid #334155' }}
              labelStyle={{ color: '#F1F5F9' }}
            />
            <Bar dataKey="latency" fill="#8B5CF6" radius={[4, 4, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
};
