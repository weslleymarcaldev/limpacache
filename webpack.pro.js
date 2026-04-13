//@ts-check
'use strict';

const path = require('path');
const base = require('./webpack.config.js');

/** @type {import('webpack').Configuration} */
const config = base({}, { mode: 'production' });

// Swap stub files with pro implementations at build time
config.resolve = {
  ...config.resolve,
  alias: {
    [path.resolve(__dirname, 'src/aiAssistant.ts')]: path.resolve(__dirname, 'src/pro/aiAssistant.ts'),
    [path.resolve(__dirname, 'src/scheduler.ts')]:   path.resolve(__dirname, 'src/pro/scheduler.ts'),
  }
};

module.exports = config;
