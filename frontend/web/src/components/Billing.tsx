import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { CreditCard, Zap, Building, Check, Loader2 } from 'lucide-react';
import { api } from '../services/api';

const plans = [
  {
    id: 'free',
    name: 'Free',
    price: 0,
    priceLabel: 'Free',
    features: ['10,000 words/month', 'Basic translation', 'Community support', '7-day history'],
    limitations: ['No cultural context', 'No slang detection', 'No API access'],
    color: 'slate',
  },
  {
    id: 'pro',
    name: 'Professional',
    price: 49,
    priceLabel: '$49',
    features: ['500,000 words/month', 'Cultural context AI', 'Slang detection', 'Email support', '30-day history', 'Analytics dashboard', 'API access'],
    limitations: [],
    color: 'blue',
    popular: true,
  },
  {
    id: 'enterprise',
    name: 'Enterprise',
    price: 199,
    priceLabel: '$199',
    features: ['5,000,000+ words/month', 'Custom AI training', 'SLA guarantee', 'Dedicated support', 'SSO integration', 'Unlimited history', 'Custom integrations', 'Compliance reporting'],
    limitations: [],
    color: 'purple',
  },
];

export const Billing: React.FC = () => {
  const [selectedPlan, setSelectedPlan] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const { data: currentPlan, refetch } = useQuery({
    queryKey: ['current-plan'],
    queryFn: () => api.get('/billing/plan').then(res => res.data),
  });

  const { data: usage } = useQuery({
    queryKey: ['usage-stats'],
    queryFn: () => api.get('/billing/usage').then(res => res.data),
  });

  const handleSubscribe = async (planId: string) => {
    setLoading(true);
    setSelectedPlan(planId);
    try {
      await api.post('/billing/subscribe', { plan_id: planId });
      await refetch();
      alert(`Successfully subscribed to ${planId} plan!`);
    } catch (error) {
      alert('Subscription failed. Please try again.');
    } finally {
      setLoading(false);
      setSelectedPlan(null);
    }
  };

  const usagePercentage = usage ? (usage.words_used / usage.monthly_limit) * 100 : 0;

  return (
    <div className="p-6 max-w-7xl mx-auto space-y-8">
      <div>
        <h1 className="text-2xl font-bold text-white">Billing & Subscription</h1>
        <p className="text-slate-400 mt-1">Manage your plan and view usage analytics</p>
      </div>

      {/* Current Usage */}
      {currentPlan && usage && (
        <div className="bg-slate-900 rounded-xl border border-slate-800 p-6">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h3 className="text-white font-semibold">Current Usage</h3>
              <p className="text-sm text-slate-400">
                {usage.words_used.toLocaleString()} / {usage.monthly_limit.toLocaleString()} words
              </p>
            </div>
            <div className="px-3 py-1 bg-blue-900/50 border border-blue-500 rounded-full">
              <span className="text-blue-300 text-sm font-medium">{currentPlan.plan}</span>
            </div>
          </div>
          
          <div className="w-full bg-slate-800 rounded-full h-3">
            <div
              className="bg-blue-600 rounded-full h-3 transition-all"
              style={{ width: `${Math.min(usagePercentage, 100)}%` }}
            />
          </div>
          
          <div className="mt-4 text-sm text-slate-400">
            Renews on {new Date(usage.renewal_date).toLocaleDateString()}
          </div>
        </div>
      )}

      {/* Plans Grid */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {plans.map((plan) => (
          <div
            key={plan.id}
            className={`relative bg-slate-900 rounded-xl border transition-all ${
              plan.popular ? 'border-blue-500 shadow-lg shadow-blue-500/10' : 'border-slate-800'
            }`}
          >
            {plan.popular && (
              <div className="absolute -top-3 left-1/2 transform -translate-x-1/2 px-3 py-1 bg-blue-600 text-white text-xs font-bold rounded-full">
                MOST POPULAR
              </div>
            )}
            
            <div className="p-6">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <h3 className="text-xl font-bold text-white">{plan.name}</h3>
                  <p className="text-3xl font-bold text-white mt-2">
                    {plan.priceLabel}
                    {plan.price > 0 && <span className="text-sm text-slate-400 font-normal">/month</span>}
                  </p>
                </div>
                <div className={`p-3 rounded-lg bg-${plan.color}-900/30`}>
                  {plan.id === 'free' ? <Building className="w-6 h-6 text-slate-400" /> : <Zap className={`w-6 h-6 text-${plan.color}-400`} />}
                </div>
              </div>
              
              <div className="space-y-3 mt-6">
                {plan.features.map((feature, idx) => (
                  <div key={idx} className="flex items-center gap-2">
                    <Check className="w-4 h-4 text-green-500" />
                    <span className="text-sm text-slate-300">{feature}</span>
                  </div>
                ))}
                {plan.limitations.map((limitation, idx) => (
                  <div key={idx} className="flex items-center gap-2 opacity-50">
                    <X className="w-4 h-4 text-red-400" />
                    <span className="text-sm text-slate-400 line-through">{limitation}</span>
                  </div>
                ))}
              </div>
              
              <button
                onClick={() => handleSubscribe(plan.id)}
                disabled={loading || currentPlan?.plan === plan.name}
                className={`w-full mt-8 py-2 rounded-lg font-semibold transition-colors ${
                  currentPlan?.plan === plan.name
                    ? 'bg-green-900 text-green-300 cursor-default'
                    : plan.id === 'free'
                    ? 'bg-slate-700 hover:bg-slate-600 text-white'
                    : `bg-${plan.color}-600 hover:bg-${plan.color}-700 text-white`
                }`}
              >
                {loading && selectedPlan === plan.id ? (
                  <Loader2 className="w-4 h-4 animate-spin mx-auto" />
                ) : currentPlan?.plan === plan.name ? (
                  'Current Plan'
                ) : plan.price === 0 ? (
                  'Downgrade'
                ) : (
                  'Upgrade'
                )}
              </button>
            </div>
          </div>
        ))}
      </div>

      {/* Payment Methods */}
      <div className="bg-slate-900 rounded-xl border border-slate-800 p-6">
        <div className="flex items-center gap-2 mb-4">
          <CreditCard className="w-5 h-5 text-blue-400" />
          <h3 className="text-white font-semibold">Payment Methods</h3>
        </div>
        
        <div className="flex items-center justify-between p-4 bg-slate-800 rounded-lg">
          <div className="flex items-center gap-3">
            <div className="w-12 h-8 bg-white rounded flex items-center justify-center">
              <span className="text-black font-bold text-xs">VISA</span>
            </div>
            <div>
              <p className="text-white text-sm">•••• 4242</p>
              <p className="text-slate-400 text-xs">Expires 12/2028</p>
            </div>
          </div>
          <button className="text-blue-400 text-sm hover:text-blue-300">Update</button>
        </div>
        
        <button className="w-full mt-4 py-2 border border-dashed border-slate-600 rounded-lg text-slate-400 hover:text-white hover:border-slate-400 transition-colors">
          + Add Payment Method
        </button>
      </div>
    </div>
  );
};
