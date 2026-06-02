export interface User {
  id: string;
  email: string;
  fullName: string;
  organizationId: string;
  role: 'admin' | 'enterprise' | 'developer' | 'viewer';
  apiKey: string;
  createdAt: Date;
}

export interface Organization {
  id: string;
  name: string;
  subscriptionTier: 'free' | 'pro' | 'enterprise';
  monthlyWordLimit: number;
  wordsUsedCurrentMonth: number;
  stripeCustomerId: string;
  isActive: boolean;
}

export interface TranslationRequest {
  sourceText: string;
  sourceLanguage: string;
  targetCountry: string;
  targetLanguage: string;
  industryVertical?: 'marketing' | 'legal' | 'medical' | 'technical' | 'diplomatic';
  preserveTone?: boolean;
  detectSlang?: boolean;
}

export interface TranslationResponse {
  translationId: string;
  adaptedText: string | null;
  culturalIntelligence: {
    slangDetected: string[];
    riskMatrixRating: 'LOW' | 'MEDIUM' | 'CRITICAL';
    culturalExplanation: string;
    recommendedAction?: string;
  };
  telemetry: {
    latencyMs: number;
  };
}

export interface BatchTranslationRequest {
  texts: TranslationRequest[];
  webhookUrl?: string;
}

export interface BatchTranslationResponse {
  batchId: string;
  status: 'processing' | 'completed' | 'failed';
  total: number;
  resultsUrl: string;
}

export interface DashboardStats {
  totalTranslations: number;
  totalWords: number;
  criticalBlocks: number;
  avgLatencyMs: number;
  costSavedCents: number;
  trend: string;
}

export interface BillingPlan {
  plan: string;
  monthlyLimit: number;
  wordsUsed: number;
  remaining: number;
  renewalDate: string;
}

export interface Alert {
  id: string;
  timestamp: string;
  country: string;
  riskLevel: string;
  sourceText: string;
  detectedSlang: string;
  recommendedAction: string;
  resolved: boolean;
}

export interface ApiError {
  error: string;
  code: string;
  details?: Record<string, unknown>;
}
