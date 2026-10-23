const express = require('express');
const router = express.Router();
const healthRoute = require('./health.route');

router.use('/health', healthRoute);

module.exports = router;

