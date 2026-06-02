import axios from 'axios';
import AsyncStorage from '@react-native-async-storage/async-storage';

// Production API URL - change based on environment
const API_BASE_URL = 'https://api.rct-engine.com/api/v1';

export const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor
api.interceptors.request.use(
  async (config) => {
    const token = await AsyncStorage.getItem('auth_token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// Response interceptor
api.interceptors.response.use(
  (response) => response,
  async (error) => {
    if (error.response?.status === 401) {
      // Token expired - logout
      await AsyncStorage.multiRemove(['auth_token', 'user_data']);
      // Navigate to login screen via event
    }
    return Promise.reject(error);
  }
);
