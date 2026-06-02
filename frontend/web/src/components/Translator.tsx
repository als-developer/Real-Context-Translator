import React, { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { Send, Copy, CheckCircle, AlertTriangle, Globe, X } from 'lucide-react';
import { api } from '../services/api';
import toast from 'react-hot-toast';

interface TranslationResponse {
  translation_id: string;
  adapted_text: string | null;
  cultural_intelligence: {
    slang_detected: string[];
    risk_matrix_rating: string;
    cultural_explanation: string;
    recommended_action?: string;
  };
  telemetry: {
    latency_ms: number;
  };
}

export const Translator: React.FC = () => {
  const [sourceText, setSourceText] = useState('');
  const [sourceLang, setSourceLang] = useState('sw');
  const [targetCountry, setTargetCountry] = useState('KE');
  const [targetLang, setTargetLang] = useState('en');
  const [industry, setIndustry] = useState('marketing');
  const [copied, setCopied] = useState(false);

  const mutation = useMutation<TranslationResponse, Error, any>({
    mutationFn: async (data) => {
      const response = await api.post('/translate', data);
      return response.data;
    },
    onSuccess: (data) => {
      if (data.cultural_intelligence.risk_matrix_rating === 'CRITICAL') {
        toast.error('Critical cultural risk detected! Translation blocked.');
      } else {
        toast.success('Translation completed successfully');
      }
    },
    onError: (error) => {
      toast.error('Translation failed: ' + error.message);
    },
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!sourceText.trim()) {
      toast.error('Please enter text to translate');
      return;
    }
    
    mutation.mutate({
      source_text: sourceText,
      source_language: sourceLang,
      target_country: targetCountry,
      target_language: targetLang,
      industry_vertical: industry,
    });
  };

  const handleCopy = () => {
    if (mutation.data?.adapted_text) {
      navigator.clipboard.writeText(mutation.data.adapted_text);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
      toast.success('Copied to clipboard');
    }
  };

  const getRiskColor = (risk: string) => {
    switch (risk) {
      case 'CRITICAL': return 'bg-red-900/50 border-red-500 text-red-300';
      case 'MEDIUM': return 'bg-yellow-900/50 border-yellow-500 text-yellow-300';
      default: return 'bg-green-900/50 border-green-500 text-green-300';
    }
  };

  const countries = [
    { code: 'KE', name: 'Kenya', languages: [{ code: 'sw', name: 'Swahili' }, { code: 'en', name: 'English' }] },
    { code: 'TZ', name: 'Tanzania', languages: [{ code: 'sw', name: 'Swahili' }] },
    { code: 'SA', name: 'Saudi Arabia', languages: [{ code: 'ar', name: 'Arabic' }] },
    { code: 'CN', name: 'China', languages: [{ code: 'zh', name: 'Chinese' }] },
    { code: 'NG', name: 'Nigeria', languages: [{ code: 'en-pcm', name: 'Pidgin English' }] },
    { code: 'US', name: 'United States', languages: [{ code: 'en', name: 'English' }] },
  ];

  const industries = [
    { value: 'marketing', label: 'Marketing & Advertising' },
    { value: 'legal', label: 'Legal & Contracts' },
    { value: 'medical', label: 'Medical & Healthcare' },
    { value: 'technical', label: 'Technical Documentation' },
    { value: 'diplomatic', label: 'Diplomatic & Official' },
  ];

  return (
    <div className="p-6 max-w-7xl mx-auto space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-white">Cultural Translator</h1>
        <p className="text-slate-400 mt-1">AI-powered translation with cultural context awareness</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Input Panel */}
        <div className="lg:col-span-2 space-y-6">
          <form onSubmit={handleSubmit} className="space-y-4">
            {/* Language Controls */}
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">Source Language</label>
                <select
                  value={sourceLang}
                  onChange={(e) => setSourceLang(e.target.value)}
                  className="w-full bg-slate-800 border border-slate-700 rounded-lg px-4 py-2 text-white focus:outline-none focus:border-blue-500"
                >
                  <option value="sw">Swahili</option>
                  <option value="en">English</option>
                  <option value="fr">French</option>
                  <option value="zh">Chinese</option>
                  <option value="ar">Arabic</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">Target Country</label>
                <select
                  value={targetCountry}
                  onChange={(e) => {
                    setTargetCountry(e.target.value);
                    const country = countries.find(c => c.code === e.target.value);
                    if (country?.languages[0]) {
                      setTargetLang(country.languages[0].code);
                    }
                  }}
                  className="w-full bg-slate-800 border border-slate-700 rounded-lg px-4 py-2 text-white focus:outline-none focus:border-blue-500"
                >
                  {countries.map(country => (
                    <option key={country.code} value={country.code}>{country.name}</option>
                  ))}
                </select>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">Target Language</label>
                <select
                  value={targetLang}
                  onChange={(e) => setTargetLang(e.target.value)}
                  className="w-full bg-slate-800 border border-slate-700 rounded-lg px-4 py-2 text-white focus:outline-none focus:border-blue-500"
                >
                  {countries.find(c => c.code === targetCountry)?.languages.map(lang => (
                    <option key={lang.code} value={lang.code}>{lang.name}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">Industry Context</label>
                <select
                  value={industry}
                  onChange={(e) => setIndustry(e.target.value)}
                  className="w-full bg-slate-800 border border-slate-700 rounded-lg px-4 py-2 text-white focus:outline-none focus:border-blue-500"
                >
                  {industries.map(ind => (
                    <option key={ind.value} value={ind.value}>{ind.label}</option>
                  ))}
                </select>
              </div>
            </div>

            {/* Text Input */}
            <div>
              <label className="block text-sm font-medium text-slate-300 mb-2">Source Text</label>
              <textarea
                value={sourceText}
                onChange={(e) => setSourceText(e.target.value)}
                rows={6}
                className="w-full bg-slate-800 border border-slate-700 rounded-lg px-4 py-3 text-white placeholder-slate-500 focus:outline-none focus:border-blue-500"
                placeholder="Enter text to translate with cultural awareness..."
              />
            </div>

            <button
              type="submit"
              disabled={mutation.isPending}
              className="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-blue-800 text-white font-semibold py-3 rounded-lg transition-colors flex items-center justify-center gap-2"
            >
              {mutation.isPending ? (
                <>Processing...</>
              ) : (
                <>
                  <Send className="w-4 h-4" />
                  Translate with Cultural Context
                </>
              )}
            </button>
          </form>
        </div>

        {/* Output Panel */}
        <div className="space-y-6">
          <div className="bg-slate-900 rounded-xl border border-slate-800 p-6">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-white font-semibold">Translation Result</h3>
              {mutation.data?.adapted_text && (
                <button
                  onClick={handleCopy}
                  className="text-slate-400 hover:text-white transition-colors"
                >
                  {copied ? <CheckCircle className="w-4 h-4 text-green-500" /> : <Copy className="w-4 h-4" />}
                </button>
              )}
            </div>

            {mutation.data?.adapted_text ? (
              <div className="p-4 bg-slate-800 rounded-lg">
                <p className="text-white whitespace-pre-wrap">{mutation.data.adapted_text}</p>
              </div>
            ) : (
              <div className="p-4 bg-slate-800 rounded-lg border border-dashed border-slate-600 text-center text-slate-400">
                Translation will appear here
              </div>
            )}
          </div>

          {/* Cultural Intelligence Panel */}
          {mutation.data?.cultural_intelligence && (
            <div className={`rounded-xl border p-6 ${getRiskColor(mutation.data.cultural_intelligence.risk_matrix_rating)}`}>
              <div className="flex items-center gap-2 mb-3">
                <Globe className="w-4 h-4" />
                <h3 className="font-semibold">Cultural Intelligence</h3>
              </div>
              
              <div className="space-y-3">
                {mutation.data.cultural_intelligence.slang_detected.length > 0 && (
                  <div>
                    <p className="text-sm opacity-80">Slang Detected:</p>
                    <div className="flex flex-wrap gap-2 mt-1">
                      {mutation.data.cultural_intelligence.slang_detected.map((slang, idx) => (
                        <span key={idx} className="px-2 py-1 bg-black/30 rounded text-xs">{slang}</span>
                      ))}
                    </div>
                  </div>
                )}
                
                <div>
                  <p className="text-sm opacity-80">Risk Rating:</p>
                  <p className="font-bold">{mutation.data.cultural_intelligence.risk_matrix_rating}</p>
                </div>
                
                <div>
                  <p className="text-sm opacity-80">Explanation:</p>
                  <p className="text-sm">{mutation.data.cultural_intelligence.cultural_explanation}</p>
                </div>
                
                {mutation.data.cultural_intelligence.recommended_action && (
                  <div className="mt-2 p-2 bg-black/30 rounded">
                    <p className="text-sm">💡 {mutation.data.cultural_intelligence.recommended_action}</p>
                  </div>
                )}
                
                <div className="text-xs opacity-60 pt-2">
                  Latency: {mutation.data.telemetry.latency_ms}ms
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
