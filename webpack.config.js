//@ts-check
'use strict';

const path = require('path');

/** @param {any} _env @param {{ mode: string }} argv */
module.exports = (_env, argv) => ({
  target: 'node',
  mode: 'none',
  entry: './src/extension.ts',
  output: {
    path: path.resolve(__dirname, 'dist'),
    filename: 'extension.js',
    libraryTarget: 'commonjs2'
  },
  externals: {
    vscode: 'commonjs vscode'
  },
  resolve: {
    extensions: ['.ts', '.js']
  },
  module: {
    rules: [
      {
        test: /\.ts$/,
        exclude: /node_modules/,
        use: [{ loader: 'ts-loader' }]
      }
    ]
  },
  devtool: argv.mode === 'production' ? false : 'nosources-source-map',
  infrastructureLogging: { level: 'log' }
});
