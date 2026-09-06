// Between Us — High-Fidelity Dual-Device Realtime Engine & Web Audio Sandbox

// Shared Global Couple State
const CoupleSpace = {
  id: 'couple_89412',
  status: 'connected',
  createdDays: 142,
  userA: { id: 'usr_jeet', name: 'Jeet', initials: 'J', mood: 'loving', battery: 92, online: true },
  userB: { id: 'usr_ananya', name: 'Ananya', initials: 'A', mood: 'missYou', battery: 78, online: true },
  distanceMeters: 1247000,
  nextMeeting: { title: 'Reunion in Mumbai', days: 14, hours: 8, mins: 22 },
  messages: [
    { id: 'm1', sender: 'usr_ananya', text: 'Good morning my love! How is your day starting?', time: '08:30 AM', reactions: '❤️' },
    { id: 'm2', sender: 'usr_jeet', text: 'Woke up thinking about you. Counting down the days! ❤️', time: '08:42 AM', reactions: '' },
    { id: 'm3', sender: 'usr_ananya', isVoice: true, duration: '0:14', time: '11:15 AM', reactions: '🥰' },
  ],
  music: {
    title: 'Tum Mile (Atmospheric Ambient)',
    artist: 'Pritam / DuoSpace Acoustic',
    category: 'Romantic',
    isPlaying: false,
    positionSec: 45,
    durationSec: 240,
    serverTimestamp: Date.now(),
    playlist: [
      { id: 's1', title: 'Tum Mile (Atmospheric Ambient)', artist: 'Pritam / DuoSpace Acoustic', category: 'Romantic' },
      { id: 's2', title: 'Midnight Distance (Lofi Waves)', artist: 'BetweenUs Chill', category: 'Late Night' },
      { id: 's3', title: 'Holding Your Hand in Paris', artist: 'Acoustic Memories', category: 'Our Memories' },
      { id: 's4', title: 'Sunlight on Your Face', artist: 'Morning Breeze', category: 'Happy' },
    ]
  },
  memories: [
    { id: 'mem1', date: 'September 5, 2025', title: 'Our First Sunset Walk', caption: 'Wish you were here watching the sky turn pink with me.', loc: 'Marine Drive, Mumbai', by: 'Jeet' },
    { id: 'mem2', date: 'April 12, 2026', title: 'Airport Goodbyes', caption: 'Every goodbye means one step closer to our next hello.', loc: 'IGI Airport, Delhi', by: 'Ananya' },
  ],
  activeTabA: 'home',
  activeTabB: 'home',
  momentOverlayA: null,
  momentOverlayB: null,
};

// Web Audio API Synthesizer for Synchronized Music Playback
let audioCtx = null;
let musicOscillator = null;
let musicGain = null;
let musicInterval = null;

function initAudio() {
  if (!audioCtx) {
    audioCtx = new (window.AudioContext || window.webkitAudioContext)();
  }
}

function playSynthesizedChords() {
  initAudio();
  if (audioCtx.state === 'suspended') {
    audioCtx.resume();
  }

  if (musicOscillator) {
    try { musicOscillator.stop(); } catch(e) {}
  }

  musicGain = audioCtx.createGain();
  musicGain.gain.setValueAtTime(0.08, audioCtx.currentTime);
  musicGain.connect(audioCtx.destination);

  musicOscillator = audioCtx.createOscillator();
  musicOscillator.type = 'triangle';
  musicOscillator.frequency.setValueAtTime(220, audioCtx.currentTime); // A3 Warm Drone
  musicOscillator.connect(musicGain);
  musicOscillator.start();
}

function stopSynthesizedChords() {
  if (musicGain && audioCtx) {
    musicGain.gain.exponentialRampToValueAtTime(0.0001, audioCtx.currentTime + 0.5);
    setTimeout(() => {
      if (musicOscillator) {
        try { musicOscillator.stop(); } catch(e) {}
        musicOscillator = null;
      }
    }, 500);
  }
}

// Proximity Classification Engine
function getProximityData(meters) {
  if (meters <= 60) {
    return {
      label: 'TOGETHER',
      distText: 'Together ❤️',
      quote: 'No more distance between us.',
      color: '#ff5470'
    };
  } else if (meters <= 500) {
    return {
      label: 'VERY CLOSE',
      distText: `${meters.toFixed(0)} m apart`,
      quote: 'Just a little distance left.',
      color: '#48cae4'
    };
  } else if (meters <= 5000) {
    return {
      label: 'NEARBY',
      distText: `${(meters / 1000).toFixed(1)} km apart`,
      quote: 'You are in the same city.',
      color: '#2ec4b6'
    };
  } else if (meters <= 50000) {
    return {
      label: 'GETTING CLOSER',
      distText: `${(meters / 1000).toFixed(0)} km apart`,
      quote: 'The distance is getting smaller.',
      color: '#ffd166'
    };
  } else {
    return {
      label: 'LONG DISTANCE',
      distText: `${(meters / 1000).toLocaleString()} km apart`,
      quote: 'Far apart, still part of each other’s day.',
      color: '#8e8ca3'
    };
  }
}

// Render Device Screen
function renderScreen(deviceKey, containerId) {
  const container = document.getElementById(containerId);
  const isA = deviceKey === 'A';
  const me = isA ? CoupleSpace.userA : CoupleSpace.userB;
  const partner = isA ? CoupleSpace.userB : CoupleSpace.userA;
  const activeTab = isA ? CoupleSpace.activeTabA : CoupleSpace.activeTabB;
  const momentOverlay = isA ? CoupleSpace.momentOverlayA : CoupleSpace.momentOverlayB;

  const prox = getProximityData(CoupleSpace.distanceMeters);

  let tabContent = '';

  if (activeTab === 'home') {
    tabContent = `
      <div class="top-nav">
        <div class="top-title">❤️ Our Space</div>
        <div class="day-badge">Day ${CoupleSpace.createdDays}</div>
      </div>
      <div class="app-body">
        <!-- Presence Bar -->
        <div class="presence-card">
          <div class="partner-bubble" onclick="openMoodPicker('${deviceKey}')">
            <div class="avatar-ring me">
              ${me.initials}
              <div class="mood-badge">${getMoodEmoji(me.mood)}</div>
              <div class="online-dot"></div>
            </div>
            <div class="bubble-name">${me.name} (You)</div>
            <div class="bubble-battery">🔋 ${me.battery}%</div>
          </div>

          <div class="presence-center">
            <div class="infinity-icon">♾️</div>
            <span style="font-size: 9px; color: var(--text-muted); font-weight:700;">CONNECTED</span>
          </div>

          <div class="partner-bubble">
            <div class="avatar-ring">
              ${partner.initials}
              <div class="mood-badge">${getMoodEmoji(partner.mood)}</div>
              <div class="online-dot"></div>
            </div>
            <div class="bubble-name">${partner.name}</div>
            <div class="bubble-battery">🔋 ${partner.battery}%</div>
          </div>
        </div>

        <!-- Ambient Map -->
        <div class="map-card">
          <canvas id="mapCanvas_${deviceKey}" class="map-canvas"></canvas>
          <div class="map-privacy-tag">🔒 Private Partner-to-Partner Location</div>
        </div>

        <!-- Proximity Badge -->
        <div class="proximity-card" style="border-color: ${prox.color}55;">
          <div class="proximity-header" style="color: ${prox.color};">
            <span style="display:inline-block; width:6px; height:6px; background:${prox.color}; border-radius:50%;"></span>
            ${prox.label}
          </div>
          <div class="distance-number">${prox.distText}</div>
          <div class="emotional-quote">“${prox.quote}”</div>
        </div>

        <!-- Meeting Countdown -->
        <div class="countdown-card">
          <div class="countdown-title">✈️ ${CoupleSpace.nextMeeting.title.toUpperCase()}</div>
          <div class="countdown-timer">
            <div class="time-unit"><div class="time-val">${CoupleSpace.nextMeeting.days}</div><div class="time-lbl">DAYS</div></div>
            <div style="font-size:18px; color:var(--text-muted);">:</div>
            <div class="time-unit"><div class="time-val">${CoupleSpace.nextMeeting.hours}</div><div class="time-lbl">HOURS</div></div>
            <div style="font-size:18px; color:var(--text-muted);">:</div>
            <div class="time-unit"><div class="time-val">${CoupleSpace.nextMeeting.mins}</div><div class="time-lbl">MINS</div></div>
          </div>
        </div>

        <!-- Emotional Quick Moments -->
        <div>
          <div class="actions-title">
            <span>Quick Moments</span>
            <span style="font-size: 11px; color: var(--lavender-soft); cursor:pointer;" onclick="openMoodPicker('${deviceKey}')">Mood: ${me.mood} ✏️</span>
          </div>
          <div class="actions-row" style="margin-top: 8px;">
            <div class="btn-action rose" onclick="sendMoment('${deviceKey}', 'missYou')">
              <span style="font-size: 20px;">❤️</span>
              <span class="action-label">Miss You</span>
            </div>
            <div class="btn-action amber" onclick="sendMoment('${deviceKey}', 'hug')">
              <span style="font-size: 20px;">🫂</span>
              <span class="action-label">Hug</span>
            </div>
            <div class="btn-action lavender" onclick="sendMoment('${deviceKey}', 'kiss')">
              <span style="font-size: 20px;">😘</span>
              <span class="action-label">Kiss</span>
            </div>
            <div class="btn-action teal" onclick="sendCustomNotePrompt('${deviceKey}')">
              <span style="font-size: 20px;">💌</span>
              <span class="action-label">Note</span>
            </div>
          </div>
        </div>
      </div>
    `;
  } else if (activeTab === 'chat') {
    tabContent = `
      <div class="top-nav">
        <div class="top-title">${partner.name} <span class="badge-private" style="font-size:9px;">● PRIVATE</span></div>
        <div style="font-size:18px; cursor:pointer;" title="Disappearing Messages">⏱️</div>
      </div>
      <div class="chat-container">
        <div class="chat-messages" id="chatMsgs_${deviceKey}">
          ${CoupleSpace.messages.map(m => {
            const isSent = m.sender === me.id;
            return `
              <div class="msg-bubble ${isSent ? 'sent' : 'received'}">
                ${m.isVoice ? '🎙️ Voice Note (0:14) ılıılıllılıı' : m.text}
                <div class="msg-meta">${m.time} ${isSent ? '✓✓' : ''} ${m.reactions ? '<span>' + m.reactions + '</span>' : ''}</div>
              </div>
            `;
          }).join('')}
        </div>
        <div class="chat-input-bar">
          <button style="background:none; border:none; color:var(--text-secondary); font-size:18px; cursor:pointer;" onclick="sendVoiceSim('${deviceKey}')">🎙️</button>
          <input type="text" class="chat-input" id="chatInput_${deviceKey}" placeholder="Message ${partner.name}..." onkeydown="if(event.key==='Enter') sendChatMsg('${deviceKey}')">
          <button class="btn-send" onclick="sendChatMsg('${deviceKey}')">➤</button>
        </div>
      </div>
    `;
  } else if (activeTab === 'together') {
    const m = CoupleSpace.music;
    const progressPercent = (m.positionSec / m.durationSec) * 100;
    tabContent = `
      <div class="top-nav">
        <div class="top-title">Together Music 🎵</div>
        <div style="font-size:11px; color:var(--teal-proximity); font-weight:700;">● SYNCED</div>
      </div>
      <div class="app-body">
        <div style="background:var(--bg-surface); border:1px solid var(--bg-border); border-radius:24px; padding:20px; text-align:center;">
          <div style="width:100px; height:100px; border-radius:50%; background:var(--bg-surface-elevated); border:3px solid var(--rose-primary); margin:0 auto; display:flex; align-items:center; justify-content:center; box-shadow:0 0 24px var(--rose-glow); ${m.isPlaying ? 'animation: spinVinyl 6s linear infinite;' : ''}">
            <div style="width:30px; height:30px; border-radius:50%; background:var(--amber-warm); display:flex; align-items:center; justify-content:center; color:#000;">🎵</div>
          </div>
          <style>
            @keyframes spinVinyl { 100% { transform: rotate(360deg); } }
          </style>

          <div style="font-family:var(--font-display); font-size:16px; font-weight:700; margin-top:14px;">${m.title}</div>
          <div style="font-size:12px; color:var(--text-secondary); margin-top:2px;">${m.artist}</div>

          <!-- Synced Scrubber -->
          <div style="margin-top:16px;">
            <div style="width:100%; height:4px; background:var(--bg-border); border-radius:2px; position:relative; cursor:pointer;" onclick="seekMusic(event)">
              <div style="width:${progressPercent}%; height:100%; background:var(--rose-primary); border-radius:2px;"></div>
            </div>
            <div style="display:flex; justify-content:space-between; font-size:10px; color:var(--text-muted); margin-top:4px;">
              <span>${formatTime(m.positionSec)}</span>
              <span>${formatTime(m.durationSec)}</span>
            </div>
          </div>

          <!-- Controls -->
          <div style="display:flex; align-items:center; justify-content:center; gap:20px; margin-top:14px;">
            <button style="background:none; border:none; color:#fff; font-size:20px; cursor:pointer;" onclick="skipTrack(-1)">⏮</button>
            <button style="width:50px; height:50px; border-radius:50%; background:var(--rose-primary); border:none; color:#fff; font-size:22px; cursor:pointer; box-shadow:0 4px 16px var(--rose-glow);" onclick="toggleMusicPlayback()">${m.isPlaying ? '⏸' : '▶'}</button>
            <button style="background:none; border:none; color:#fff; font-size:20px; cursor:pointer;" onclick="skipTrack(1)">⏭</button>
          </div>
        </div>

        <!-- Playlist -->
        <div style="font-size:13px; font-weight:600; margin-top:6px;">Shared Playlist</div>
        <div style="display:flex; flex-direction:column; gap:8px;">
          ${m.playlist.map((p, idx) => `
            <div style="background:var(--bg-surface); border:1px solid ${p.title === m.title ? 'var(--rose-primary)' : 'var(--bg-border)'}; border-radius:14px; padding:10px 14px; display:flex; align-items:center; justify-content:space-between; cursor:pointer;" onclick="selectSong('${p.id}')">
              <div>
                <div style="font-size:12px; font-weight:600; color:${p.title === m.title ? 'var(--rose-primary)' : '#fff'}">${p.title}</div>
                <div style="font-size:10px; color:var(--text-muted);">${p.artist} · ${p.category}</div>
              </div>
              <div style="font-size:14px;">${p.title === m.title && m.isPlaying ? '🔊' : '▶'}</div>
            </div>
          `).join('')}
        </div>
      </div>
    `;
  } else if (activeTab === 'memories') {
    tabContent = `
      <div class="top-nav">
        <div class="top-title">Our Story Timeline 📖</div>
        <div style="font-size:16px; color:var(--rose-primary); cursor:pointer;" onclick="promptAddMemory('${deviceKey}')">➕</div>
      </div>
      <div class="app-body">
        <div style="background:linear-gradient(135deg, rgba(255,84,112,0.2), var(--bg-surface-elevated)); border:1px solid rgba(255,84,112,0.4); border-radius:18px; padding:14px;">
          <div style="font-size:9px; font-weight:700; color:var(--amber-warm); letter-spacing:1px;">✨ ON THIS DAY LAST YEAR</div>
          <div style="font-size:14px; font-weight:700; margin-top:6px;">Our First Sunset Walk</div>
          <div style="font-family:var(--font-quote); font-style:italic; font-size:12px; color:#fff; margin-top:2px;">“Wish you were here watching the sky turn pink with me.”</div>
        </div>

        <div style="font-size:13px; font-weight:600; margin-top:6px;">All Memories</div>
        ${CoupleSpace.memories.map(mem => `
          <div style="background:var(--bg-surface); border:1px solid var(--bg-border); border-radius:16px; padding:14px;">
            <div style="display:flex; justify-content:space-between; font-size:11px; color:var(--amber-warm); font-weight:600;">
              <span>📅 ${mem.date}</span>
              <span style="color:var(--text-muted);">📍 ${mem.loc}</span>
            </div>
            <div style="font-size:14px; font-weight:600; margin-top:6px;">${mem.title}</div>
            <div style="font-family:var(--font-quote); font-style:italic; font-size:12px; color:var(--text-primary); margin-top:4px;">“${mem.caption}”</div>
            <div style="font-size:9px; color:var(--text-muted); margin-top:8px;">Saved by ${mem.by}</div>
          </div>
        `).join('')}
      </div>
    `;
  } else if (activeTab === 'us') {
    tabContent = `
      <div class="top-nav">
        <div class="top-title">Us & Settings 🔒</div>
      </div>
      <div class="app-body">
        <div style="background:var(--bg-surface); border:1px solid var(--bg-border); border-radius:18px; padding:14px;">
          <div style="font-size:13px; font-weight:600;">Couple Space: Jeet & Ananya</div>
          <div style="font-size:10px; color:var(--text-muted); margin-top:2px;">E2EE Space ID: ${CoupleSpace.id}</div>
        </div>

        <div style="background:var(--bg-surface); border:1px solid var(--bg-border); border-radius:18px; padding:14px; display:flex; flex-direction:column; gap:12px;">
          <div style="display:flex; justify-content:space-between; align-items:center;">
            <div>
              <div style="font-size:12px; font-weight:600;">Live Location Sharing</div>
              <div style="font-size:10px; color:var(--text-muted);">Battery-aware motion updates</div>
            </div>
            <input type="checkbox" checked style="accent-color:var(--teal-proximity);">
          </div>
          <div style="display:flex; justify-content:space-between; align-items:center;">
            <div>
              <div style="font-size:12px; font-weight:600;">Quiet Hours (11PM - 7AM)</div>
              <div style="font-size:10px; color:var(--text-muted);">Silence non-urgent notifications</div>
            </div>
            <input type="checkbox" checked style="accent-color:var(--lavender-soft);">
          </div>
        </div>

        <div style="background:var(--bg-surface); border:1px solid rgba(239,71,111,0.3); border-radius:18px; padding:14px; cursor:pointer;" onclick="alert('In production, this securely unlinks device tokens and erases local couple storage.')">
          <div style="font-size:12px; font-weight:600; color:var(--error);">🔗 Disconnect & Unpair Space</div>
          <div style="font-size:10px; color:var(--text-muted); margin-top:2px;">Requires confirmation from both partners</div>
        </div>
      </div>
    `;
  }

  // Persistent mini-player if playing and not on together tab
  let miniPlayerHtml = '';
  if (CoupleSpace.music.isPlaying && activeTab !== 'together') {
    miniPlayerHtml = `
      <div class="mini-player" onclick="switchTab('${deviceKey}', 'together')">
        <div class="mini-thumb">🎵</div>
        <div class="mini-info">
          <div class="mini-title">${CoupleSpace.music.title}</div>
          <div class="mini-sub">Listening with ${partner.name}</div>
        </div>
        <div style="font-size:16px; color:var(--rose-primary); cursor:pointer;" onclick="event.stopPropagation(); toggleMusicPlayback();">⏸</div>
      </div>
    `;
  }

  // Bottom Navigation
  const bottomNavHtml = `
    <div class="bottom-nav">
      <div class="nav-item ${activeTab === 'home' ? 'active' : ''}" onclick="switchTab('${deviceKey}', 'home')">
        <div class="nav-icon">❤️</div>
        <div class="nav-label">Home</div>
      </div>
      <div class="nav-item ${activeTab === 'chat' ? 'active' : ''}" onclick="switchTab('${deviceKey}', 'chat')">
        <div class="nav-icon">💬</div>
        <div class="nav-label">Chat</div>
      </div>
      <div class="nav-item ${activeTab === 'together' ? 'active' : ''}" onclick="switchTab('${deviceKey}', 'together')">
        <div class="nav-icon">🎵</div>
        <div class="nav-label">Together</div>
      </div>
      <div class="nav-item ${activeTab === 'memories' ? 'active' : ''}" onclick="switchTab('${deviceKey}', 'memories')">
        <div class="nav-icon">📖</div>
        <div class="nav-label">Memories</div>
      </div>
      <div class="nav-item ${activeTab === 'us' ? 'active' : ''}" onclick="switchTab('${deviceKey}', 'us')">
        <div class="nav-icon">👤</div>
        <div class="nav-label">Us</div>
      </div>
    </div>
  `;

  // Love Moment Overlay
  let overlayHtml = '';
  if (momentOverlay) {
    overlayHtml = `
      <div class="moment-overlay">
        <canvas id="particleCanvas_${deviceKey}" class="particle-canvas"></canvas>
        <div class="moment-icon-large">${momentOverlay.icon}</div>
        <div class="moment-title">${momentOverlay.title}</div>
        <div class="moment-quote">“${momentOverlay.msg}”</div>
        <button class="btn-moment-back" onclick="sendMoment('${deviceKey}', 'hug'); closeMoment('${deviceKey}');">Send Warm Hug Back 🫂</button>
        <button class="btn-moment-close" onclick="closeMoment('${deviceKey}')">Close</button>
      </div>
    `;
  }

  container.innerHTML = `
    <div class="app-view">
      ${tabContent}
      ${miniPlayerHtml}
      ${bottomNavHtml}
      ${overlayHtml}
    </div>
  `;

  // Draw Map Canvas if on home tab
  if (activeTab === 'home') {
    drawAmbientMap(`mapCanvas_${deviceKey}`, isA);
  }

  // Animate particle canvas if moment overlay is active
  if (momentOverlay) {
    animateHeartParticles(`particleCanvas_${deviceKey}`);
  }
}

function getMoodEmoji(mood) {
  const map = { happy: '😊', loving: '🥰', missYou: '🥺', sad: '😔', angry: '😡', tired: '😴', intimate: '🔥' };
  return map[mood] || '🥰';
}

function formatTime(sec) {
  const m = Math.floor(sec / 60);
  const s = Math.floor(sec % 60);
  return `${m}:${s < 10 ? '0' : ''}${s}`;
}

// Canvas Map Drawing with Animated Geodesic Arc
function drawAmbientMap(canvasId, isA) {
  const canvas = document.getElementById(canvasId);
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  canvas.width = canvas.parentElement.clientWidth;
  canvas.height = canvas.parentElement.clientHeight;

  // Background Grid
  ctx.strokeStyle = '#1e1b33';
  ctx.lineWidth = 0.5;
  for (let x = 0; x < canvas.width; x += 30) {
    ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, canvas.height); ctx.stroke();
  }
  for (let y = 0; y < canvas.height; y += 30) {
    ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(canvas.width, y); ctx.stroke();
  }

  // Geodesic Arc
  const startX = 45;
  const startY = 75;
  const endX = canvas.width - 45;
  const endY = canvas.height - 55;

  ctx.beginPath();
  ctx.moveTo(startX, startY);
  ctx.bezierCurveTo(canvas.width * 0.35, 20, canvas.width * 0.65, canvas.height - 15, endX, endY);
  ctx.strokeStyle = 'rgba(255, 84, 112, 0.4)';
  ctx.lineWidth = 6;
  ctx.stroke();

  ctx.strokeStyle = '#ff5470';
  ctx.lineWidth = 2;
  ctx.stroke();

  // Pin A (Left)
  drawPin(ctx, startX, startY, isA ? 'Jeet (You)' : 'Jeet', '#c4b5fd');
  // Pin B (Right)
  drawPin(ctx, endX, endY, !isA ? 'Ananya (You)' : 'Ananya', '#ff5470');
}

function drawPin(ctx, x, y, label, color) {
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.arc(x, y, 7, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = '#fff';
  ctx.lineWidth = 2;
  ctx.stroke();

  // Label pill
  ctx.fillStyle = 'rgba(30, 27, 48, 0.9)';
  ctx.fillRect(x - 30, y - 24, 60, 16);
  ctx.strokeStyle = color;
  ctx.lineWidth = 1;
  ctx.strokeRect(x - 30, y - 24, 60, 16);

  ctx.fillStyle = '#fff';
  ctx.font = '9px Inter';
  ctx.textAlign = 'center';
  ctx.fillText(label, x, y - 13);
}

// Particle explosion
function animateHeartParticles(canvasId) {
  const canvas = document.getElementById(canvasId);
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  canvas.width = canvas.parentElement.clientWidth;
  canvas.height = canvas.parentElement.clientHeight;

  const particles = [];
  for (let i = 0; i < 35; i++) {
    particles.push({
      x: Math.random() * canvas.width,
      y: canvas.height + Math.random() * 50,
      size: 12 + Math.random() * 18,
      speed: 1.5 + Math.random() * 2.5,
      opacity: 0.6 + Math.random() * 0.4,
      color: i % 2 === 0 ? '#ff5470' : '#ffd166',
    });
  }

  function frame() {
    if (!document.getElementById(canvasId)) return;
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    for (let p of particles) {
      p.y -= p.speed;
      p.x += Math.sin(p.y * 0.05) * 1.2;
      ctx.fillStyle = p.color;
      ctx.globalAlpha = p.opacity * (p.y / canvas.height);
      ctx.font = `${p.size}px sans-serif`;
      ctx.fillText('❤️', p.x, p.y);
    }
    requestAnimationFrame(frame);
  }
  frame();
}

// State Action Handlers
function switchTab(deviceKey, tab) {
  if (deviceKey === 'A') CoupleSpace.activeTabA = tab;
  else CoupleSpace.activeTabB = tab;
  renderBoth();
}

function sendMoment(senderDeviceKey, type) {
  const isSenderA = senderDeviceKey === 'A';
  const senderName = isSenderA ? CoupleSpace.userA.name : CoupleSpace.userB.name;
  const targetKey = isSenderA ? 'B' : 'A';

  const typeMap = {
    missYou: { icon: '❤️', title: `${senderName} misses you`, msg: 'Thinking of you across the distance right now.' },
    hug: { icon: '🫂', title: `${senderName} sent you a warm hug`, msg: 'Holding you tight in thought.' },
    kiss: { icon: '😘', title: `${senderName} sent you a sweet kiss`, msg: 'A little sweetness across the miles.' },
    loveNote: { icon: '💌', title: `Love Note from ${senderName}`, msg: 'Just wanted to remind you how much you mean to me.' }
  };

  if (targetKey === 'A') CoupleSpace.momentOverlayA = typeMap[type];
  else CoupleSpace.momentOverlayB = typeMap[type];

  renderBoth();
}

function closeMoment(deviceKey) {
  if (deviceKey === 'A') CoupleSpace.momentOverlayA = null;
  else CoupleSpace.momentOverlayB = null;
  renderBoth();
}

function sendChatMsg(deviceKey) {
  const input = document.getElementById(`chatInput_${deviceKey}`);
  if (!input || !input.value.trim()) return;
  const isA = deviceKey === 'A';
  const senderId = isA ? CoupleSpace.userA.id : CoupleSpace.userB.id;

  CoupleSpace.messages.push({
    id: 'm_' + Date.now(),
    sender: senderId,
    text: input.value.trim(),
    time: 'Now',
    reactions: ''
  });

  input.value = '';
  renderBoth();

  setTimeout(() => {
    const chatA = document.getElementById('chatMsgs_A');
    const chatB = document.getElementById('chatMsgs_B');
    if (chatA) chatA.scrollTop = chatA.scrollHeight;
    if (chatB) chatB.scrollTop = chatB.scrollHeight;
  }, 50);
}

function sendVoiceSim(deviceKey) {
  const isA = deviceKey === 'A';
  const senderId = isA ? CoupleSpace.userA.id : CoupleSpace.userB.id;

  CoupleSpace.messages.push({
    id: 'm_' + Date.now(),
    sender: senderId,
    isVoice: true,
    duration: '0:07',
    time: 'Now',
    reactions: ''
  });
  renderBoth();
}

function toggleMusicPlayback() {
  CoupleSpace.music.isPlaying = !CoupleSpace.music.isPlaying;
  if (CoupleSpace.music.isPlaying) {
    playSynthesizedChords();
    if (!musicInterval) {
      musicInterval = setInterval(() => {
        if (CoupleSpace.music.isPlaying) {
          CoupleSpace.music.positionSec++;
          if (CoupleSpace.music.positionSec >= CoupleSpace.music.durationSec) {
            CoupleSpace.music.positionSec = 0;
          }
          renderBoth();
        }
      }, 1000);
    }
  } else {
    stopSynthesizedChords();
  }
  renderBoth();
}

function seekMusic(e) {
  const rect = e.currentTarget.getBoundingClientRect();
  const clickX = e.clientX - rect.left;
  const ratio = clickX / rect.width;
  CoupleSpace.music.positionSec = Math.floor(ratio * CoupleSpace.music.durationSec);
  renderBoth();
}

function skipTrack(dir) {
  const pl = CoupleSpace.music.playlist;
  let idx = pl.findIndex(s => s.title === CoupleSpace.music.title);
  idx = (idx + dir + pl.length) % pl.length;
  CoupleSpace.music.title = pl[idx].title;
  CoupleSpace.music.artist = pl[idx].artist;
  CoupleSpace.music.category = pl[idx].category;
  CoupleSpace.music.positionSec = 0;
  renderBoth();
}

function selectSong(id) {
  const s = CoupleSpace.music.playlist.find(p => p.id === id);
  if (s) {
    CoupleSpace.music.title = s.title;
    CoupleSpace.music.artist = s.artist;
    CoupleSpace.music.category = s.category;
    CoupleSpace.music.positionSec = 0;
    if (!CoupleSpace.music.isPlaying) toggleMusicPlayback();
    else renderBoth();
  }
}

function openMoodPicker(deviceKey) {
  const moods = ['happy', 'loving', 'missYou', 'sad', 'angry', 'tired', 'intimate'];
  const mood = prompt('Pick your current mood: happy, loving, missYou, sad, angry, tired, intimate', 'loving');
  if (mood && moods.includes(mood)) {
    if (deviceKey === 'A') CoupleSpace.userA.mood = mood;
    else CoupleSpace.userB.mood = mood;
    renderBoth();
  }
}

function sendCustomNotePrompt(deviceKey) {
  const note = prompt('Write a private love note for your partner:');
  if (note) {
    const isSenderA = deviceKey === 'A';
    const senderName = isSenderA ? CoupleSpace.userA.name : CoupleSpace.userB.name;
    const targetKey = isSenderA ? 'B' : 'A';
    const overlay = { icon: '💌', title: `Love Note from ${senderName}`, msg: note };

    if (targetKey === 'A') CoupleSpace.momentOverlayA = overlay;
    else CoupleSpace.momentOverlayB = overlay;
    renderBoth();
  }
}

function promptAddMemory(deviceKey) {
  const title = prompt('Memory Title (e.g. Stargazing on Call):');
  if (title) {
    const caption = prompt('Caption:') || '';
    const loc = prompt('Location / City:') || 'Our Special Place';
    const by = deviceKey === 'A' ? CoupleSpace.userA.name : CoupleSpace.userB.name;
    CoupleSpace.memories.unshift({
      id: 'mem_' + Date.now(),
      date: 'Today',
      title: title,
      caption: caption,
      loc: loc,
      by: by
    });
    renderBoth();
  }
}

// Global Sandbox Controls
document.getElementById('distanceSlider').addEventListener('input', (e) => {
  const km = parseInt(e.target.value);
  CoupleSpace.distanceMeters = km * 1000;
  document.getElementById('sliderDistanceValue').innerText = km > 0 ? `${km.toLocaleString()} km` : '0 m (Together)';
  renderBoth();
});

function simulateTogetherProximity() {
  CoupleSpace.distanceMeters = 30; // 30 meters -> Together state
  document.getElementById('distanceSlider').value = 0;
  document.getElementById('sliderDistanceValue').innerText = '30 m (Together)';
  renderBoth();
}

function triggerDeviceAMissYou() {
  sendMoment('A', 'missYou');
}

function triggerPartnerUpset() {
  CoupleSpace.userB.mood = 'angry';
  renderBoth();
  setTimeout(() => {
    alert('Ananya set her mood to Upset. Jeet can now access the gentle "Make Up" Communication Assistant from his top bar!');
  }, 200);
}

function renderBoth() {
  renderScreen('A', 'screenA');
  renderScreen('B', 'screenB');
}

// Initial Boot
renderBoth();
