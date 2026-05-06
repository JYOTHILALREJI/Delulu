const onlineUsers = new Map(); // userId -> Set of socketIds

module.exports = {
  onlineUsers,
  isOnline: (userId) => onlineUsers.has(userId),
  addSocket: (userId, socketId) => {
    if (!onlineUsers.has(userId)) {
      onlineUsers.set(userId, new Set());
    }
    onlineUsers.get(userId).add(socketId);
    return onlineUsers.get(userId).size === 1; // True if first socket for this user
  },
  removeSocket: (userId, socketId) => {
    if (onlineUsers.has(userId)) {
      onlineUsers.get(userId).delete(socketId);
      if (onlineUsers.get(userId).size === 0) {
        onlineUsers.delete(userId);
        return true; // True if last socket removed
      }
    }
    return false;
  }
};
