import React from 'react';
import { useQuery } from '@tanstack/react-query';
import { AlertTriangle, Bell, CheckCircle, XCircle, Eye, Globe } from 'lucide-react';
import { api } from '../services/api';

interface Alert {
  id: string;
  timestamp: string;
  country: string;
  risk_level: string;
  source_text: string;
  detected_slang: string;
  recommended_action: string;
  resolved: boolean;
}

export const RiskAlert: React.FC = () => {
  const { data: alerts, refetch } = useQuery<Alert[]>({
    queryKey: ['alerts'],
    queryFn: () => api.get('/alerts/unresolved').then(res => res.data),
    refetchInterval: 30000,
  });

  const { data: stats } = useQuery({
    queryKey: ['alert-stats'],
    queryFn: () => api.get('/alerts/stats').then(res => res.data),
  });

  const handleResolve = async (alertId: string) => {
    await api.post(`/alerts/${alertId}/resolve`);
    refetch();
  };

  const getRiskBadge = (risk: string) => {
    switch (risk) {
      case 'CRITICAL':
        return <span className="px-2 py-1 bg-red-900/50 border border-red-500 text-red-300 text-xs rounded-full">CRITICAL</span>;
      case 'MEDIUM':
        return <span className="px-2 py-1 bg-yellow-900/50 border border-yellow-500 text-yellow-300 text-xs rounded-full">MEDIUM</span>;
      default:
        return <span className="px-2 py-1 bg-green-900/50 border border-green-500 text-green-300 text-xs rounded-full">LOW</span>;
    }
  };

  return (
    <div className="p-6 max-w-7xl mx-auto space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Risk Alerts</h1>
          <p className="text-slate-400 mt-1">Real-time cultural compliance monitoring</p>
        </div>
        <Bell className="w-5 h-5 text-slate-400" />
      </div>

      {/* Stats Summary */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-slate-900 rounded-xl border border-slate-800 p-4">
          <p className="text-slate-400 text-sm">Total Alerts (30d)</p>
          <p className="text-2xl font-bold text-white">{stats?.total || 0}</p>
        </div>
        <div className="bg-slate-900 rounded-xl border border-slate-800 p-4">
          <p className="text-slate-400 text-sm">Critical</p>
          <p className="text-2xl font-bold text-red-400">{stats?.critical || 0}</p>
        </div>
        <div className="bg-slate-900 rounded-xl border border-slate-800 p-4">
          <p className="text-slate-400 text-sm">Resolved</p>
          <p className="text-2xl font-bold text-green-400">{stats?.resolved || 0}</p>
        </div>
        <div className="bg-slate-900 rounded-xl border border-slate-800 p-4">
          <p className="text-slate-400 text-sm">Avg Response Time</p>
          <p className="text-2xl font-bold text-white">{stats?.avgResponseMinutes || 0}m</p>
        </div>
      </div>

      {/* Alerts List */}
      <div className="bg-slate-900 rounded-xl border border-slate-800 overflow-hidden">
        <div className="px-6 py-4 border-b border-slate-800">
          <h3 className="text-white font-semibold">Unresolved Alerts</h3>
        </div>
        
        <div className="divide-y divide-slate-800">
          {alerts?.length === 0 ? (
            <div className="p-12 text-center">
              <CheckCircle className="w-12 h-12 text-green-500 mx-auto mb-3" />
              <p className="text-slate-400">No unresolved alerts. All clear!</p>
            </div>
          ) : (
            alerts?.map((alert) => (
              <div key={alert.id} className="p-6 hover:bg-slate-800/50 transition-colors">
                <div className="flex items-start justify-between">
                  <div className="flex items-start gap-3">
                    <AlertTriangle className={`w-5 h-5 mt-0.5 ${alert.risk_level === 'CRITICAL' ? 'text-red-400' : alert.risk_level === 'MEDIUM' ? 'text-yellow-400' : 'text-blue-400'}`} />
                    <div>
                      <div className="flex items-center gap-3 mb-2">
                        {getRiskBadge(alert.risk_level)}
                        <div className="flex items-center gap-1 text-slate-400 text-xs">
                          <Globe className="w-3 h-3" />
                          {alert.country}
                        </div>
                        <span className="text-slate-500 text-xs">
                          {new Date(alert.timestamp).toLocaleString()}
                        </span>
                      </div>
                      
                      <p className="text-white text-sm mb-2">
                        Detected slang: <span className="font-mono text-yellow-400">"{alert.detected_slang}"</span>
                      </p>
                      
                      <p className="text-slate-400 text-sm mb-3">
                        Original: "{alert.source_text.substring(0, 100)}..."
                      </p>
                      
                      <div className="flex items-center gap-2">
                        <button
                          onClick={() => handleResolve(alert.id)}
                          className="flex items-center gap-1 px-3 py-1 bg-green-900/50 hover:bg-green-900 rounded text-green-300 text-xs transition-colors"
                        >
                          <CheckCircle className="w-3 h-3" />
                          Resolve
                        </button>
                        <button className="flex items-center gap-1 px-3 py-1 bg-slate-800 hover:bg-slate-700 rounded text-slate-300 text-xs transition-colors">
                          <Eye className="w-3 h-3" />
                          View Details
                        </button>
                      </div>
                    </div>
                  </div>
                  
                  <div className="max-w-xs bg-slate-800/50 rounded-lg p-3">
                    <p className="text-xs text-slate-400 mb-1">Recommended Action</p>
                    <p className="text-sm text-white">{alert.recommended_action}</p>
                  </div>
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
};
