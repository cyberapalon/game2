const path = require('node:path');
const prepared = require('./playwright.config.cjs');

// Exercise the existing real-keyboard route under a Pages-style subdirectory,
// using an ordinary static server without cross-origin isolation headers.
process.env.GODOT_WEB_BASE_PATH = '/game2';
const directory = process.env.GODOT_WEB_DIR || path.resolve(__dirname, '../../build/pages-preview');
module.exports = {
  ...prepared,
  testMatch: 'route.spec.cjs',
  outputDir: path.resolve(__dirname, '../../reports/pages/artifacts'),
  reporter: [['list'], ['json', { outputFile: path.resolve(__dirname, '../../reports/pages/results.json') }]],
  use: { ...prepared.use, baseURL: 'http://127.0.0.1:8866' },
  webServer: {
    command: 'python3 -m http.server 8866 --bind 127.0.0.1 --directory "' + directory + '"',
    url: 'http://127.0.0.1:8866/game2/index.html',
    timeout: 15000,
    reuseExistingServer: false,
  },
};
