// Run once, right after `flutter create . --platforms=android,ios --project-name classroom360_mobile`.
// It makes the settings the README asks for in the generated android/ and ios/ folders, so nothing is edited by hand:
//   Android: the network permissions, and minSdk 23 (flutter_webrtc needs it)
//   iOS:     the local-network text (the cameras are on the school's network) and the camera/microphone texts flutter_webrtc asks for
// It is safe to run again: it only adds what is missing. It never touches lib/.
//
//   node tool/setup_platforms.mjs        (Node 18 or newer)
import { existsSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const at = (...p) => join(root, ...p);
const said = [];
const note = (s) => said.push(s);

if (!existsSync(at('android')) && !existsSync(at('ios'))) {
  console.error('There is no android/ or ios/ folder yet. First run, in the mobile folder:\n  flutter create . --platforms=android,ios --project-name classroom360_mobile');
  process.exit(1);
}

const read = (p) => readFileSync(p, 'utf8');
const eol = (s) => (s.includes('\r\n') ? '\r\n' : '\n');

// ---------------------------------------------------------------- Android: permissions
const manifestPath = at('android', 'app', 'src', 'main', 'AndroidManifest.xml');
if (existsSync(manifestPath)) {
  let xml = read(manifestPath);
  const nl = eol(xml);
  const wanted = ['INTERNET', 'ACCESS_NETWORK_STATE', 'CHANGE_NETWORK_STATE', 'MODIFY_AUDIO_SETTINGS'];
  const missing = wanted.filter((p) => !xml.includes(`android.permission.${p}"`));
  if (missing.length) {
    const lines = missing.map((p) => `    <uses-permission android:name="android.permission.${p}" />`).join(nl);
    const open = /<manifest\b[^>]*>/.exec(xml);
    if (!open) {
      console.error('Could not find the <manifest> tag in ' + manifestPath);
      process.exit(1);
    }
    const end = open.index + open[0].length;
    xml = xml.slice(0, end) + nl + lines + xml.slice(end);
    writeFileSync(manifestPath, xml);
    note('Android: added the permissions ' + missing.join(', '));
  } else {
    note('Android: permissions were already there');
  }
} else {
  console.error('Not found: ' + manifestPath);
  process.exit(1);
}

// ---------------------------------------------------------------- Android: minSdk 23
const gradleFiles = [at('android', 'app', 'build.gradle.kts'), at('android', 'app', 'build.gradle')].filter(existsSync);
if (gradleFiles.length === 0) {
  console.error('Not found: android/app/build.gradle.kts (or build.gradle)');
  process.exit(1);
}
for (const file of gradleFiles) {
  let g = read(file);
  // minSdk = flutter.minSdkVersion   |   minSdkVersion flutter.minSdkVersion   |   minSdk = 21   ...
  const re = /\b(minSdk(?:Version)?)(\s*=\s*|\s+)(flutter\.minSdkVersion|\d+)/;
  const m = re.exec(g);
  if (!m) {
    note('Android: could not find the minSdk line in ' + file + '; set it to 23 by hand');
  } else if (m[3] === '23' || (/^\d+$/.test(m[3]) && Number(m[3]) > 23)) {
    note('Android: minSdk was already ' + m[3]);
  } else {
    g = g.replace(re, `${m[1]}${m[2]}23`);
    writeFileSync(file, g);
    note('Android: minSdk set to 23');
  }
}

// ---------------------------------------------------------------- iOS: Info.plist texts
const plistPath = at('ios', 'Runner', 'Info.plist');
if (existsSync(plistPath)) {
  let plist = read(plistPath);
  const nl = eol(plist);
  const entries = {
    NSLocalNetworkUsageDescription: 'Shows the classroom cameras on the school network.',
    NSCameraUsageDescription: 'The classroom cameras are shown on screen. This app does not use your own camera.',
    NSMicrophoneUsageDescription: 'This app does not record audio.',
  };
  const added = [];
  for (const [key, text] of Object.entries(entries)) {
    if (plist.includes(`<key>${key}</key>`)) continue;
    const at2 = plist.lastIndexOf('</dict>');
    if (at2 < 0) {
      console.error('Could not find the end of Info.plist');
      process.exit(1);
    }
    plist = plist.slice(0, at2) + `\t<key>${key}</key>${nl}\t<string>${text}</string>${nl}` + plist.slice(at2);
    added.push(key);
  }
  if (added.length) {
    writeFileSync(plistPath, plist);
    note('iOS: added ' + added.join(', '));
  } else {
    note('iOS: Info.plist texts were already there');
  }
} else {
  note('iOS: no ios/ folder, skipped');
}

// ---------------------------------------------------------------- leftovers of `flutter create`
const stub = at('test', 'widget_test.dart');
if (existsSync(stub) && /\bMyApp\b/.test(read(stub))) {
  rmSync(stub);
  note('Removed test/widget_test.dart (the sample test flutter create adds; it does not match this app)');
}
const main = at('lib', 'main.dart');
if (!existsSync(main) || !read(main).includes('Classroom360App')) {
  console.error('\nWARNING: lib/main.dart is not the Classroom360 one. flutter create may have replaced it; restore it from your copy before running.');
  process.exitCode = 2;
}

console.log(said.map((s) => '  ' + s).join('\n'));
console.log('\nNext: flutter pub get');
