import React, { createContext, useState, useContext, useEffect } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { api } from '../services/api';
import ReactNativeBiometrics from 'react-native-biometrics';

interface User {
  id: string;
  email: string;
  name: string;
  organization: string;
  plan: string;
}

interface AuthContextType {
  isAuthenticated: boolean;
  user: User | null;
  isLoading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  enableBiometric: () => Promise<boolean>;
  biometricAvailable: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [biometricAvailable, setBiometricAvailable] = useState(false);

  useEffect(() => {
    checkAuth();
    checkBiometric();
  }, []);

  const checkAuth = async () => {
    try {
      const token = await AsyncStorage.getItem('auth_token');
      const userData = await AsyncStorage.getItem('user_data');
      
      if (token && userData) {
        api.defaults.headers.common['Authorization'] = `Bearer ${token}`;
        setUser(JSON.parse(userData));
        setIsAuthenticated(true);
      }
    } catch (error) {
      console.error('Auth check failed', error);
    } finally {
      setIsLoading(false);
    }
  };

  const checkBiometric = async () => {
    const rnBiometrics = new ReactNativeBiometrics();
    const { available } = await rnBiometrics.isSensorAvailable();
    setBiometricAvailable(available);
  };

  const login = async (email: string, password: string) => {
    try {
      const response = await api.post('/auth/login', { email, password });
      const { access_token, user: userData } = response.data;
      
      await AsyncStorage.setItem('auth_token', access_token);
      await AsyncStorage.setItem('user_data', JSON.stringify(userData));
      
      api.defaults.headers.common['Authorization'] = `Bearer ${access_token}`;
      setUser(userData);
      setIsAuthenticated(true);
    } catch (error) {
      throw new Error('Login failed');
    }
  };

  const logout = async () => {
    await AsyncStorage.multiRemove(['auth_token', 'user_data']);
    delete api.defaults.headers.common['Authorization'];
    setUser(null);
    setIsAuthenticated(false);
  };

  const enableBiometric = async (): Promise<boolean> => {
    if (!biometricAvailable) return false;
    
    const rnBiometrics = new ReactNativeBiometrics();
    const { success } = await rnBiometrics.simplePrompt({
      promptMessage: 'Authenticate to access RCT Engine',
    });
    
    return success;
  };

  return (
    <AuthContext.Provider
      value={{
        isAuthenticated,
        user,
        isLoading,
        login,
        logout,
        enableBiometric,
        biometricAvailable,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
};
