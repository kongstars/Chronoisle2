/* ===== 四时清单管理后台 · 核心逻辑 v2 ===== */

const API = window.location.origin;
let currentPage = 'dashboard';
let usersPage = 1;
let revenueUsersPage = 1;
let trendChart = null;
let revenueChart = null;
let aiFunnelChart = null;
let eventCategoryChart = null;
let telemetryTrendChart = null;

// ===== Auth =====
function getToken() { return localStorage.getItem('admin_token'); }
function authHeaders() {
  return { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + getToken() };
}
async function apiFetch(path, opts = {}) {
  const res = await fetch(API + path, { headers: authHeaders(), ...opts });
  if (res.status === 401) {
    localStorage.removeItem('admin_token');
    window.location.href = 'login.html';
    return null;
  }
  return res.json();
}

// ===== Init =====
document.addEventListener('DOMContentLoaded', () => {
  if (!getToken()) { window.location.href = 'login.html'; return; }
  initNav();
  loadDashboard();
});

// ===== Navigation =====
function initNav() {
  document.querySelectorAll('.nav-item').forEach(item => {
    item.addEventListener('click', () => switchPage(item.dataset.page));
  });
  document.getElementById('logoutBtn').addEventListener('click', () => {
    localStorage.removeItem('admin_token');
    window.location.href = 'login.html';
  });
  document.getElementById('userSearch').addEventListener('keydown', e => {
    if (e.key === 'Enter') searchUsers();
  });
}

function switchPage(page) {
  currentPage = page;
  document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
  document.querySelector(`.nav-item[data-page="${page}"]`).classList.add('active');
  document.querySelectorAll('[id^="page-"]').forEach(s => s.style.display = 'none');
  document.getElementById('page-' + page).style.display = 'block';

  if (page === 'dashboard') loadDashboard();
  else if (page === 'users') loadUsers(1);
  else if (page === 'revenue') loadRevenue();
  else if (page === 'reports') loadReports();
  else if (page === 'aimetrics') loadAiMetrics();
  else if (page === 'telemetry') loadTelemetry();
}

// ===== Helpers =====
function formatSeconds(s) {
  if (!s || s <= 0) return '0秒';
  if (s < 60) return s + '秒';
  if (s < 3600) return Math.floor(s / 60) + '分' + (s % 60 > 0 ? (s % 60) + '秒' : '');
  const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
  return h + '时' + (m > 0 ? m + '分' : '');
}
function formatTokens(t) {
  if (!t || t <= 0) return '0';
  if (t >= 1000000) return (t / 1000000).toFixed(1) + 'M';
  if (t >= 1000) return (t / 1000).toFixed(1) + 'K';
  return t.toString();
}
function formatDate(ts) {
  if (!ts) return '-';
  const d = new Date(ts);
  return d.getFullYear() + '-' +
    String(d.getMonth() + 1).padStart(2, '0') + '-' +
    String(d.getDate()).padStart(2, '0') + ' ' +
    String(d.getHours()).padStart(2, '0') + ':' +
    String(d.getMinutes()).padStart(2, '0');
}
function formatDateShort(ts) {
  if (!ts) return '-';
  const d = new Date(ts);
  return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
}
function accountTypeBadge(type) {
  const map = {
    huawei: ['华为', 'primary'], phone: ['手机', 'success'],
    email: ['邮箱', 'warning'], wechat: ['微信', 'success'], qq: ['QQ', 'primary']
  };
  const [label, cls] = map[type] || [type, 'primary'];
  return `<span class="badge badge-${cls}">${label}</span>`;
}
function membershipBadge(user) {
  const now = Date.now();
  if (user.membershipType === 'premium') {
    if (user.membershipExpireAt > now) {
      const days = Math.ceil((user.membershipExpireAt - now) / 86400000);
      return `<span class="badge badge-warning">高级会员</span> <span style="font-size:11px;color:var(--text-muted);">剩${days}天</span>`;
    }
    return `<span class="badge badge-danger">已到期</span>`;
  }
  return `<span style="color:var(--text-muted);font-size:12px;">免费用户</span>`;
}
function copyToClipboard(text) {
  navigator.clipboard.writeText(text).then(() => showToast('已复制到剪贴板'));
}
function showToast(msg) {
  const t = document.createElement('div');
  t.textContent = msg;
  t.style.cssText = 'position:fixed;bottom:30px;left:50%;transform:translateX(-50%);background:#22c55e;color:#fff;padding:10px 22px;border-radius:20px;font-size:14px;z-index:9999;animation:fadeInUp .3s ease';
  document.body.appendChild(t);
  setTimeout(() => t.remove(), 2200);
}
function renderPagination(elId, p, callback, ...args) {
  const el = document.getElementById(elId);
  if (!el || p.totalPages <= 1) { if (el) el.innerHTML = ''; return; }
  el.innerHTML = `
    <button ${p.page <= 1 ? 'disabled' : ''} onclick="${callback.name}(${p.page - 1}${args.map(a => ',' + JSON.stringify(a)).join('')})">上一页</button>
    <span class="page-info">第 ${p.page} / ${p.totalPages} 页（共 ${p.total} 条）</span>
    <button ${p.page >= p.totalPages ? 'disabled' : ''} onclick="${callback.name}(${p.page + 1}${args.map(a => ',' + JSON.stringify(a)).join('')})">下一页</button>
  `;
}

// ===== Dashboard =====
async function loadDashboard() {
  document.getElementById('dashboardStats').innerHTML = '<div class="loading">加载中...</div>';

  const [overviewData, statsData, creditData] = await Promise.all([
    apiFetch('/api/admin/usage/overview'),
    apiFetch('/api/admin/stats/overview'),
    apiFetch('/api/admin/stats/credits')
  ]);

  if (!overviewData?.success || !statsData?.success) {
    document.getElementById('dashboardStats').innerHTML = '<div class="empty-state">加载失败</div>';
    return;
  }
  const d = overviewData.data, s = statsData.data, c = creditData?.success ? creditData.data : { totalBalance: 0, todayIssued: 0, totalEarned: 0, monthConsumed: 0 };

  // 积分盘点渲染
  document.getElementById('creditStats').innerHTML = `
    <div class="stat-card" style="border-left-color: #8b5cf6;">
      <div class="stat-label">全站流转积分池</div>
      <div class="stat-value" style="color:#8b5cf6;">${c.totalBalance.toLocaleString()}</div>
      <div class="stat-sub">总计用户当前可用沉淀额度</div>
    </div>
    <div class="stat-card" style="border-left-color: #10b981;">
      <div class="stat-label">今日发放预估</div>
      <div class="stat-value" style="color:#10b981;">${c.todayIssued.toLocaleString()}</div>
      <div class="stat-sub">历史累计下发 ${c.totalEarned.toLocaleString()}</div>
    </div>
    <div class="stat-card" style="border-left-color: #f43f5e;">
      <div class="stat-label">本月消耗积分</div>
      <div class="stat-value" style="color:#f43f5e;">${c.monthConsumed.toLocaleString()}</div>
      <div class="stat-sub">近期用户 AI 调用消耗估值</div>
    </div>
  `;

  document.getElementById('dashboardStats').innerHTML = `
    <div class="stat-card primary">
      <div class="stat-label">注册用户总数</div>
      <div class="stat-value">${d.totalUsers.toLocaleString()}</div>
      <div class="stat-sub">今日新增 +${s.users.todayNew} · 本月 +${s.users.thisMonthNew}</div>
    </div>
    <div class="stat-card success">
      <div class="stat-label">本月活跃用户 (MAU)</div>
      <div class="stat-value">${d.monthly.activeUsers || 0}</div>
      <div class="stat-sub">${d.currentMonth}</div>
    </div>
    <div class="stat-card warning">
      <div class="stat-label">有效高级会员</div>
      <div class="stat-value">${s.membership.activeMembers}</div>
      <div class="stat-sub">转化率 ${s.membership.conversionRate}% · 已到期 ${s.membership.expiredMembers}</div>
    </div>
    <div class="stat-card danger">
      <div class="stat-label">AI Token 总消耗</div>
      <div class="stat-value">${formatTokens(d.cumulative.totalTokens)}</div>
      <div class="stat-sub">本月 ${formatTokens(d.monthly.totalTokens)} · ${d.monthly.tokenCount || 0}次</div>
    </div>
  `;

  // 用户增长统计
  document.getElementById('userGrowthStats').innerHTML = `
    <div class="kv-grid">
      <div class="kv-item"><span class="kv-label">今日新增</span><span class="kv-value" style="color:var(--success);">+${s.users.todayNew}</span></div>
      <div class="kv-item"><span class="kv-label">近7日新增</span><span class="kv-value">+${s.users.last7New}</span></div>
      <div class="kv-item"><span class="kv-label">近30日新增</span><span class="kv-value">+${s.users.last30New}</span></div>
      <div class="kv-item"><span class="kv-label">本月新增</span><span class="kv-value" style="color:var(--primary);">+${s.users.thisMonthNew}</span></div>
      <div class="kv-item"><span class="kv-label">上月新增</span><span class="kv-value">+${s.users.prevMonthNew}</span></div>
      <div class="kv-item"><span class="kv-label">注册总数</span><span class="kv-value">${d.totalUsers.toLocaleString()}</span></div>
    </div>
  `;

  // 会员转化统计
  document.getElementById('membershipStats').innerHTML = `
    <div class="kv-grid">
      <div class="kv-item"><span class="kv-label">当前有效会员</span><span class="kv-value" style="color:var(--warning);">${s.membership.activeMembers}</span></div>
      <div class="kv-item"><span class="kv-label">历史付费用户</span><span class="kv-value">${s.membership.totalEver}</span></div>
      <div class="kv-item"><span class="kv-label">已到期会员</span><span class="kv-value" style="color:var(--danger);">${s.membership.expiredMembers}</span></div>
      <div class="kv-item"><span class="kv-label">付费转化率</span><span class="kv-value">${s.membership.conversionRate}%</span></div>
      <div class="kv-item"><span class="kv-label">在有效期内比例</span><span class="kv-value">${s.membership.activeRate}%</span></div>
      <div class="kv-item"><span class="kv-label">语音总时长</span><span class="kv-value">${formatSeconds(d.cumulative.voiceSeconds)}</span></div>
    </div>
  `;

  loadTrendChart();
  loadExpiringWarning();
}

async function loadTrendChart() {
  const data = await apiFetch('/api/admin/usage/monthly?months=6');
  if (!data?.success || !data.data.length) return;

  const labels = data.data.map(r => r.yearMonth);
  const voiceData = data.data.map(r => Math.round((r.voiceSeconds || 0) / 60));
  const tokenData = data.data.map(r => Math.round((r.totalTokens || 0) / 1000));
  const activeUsersData = data.data.map(r => r.activeUsers || 0);

  const ctx = document.getElementById('trendChart');
  if (trendChart) trendChart.destroy();
  trendChart = new Chart(ctx, {
    type: 'bar',
    data: {
      labels,
      datasets: [
        { label: '语音时长(分钟)', data: voiceData, backgroundColor: 'rgba(99,102,241,0.6)', borderRadius: 6, barPercentage: 0.5 },
        { label: 'Token消耗(K)', data: tokenData, backgroundColor: 'rgba(239,68,68,0.6)', borderRadius: 6, barPercentage: 0.5, yAxisID: 'y' },
        { label: '月活用户(MAU)', data: activeUsersData, type: 'line', borderColor: '#f59e0b', backgroundColor: '#f59e0b', borderWidth: 2, tension: 0.3, yAxisID: 'y1' }
      ]
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      plugins: { legend: { labels: { color: '#94a3b8', font: { size: 12 } } } },
      scales: {
        x: { ticks: { color: '#64748b' }, grid: { color: '#2e3142' } },
        y: { type: 'linear', display: true, position: 'left', ticks: { color: '#64748b' }, grid: { color: '#2e3142' }, beginAtZero: true },
        y1: { type: 'linear', display: true, position: 'right', ticks: { color: '#f59e0b' }, grid: { drawOnChartArea: false }, beginAtZero: true }
      }
    }
  });
}

async function loadExpiringWarning() {
  const data = await apiFetch('/api/admin/revenue/expiring?days=7');
  const tbody = document.getElementById('expiringTableBody');
  const countEl = document.getElementById('expiringCount');
  if (!data?.success) { tbody.innerHTML = '<tr><td colspan="5" class="empty-state">加载失败</td></tr>'; return; }

  const users = data.data;
  if (countEl) countEl.textContent = users.length > 0 ? `共 ${users.length} 位用户即将到期` : '暂无即将到期会员';

  if (!users.length) {
    tbody.innerHTML = '<tr><td colspan="5" class="empty-state">暂无即将到期的会员</td></tr>';
    return;
  }
  tbody.innerHTML = users.map(u => `
    <tr>
      <td style="color:var(--text);font-weight:600;">${u.displayId || '-'}</td>
      <td>${u.nickname || u.account || '-'}</td>
      <td style="color:var(--warning);">${formatDate(u.membershipExpireAt)}</td>
      <td><span class="badge ${u.remainingDays <= 3 ? 'badge-danger' : 'badge-warning'}">${u.remainingDays}天</span></td>
      <td><a href="#" onclick="openUserDetail('${u.userId}');return false;" style="color:var(--primary);font-weight:500;">管理</a></td>
    </tr>
  `).join('');
}

// ===== Users =====
async function loadUsers(page) {
  usersPage = page;
  const search = document.getElementById('userSearch').value;
  const membershipFilter = document.getElementById('userFilterMembership')?.value || 'all';
  const accountFilter = document.getElementById('userFilterAccount')?.value || 'all';
  const tbody = document.getElementById('usersTableBody');
  tbody.innerHTML = '<tr><td colspan="11" class="loading">加载中...</td></tr>';

  const q = new URLSearchParams({ page, limit: 15, search, membershipType: membershipFilter, accountType: accountFilter });
  const data = await apiFetch('/api/admin/users?' + q.toString());
  if (!data?.success) { tbody.innerHTML = '<tr><td colspan="12" class="empty-state">加载失败</td></tr>'; return; }

  const { users, pagination } = data.data;
  if (!users.length) {
    tbody.innerHTML = '<tr><td colspan="12" class="empty-state">暂无用户数据</td></tr>';
    document.getElementById('usersPagination').innerHTML = '';
    return;
  }

  tbody.innerHTML = users.map(u => {
    const shortUuid = u.userId ? u.userId.substring(0, 8) + '...' : '-';
    const platform = u.deviceInfo?.platform || '-';
    const deviceModel = u.deviceInfo?.model ? `<span title="${u.deviceInfo.model}" style="font-size:11px;">${u.deviceInfo.model.substring(0, 10)}</span>` : '-';
    return `
    <tr onclick="openUserDetail('${u.userId}')" style="cursor:pointer;">
      <td style="color:var(--text);font-weight:600;">${u.displayId || '-'}</td>
      <td>
        <span class="uuid-cell" title="${u.userId}" onclick="event.stopPropagation();copyToClipboard('${u.userId}')">${shortUuid}</span>
      </td>
      <td>${u.nickname ? `<strong>${u.nickname}</strong><br><span style="font-size:11px;color:var(--text-muted);">${u.account}</span>` : u.account || '-'}</td>
      <td>${accountTypeBadge(u.accountType)}</td>
      <td>${deviceModel}</td>
      <td><span style="font-size:11px;color:var(--text-muted);">${u.appVersion || '-'}</span></td>
      <td><span class="badge" style="background:#8b5cf6;color:white;">${u.creditBalance || 0} 积分</span></td>
      <td>${membershipBadge(u)}</td>
      <td style="font-size:12px;">${u.membershipType === 'premium' && u.membershipExpireAt > Date.now() ? formatDate(u.membershipExpireAt) : '-'}</td>
      <td style="font-size:12px;">${formatDateShort(u.createdAt)}</td>
      <td style="font-size:12px;">${u.lastActiveAt ? formatDate(u.lastActiveAt) : formatDate(u.lastLoginAt)}</td>
      <td onclick="event.stopPropagation();">
        <a href="#" onclick="openUserDetail('${u.userId}');return false;" style="color:var(--primary);text-decoration:none;font-weight:500;font-size:13px;">详情</a>
      </td>
    </tr>`;
  }).join('');

  renderPagination('usersPagination', pagination, loadUsers);
}

function searchUsers() { loadUsers(1); }

// ===== User Detail Modal =====
async function openUserDetail(userId) {
  const modal = document.getElementById('userModal');
  const body = document.getElementById('modalBody');
  modal.style.display = 'flex';
  body.innerHTML = '<div class="loading">加载中...</div>';

  const [userData, syncData, behaviorData, txData] = await Promise.all([
    apiFetch('/api/admin/users/' + userId),
    apiFetch('/api/admin/users/' + userId + '/sync-data-stats'),
    apiFetch('/api/telemetry/admin/user/' + userId + '?limit=15'),
    apiFetch('/api/admin/users/' + userId + '/credit-transactions?limit=10')
  ]);

  if (!userData?.success) { body.innerHTML = '<div class="empty-state">加载失败</div>'; return; }

  const { user, monthlySummaries, cumulative, creditAccount } = userData.data;
  document.getElementById('modalTitle').textContent = user.nickname || user.account || '用户详情';

  const syncStats = syncData?.success ? syncData.data : { goals: 0, tasks: 0 };
  const behavior = behaviorData?.success ? behaviorData.data : { events: [], stats: [] };

  // 月度用量表行
  const monthlyRows = (monthlySummaries?.length ? monthlySummaries : []).map(s => `
    <tr>
      <td>${s.yearMonth}</td>
      <td>${s.voiceCount || 0}次 / ${formatSeconds(s.voiceSeconds)}</td>
      <td>${s.tokenCount || 0}次 / ${formatTokens(s.totalTokens)}</td>
    </tr>
  `).join('') || '<tr><td colspan="3" class="empty-state">暂无用量数据</td></tr>';

  // 行为时间线
  const behaviorRows = (behavior.events || []).slice(0, 15).map(e => `
    <div class="timeline-item">
      <span class="event-tag cat-${e.eventCategory}">${e.eventName}</span>
      <span class="timeline-time">${formatDate(e.createdAt)}</span>
      ${e.properties && Object.keys(e.properties).length ? `<span style="font-size:11px;color:var(--text-muted);">${JSON.stringify(e.properties).substring(0,60)}</span>` : ''}
    </div>
  `).join('') || '<div class="empty-state" style="font-size:13px;">暂无行为数据</div>';

  // 积分流水时间线
  const txList = txData?.success ? txData.data.transactions : [];
  const creditTxRows = txList.length ? txList.map(tx => `
    <div class="timeline-item">
      <span class="event-tag" style="background:${tx.amount > 0 ? '#10b981' : '#f43f5e'};color:#fff;">${tx.amount > 0 ? '+' : ''}${tx.amount} 积分</span>
      <span class="timeline-time">${formatDate(tx.createdAt)}</span>
      <span style="font-size:12px;color:var(--text);">${tx.description || tx.type}</span>
      <span style="font-size:11px;color:var(--text-muted);margin-left:8px;">(单次后余额: ${tx.balanceAfter})</span>
    </div>
  `).join('') : '<div class="empty-state" style="font-size:13px;">暂无积分流水</div>';

  const now = Date.now();
  body.innerHTML = `
    <div class="user-info-grid">
      <div class="info-item" style="grid-column:span 2;">
        <div class="info-label" style="color:var(--primary);">云端数据规模</div>
        <div class="info-value" style="color:var(--primary);font-weight:700;">${syncStats.goals} 个目标 / ${syncStats.tasks} 个任务</div>
      </div>
      <div class="info-item"><div class="info-label">用户UUID</div><div class="info-value uuid-cell" onclick="copyToClipboard('${user.userId}')" title="点击复制">${user.userId}</div></div>
      <div class="info-item"><div class="info-label">四时显示号</div><div class="info-value">${user.displayId || '-'}</div></div>
      <div class="info-item"><div class="info-label">账号</div><div class="info-value">${user.account || '-'}</div></div>
      <div class="info-item"><div class="info-label">昵称</div><div class="info-value">${user.nickname || '-'}</div></div>
      <div class="info-item"><div class="info-label">账号类型</div><div class="info-value">${accountTypeBadge(user.accountType)}</div></div>
      <div class="info-item"><div class="info-label">设备型号</div><div class="info-value">${user.deviceInfo?.model || '-'}</div></div>
      <div class="info-item"><div class="info-label">客户端版本</div><div class="info-value">${user.appVersion || '-'}</div></div>
      <div class="info-item"><div class="info-label">注册时间</div><div class="info-value">${formatDate(user.createdAt)}</div></div>
      <div class="info-item"><div class="info-label">最后活跃</div><div class="info-value">${formatDate(user.lastActiveAt || user.lastLoginAt)}</div></div>
      <div class="info-item" style="grid-column:span 2;">
        <div class="info-label">会员状态</div>
        <div class="info-value" style="display:flex;align-items:center;justify-content:space-between;">
          <div>
            <span class="badge ${user.membershipType === 'premium' ? 'badge-warning' : 'badge-primary'}">${user.membershipType === 'premium' ? '高级会员' : '免费用户'}</span>
            ${user.membershipType === 'premium' ? `<span style="margin-left:8px;font-size:12px;color:${user.membershipExpireAt > now ? 'var(--text-muted)' : 'var(--danger)'};">${user.membershipExpireAt > now ? '到期：' + formatDate(user.membershipExpireAt) : '已于 ' + formatDate(user.membershipExpireAt) + ' 到期'}</span>` : ''}
          </div>
          <button class="btn-primary" style="height:32px;font-size:12px;padding:0 12px;border-radius:6px;" onclick="openMembershipManage('${user.userId}')">管理增减</button>
        </div>
      </div>
      <div class="info-item" style="grid-column:span 2;">
        <div class="info-label">积分账户余额</div>
        <div class="info-value" style="display:flex;align-items:center;justify-content:space-between;">
          <div>
            <span style="font-size:24px;font-weight:700;color:#8b5cf6;">${creditAccount ? creditAccount.balance : 0}</span>
            <span style="font-size:12px;color:var(--text-muted);margin-left:8px;">(总计发放: ${creditAccount ? creditAccount.totalEarned : 0} / 总计消耗: ${creditAccount ? creditAccount.totalConsumed : 0})</span>
          </div>
          <button class="btn-primary" style="height:32px;font-size:12px;padding:0 12px;border-radius:6px;background:#8b5cf6;" onclick="openCreditManage('${user.userId}')">管理积分</button>
        </div>
      </div>
    </div>

    <div class="stats-grid" style="grid-template-columns:1fr 1fr;margin-top:16px;">
      <div class="stat-card warning">
        <div class="stat-label">累计语音</div>
        <div class="stat-value" style="font-size:22px;">${formatSeconds(cumulative.voiceSeconds)}</div>
        <div class="stat-sub">${cumulative.voiceCount || 0} 次调用</div>
      </div>
      <div class="stat-card danger">
        <div class="stat-label">累计Token</div>
        <div class="stat-value" style="font-size:22px;">${formatTokens(cumulative.totalTokens)}</div>
        <div class="stat-sub">${cumulative.tokenCount || 0} 次调用</div>
      </div>
    </div>

    <h3 style="font-size:14px;font-weight:600;margin:20px 0 8px;">月度用量明细</h3>
    <table>
      <thead><tr><th>月份</th><th>语音</th><th>Token</th></tr></thead>
      <tbody>${monthlyRows}</tbody>
    </table>

    <div style="display:grid; grid-template-columns:1fr 1fr; gap:20px; margin-top:20px;">
      <div>
        <h3 style="font-size:14px;font-weight:600;margin-bottom:8px;">近期积分流水</h3>
        <div class="timeline">${creditTxRows}</div>
      </div>
      <div>
        <h3 style="font-size:14px;font-weight:600;margin-bottom:8px;">近期行为事件流</h3>
        <div class="timeline">${behaviorRows}</div>
      </div>
    </div>
  `;
}

function closeUserModal() { document.getElementById('userModal').style.display = 'none'; }
document.getElementById('userModal').addEventListener('click', e => { if (e.target === e.currentTarget) closeUserModal(); });

// ===== Membership Manage =====
let currentManageUserId = '';
function openMembershipManage(userId) {
  currentManageUserId = userId;
  document.getElementById('membershipDays').value = '';
  document.getElementById('membershipModal').style.display = 'flex';
}
function closeMembershipModal() {
  document.getElementById('membershipModal').style.display = 'none';
  currentManageUserId = '';
}
async function submitMembershipChange(operation = 'add') {
  if (!currentManageUserId) return;
  let days = parseInt(document.getElementById('membershipDays').value, 10);
  if (isNaN(days) || days <= 0) return alert('请输入有效的天数');
  if (operation === 'deduct') days = -days;

  const btn = window.event?.target;
  const originText = btn?.textContent || '';
  if (btn) { btn.textContent = '处理中...'; btn.disabled = true; }

  try {
    const data = await apiFetch('/api/admin/users/' + currentManageUserId + '/membership', {
      method: 'POST',
      body: JSON.stringify({ action: 'add_days', value: days })
    });
    if (data?.success) {
      showToast(data.message);
      closeMembershipModal();
      openUserDetail(currentManageUserId);
      if (currentPage === 'users') loadUsers(usersPage);
    } else {
      alert(data ? data.message : '请求失败');
    }
  } finally {
    if (btn) { btn.textContent = originText; btn.disabled = false; }
  }
}
document.getElementById('membershipModal').addEventListener('click', e => { if (e.target === e.currentTarget) closeMembershipModal(); });

// ===== Credit Manage =====
function openCreditManage(userId) {
  currentManageUserId = userId;
  document.getElementById('creditAmount').value = '';
  document.getElementById('creditReason').value = '';
  document.getElementById('creditModal').style.display = 'flex';
}
function closeCreditModal() {
  document.getElementById('creditModal').style.display = 'none';
  currentManageUserId = '';
}
async function submitCreditChange(operation = 'add') {
  if (!currentManageUserId) return;
  const amountStr = document.getElementById('creditAmount').value;
  const amount = parseInt(amountStr, 10);
  const reason = document.getElementById('creditReason').value.trim();

  if (isNaN(amount) || amount <= 0) return alert('请输入有效的正额度');

  const btn = window.event?.target;
  const originText = btn?.textContent || '';
  if (btn) { btn.textContent = '处理中...'; btn.disabled = true; }

  try {
    const data = await apiFetch('/api/admin/users/' + currentManageUserId + '/credits', {
      method: 'POST',
      body: JSON.stringify({ action: operation, amount, reason })
    });
    if (data?.success) {
      showToast(data.message);
      closeCreditModal();
      openUserDetail(currentManageUserId);
      if (currentPage === 'users') loadUsers(usersPage);
    } else {
      alert(data ? data.message : '请求失败');
    }
  } finally {
    if (btn) { btn.textContent = originText; btn.disabled = false; }
  }
}
document.getElementById('creditModal').addEventListener('click', e => { if (e.target === e.currentTarget) closeCreditModal(); });

// ===== Revenue =====
async function loadRevenue() {
  const [statsData, monthlyData] = await Promise.all([
    apiFetch('/api/admin/stats/overview'),
    apiFetch('/api/admin/revenue/monthly?months=12')
  ]);

  // 付费概览卡片
  if (statsData?.success) {
    const s = statsData.data;
    document.getElementById('revenueStats').innerHTML = `
      <div class="stat-card warning">
        <div class="stat-label">当前有效会员</div>
        <div class="stat-value">${s.membership.activeMembers}</div>
        <div class="stat-sub">历史峰值 ${s.membership.totalEver} 人</div>
      </div>
      <div class="stat-card danger">
        <div class="stat-label">已到期会员</div>
        <div class="stat-value">${s.membership.expiredMembers}</div>
        <div class="stat-sub">续费转化待挖掘</div>
      </div>
      <div class="stat-card success">
        <div class="stat-label">付费转化率</div>
        <div class="stat-value">${s.membership.conversionRate}%</div>
        <div class="stat-sub">基于注册总量 ${s.users.total} 人</div>
      </div>
      <div class="stat-card primary">
        <div class="stat-label">本月新注册用户</div>
        <div class="stat-value">${s.users.thisMonthNew}</div>
        <div class="stat-sub">上月 ${s.users.prevMonthNew} 人</div>
      </div>
    `;
  }

  // 月度付费趋势图 + 明细表
  if (monthlyData?.success && monthlyData.data.length) {
    const rows = monthlyData.data;
    const labels = rows.map(r => r.yearMonth);
    const newUsersData = rows.map(r => r.newUsers || 0);
    const newPaidData = rows.map(r => r.newPaidUsers || 0);
    const peakData = rows.map(r => r.membersAtPeak || 0);

    const ctx = document.getElementById('revenueChart');
    if (revenueChart) revenueChart.destroy();
    revenueChart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels,
        datasets: [
          { label: '月新注册用户', data: newUsersData, backgroundColor: 'rgba(99,102,241,0.5)', borderRadius: 5, barPercentage: 0.5 },
          { label: '月新付费用户', data: newPaidData, backgroundColor: 'rgba(245,158,11,0.7)', borderRadius: 5, barPercentage: 0.5 },
          { label: '月有效会员峰值', data: peakData, type: 'line', borderColor: '#22c55e', backgroundColor: 'rgba(34,197,94,0.15)', borderWidth: 2, tension: 0.3, fill: true }
        ]
      },
      options: {
        responsive: true, maintainAspectRatio: false,
        plugins: { legend: { labels: { color: '#94a3b8', font: { size: 12 } } } },
        scales: {
          x: { ticks: { color: '#64748b' }, grid: { color: '#2e3142' } },
          y: { ticks: { color: '#64748b' }, grid: { color: '#2e3142' }, beginAtZero: true }
        }
      }
    });

    document.getElementById('revenueMonthlyBody').innerHTML = rows.reverse().map(r => `
      <tr>
        <td style="font-weight:600;color:var(--text);">${r.yearMonth}</td>
        <td>${r.newUsers || 0}</td>
        <td style="color:var(--warning);font-weight:600;">${r.newPaidUsers || 0}</td>
        <td>${r.membersAtPeak || 0}</td>
      </tr>
    `).join('');
  }

  loadRevenueUsers(1);
}

async function loadRevenueUsers(page) {
  revenueUsersPage = page;
  const status = document.getElementById('revenueUserStatus')?.value || 'active';
  const search = document.getElementById('revenueUserSearch')?.value || '';
  const tbody = document.getElementById('revenueUsersBody');
  tbody.innerHTML = '<tr><td colspan="6" class="loading">加载中...</td></tr>';

  const q = new URLSearchParams({ page, limit: 20, status, search });
  const data = await apiFetch('/api/admin/revenue/users?' + q.toString());
  if (!data?.success) { tbody.innerHTML = '<tr><td colspan="6" class="empty-state">加载失败</td></tr>'; return; }

  const { users, pagination } = data.data;
  if (!users.length) {
    tbody.innerHTML = '<tr><td colspan="6" class="empty-state">暂无数据</td></tr>';
    document.getElementById('revenueUsersPagination').innerHTML = '';
    return;
  }

  tbody.innerHTML = users.map(u => `
    <tr>
      <td style="font-weight:600;color:var(--text);">${u.displayId || '-'}</td>
      <td>${u.nickname || u.account || '-'}</td>
      <td>${u.isActive ? '<span class="badge badge-warning">有效</span>' : '<span class="badge badge-danger">已到期</span>'}</td>
      <td style="font-size:12px;">${formatDate(u.membershipExpireAt)}</td>
      <td><span style="color:${u.remainingDays > 7 ? 'var(--success)' : u.remainingDays > 0 ? 'var(--warning)' : 'var(--danger)'};">${u.remainingDays > 0 ? u.remainingDays + '天' : '已到期'}</span></td>
      <td><a href="#" onclick="openUserDetail('${u.userId}');return false;" style="color:var(--primary);font-weight:500;font-size:13px;">详情</a></td>
    </tr>
  `).join('');

  renderPagination('revenueUsersPagination', pagination, loadRevenueUsers);
}

// ===== Reports =====
async function loadReports() {
  await Promise.all([loadMonthlyReport(), loadRanking()]);
}
async function loadMonthlyReport() {
  const tbody = document.getElementById('monthlyTableBody');
  tbody.innerHTML = '<tr><td colspan="6" class="loading">加载中...</td></tr>';
  const data = await apiFetch('/api/admin/usage/monthly?months=12');
  if (!data?.success || !data.data.length) { tbody.innerHTML = '<tr><td colspan="6" class="empty-state">暂无数据</td></tr>'; return; }
  tbody.innerHTML = data.data.map(r => `
    <tr>
      <td style="color:var(--text);font-weight:600;">${r.yearMonth}</td>
      <td>${r.activeUsers || 0}</td>
      <td>${r.voiceCount || 0}</td>
      <td>${formatSeconds(r.voiceSeconds)}</td>
      <td>${r.tokenCount || 0}</td>
      <td>${formatTokens(r.totalTokens)}</td>
    </tr>
  `).join('');
}
async function loadRanking() {
  const type = document.getElementById('rankingType').value;
  const tbody = document.getElementById('rankingTableBody');
  tbody.innerHTML = '<tr><td colspan="5" class="loading">加载中...</td></tr>';
  const data = await apiFetch(`/api/admin/usage/ranking?type=${type}&limit=20`);
  if (!data?.success || !data.data.length) { tbody.innerHTML = '<tr><td colspan="5" class="empty-state">暂无排行数据</td></tr>'; return; }
  const isVoice = type === 'voice';
  tbody.innerHTML = data.data.map((r, i) => `
    <tr>
      <td style="color:var(--text);font-weight:700;">${i + 1}</td>
      <td>${r.user ? (r.user.nickname || r.user.account || r.userId) : r.userId}</td>
      <td>${r.user ? accountTypeBadge(r.user.accountType) : '-'}</td>
      <td style="color:${isVoice ? 'var(--warning)' : 'var(--danger)'};font-weight:600;">${isVoice ? formatSeconds(r.amount) : formatTokens(r.amount)}</td>
      <td>${r.count || 0}次</td>
    </tr>
  `).join('');
}

// ===== AI Metrics =====
async function loadAiMetrics() {
  const data = await apiFetch('/api/admin/usage/ai-features');
  if (!data?.success) return;
  const d = data.data || {};
  const labels = ['今日规划', '目标拆解', '智能重排', '任务提取'];
  const triggers = [d.planTriggers || 0, d.goalTriggers || 0, d.rescheduleTriggers || 0, d.taskTriggers || 0];
  const adopts = [d.planAdopts || 0, d.goalAdopts || 0, d.rescheduleAdopts || 0, d.taskAdopts || 0];

  const ctx = document.getElementById('aiFunnelChart');
  if (aiFunnelChart) aiFunnelChart.destroy();
  aiFunnelChart = new Chart(ctx, {
    type: 'bar',
    data: {
      labels,
      datasets: [
        { label: '触发次数', data: triggers, backgroundColor: 'rgba(99,102,241,0.6)', borderRadius: 4 },
        { label: '采纳次数', data: adopts, backgroundColor: 'rgba(34,197,94,0.6)', borderRadius: 4 }
      ]
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      plugins: {
        legend: { labels: { color: '#94a3b8' } },
        tooltip: {
          callbacks: {
            afterLabel: (ctx) => {
              if (ctx.datasetIndex === 1) {
                const t = triggers[ctx.dataIndex];
                const rate = t > 0 ? ((ctx.parsed.y / t) * 100).toFixed(0) : 0;
                return `采纳率: ${rate}%`;
              }
            }
          }
        }
      },
      scales: {
        x: { ticks: { color: '#64748b' }, grid: { color: '#2e3142' } },
        y: { ticks: { color: '#64748b' }, grid: { color: '#2e3142' }, beginAtZero: true }
      }
    }
  });
}

// ===== Telemetry =====
async function loadTelemetry() {
  await Promise.all([loadTopEvents(), loadDailyTrend(), loadEventStream(1)]);
}

async function loadTopEvents() {
  const days = document.getElementById('topEventDays')?.value || '7';
  const container = document.getElementById('topEventsContainer');
  container.innerHTML = '<div class="loading">加载中...</div>';

  const data = await apiFetch(`/api/telemetry/admin/top-events?days=${days}&limit=15`);
  if (!data?.success || !data.data.length) {
    container.innerHTML = '<div class="empty-state">暂无埋点数据</div>';
    return;
  }
  const maxCount = data.data[0]?.count || 1;
  container.innerHTML = `
    <div style="font-size:12px;color:var(--text-muted);margin-bottom:12px;">近${days}天，共 ${data.data.length} 种事件</div>
    ${data.data.map((e, i) => `
      <div style="margin-bottom:10px;">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:4px;">
          <span style="font-size:13px;font-weight:500;">${i + 1}. ${e.eventName}</span>
          <span style="font-size:12px;color:var(--text-muted);">${e.count.toLocaleString()} 次 · ${e.uniqueUsers} 人</span>
        </div>
        <div style="background:var(--border);border-radius:3px;height:4px;overflow:hidden;">
          <div style="background:var(--primary);height:100%;width:${Math.round(e.count / maxCount * 100)}%;border-radius:3px;transition:width .5s;"></div>
        </div>
      </div>
    `).join('')}
  `;
}

async function loadDailyTrend() {
  const data = await apiFetch('/api/telemetry/admin/daily-trend?days=14');
  if (!data?.success || !data.data.length) return;

  const rows = data.data;
  const labels = rows.map(r => r.date);
  const categories = ['task', 'ai', 'goal', 'membership', 'session', 'voice', 'search'];
  const colorMap = {
    task: 'rgba(99,102,241,0.7)', ai: 'rgba(239,68,68,0.7)', goal: 'rgba(245,158,11,0.7)',
    membership: 'rgba(34,197,94,0.7)', session: 'rgba(148,163,184,0.5)',
    voice: 'rgba(168,85,247,0.7)', search: 'rgba(20,184,166,0.7)'
  };

  // 饼图：事件分类分布
  const categorySums = {};
  categories.forEach(c => { categorySums[c] = rows.reduce((sum, r) => sum + (r[c] || 0), 0); });
  const pieCtx = document.getElementById('eventCategoryChart');
  if (eventCategoryChart) eventCategoryChart.destroy();
  eventCategoryChart = new Chart(pieCtx, {
    type: 'doughnut',
    data: {
      labels: categories,
      datasets: [{ data: categories.map(c => categorySums[c]), backgroundColor: categories.map(c => colorMap[c]), borderWidth: 0 }]
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      plugins: { legend: { position: 'right', labels: { color: '#94a3b8', font: { size: 12 } } } }
    }
  });

  // 堆叠面积图：每日趋势
  const trendCtx = document.getElementById('telemetryTrendChart');
  if (telemetryTrendChart) telemetryTrendChart.destroy();
  telemetryTrendChart = new Chart(trendCtx, {
    type: 'bar',
    data: {
      labels,
      datasets: categories.filter(c => categorySums[c] > 0).map(c => ({
        label: c,
        data: rows.map(r => r[c] || 0),
        backgroundColor: colorMap[c],
        borderRadius: 3,
        stack: 'stack'
      }))
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      plugins: { legend: { labels: { color: '#94a3b8', font: { size: 12 } } } },
      scales: {
        x: { stacked: true, ticks: { color: '#64748b' }, grid: { color: '#2e3142' } },
        y: { stacked: true, ticks: { color: '#64748b' }, grid: { color: '#2e3142' }, beginAtZero: true }
      }
    }
  });
}

async function loadEventStream(page) {
  const tbody = document.getElementById('eventStreamBody');
  tbody.innerHTML = '<tr><td colspan="7" class="loading">加载中...</td></tr>';

  const userId = document.getElementById('telemetryUserId')?.value || '';
  const eventName = document.getElementById('telemetryEventName')?.value || '';
  const category = document.getElementById('telemetryCategory')?.value || '';
  const days = document.getElementById('telemetryDays')?.value || '7';

  const q = new URLSearchParams({ page, limit: 30, days });
  if (userId) q.append('userId', userId);
  if (eventName) q.append('eventName', eventName);
  if (category) q.append('category', category);

  const data = await apiFetch('/api/telemetry/admin/events?' + q.toString());
  if (!data?.success) { tbody.innerHTML = '<tr><td colspan="7" class="empty-state">加载失败</td></tr>'; return; }

  const { events, pagination } = data.data;
  if (!events.length) {
    tbody.innerHTML = '<tr><td colspan="7" class="empty-state">暂无事件数据</td></tr>';
    document.getElementById('eventStreamPagination').innerHTML = '';
    return;
  }

  tbody.innerHTML = events.map(e => {
    const props = e.properties && Object.keys(e.properties).length
      ? `<span style="font-size:11px;color:var(--text-muted);font-family:monospace;">${JSON.stringify(e.properties).substring(0, 80)}</span>`
      : '-';
    return `
    <tr>
      <td style="font-size:12px;white-space:nowrap;">${formatDate(e.createdAt)}</td>
      <td><span class="uuid-cell" onclick="copyToClipboard('${e.userId}')" title="${e.userId}">${e.userId.substring(0, 8)}...</span></td>
      <td style="font-weight:500;">${e.eventName}</td>
      <td><span class="event-tag cat-${e.eventCategory}">${e.eventCategory}</span></td>
      <td style="font-size:12px;">${e.platform || '-'}</td>
      <td style="font-size:12px;">${e.appVersion || '-'}</td>
      <td>${props}</td>
    </tr>`;
  }).join('');

  renderPagination('eventStreamPagination', pagination, loadEventStream);
}
