import { useEffect, useState } from 'react';
import { useSettingsStore } from '@/stores/settingsStore';
import { api } from '@/services/api';

export interface ApiConfigStatus {
  isConfigured: boolean;
  isValidating: boolean;
  isValid: boolean | null;
  error: string | null;
  needsConfiguration: boolean;
}

export const useApiConfig = () => {
  const { apiBaseUrl, serverConfig, isLoadingServerConfig } = useSettingsStore();
  const [validationState, setValidationState] = useState<{
    isValidating: boolean;
    isValid: boolean | null;
    error: string | null;
  }>({
    isValidating: false,
    isValid: null,
    error: null,
  });

  const isConfigured = Boolean(apiBaseUrl && apiBaseUrl.trim());
  const needsConfiguration = !isConfigured;

  // Validate API configuration when it changes
  useEffect(() => {
    if (!isConfigured) {
      setValidationState({
        isValidating: false,
        isValid: false,
        error: null,
      });
      return;
    }

    const validateConfig = async () => {
      setValidationState(prev => ({ ...prev, isValidating: true, error: null }));

      try {
        await api.getSiteBasic();
        setValidationState({
          isValidating: false,
          isValid: true,
          error: null,
        });
      } catch (error) {
        let errorMessage = '服务器连接失败';

        if (error instanceof Error) {
          switch (error.message) {
            case 'API_URL_NOT_SET':
              errorMessage = 'API地址未设置';
              break;
            case 'UNAUTHORIZED':
              errorMessage = '服务器认证失败';
              break;
            default:
              if (error.message.includes('Network')) {
                errorMessage = '网络连接失败，请检查网络或服务器地址';
              } else if (error.message.includes('timeout')) {
                errorMessage = '连接超时，请检查服务器地址';
              } else if (error.message.includes('404')) {
                errorMessage = '服务器地址无效，请检查API路径';
              } else if (error.message.includes('500')) {
                errorMessage = '服务器内部错误';
              }
              break;
          }
        }

        setValidationState({
          isValidating: false,
          isValid: false,
          error: errorMessage,
        });
      }
    };

    // Only validate if not already loading server config
    if (!isLoadingServerConfig) {
      validateConfig();
    }
  }, [apiBaseUrl, isConfigured, isLoadingServerConfig]);

  // Reset validation when server config loading state changes
  useEffect(() => {
    if (isLoadingServerConfig) {
      setValidationState(prev => ({ ...prev, isValidating: true, error: null }));
    }
  }, [isLoadingServerConfig]);

  // ★★ 兜底：验证最多等 15 秒，无论如何都放行。
  //
  //   这台电视（VIDAA / Android 6）上，实测首页会**一直**停在
  //   「正在验证服务器配置...」，整个 App 看起来就是「卡死」——
  //   而根因是下面这一串 await 链条里**任何一环卡住**都收不到终态：
  //     loadSettings() → await SettingsManager.get() → AsyncStorage
  //     loadServerConfig() → await api.getSiteBasic() → fetch
  //   给每一环都加了超时还不够（AsyncStorage 3 秒、fetch 10 秒实测都没解决），
  //   说明还有别的等待点。
  //
  //   ⇒ UI 层面加一道**硬上限**：isValidating 最多维持 15 秒，
  //   之后强制置 false，让首页正常显示内容（配置无效也照样能进设置页改）。
  useEffect(() => {
    if (!validationState.isValidating) return;
    const timer = setTimeout(() => {
      setValidationState(prev => ({
        ...prev,
        isValidating: false,
        isValid: prev.isValid ?? false,
        error: prev.error ?? "服务器连接超时，请检查地址",
      }));
    }, 15000);
    return () => clearTimeout(timer);
  }, [validationState.isValidating]);

  // Update validation state based on server config
  useEffect(() => {
    if (!isLoadingServerConfig && isConfigured) {
      if (serverConfig) {
        setValidationState(prev => ({ ...prev, isValid: true, error: null }));
      } else {
        setValidationState(prev => ({
          ...prev,
          isValid: false,
          error: prev.error || '无法获取服务器配置'
        }));
      }
    }
  }, [serverConfig, isLoadingServerConfig, isConfigured]);

  const status: ApiConfigStatus = {
    isConfigured,
    isValidating: validationState.isValidating || isLoadingServerConfig,
    isValid: validationState.isValid,
    error: validationState.error,
    needsConfiguration,
  };

  return status;
};

export const getApiConfigErrorMessage = (status: ApiConfigStatus): string => {
  if (status.needsConfiguration) {
    return '请点击右上角设置按钮，配置您的服务器地址';
  }

  if (status.error) {
    return status.error;
  }

  if (status.isValidating) {
    return '正在验证服务器配置...';
  }

  if (status.isValid === false) {
    return '服务器配置验证失败，请检查设置';
  }

  return '加载失败，请重试';
};