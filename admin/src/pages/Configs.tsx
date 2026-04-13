import React, { useEffect, useState } from 'react';
import {
  Box, Typography, Table, TableBody, TableCell, TableContainer, TableHead,
  TableRow, Paper, Button, Dialog, DialogTitle, DialogContent, DialogActions,
  TextField, CircularProgress, Alert, Snackbar, Chip,
} from '@mui/material';
import { Edit } from '@mui/icons-material';
import { getConfigs, updateConfig } from '@/api/client';

interface ConfigItem {
  key: string;
  value: any;
  description: string | null;
  updated_at: string;
}

const CONFIG_LABELS: Record<string, string> = {
  sms_provider: '短信供应商',
  sms_daily_limit: '每日短信限制',
  sms_code_ttl: '验证码有效期(秒)',
  location_update_interval: '定位上报间隔(秒)',
  trajectory_retention_days: '轨迹保留天数',
  max_family_members: '最大家庭成员数',
  amap_web_key: '高德地图 Web Key',
  amap_android_key: '高德地图 Android Key',
  amap_ios_key: '高德地图 iOS Key',
  sms_aliyun_access_key_id: '阿里云短信 AccessKeyId',
  sms_aliyun_access_key_secret: '阿里云短信 AccessKeySecret',
  sms_aliyun_sign_name: '阿里云短信签名',
  sms_aliyun_template_code: '阿里云短信模板',
  sms_tencent_secret_id: '腾讯云短信 SecretId',
  sms_tencent_secret_key: '腾讯云短信 SecretKey',
  sms_tencent_sdk_app_id: '腾讯云短信 SdkAppId',
  sms_tencent_sign_name: '腾讯云短信签名',
  sms_tencent_template_id: '腾讯云短信模板',
};

export default function ConfigsPage() {
  const [configs, setConfigs] = useState<ConfigItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [editItem, setEditItem] = useState<ConfigItem | null>(null);
  const [editValue, setEditValue] = useState('');
  const [editDesc, setEditDesc] = useState('');
  const [saving, setSaving] = useState(false);
  const [snackbar, setSnackbar] = useState<{ open: boolean; msg: string; severity: 'success' | 'error' }>({ open: false, msg: '', severity: 'success' });

  const fetchConfigs = async () => {
    setLoading(true);
    try { setConfigs(await getConfigs()); } finally { setLoading(false); }
  };

  useEffect(() => { fetchConfigs(); }, []);

  const handleEdit = (item: ConfigItem) => {
    setEditItem(item);
    setEditValue(typeof item.value === 'string' ? item.value : JSON.stringify(item.value));
    setEditDesc(item.description || '');
  };

  const handleSave = async () => {
    if (!editItem) return;
    setSaving(true);
    try {
      let parsedValue: any;
      try { parsedValue = JSON.parse(editValue); } catch { parsedValue = editValue; }
      await updateConfig(editItem.key, parsedValue, editDesc || undefined);
      setSnackbar({ open: true, msg: '配置已更新', severity: 'success' });
      setEditItem(null);
      fetchConfigs();
    } catch {
      setSnackbar({ open: true, msg: '更新失败', severity: 'error' });
    } finally {
      setSaving(false);
    }
  };

  return (
    <Box>
      <Typography variant="h5" fontWeight={700} gutterBottom>系统配置</Typography>
      <TableContainer component={Paper}>
        {loading ? (
          <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}><CircularProgress /></Box>
        ) : (
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>配置项</TableCell>
                <TableCell>值</TableCell>
                <TableCell>说明</TableCell>
                <TableCell>更新时间</TableCell>
                <TableCell align="right">操作</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {configs.map((c) => (
                <TableRow key={c.key} hover>
                  <TableCell><Chip label={CONFIG_LABELS[c.key] || c.key} size="small" variant="outlined" /></TableCell>
                  <TableCell sx={{ maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {typeof c.value === 'string' ? c.value : JSON.stringify(c.value)}
                  </TableCell>
                  <TableCell sx={{ color: 'text.secondary' }}>{c.description || '-'}</TableCell>
                  <TableCell>{new Date(c.updated_at).toLocaleString('zh-CN')}</TableCell>
                  <TableCell align="right">
                    <Button size="small" startIcon={<Edit />} onClick={() => handleEdit(c)}>编辑</Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
      </TableContainer>

      <Dialog open={!!editItem} onClose={() => setEditItem(null)} maxWidth="sm" fullWidth>
        <DialogTitle>编辑配置: {editItem && (CONFIG_LABELS[editItem.key] || editItem.key)}</DialogTitle>
        <DialogContent>
          <TextField label="值" fullWidth multiline rows={3} value={editValue} onChange={(e) => setEditValue(e.target.value)} sx={{ mt: 1, mb: 2 }} />
          <TextField label="说明" fullWidth value={editDesc} onChange={(e) => setEditDesc(e.target.value)} />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setEditItem(null)}>取消</Button>
          <Button variant="contained" onClick={handleSave} disabled={saving}>{saving ? '保存中...' : '保存'}</Button>
        </DialogActions>
      </Dialog>

      <Snackbar open={snackbar.open} autoHideDuration={3000} onClose={() => setSnackbar({ ...snackbar, open: false })}>
        <Alert severity={snackbar.severity} variant="filled">{snackbar.msg}</Alert>
      </Snackbar>
    </Box>
  );
}
