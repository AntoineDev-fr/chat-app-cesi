const els = {
  apiUrl: document.getElementById('api-url'),
  username: document.getElementById('username'),
  password: document.getElementById('password'),
  loginBtn: document.getElementById('login-btn'),
  logoutBtn: document.getElementById('logout-btn'),
  authStatus: document.getElementById('auth-status'),
  sessionUser: document.getElementById('session-user'),
  usersList: document.getElementById('users-list'),
  refreshUsers: document.getElementById('refresh-users'),
  chatTitle: document.getElementById('chat-title'),
  chatSubtitle: document.getElementById('chat-subtitle'),
  messages: document.getElementById('messages'),
  sendForm: document.getElementById('send-form'),
  messageInput: document.getElementById('message-input'),
  sendBtn: document.querySelector('#send-form button'),
  pollingBadge: document.getElementById('polling-status'),
};

const state = {
  token: null,
  userId: null,
  username: null,
  api: 'http://localhost:8080',
  selectedUser: null,
  messages: [],
  lastMessageId: 0,
  pollTimer: null,
};

function saveSession() {
  localStorage.setItem('chat_api', state.api);
  if (state.token) {
    localStorage.setItem('chat_token', state.token);
    localStorage.setItem('chat_user', JSON.stringify({ id: state.userId, username: state.username }));
  } else {
    localStorage.removeItem('chat_token');
    localStorage.removeItem('chat_user');
  }
}

function loadSession() {
  const savedApi = localStorage.getItem('chat_api');
  if (savedApi) state.api = savedApi;
  els.apiUrl.value = state.api;

  const token = localStorage.getItem('chat_token');
  const user = localStorage.getItem('chat_user');
  if (token && user) {
    try {
      const parsed = JSON.parse(user);
      state.token = token;
      state.userId = parsed.id;
      state.username = parsed.username;
      updateSessionUI();
      fetchUsers();
    } catch (_) {
      clearSession();
    }
  }
}

function updateSessionUI() {
  if (state.token) {
    els.sessionUser.textContent = `${state.username} (#${state.userId})`;
    els.messageInput.disabled = false;
    els.sendBtn.disabled = false;
  } else {
    els.sessionUser.textContent = 'Non connecte';
    els.messageInput.disabled = true;
    els.sendBtn.disabled = true;
    els.usersList.innerHTML = 'Connecte-toi pour charger les utilisateurs.';
    els.usersList.classList.add('empty');
  }
}

function setStatus(text, type = '') {
  els.authStatus.textContent = text;
  els.authStatus.className = `status ${type}`;
}

function clearSession() {
  state.token = null;
  state.userId = null;
  state.username = null;
  state.selectedUser = null;
  state.messages = [];
  stopPolling();
  renderMessages();
  updateSessionUI();
  saveSession();
}

async function login() {
  const api = els.apiUrl.value.trim();
  const username = els.username.value.trim();
  const password = els.password.value;
  if (!api || !username || !password) {
    setStatus('URL, username et mot de passe requis.', 'error');
    return;
  }
  setStatus('Connexion en cours...');
  try {
    const res = await fetch(`${api}/auth`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Erreur API');

    state.api = api;
    state.token = data.token;
    state.userId = data.user_id;
    state.username = data.username;
    saveSession();
    updateSessionUI();
    setStatus('Connecte', 'ok');
    fetchUsers();
  } catch (err) {
    console.error(err);
    setStatus(err.message || 'Erreur inconnue', 'error');
  }
}

function authHeaders() {
  return state.token ? { Authorization: `Bearer ${state.token}` } : {};
}

async function fetchUsers() {
  if (!state.token) return;
  els.usersList.innerHTML = 'Chargement...';
  els.usersList.classList.add('empty');
  try {
    const res = await fetch(`${state.api}/users`, { headers: authHeaders() });
    if (res.status === 401) {
      clearSession();
      setStatus('Session expiree, reconnecte-toi.', 'error');
      return;
    }
    const data = await res.json();
    renderUsers(data.users || []);
  } catch (err) {
    console.error(err);
    els.usersList.innerHTML = 'Erreur lors du chargement.';
  }
}

function renderUsers(users) {
  if (!users || users.length === 0) {
    els.usersList.textContent = 'Aucun autre utilisateur.';
    els.usersList.classList.add('empty');
    return;
  }
  els.usersList.classList.remove('empty');
  els.usersList.innerHTML = '';
  users.forEach((user) => {
    const row = document.createElement('div');
    row.className = `user-row ${state.selectedUser?.id === user.id ? 'active' : ''}`;
    row.innerHTML = `<span>${user.username}</span><span class="pill">#${user.id}</span>`;
    row.onclick = () => selectUser(user);
    els.usersList.appendChild(row);
  });
}

async function selectUser(user) {
  state.selectedUser = user;
  state.messages = [];
  state.lastMessageId = 0;
  els.chatTitle.textContent = `Conversation avec ${user.username} (#${user.id})`;
  els.chatSubtitle.textContent = 'Historique en cours de chargement...';
  renderMessages();
  await fetchHistory();
}

async function fetchHistory() {
  if (!state.selectedUser) return;
  try {
    const res = await fetch(
      `${state.api}/messages/history?with=${state.selectedUser.id}&limit=50`,
      { headers: authHeaders() }
    );
    if (!res.ok) throw new Error('Impossible de charger l\'historique');
    const data = await res.json();
    state.messages = data.messages || [];
    state.lastMessageId = state.messages.length ? state.messages[state.messages.length - 1].id : 0;
    els.chatSubtitle.textContent = 'Derniers messages';
    renderMessages(true);
    startPolling();
  } catch (err) {
    console.error(err);
    els.chatSubtitle.textContent = 'Erreur de chargement.';
  }
}

function startPolling() {
  stopPolling();
  els.pollingBadge.textContent = 'Live';
  els.pollingBadge.classList.add('active');
  state.pollTimer = setInterval(getNewMessages, 2000);
}

function stopPolling() {
  if (state.pollTimer) clearInterval(state.pollTimer);
  state.pollTimer = null;
  els.pollingBadge.textContent = 'Pause';
  els.pollingBadge.classList.remove('active');
}

async function getNewMessages() {
  if (!state.selectedUser) return;
  try {
    const res = await fetch(
      `${state.api}/messages/new?with=${state.selectedUser.id}&since_id=${state.lastMessageId}`,
      { headers: authHeaders() }
    );
    if (!res.ok) return;
    const data = await res.json();
    const fresh = data.messages || [];
    if (fresh.length) {
      state.messages.push(...fresh);
      state.lastMessageId = state.messages[state.messages.length - 1].id;
      renderMessages(true);
    }
  } catch (err) {
    console.error(err);
  }
}

function renderMessages(scroll = false) {
  els.messages.innerHTML = '';
  if (!state.messages.length) {
    els.messages.innerHTML = '<div style="color: var(--muted);">Aucun message.</div>';
    return;
  }
  state.messages.forEach((m) => {
    const isMe = m.sender_id === state.userId;
    const div = document.createElement('div');
    div.className = `message ${isMe ? 'me' : 'them'}`;
    div.innerHTML = `
      <div class="meta">${isMe ? 'Moi' : state.selectedUser?.username || 'Autre'} - ${formatDate(m.created_at)}</div>
      <div class="text">${escapeHtml(m.content)}</div>
    `;
    if (isMe) {
      const del = document.createElement('button');
      del.className = 'delete';
      del.textContent = 'Suppr';
      del.onclick = () => deleteMessage(m.id);
      div.appendChild(del);
    }
    els.messages.appendChild(div);
  });
  if (scroll) {
    els.messages.scrollTop = els.messages.scrollHeight;
  }
}

function escapeHtml(str) {
  return str.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
}

function formatDate(val) {
  try {
    const d = new Date(val);
    return d.toLocaleTimeString();
  } catch {
    return val;
  }
}

async function sendMessage(event) {
  event.preventDefault();
  if (!state.selectedUser || !state.token) return;
  const content = els.messageInput.value.trim();
  if (!content) return;
  els.sendBtn.disabled = true;
  try {
    const res = await fetch(`${state.api}/messages/send`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...authHeaders() },
      body: JSON.stringify({ to: state.selectedUser.id, content }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Erreur envoi');
    const now = new Date().toISOString();
    state.messages.push({
      id: data.message_id,
      sender_id: state.userId,
      receiver_id: state.selectedUser.id,
      content,
      created_at: now,
    });
    state.lastMessageId = data.message_id;
    els.messageInput.value = '';
    renderMessages(true);
  } catch (err) {
    console.error(err);
    setStatus(err.message || 'Erreur envoi', 'error');
  } finally {
    els.sendBtn.disabled = false;
  }
}

async function deleteMessage(id) {
  try {
    const res = await fetch(`${state.api}/messages/delete?id=${id}`, {
      method: 'DELETE',
      headers: authHeaders(),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Suppression impossible');
    state.messages = state.messages.filter((m) => m.id !== id);
    renderMessages();
  } catch (err) {
    console.error(err);
    setStatus(err.message || 'Erreur suppression', 'error');
  }
}

function bindEvents() {
  els.loginBtn.addEventListener('click', login);
  els.refreshUsers.addEventListener('click', fetchUsers);
  els.sendForm.addEventListener('submit', sendMessage);
  els.logoutBtn.addEventListener('click', () => {
    clearSession();
    setStatus('Deconnecte');
  });
  els.apiUrl.addEventListener('change', () => {
    state.api = els.apiUrl.value.trim();
    saveSession();
  });
}

bindEvents();
loadSession();
