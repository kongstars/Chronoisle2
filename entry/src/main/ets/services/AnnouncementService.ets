import http from '@ohos.net.http';
import AppConfig from '../Utils/AppConfig';
import { trackApiError, trackNetworkError } from './TelemetryHelper';
import { TelemetryErrorCode } from '../models/TelemetryErrorCode';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('AnnouncementService');

interface AnnouncementApiResponse {
  success: boolean;
  message?: string;
  error?: string;
  data?: AnnouncementItem[];
}

export interface AnnouncementItem {
  id: string;
  title: string;
  subtitle: string;
  url: string;
  active: boolean;
  createdAt: number;
  expiresAt: number;
}

class AnnouncementService {
  public async getActiveAnnouncements(): Promise<AnnouncementItem[]> {
    let httpRequest = http.createHttp();
    const requestPath: string = 'announcements/active';
    try {
      const response = await httpRequest.request(
        `${AppConfig.getBaseUrl()}/api/announcements/active`,
        {
          method: http.RequestMethod.GET,
          connectTimeout: 8000,
          readTimeout: 8000
        }
      );

      if (response.responseCode !== 200) {
        logger.warn('AnnouncementService unexpected status: ${response.responseCode}');
        trackNetworkError(requestPath, `HTTP ${response.responseCode}`, response.responseCode);
        return [];
      }

      const result = JSON.parse(response.result as string) as AnnouncementApiResponse;
      if (!result.success || !result.data) {
        trackApiError(
          TelemetryErrorCode.ERR_HTTP_EXCEPTION,
          result.message || result.error || 'announcements business failure',
          requestPath
        );
        return [];
      }
      return result.data;
    } catch (error) {
      logger.error('AnnouncementService getActiveAnnouncements failed', error as Object);
      trackNetworkError(requestPath, error);
      return [];
    } finally {
      httpRequest.destroy();
    }
  }
}

export const announcementService = new AnnouncementService();
