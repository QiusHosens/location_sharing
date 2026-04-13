import React, { useEffect, useState, useCallback } from 'react';
import {
  Box, Typography, TextField, Table, TableBody, TableCell, TableContainer,
  TableHead, TableRow, Paper, TablePagination, InputAdornment, CircularProgress,
} from '@mui/material';
import { Search } from '@mui/icons-material';
import { getUsers } from '@/api/client';

export default function UsersPage() {
  const [users, setUsers] = useState<any[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(20);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);

  const fetchUsers = useCallback(async () => {
    setLoading(true);
    try {
      const res = await getUsers({
        page: page + 1, page_size: pageSize,
        phone: search || undefined, nickname: search || undefined,
      });
      setUsers(res.items);
      setTotal(res.total);
    } finally {
      setLoading(false);
    }
  }, [page, pageSize, search]);

  useEffect(() => { fetchUsers(); }, [fetchUsers]);

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Typography variant="h5" fontWeight={700}>用户管理</Typography>
        <TextField size="small" placeholder="搜索手机号或昵称" value={search}
          onChange={(e) => { setSearch(e.target.value); setPage(0); }}
          InputProps={{ startAdornment: <InputAdornment position="start"><Search /></InputAdornment> }}
          sx={{ width: 280 }} />
      </Box>
      <TableContainer component={Paper}>
        {loading ? (
          <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}><CircularProgress /></Box>
        ) : (
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>手机号</TableCell>
                <TableCell>昵称</TableCell>
                <TableCell>注册时间</TableCell>
                <TableCell>更新时间</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {users.map((u) => (
                <TableRow key={u.id} hover>
                  <TableCell>{u.phone}</TableCell>
                  <TableCell>{u.nickname || '-'}</TableCell>
                  <TableCell>{new Date(u.created_at).toLocaleString('zh-CN')}</TableCell>
                  <TableCell>{new Date(u.updated_at).toLocaleString('zh-CN')}</TableCell>
                </TableRow>
              ))}
              {users.length === 0 && (
                <TableRow><TableCell colSpan={4} align="center" sx={{ py: 4, color: 'text.secondary' }}>暂无数据</TableCell></TableRow>
              )}
            </TableBody>
          </Table>
        )}
        <TablePagination component="div" count={total} page={page} rowsPerPage={pageSize}
          onPageChange={(_, p) => setPage(p)}
          onRowsPerPageChange={(e) => { setPageSize(parseInt(e.target.value)); setPage(0); }}
          rowsPerPageOptions={[10, 20, 50]}
          labelRowsPerPage="每页行数" />
      </TableContainer>
    </Box>
  );
}
