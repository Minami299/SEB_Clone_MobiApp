require('dotenv').config();

module.exports = {
  port: process.env.PORT || 5000,
  nodeEnv: process.env.NODE_ENV || 'development',
  mongoUri: process.env.MONGODB_URI || 'mongodb://localhost:27017/seb_clone',
  jwt: {
    secret: process.env.JWT_SECRET || 'seb_clone_secret_key_default',
    expiresIn: process.env.JWT_EXPIRES_IN || '1d'
  }
};


