const path = require('node:path');
const prepared = require('/workspace/.godot-cloud/playwright.config.cjs');

// Reuse the pinned runner, browser and HTTP server; install no second toolchain.
module.exports = {
  ...prepared,
  testDir: __dirname,
  outputDir: path.resolve(__dirname, '../../reports/web/artifacts'),
  reporter: [['list'], ['json', {
    outputFile: path.resolve(__dirname, '../../reports/web/results.json'),
  }]],
  use: { ...prepared.use, viewport: { width: 960, height: 540 } },
};
