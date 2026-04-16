/** HTTP 请求体 / 查询参数，满足 arkts-no-untyped-obj-literals */

export interface AuthPasswordBody {
  phone: string;
  password: string;
}

export interface LocationUploadBody {
  longitude: number;
  latitude: number;
  altitude?: number;
  source: string;
}

export interface GroupCreateBody {
  name: string;
}

export interface InviteMemberBody {
  phone: string;
}

export interface SharingRespondBody {
  accept: boolean;
}

export interface SharingRequestBody {
  phone: string;
}

export interface SharingUpdateBody {
  is_paused: boolean;
}

export interface ProfileUpdateBody {
  nickname: string;
}

export interface TrajectoryQueryParams {
  user_id: string;
  start_time: string;
  end_time: string;
}

export interface NotificationListParams {
  page: string;
  page_size: string;
}

/** 将查询参数拼进 path，避免 Record 字面量触发 arkts-no-untyped-obj-literals */
export function appendTrajectoryQuery(path: string, p: TrajectoryQueryParams): string {
  const q = 'user_id=' + encodeURIComponent(p.user_id) + '&start_time=' + encodeURIComponent(p.start_time) +
    '&end_time=' + encodeURIComponent(p.end_time);
  return path + '?' + q;
}

export function appendNotificationListQuery(path: string, p: NotificationListParams): string {
  const q = 'page=' + encodeURIComponent(p.page) + '&page_size=' + encodeURIComponent(p.page_size);
  return path + '?' + q;
}

/** GET /trajectory/day-summary?date=YYYY-MM-DD */
export function appendDaySummaryQuery(path: string, date: string): string {
  return path + '?date=' + encodeURIComponent(date);
}
