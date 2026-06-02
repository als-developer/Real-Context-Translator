import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  ScrollView,
  TouchableOpacity,
  ActivityIndicator,
  Alert,
  Share,
} from 'react-native';
import { useMutation } from '@tanstack/react-query';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import { Picker } from '@react-native-picker/picker';
import { api } from '../services/api';

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

const COUNTRIES = [
  { code: 'KE', name: 'Kenya', flag: '🇰🇪' },
  { code: 'TZ', name: 'Tanzania', flag: '🇹🇿' },
  { code: 'SA', name: 'Saudi Arabia', flag: '🇸🇦' },
  { code: 'CN', name: 'China', flag: '🇨🇳' },
  { code: 'NG', name: 'Nigeria', flag: '🇳🇬' },
  { code: 'US', name: 'United States', flag: '🇺🇸' },
  { code: 'GB', name: 'United Kingdom', flag: '🇬🇧' },
  { code: 'FR', name: 'France', flag: '🇫🇷' },
  { code: 'DE', name: 'Germany', flag: '🇩🇪' },
  { code: 'JP', name: 'Japan', flag: '🇯🇵' },
];

export const TranslatorScreen: React.FC = () => {
  const [sourceText, setSourceText] = useState('');
  const [sourceLang, setSourceLang] = useState('sw');
  const [targetCountry, setTargetCountry] = useState('KE');
  const [targetLang, setTargetLang] = useState('en');
  const [industry, setIndustry] = useState('marketing');

  const mutation = useMutation<TranslationResponse, Error, any>({
    mutationFn: async (data) => {
      const response = await api.post('/translate', data);
      return response.data;
    },
    onSuccess: (data) => {
      if (data.cultural_intelligence.risk_matrix_rating === 'CRITICAL') {
        Alert.alert(
          '⚠️ Cultural Risk Detected',
          data.cultural_intelligence.cultural_explanation,
          [{ text: 'OK', style: 'destructive' }]
        );
      } else {
        // Haptic feedback for success
      }
    },
  });

  const handleShare = async () => {
    if (mutation.data?.adapted_text) {
      try {
        await Share.share({
          message: mutation.data.adapted_text,
          title: 'Translation Result',
        });
      } catch (error) {
        console.error('Share failed', error);
      }
    }
  };

  const getRiskColor = (risk: string) => {
    switch (risk) {
      case 'CRITICAL':
        return '#EF4444';
      case 'MEDIUM':
        return '#F59E0B';
      default:
        return '#10B981';
    }
  };

  return (
    <ScrollView style={styles.container} showsVerticalScrollIndicator={false}>
      <View style={styles.header}>
        <Text style={styles.title}>Cultural Translator</Text>
        <Text style={styles.subtitle}>AI-powered translation with context</Text>
      </View>

      {/* Language Selection */}
      <View style={styles.card}>
        <Text style={styles.label}>Source Language</Text>
        <View style={styles.pickerContainer}>
          <Picker
            selectedValue={sourceLang}
            onValueChange={setSourceLang}
            style={styles.picker}
            dropdownIconColor="#94A3B8"
          >
            <Picker.Item label="🇹🇿 Swahili" value="sw" />
            <Picker.Item label="🇬🇧 English" value="en" />
            <Picker.Item label="🇫🇷 French" value="fr" />
            <Picker.Item label="🇨🇳 Chinese" value="zh" />
            <Picker.Item label="🇸🇦 Arabic" value="ar" />
          </Picker>
        </View>
      </View>

      <View style={styles.card}>
        <Text style={styles.label}>Target Country</Text>
        <View style={styles.pickerContainer}>
          <Picker
            selectedValue={targetCountry}
            onValueChange={(value) => {
              setTargetCountry(value);
              const country = COUNTRIES.find(c => c.code === value);
              if (country?.code === 'SA') setTargetLang('ar');
              else if (country?.code === 'CN') setTargetLang('zh');
              else setTargetLang('en');
            }}
            style={styles.picker}
          >
            {COUNTRIES.map(country => (
              <Picker.Item
                key={country.code}
                label={`${country.flag} ${country.name}`}
                value={country.code}
              />
            ))}
          </Picker>
        </View>
      </View>

      <View style={styles.row}>
        <View style={[styles.card, styles.halfCard]}>
          <Text style={styles.label}>Target Language</Text>
          <View style={styles.pickerContainer}>
            <Picker
              selectedValue={targetLang}
              onValueChange={setTargetLang}
              style={styles.picker}
            >
              <Picker.Item label="English" value="en" />
              <Picker.Item label="Arabic" value="ar" />
              <Picker.Item label="Chinese" value="zh" />
              <Picker.Item label="French" value="fr" />
            </Picker>
          </View>
        </View>

        <View style={[styles.card, styles.halfCard]}>
          <Text style={styles.label}>Industry</Text>
          <View style={styles.pickerContainer}>
            <Picker
              selectedValue={industry}
              onValueChange={setIndustry}
              style={styles.picker}
            >
              <Picker.Item label="Marketing" value="marketing" />
              <Picker.Item label="Legal" value="legal" />
              <Picker.Item label="Medical" value="medical" />
              <Picker.Item label="Technical" value="technical" />
            </Picker>
          </View>
        </View>
      </View>

      {/* Text Input */}
      <View style={styles.card}>
        <Text style={styles.label}>Source Text</Text>
        <TextInput
          style={styles.textInput}
          multiline
          numberOfLines={6}
          placeholder="Enter text to translate with cultural awareness..."
          placeholderTextColor="#64748B"
          value={sourceText}
          onChangeText={setSourceText}
          textAlignVertical="top"
        />
      </View>

      {/* Translate Button */}
      <TouchableOpacity
        style={[styles.button, mutation.isPending && styles.buttonDisabled]}
        onPress={() => mutation.mutate({
          source_text: sourceText,
          source_language: sourceLang,
          target_country: targetCountry,
          target_language: targetLang,
          industry_vertical: industry,
        })}
        disabled={mutation.isPending || !sourceText.trim()}
      >
        {mutation.isPending ? (
          <ActivityIndicator color="#FFFFFF" />
        ) : (
          <>
            <Icon name="translate" size={20} color="#FFFFFF" />
            <Text style={styles.buttonText}>Translate with Cultural Context</Text>
          </>
        )}
      </TouchableOpacity>

      {/* Results */}
      {mutation.data && (
        <View style={styles.resultCard}>
          <View style={styles.resultHeader}>
            <Text style={styles.resultTitle}>Translation Result</Text>
            <TouchableOpacity onPress={handleShare}>
              <Icon name="share-variant" size={22} color="#94A3B8" />
            </TouchableOpacity>
          </View>

          {mutation.data.adapted_text ? (
            <Text style={styles.resultText}>{mutation.data.adapted_text}</Text>
          ) : (
            <Text style={styles.blockedText}>
              ⚠️ Translation blocked due to cultural sensitivity
            </Text>
          )}

          {/* Cultural Intelligence */}
          <View
            style={[
              styles.culturalCard,
              { borderLeftColor: getRiskColor(mutation.data.cultural_intelligence.risk_matrix_rating) },
            ]}
          >
            <View style={styles.culturalHeader}>
              <Icon name="earth" size={18} color="#94A3B8" />
              <Text style={styles.culturalTitle}>Cultural Intelligence</Text>
            </View>

            {mutation.data.cultural_intelligence.slang_detected.length > 0 && (
              <View style={styles.slangContainer}>
                <Text style={styles.slangLabel}>Slang Detected:</Text>
                <View style={styles.slangTags}>
                  {mutation.data.cultural_intelligence.slang_detected.map((slang, idx) => (
                    <View key={idx} style={styles.slangTag}>
                      <Text style={styles.slangTagText}>{slang}</Text>
                    </View>
                  ))}
                </View>
              </View>
            )}

            <View style={styles.riskRow}>
              <Text style={styles.riskLabel}>Risk Rating:</Text>
              <Text
                style={[
                  styles.riskValue,
                  { color: getRiskColor(mutation.data.cultural_intelligence.risk_matrix_rating) },
                ]}
              >
                {mutation.data.cultural_intelligence.risk_matrix_rating}
              </Text>
            </View>

            <Text style={styles.explanation}>
              {mutation.data.cultural_intelligence.cultural_explanation}
            </Text>

            {mutation.data.cultural_intelligence.recommended_action && (
              <View style={styles.recommendation}>
                <Icon name="lightbulb-outline" size={16} color="#F59E0B" />
                <Text style={styles.recommendationText}>
                  {mutation.data.cultural_intelligence.recommended_action}
                </Text>
              </View>
            )}

            <Text style={styles.latency}>
              Latency: {mutation.data.telemetry.latency_ms}ms
            </Text>
          </View>
        </View>
      )}
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0F172A',
    padding: 16,
  },
  header: {
    marginBottom: 20,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#F1F5F9',
  },
  subtitle: {
    fontSize: 14,
    color: '#94A3B8',
    marginTop: 4,
  },
  card: {
    backgroundColor: '#1E293B',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: '#334155',
  },
  halfCard: {
    flex: 1,
    marginHorizontal: 4,
  },
  row: {
    flexDirection: 'row',
    marginHorizontal: -4,
  },
  label: {
    fontSize: 14,
    fontWeight: '500',
    color: '#94A3B8',
    marginBottom: 8,
  },
  pickerContainer: {
    backgroundColor: '#0F172A',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#334155',
  },
  picker: {
    color: '#F1F5F9',
    height: 50,
  },
  textInput: {
    backgroundColor: '#0F172A',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#334155',
    padding: 12,
    color: '#F1F5F9',
    fontSize: 16,
    minHeight: 120,
    textAlignVertical: 'top',
  },
  button: {
    backgroundColor: '#3B82F6',
    borderRadius: 12,
    padding: 16,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    marginTop: 8,
    marginBottom: 20,
  },
  buttonDisabled: {
    backgroundColor: '#1E3A5F',
    opacity: 0.6,
  },
  buttonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
  resultCard: {
    backgroundColor: '#1E293B',
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
    borderColor: '#334155',
    marginBottom: 20,
  },
  resultHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  resultTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#F1F5F9',
  },
  resultText: {
    fontSize: 16,
    color: '#F1F5F9',
    lineHeight: 24,
    marginBottom: 16,
  },
  blockedText: {
    fontSize: 16,
    color: '#EF4444',
    textAlign: 'center',
    paddingVertical: 20,
  },
  culturalCard: {
    backgroundColor: '#0F172A',
    borderRadius: 8,
    padding: 12,
    borderLeftWidth: 3,
  },
  culturalHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: 12,
  },
  culturalTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#94A3B8',
  },
  slangContainer: {
    marginBottom: 12,
  },
  slangLabel: {
    fontSize: 12,
    color: '#64748B',
    marginBottom: 6,
  },
  slangTags: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 6,
  },
  slangTag: {
    backgroundColor: '#334155',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
  },
  slangTagText: {
    fontSize: 11,
    color: '#F1F5F9',
  },
  riskRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: 8,
  },
  riskLabel: {
    fontSize: 12,
    color: '#64748B',
  },
  riskValue: {
    fontSize: 14,
    fontWeight: 'bold',
  },
  explanation: {
    fontSize: 13,
    color: '#94A3B8',
    lineHeight: 18,
    marginBottom: 12,
  },
  recommendation: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: '#F59E0B20',
    padding: 10,
    borderRadius: 8,
    marginBottom: 8,
  },
  recommendationText: {
    fontSize: 12,
    color: '#F59E0B',
    flex: 1,
  },
  latency: {
    fontSize: 11,
    color: '#64748B',
    textAlign: 'right',
  },
});
