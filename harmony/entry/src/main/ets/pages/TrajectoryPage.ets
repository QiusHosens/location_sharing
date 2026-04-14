import { HttpClient } from '../api/HttpClient';
import { appendDaySummaryQuery } from '../api/ApiPayloads';
import { MainBottomNav } from '../components/MainBottomNav';
import { AppTheme } from '../common/AppTheme';

interface TrajectorySegment {
  start_time: string;
  end_time: string;
  point_count: number;
}

interface TrajectoryUserSummary {
  user_id: string;
  phone: string;
  nickname?: string;
  segments: TrajectorySegment[];
}

interface DaySummaryData {
  date?: string;
  users?: TrajectoryUserSummary[];
}

interface DayChip {
  dateStr: string;
  weekLabel: string;
  dayNum: number;
}

const WEEK_CN: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

function pad2(n: number): string {
  return n < 10 ? ('0' + n) : ('' + n);
}

function dateToStr(d: Date): string {
  return d.getFullYear() + '-' + pad2(d.getMonth() + 1) + '-' + pad2(d.getDate());
}

function parseDateStr(s: string): Date {
  const parts = s.split('-');
  if (parts.length !== 3) {
    return new Date();
  }
  const y = parseInt(parts[0], 10);
  const m = parseInt(parts[1], 10) - 1;
  const day = parseInt(parts[2], 10);
  return new Date(y, m, day);
}

function maskPhone(p: string): string {
  const t = p.trim();
  if (t.length < 8) {
    return t;
  }
  return t.substring(0, 3) + '****' + t.substring(t.length - 4);
}

function fmtHm(iso: string): string {
  if (iso.length === 0) {
    return '';
  }
  const t = iso.indexOf('T');
  if (t >= 0) {
    const part = iso.substring(t + 1);
    if (part.length >= 5) {
      return part.substring(0, 5);
    }
  }
  return iso;
}

@Entry
@Component
struct TrajectoryPage {
  @State selectedDateStr: string = dateToStr(new Date());
  @State dayChips: DayChip[] = [];
  @State summary: DaySummaryData | null = null;
  @State loading: boolean = false;
  @State expandedUserId: string = '';

  aboutToAppear(): void {
    this.buildDayChips();
    void this.loadSummary();
  }

  buildDayChips(): void {
    const chips: DayChip[] = [];
    const end = new Date();
    for (let i = 13; i >= 0; i--) {
      const d = new Date(end.getFullYear(), end.getMonth(), end.getDate() - i);
      chips.push({
        dateStr: dateToStr(d),
        weekLabel: WEEK_CN[d.getDay()],
        dayNum: d.getDate(),
      });
    }
    this.dayChips = chips;
  }

  async loadSummary(): Promise<void> {
    this.loading = true;
    try {
      const path = appendDaySummaryQuery('/trajectory/day-summary', this.selectedDateStr);
      const res = await HttpClient.get(path) as Record<string, object>;
      const data = res['data'] as DaySummaryData;
      this.summary = data;
      const users = data.users;
      if (users !== undefined && users.length > 0) {
        this.expandedUserId = users[0].user_id;
      } else {
        this.expandedUserId = '';
      }
    } catch {
      this.summary = null;
    }
    this.loading = false;
  }

  toggleUser(uid: string): void {
    this.expandedUserId = this.expandedUserId === uid ? '' : uid;
  }

  formatDateLabel(): string {
    const d = parseDateStr(this.selectedDateStr);
    return d.getFullYear() + '年' + (d.getMonth() + 1) + '月' + d.getDate() + '日';
  }

  displayName(u: TrajectoryUserSummary): string {
    const masked = maskPhone(u.phone);
    if (u.nickname !== undefined && u.nickname.length > 0) {
      return u.nickname + ' (' + masked + ')';
    }
    return '家人 (' + masked + ')';
  }

  summaryLine(u: TrajectoryUserSummary): string {
    const n = u.segments.length;
    if (n === 0) {
      return '无记录 • 状态：静止';
    }
    return n + ' 条轨迹 • 今日已行 —';
  }

  avatarColor(index: number): string {
    const colors: string[] = ['#5B8DEF', '#4CAF50', '#FFB74D', '#AB47BC', '#26A69A'];
    return colors[index % colors.length];
  }

  @Builder
  userCardBuilder(u: TrajectoryUserSummary, index: number) {
    Column() {
      Row() {
        Text((u.nickname !== undefined && u.nickname.length > 0) ? u.nickname.substring(0, 1) :
          (u.phone.length > 0 ? u.phone.substring(0, 1) : '?'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.avatarColor(index))
          .width(44)
          .height(44)
          .borderRadius(22)
          .textAlign(TextAlign.Center)
          .backgroundColor('#E8EAF0')
        Column() {
          Text(this.displayName(u))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.textPrimary)
          Text(this.summaryLine(u))
            .fontSize(13)
            .fontColor(AppTheme.textSecondary)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 12 })
        Text(this.expandedUserId === u.user_id ? '⌃' : '⌄')
          .fontSize(18)
          .fontColor(AppTheme.textSecondary)
      }
      .width('100%')
      .padding(14)
      .onClick(() => this.toggleUser(u.user_id))

      if (this.expandedUserId === u.user_id && u.segments.length > 0) {
        Column() {
          ForEach(u.segments, (seg: TrajectorySegment, si: number) => {
            Row() {
              Column() {
                Text(fmtHm(seg.start_time) + ' - ' + fmtHm(seg.end_time))
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.accentBlue)
                Text('轨迹记录 · ' + seg.point_count + ' 个定位点')
                  .fontSize(12)
                  .fontColor(AppTheme.textSecondary)
                  .margin({ top: 4 })
                Text(maskPhone(u.phone))
                  .fontSize(12)
                  .fontColor(AppTheme.textSecondary)
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Text('›')
                .fontSize(22)
                .fontColor(AppTheme.accentBlue)
            }
            .width('100%')
            .padding(10)
            .backgroundColor('#F9FAFB')
            .borderRadius(12)
            .margin({ bottom: 8 })
          })
        }
        .width('100%')
        .padding({ left: 12, right: 12, bottom: 12 })
      }
    }
    .width('100%')
    .backgroundColor(Color.White)
    .borderRadius(16)
    .margin({ bottom: 12 })
  }

  build() {
    Column() {
      Row() {
        Text('历史轨迹')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.textPrimary)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })

      Row() {
        Text(this.formatDateLabel())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)
          .layoutWeight(1)
        Text('滑动选择日期')
          .fontSize(13)
          .fontColor(AppTheme.textSecondary)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      Scroll() {
        Row() {
          ForEach(this.dayChips, (chip: DayChip) => {
            Column() {
              Text(chip.weekLabel)
                .fontSize(12)
                .fontColor(this.selectedDateStr === chip.dateStr ? Color.White : AppTheme.textSecondary)
              Text(String(chip.dayNum))
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.selectedDateStr === chip.dateStr ? Color.White : AppTheme.textPrimary)
                .margin({ top: 4 })
            }
            .width(56)
            .padding({ top: 10, bottom: 10, left: 6, right: 6 })
            .borderRadius(14)
            .backgroundColor(this.selectedDateStr === chip.dateStr ? AppTheme.accentBlue : Color.White)
            .margin({ right: 8 })
            .onClick(() => {
              this.selectedDateStr = chip.dateStr;
              void this.loadSummary();
            })
          }, (chip: DayChip) => chip.dateStr)
        }
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .height(88)

      if (this.loading) {
        LoadingProgress().width(32).height(32).margin({ top: 24 })
      } else if (this.summary === null ||
        this.summary.users === undefined ||
        this.summary.users.length === 0) {
        Text('该日暂无轨迹')
          .fontSize(15)
          .fontColor(AppTheme.textSecondary)
          .margin({ top: 48 })
          .layoutWeight(1)
      } else {
        List() {
          ForEach(this.summary.users, (u: TrajectoryUserSummary, idx: number) => {
            ListItem() {
              this.userCardBuilder(u, idx)
            }
          }, (u: TrajectoryUserSummary) => u.user_id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 12, right: 12, bottom: 8 })
      }

      MainBottomNav({ currentIndex: 2 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.pageBg)
  }
}
