const onlineUsers = new Map(); // userId -> { socketIds: Set, lastHeartbeat, typingTo, hiddenOnline, hiddenTyping, hiddenLastSeen, hiddenLocation }

module.exports = {
  addSocket(userId, socketId, privacy = {}) {
    if (!onlineUsers.has(userId)) {
      onlineUsers.set(userId, {
        socketIds: new Set(),
        lastHeartbeat: Date.now(),
        typingTo: null,
        hiddenOnline: privacy.hiddenOnline ?? false,
        hiddenTyping: privacy.hiddenTyping ?? false,
        hiddenLastSeen: privacy.hiddenLastSeen ?? false,
        hiddenLocation: privacy.hiddenLocation ?? false,
      });
    } else {
      // Sync privacy settings on reconnect
      const user = onlineUsers.get(userId);
      if (privacy.hiddenOnline !== undefined) user.hiddenOnline = privacy.hiddenOnline;
      if (privacy.hiddenTyping !== undefined) user.hiddenTyping = privacy.hiddenTyping;
      if (privacy.hiddenLastSeen !== undefined) user.hiddenLastSeen = privacy.hiddenLastSeen;
      if (privacy.hiddenLocation !== undefined) user.hiddenLocation = privacy.hiddenLocation;
    }
    const user = onlineUsers.get(userId);
    user.socketIds.add(socketId);
    user.lastHeartbeat = Date.now();
    return user.socketIds.size === 1; // first connection
  },

  removeSocket(userId, socketId) {
    const user = onlineUsers.get(userId);
    if (!user) return false;
    user.socketIds.delete(socketId);
    if (user.socketIds.size === 0) {
      // Keep for a while to allow heartbeat consistency check
      user.lastHeartbeat = Date.now();
      // Option: We could delete it, but keeping it lets isOnline handle the 40s timeout
      return true; // went offline (socket-wise)
    }
    return false;
  },

  updateHeartbeat(userId) {
    const user = onlineUsers.get(userId);
    if (user) user.lastHeartbeat = Date.now();
  },

  isOnline(userId) {
    const user = onlineUsers.get(userId);
    if (!user) return false;
    // 40s grace period for heartbeats
    return (Date.now() - user.lastHeartbeat) < 40000;
  },

  canSeeOnlineStatus(targetUserId, viewerUserId) {
    const target = onlineUsers.get(targetUserId);
    if (!target) return false;
    if (target.hiddenOnline && targetUserId !== viewerUserId) return false;
    return this.isOnline(targetUserId);
  },

  canSeeTyping(targetUserId, viewerUserId) {
    const target = onlineUsers.get(targetUserId);
    if (!target) return false;
    if (target.hiddenTyping && targetUserId !== viewerUserId) return false;
    return true;
  },

  isTypingTo(userId, targetId) {
    const user = onlineUsers.get(userId);
    if (!user) return false;
    return user.typingTo === targetId;
  },

  updateTyping(userId, targetId) {
    const user = onlineUsers.get(userId);
    if (user) {
      user.typingTo = targetId;
      // Auto-expire after 4 seconds
      if (targetId) {
        setTimeout(() => {
          const u = onlineUsers.get(userId);
          if (u && u.typingTo === targetId) u.typingTo = null;
        }, 4000);
      }
    }
  },

  getLastSeen(userId, viewerUserId) {
    const user = onlineUsers.get(userId);
    if (!user) return null;
    if (user.hiddenLastSeen && userId !== viewerUserId) return null;
    return new Date(user.lastHeartbeat).toISOString();
  },

  // Keep compatibility with existing privacy setting updates
  setPrivacySettings(userId, settings) {
    if (onlineUsers.has(userId)) {
      const user = onlineUsers.get(userId);
      Object.assign(user, settings);
    }
  },

  getPrivacySettings(userId) {
    const user = onlineUsers.get(userId);
    if (!user) return null;
    return {
      hiddenOnline: user.hiddenOnline,
      hiddenTyping: user.hiddenTyping,
      hiddenLastSeen: user.hiddenLastSeen,
      hiddenLocation: user.hiddenLocation
    };
  }
};
