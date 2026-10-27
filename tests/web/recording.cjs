const fs = require('node:fs');
const path = require('node:path');

// Capture actual rendered browser frames. Encoding uses the already installed
// system FFmpeg afterwards; Playwright's separate FFmpeg build is not needed.
async function recording(page, directory, name) {
  fs.mkdirSync(path.join(directory, name), { recursive: true });
  const session = await page.context().newCDPSession(page);
  const frames = [];
  session.on('Page.screencastFrame', event => {
    const file = `${name}/frame-${String(frames.length).padStart(5, '0')}.jpg`;
    fs.writeFileSync(path.join(directory, file), Buffer.from(event.data, 'base64'));
    frames.push({ file, timestamp: event.metadata.timestamp });
    session.send('Page.screencastFrameAck', { sessionId: event.sessionId }).catch(() => {});
  });
  await session.send('Page.startScreencast', {
    format: 'jpeg', quality: 90, maxWidth: 960, maxHeight: 540, everyNthFrame: 1,
  });
  return async samples => {
    await session.send('Page.stopScreencast');
    await session.detach();
    if (frames.length < 10) throw new Error('Not enough rendered frames for visual review');
    const concat = frames.map((frame, index) => {
      const next = frames[index + 1]?.timestamp ?? frame.timestamp + 1 / 30;
      return `file '${frame.file}'\nduration ${Math.max(0.016, next - frame.timestamp)}\n`;
    }).join('');
    fs.writeFileSync(path.join(directory, `${name}.concat`), concat);
    fs.writeFileSync(path.join(directory, `${name}-recording.json`), JSON.stringify({ name, frames, samples }, null, 2));
  };
}

module.exports = { recording };
