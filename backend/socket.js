let io;

module.exports = {
  init: (server) => {
    io = require('socket.io')(server, {
      cors: {
        origin: '*',
        methods: ['GET', 'POST']
      }
    });
    return io;
  },
  getIo: () => {
    if (!io) {
      throw new Error('Socket.io not initialized!');
    }
    return io;
  },
  getSocketIdForUser: (userId) => {
    if (!io) return null;
    const sockets = io.sockets.adapter.rooms.get(userId);
    if (sockets && sockets.size > 0) {
      return Array.from(sockets)[0];
    }
    return null;
  }
};
