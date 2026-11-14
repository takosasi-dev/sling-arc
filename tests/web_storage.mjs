// 保存の置き場をブラウザで確かめる(save/save_store.gd の頭)。Web 書き出しを手元で配り、
// 窓なし・消音・使い捨てのプロフィールの Chrome / Edge を CDP で操作する。入力は本物のマウスを送る。
//   node tests/web_storage.mjs
// 確かめる事:
//   (1) v0.1.0 の保存(IndexedDB の /userfs)を引き継ぎ、書く時に localStorage へ移る
//   (2) 起動した後に別のゲームが /userfs に書いた物が、こちらが保存しても、プレイを数秒動かした後も残る
//   (+) 音を切ってすぐ読み込み直しても、切のまま
// 環境変数: SA_WEB(確かめる書き出し。既定は build/web)、SA_URL(手元で配らずに、この URL(最後は /)を開く。公開した物など)、
//           SA_HTTP_PORT・SA_CDP_PORT(既定 8773・9773)、SA_BROWSERS(既定 chrome,edge)。
// 画像は build/web_shots/。失敗が 1 件でもあれば終了コード 1。
import { spawn } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { setTimeout as sleep } from 'node:timers/promises';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const WEB = process.env.SA_WEB ? path.resolve(process.env.SA_WEB) : path.join(ROOT, 'build', 'web');
const OUT = path.join(ROOT, 'build', 'web_shots');
const HTTP_PORT = Number(process.env.SA_HTTP_PORT || 8773);
const CDP_PORT = Number(process.env.SA_CDP_PORT || 9773);
const SAVE_KEY = 'sling-arc/save'; // save/save_store.gd の WEB_KEY
const BROWSERS = {
	chrome: 'C:/Program Files/Google/Chrome/Application/chrome.exe',
	edge: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
};
const SCALE = 0.75; // 540 × 960 の窓 = ゲームの 720 × 1280 の 0.75 倍(縦横比が同じなので余白なし)
// ゲームの座標(ui/title.gd・ui/play.gd のボタンの中心)
const SOUND = [360, 1126];
const DAILY = [360, 885];
const SKIP = [610, 178];
const SETTLE_MS = 2500; // 起動の後、暗転と出てくる動きが済むまで

let failures = 0;
function expect(ok, label) {
	console.log(`${ok ? 'OK' : 'NG'}  ${label}`);
	if (!ok) failures++;
	return ok;
}

async function waitFor(fn, timeoutMs, everyMs = 200) {
	const end = Date.now() + timeoutMs;
	while (Date.now() < end) {
		const v = await fn();
		if (v) return v;
		await sleep(everyMs);
	}
	return null;
}

// build/web を /sling-arc/ の下に置いて配る(Pages と同じ形)
function serve() {
	if (process.env.SA_URL) return { url: process.env.SA_URL, stop: () => {} };
	if (!existsSync(path.join(WEB, 'index.html'))) throw new Error('build/web/index.html が無い(先に Web へ書き出す)');
	const root = mkdtempSync(path.join(tmpdir(), 'sa-site-'));
	symlinkSync(WEB, path.join(root, 'sling-arc'), 'junction');
	const server = spawn('python', ['-m', 'http.server', String(HTTP_PORT), '--bind', '127.0.0.1', '--directory', root], { stdio: 'ignore' });
	return {
		url: `http://127.0.0.1:${HTTP_PORT}/sling-arc/`,
		stop: () => { server.kill(); rmSync(path.join(root, 'sling-arc')); }, // ジャンクションだけ消す(build/web は残す)
	};
}

async function connect(url) {
	const ws = new WebSocket(url);
	await new Promise((ok, ng) => { ws.onopen = ok; ws.onerror = ng; });
	let id = 0;
	const pending = new Map();
	const listeners = [];
	ws.onmessage = (m) => {
		const msg = JSON.parse(m.data);
		if (msg.id && pending.has(msg.id)) {
			const { ok, ng } = pending.get(msg.id);
			pending.delete(msg.id);
			msg.error ? ng(new Error(msg.error.message)) : ok(msg.result);
		} else listeners.forEach((f) => f(msg));
	};
	return {
		send: (method, params = {}) => new Promise((ok, ng) => {
			const i = ++id;
			pending.set(i, { ok, ng });
			ws.send(JSON.stringify({ id: i, method, params }));
		}),
		onEvent: (f) => listeners.push(f),
		close: () => ws.close(),
	};
}

async function open(name) {
	mkdirSync(OUT, { recursive: true });
	const profile = mkdtempSync(path.join(tmpdir(), `sa-${name}-`));
	const proc = spawn(BROWSERS[name], ['--headless=new', '--mute-audio', `--remote-debugging-port=${CDP_PORT}`, `--user-data-dir=${profile}`,
		'--no-first-run', '--no-default-browser-check', '--disable-background-timer-throttling', '--disable-renderer-backgrounding',
		'--enable-unsafe-swiftshader', 'about:blank'], { stdio: 'ignore' });
	const target = await waitFor(async () => {
		try { return (await (await fetch(`http://127.0.0.1:${CDP_PORT}/json/list`)).json()).find((t) => t.type === 'page'); }
		catch { return null; }
	}, 60000);
	if (!target) { proc.kill(); throw new Error(`${name}: ブラウザにつながらない`); }
	const cdp = await connect(target.webSocketDebuggerUrl);
	const logs = [];
	cdp.onEvent((msg) => {
		const p = msg.params;
		if (msg.method === 'Runtime.consoleAPICalled') logs.push({ level: p.type, text: p.args.map((a) => a.value ?? a.description).join(' ') });
		else if (msg.method === 'Runtime.exceptionThrown') logs.push({ level: 'exception', text: p.exceptionDetails.exception?.description ?? p.exceptionDetails.text });
		else if (msg.method === 'Log.entryAdded') logs.push({ level: p.entry.level, text: `${p.entry.text} ${p.entry.url ?? ''}` });
	});
	for (const m of ['Runtime.enable', 'Log.enable', 'Page.enable']) await cdp.send(m);
	await cdp.send('Network.setCacheDisabled', { cacheDisabled: true });
	await cdp.send('Emulation.setFocusEmulationEnabled', { enabled: true });
	await cdp.send('Emulation.setDeviceMetricsOverride', { width: 720 * SCALE, height: 1280 * SCALE, deviceScaleFactor: 1, mobile: false });

	const evaluate = async (expression) => (await cdp.send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true })).result.value;
	const mouse = (type, [gx, gy]) => cdp.send('Input.dispatchMouseEvent', { type, x: gx * SCALE, y: gy * SCALE, button: 'left', buttons: type === 'mouseReleased' ? 0 : 1, clickCount: 1 });
	const openDb = `await new Promise((ok, ng) => { const r = indexedDB.open('/userfs'); r.onsuccess = () => ok(r.result); r.onerror = () => ng(r.error); })`;
	const page = {
		name,
		// 開く(読み込み直す)。Godot が起動して、タイトルが出そろうまで待つ
		goto: async (to) => {
			const from = logs.length;
			await cdp.send('Page.navigate', { url: to });
			const booted = await waitFor(() => logs.slice(from).some((l) => l.text.startsWith('Godot Engine v')), 60000, 50);
			await sleep(SETTLE_MS);
			return booted !== null;
		},
		click: async (g) => { await mouse('mousePressed', g); await mouse('mouseReleased', g); },
		// 引っ張って離す(ゲームの座標)
		drag: async (from, to, n = 8) => {
			await mouse('mousePressed', from);
			for (let i = 1; i <= n; i++) {
				const p = [from[0] + (to[0] - from[0]) * i / n, from[1] + (to[1] - from[1]) * i / n];
				await cdp.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: p[0] * SCALE, y: p[1] * SCALE, button: 'left', buttons: 1 });
				await sleep(30);
			}
			await mouse('mouseReleased', to);
		},
		// localStorage の保存。無ければ null
		saved: async () => JSON.parse(await evaluate(`localStorage.getItem('${SAVE_KEY}')`) ?? 'null'),
		// IndexedDB の /userfs(Godot の user:// の実体。同じサイトの Godot のゲーム全部で 1 つ)の鍵の一覧
		userfsKeys: async () => JSON.parse(await evaluate(`(async () => {
			if (!(await indexedDB.databases()).some((d) => d.name === '/userfs')) return '[]';
			const db = ${openDb};
			const keys = await new Promise((ok) => { const r = db.transaction('FILE_DATA').objectStore('FILE_DATA').getAllKeys(); r.onsuccess = () => ok(r.result); r.onerror = () => ok([]); });
			db.close();
			return JSON.stringify(keys);
		})()`)),
		// /userfs の 1 つのファイルの中身。無ければ null
		userfsGet: (p) => evaluate(`(async () => {
			if (!(await indexedDB.databases()).some((d) => d.name === '/userfs')) return null;
			const db = ${openDb};
			const e = await new Promise((ok) => { const r = db.transaction('FILE_DATA').objectStore('FILE_DATA').get(${JSON.stringify(p)}); r.onsuccess = () => ok(r.result); r.onerror = () => ok(null); });
			db.close();
			return e && e.contents ? new TextDecoder().decode(e.contents) : null;
		})()`),
		// /userfs にファイルを入れる(別のゲームや v0.1.0 が書いた物の代わり)。files は { パス: 中身の文字 }。
		// Godot が起動して /userfs を作った後に呼ぶ。IDBFS と同じ形で、上のフォルダの項目も足す
		userfsPut: (files) => evaluate(`(async () => {
			const db = ${openDb};
			const tx = db.transaction('FILE_DATA', 'readwrite');
			const store = tx.objectStore('FILE_DATA');
			const now = new Date();
			for (const [p, text] of Object.entries(${JSON.stringify(files)})) {
				const parts = p.split('/');
				for (let i = 3; i < parts.length; i++) store.put({ timestamp: now, mode: 0o40777 }, parts.slice(0, i).join('/'));
				store.put({ timestamp: now, mode: 0o100666, contents: new TextEncoder().encode(text) }, p);
			}
			await new Promise((ok, ng) => { tx.oncomplete = ok; tx.onerror = () => ng(tx.error); });
			db.close();
			return true;
		})()`),
		shot: async (label) => {
			writeFileSync(path.join(OUT, `${name}_${label}.png`), Buffer.from((await cdp.send('Page.captureScreenshot', { format: 'png' })).data, 'base64'));
		},
		errors: () => logs.filter((l) => ['error', 'exception'].includes(l.level) && !l.text.includes('favicon.ico')),
		close: async () => {
			try { await cdp.send('Browser.close'); } catch { /* もう閉じた */ }
			cdp.close();
			await Promise.race([new Promise((ok) => proc.once('exit', ok)), sleep(3000)]);
			proc.kill();
			rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 500 });
		},
	};
	return page;
}

const LEGACY = '/userfs/godot/app_userdata/SlingArc/save.json';
const OTHER = '/userfs/godot/app_userdata/OtherGame/save.json';
const OTHER2 = '/userfs/godot/app_userdata/OtherGame/later.json';
// v0.1.0 の保存。既定(音は入・練習はまだ・日替わり無し)と見分けが付く値にする
const OLD = { version: 1, tutorial_done: false, sound_on: false, daily: { '2026-11-01': { course_id: 5, attempts: 2, first_total: 12, first_holes: [3, 2, 3, 2, 2] } } };

async function storage(name, base) {
	const page = await open(name);
	try {
		if (!expect(await page.goto(base), `${name}: Godot が起動した`)) return;
		await page.userfsPut({ [LEGACY]: JSON.stringify(OLD) });
		await page.goto(base);
		await page.shot('title');
		const before = await page.userfsGet(LEGACY);
		expect(before !== null && (await page.saved()) === null, `${name}: 読み込み直した時点で、/userfs に v0.1.0 の保存があり、localStorage は空`);

		// (1)(2) 音を押して保存させる。旧保存を読んでいれば 切 → 入 になる
		await page.userfsPut({ [OTHER]: '{"other":true}' }); // このタブが起動した後に、別のゲームが書いた
		await page.click(SOUND);
		const where = await waitFor(async () => ((await page.saved()) ? 'localStorage' : (await page.userfsGet(LEGACY)) !== before ? '/userfs' : null), 8000);
		expect(where !== null, `${name}: 音を押すと保存が書かれる(書いた先: ${where})`);
		const s = await page.saved();
		expect(s?.sound_on === true && s?.tutorial_done === false && s?.daily?.['2026-11-01']?.first_total === 12,
			`${name}: (1) v0.1.0 の保存を引き継いで localStorage に書く(${JSON.stringify(s)})`);
		await sleep(2000); // Godot が /userfs を書き戻すなら、この間に起きる
		let keys = await page.userfsKeys();
		expect(keys.includes(OTHER), `${name}: (2) 保存した後も、起動した後に別のゲームが書いた /userfs の物が残る(/userfs の鍵: ${keys.join(' ')})`);
		expect((await page.userfsGet(LEGACY)) === before, `${name}: /userfs の v0.1.0 の保存は書き換えない`);

		// (2) プレイを数秒動かす。今日のコース → 練習をスキップ(練習済みを保存)→ 1 発撃って 5 秒
		await page.userfsPut({ [OTHER2]: '{}' });
		await page.click(DAILY);
		await sleep(1500);
		await page.shot('tutorial');
		await page.click(SKIP);
		const skipped = await waitFor(async () => (await page.saved())?.tutorial_done === true || (await page.userfsGet(LEGACY))?.includes('"tutorial_done":true'), 8000);
		expect(Boolean(skipped), `${name}: 練習をスキップすると、練習済みが保存される`);
		await sleep(1500);
		await page.drag([360, 700], [330, 950]);
		await sleep(5000);
		await page.shot('play');
		keys = await page.userfsKeys();
		expect(keys.includes(OTHER2) && keys.includes(OTHER), `${name}: (2) プレイを 5 秒動かした後も、別のゲームが書いた /userfs の物が残る(/userfs の鍵: ${keys.join(' ')})`);

		// (+) 音を切って、待たずに読み込み直す。切のままなら、次に押すと 入 になる
		await page.goto(base);
		await page.click(SOUND);
		const off = await waitFor(async () => (await page.saved())?.sound_on === false, 3000, 20);
		await page.goto(base);
		await page.click(SOUND);
		const on = await waitFor(async () => (await page.saved())?.sound_on === true, 5000);
		expect(Boolean(off) && Boolean(on), `${name}: 音を切ってすぐ読み込み直しても、切のまま残る`);

		page.errors().forEach((l) => console.log(`    [${l.level}] ${l.text}`));
		expect(page.errors().length === 0, `${name}: コンソールにエラーが無い`);
	} catch (e) {
		expect(false, `${name}: 途中で止まった: ${e.stack ?? e}`);
	} finally { await page.close(); }
}

const site = serve();
try {
	console.log(`==  ${site.url}`);
	for (const name of (process.env.SA_BROWSERS || 'chrome,edge').split(',')) {
		if (existsSync(BROWSERS[name] ?? '')) await storage(name, site.url);
		else console.log(`--  ${name}: 入っていない`);
	}
} finally { site.stop(); }
console.log(failures === 0 ? 'ALL OK' : `${failures} 件 NG`);
process.exitCode = failures === 0 ? 0 : 1;
