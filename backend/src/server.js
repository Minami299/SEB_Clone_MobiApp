const app = require('./app');
const config = require('./config');
const connectDB = require('./config/database');

const startServer = async () => {
  await connectDB();

  app.listen(config.port, () => {
    console.log(`Server is running on port ${config.port} in ${config.nodeEnv} mode`);
  });
};

startServer();


