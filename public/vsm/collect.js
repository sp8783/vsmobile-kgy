/*
 * VS.モバイル連携の収集スクリプト（VS.モバイル for KGY）
 *
 * 参加者のブックマーク「KGY 戦績送信」（javascript: の URL）が、web.vsmobile.jp のページ上でこのスクリプトを読み込む。
 * 読み込み元の URL に本人用の鍵（k=）が付いている。
 *
 * 動き:
 *   0. VS.モバイル以外のページで開かれたときは、VS.モバイルの店内対戦のページへ移る（もう一度開いてもらう）
 *   1. アプリに「送ってほしい対象」（直近 30 日に自分が出たイベントと、既に届いている試合）を聞く
 *   2. VS.モバイルの店内対戦の対戦履歴（過去 30 日）から、対象の日の試合一覧を読む（同一オリジンの fetch。Cookie は読まない）
 *   3. まだ届いていない試合の詳細ページの HTML を、開始時刻の昇順で 1 試合ずつアプリに送る（解析はサーバー側）
 *   4. 画面の下に進み具合を出す。ページからは移動しない
 */
(function () {
  "use strict";

  if (window.__kgyCollect) { window.__kgyCollect.show(); return; }

  var script = document.currentScript;
  var src = script && script.src ? script.src : "";
  var keyMatch = /[?&]k=([^&]+)/.exec(src);
  var token = keyMatch ? decodeURIComponent(keyMatch[1]) : null;
  var base = src ? new URL(src).origin : null;
  var WAIT_MS = 600;

  var ui = buildUi();
  window.__kgyCollect = ui;
  main().catch(function (error) { ui.fail(error && error.message ? error.message : String(error)); });

  async function main() {
    if (!token || !base) throw new Error("連携 URL が壊れています。アプリの「設定」で URL をコピーし直してください。");
    if (location.hostname !== "web.vsmobile.jp") {
      // VS.モバイル以外のページで開かれたら、VS.モバイルの店内対戦のページへ移る（移ったあと、もう一度ブックマークを開いてもらう）
      ui.info("VS.モバイルを開きます。開いたら、もう一度このブックマークを開いてください。");
      await sleep(1500);
      location.href = "https://web.vsmobile.jp/exvs2ib/results/shop";
      return;
    }

    ui.info("送る対象を確認しています…");
    var targets = await api("GET", "/api/vsmobile/targets");
    var events = (targets.events || []).filter(function (event) { return !event.complete; });
    if (events.length === 0) {
      ui.done("送る対象のイベントがありません。直近 30 日に出た対戦会の統計はそろっています。", null);
      return;
    }

    ui.info("VS.モバイルの対戦履歴を読んでいます…");
    var topPage = await fetchPage("/exvs2ib/results/shop");
    var historyBox = findHistoryBox(topPage.doc);
    if (!historyBox) {
      ui.detail("読めたページ: 「" + (topPage.doc.title || "タイトルなし").trim() + "」 " + topPage.url);
      throw new Error("店内対戦の対戦履歴のページとして読めませんでした。VS.モバイルにログインしているか、スマートフォン向けの画面で開いているかを確認してください。" +
        "（PC の Chrome で試すときは、デベロッパーツールのデバイスモードで iPhone を選んでから押してください）");
    }
    var dayLinks = findDayLinks(historyBox);
    if (dayLinks.length === 0) throw new Error("店内対戦の対戦履歴（過去30日）に試合がありません。直近 30 日に店内対戦をしていないか、VS.モバイルにまだ反映されていない可能性があります。");

    var imported = 0, already = 0, problems = [], last = null, lastEvent = null;
    for (var e = 0; e < events.length; e++) {
      var event = events[e];
      var link = await findDayLink(dayLinks, event.held_on);
      if (!link) { problems.push(event.name + "（" + formatDate(event.held_on) + "）の対戦履歴が VS.モバイルにありません"); continue; }

      var day = await readDay(link);
      var covered = {};
      (event.covered_match_ts || []).forEach(function (ts) { covered[ts] = true; });
      var pending = day.matches.filter(function (m) { return !covered[m.ts]; }).sort(function (a, b) { return a.ts - b.ts; });
      if (pending.length === 0) { already += day.matches.length; continue; }

      for (var i = 0; i < pending.length; i++) {
        var m = pending[i];
        ui.progress(event.name + ": 試合の詳細を読み込み中… " + (i + 1) + " / " + pending.length, (i + 1) / pending.length);
        var html = await fetchText(m.href);
        var result = await api("POST", "/api/vsmobile/matches", {
          event_id: event.id, match_ts: m.ts, result_self: m.result_self, time: m.time,
          self_name: day.self_name, game_date: day.game_date, shop_name: day.shop_name, html: html
        }, true);
        if (result.error) {
          // 対応づけは開始時刻の順が前提なので、1 試合でも失敗したらその日の残りは送らない
          problems.push(event.name + " " + (m.time || "") + " の試合: " + result.error);
          break;
        }
        if (result.status === "imported") imported++; else already++;
        last = result; lastEvent = event;
        await sleep(WAIT_MS);
      }
    }

    var message;
    if (imported > 0) {
      message = "✓ " + imported + " 試合を送りました";
      if (last && lastEvent) {
        message += "。" + lastEvent.name + " は" + (last.remaining > 0 ? "あと " + last.remaining + " 試合で全部そろいます" : "全試合そろいました");
      }
    } else if (problems.length === 0) {
      message = "送る試合はありませんでした。あなたの分はすべて届いています。";
    } else {
      message = "送れませんでした。";
    }
    if (problems.length > 0) message += "\n" + problems.join("\n");
    ui.done(message, lastEvent ? lastEvent.url : null, problems.length > 0);
  }

  // --- アプリの API（本人用の鍵で認証） ---

  async function api(method, path, body, soft) {
    var response;
    try {
      response = await fetch(base + path, {
        method: method,
        headers: { "Authorization": "Bearer " + token, "Content-Type": "application/json", "Accept": "application/json" },
        body: body ? JSON.stringify(body) : undefined,
        mode: "cors", credentials: "omit"
      });
    } catch (error) {
      throw new Error("アプリに接続できませんでした（" + error.message + "）。電波の状態を確認して、もう一度押してください。");
    }
    var json = {};
    try { json = await response.json(); } catch (error) { json = {}; }
    if (response.status === 401) throw new Error(json.error || "連携 URL が無効です。アプリの「設定」で作り直してください。");
    if (!response.ok) {
      var message = json.error || ("アプリがエラーを返しました（HTTP " + response.status + "）");
      if (soft) return { error: message };
      throw new Error(message);
    }
    return json;
  }

  // --- VS.モバイルのページ（同一オリジン。ログインしているブラウザの中でだけ読める） ---

  async function fetchResponse(path) {
    var response = await fetch(new URL(path, location.href).toString(), { credentials: "same-origin" });
    if (/\/login|oauth|bandainamcoid\.com/.test(response.url)) {
      ui.detail("ログインページに移されました: " + response.url);
      throw new Error("VS.モバイルにログインしていません。ログインしてから、もう一度押してください。");
    }
    if (!response.ok) throw new Error("VS.モバイルのページが読めませんでした（HTTP " + response.status + "）。少し待ってから、もう一度押してください。");
    return response;
  }

  async function fetchText(path) {
    return await (await fetchResponse(path)).text();
  }

  // { doc, url }（url は転送されたあとの実際の URL）
  async function fetchPage(path) {
    var response = await fetchResponse(path);
    return { doc: new DOMParser().parseFromString(await response.text(), "text/html"), url: response.url };
  }

  async function fetchDoc(path) {
    return (await fetchPage(path)).doc;
  }

  // 店内対戦トップの「対戦履歴（過去30日）」の箱。見つからなければ null（ログインしていない・PC 向けの画面・ページの形が変わった）
  function findHistoryBox(doc) {
    var heads = Array.prototype.filter.call(doc.querySelectorAll("p"), function (p) { return /対戦履歴[（(]過去30日[）)]/.test(p.textContent); });
    if (heads.length === 0) return null;
    return heads[0].closest("div.box") || heads[0].parentElement || doc.body;
  }

  // その箱にある日ごとのリンク。行の文字から日付も読む（読めなければ null）
  function findDayLinks(box) {
    var links = [], seen = {};
    Array.prototype.forEach.call(box.querySelectorAll('a[href*="daily_detail"]'), function (a) {
      var href = new URL(a.getAttribute("href"), location.href).toString();
      if (seen[href]) return;
      seen[href] = true;
      var row = a.closest("li") || a;
      links.push({ href: href, date: normalizeDate(row.textContent), doc: null });
    });
    return links;
  }

  // 対象の日のリンク。行に日付がなければ、その日のページを開いて日付を読む
  async function findDayLink(links, heldOn) {
    for (var i = 0; i < links.length; i++) if (links[i].date === heldOn) return links[i];
    for (var j = 0; j < links.length; j++) {
      var link = links[j];
      if (link.date) continue;
      link.doc = await fetchDoc(link.href);
      link.date = normalizeDate(textOf(link.doc, "div.box h3 div.ta-l span.datetime"));
      await sleep(WAIT_MS);
      if (link.date === heldOn) return link;
    }
    return null;
  }

  // その日の試合一覧（ページ送りを含む）: {matches: [{href, ts, result_self, time}], self_name, game_date, shop_name}
  async function readDay(link) {
    var doc = link.doc || await fetchDoc(link.href);
    var day = {
      matches: [],
      self_name: textOf(doc, "p.fz-xs.fw-b"),
      game_date: textOf(doc, "div.box h3 div.ta-l span.datetime"),
      shop_name: textOf(doc, "div.box h3 div.ta-r span.col-stand")
    };
    collectMatches(doc, day.matches);
    var maxPage = 1;
    Array.prototype.forEach.call(doc.querySelectorAll("div.page-send a[href*='page=']"), function (a) {
      if (a.classList.contains("disabled")) return;
      var page = parseInt(new URL(a.getAttribute("href"), location.href).searchParams.get("page"), 10);
      if (page > maxPage) maxPage = page;
    });
    for (var page = 2; page <= maxPage; page++) {
      await sleep(WAIT_MS);
      var url = new URL(link.href);
      url.searchParams.set("page", String(page));
      collectMatches(await fetchDoc(url.toString()), day.matches);
    }
    return day;
  }

  function collectMatches(doc, into) {
    Array.prototype.forEach.call(doc.querySelectorAll("li.item > a.vs-detail"), function (a) {
      var href = new URL(a.getAttribute("href"), location.href);
      var ts = parseInt(href.searchParams.get("ts"), 10);
      if (!ts) return;
      into.push({
        href: href.toString(), ts: ts,
        result_self: a.classList.contains("win") ? "win" : "lose",
        time: textOf(a, "p.datetime.fz-ss")
      });
    });
  }

  // --- 小道具 ---

  function textOf(root, selector) {
    var el = root.querySelector(selector);
    return el ? el.textContent.trim() : "";
  }

  // 「2026年11月7日」「2026/11/07(土)」などを YYYY-MM-DD に
  function normalizeDate(text) {
    var m = /(\d{4})[\/年.\-](\d{1,2})[\/月.\-](\d{1,2})/.exec(text || "");
    if (!m) return null;
    return m[1] + "-" + ("0" + m[2]).slice(-2) + "-" + ("0" + m[3]).slice(-2);
  }

  function formatDate(iso) {
    var parts = (iso || "").split("-");
    return parts.length === 3 ? parseInt(parts[1], 10) + "/" + parseInt(parts[2], 10) : iso;
  }

  function sleep(ms) { return new Promise(function (resolve) { setTimeout(resolve, ms); }); }

  // --- 画面の下の小さな表示 ---

  function buildUi() {
    var host = document.createElement("div");
    host.setAttribute("style", "position:fixed;left:10px;right:10px;top:calc(10px + env(safe-area-inset-top, 0px));z-index:2147483647;font-family:-apple-system,BlinkMacSystemFont,'Hiragino Sans','Noto Sans JP',sans-serif;");
    var shadow = host.attachShadow ? host.attachShadow({ mode: "open" }) : host;
    shadow.innerHTML =
      '<style>' +
      '.sheet{background:#fff;color:#1c2230;border-radius:14px;padding:12px 14px 12px;box-shadow:0 6px 24px rgba(0,0,0,.35);font-size:13px;line-height:1.5;position:relative}' +
      '.t{font-weight:700;padding-right:28px;white-space:pre-line}' +
      '.t.ok{color:#1e8a4c}.t.ng{color:#b42318}' +
      '.bar{height:6px;border-radius:3px;background:#e4e7ee;overflow:hidden;margin:8px 0 6px}.bar i{display:block;height:100%;width:0;background:#2458c7;transition:width .3s}' +
      '.bar.full i{width:100%;background:#1e8a4c}' +
      '.s{font-size:12px;color:#5d6675}.s a{color:#2458c7}' +
      '.d{font-size:11px;color:#8a93a3;margin-top:6px;word-break:break-all;white-space:pre-line}' +
      '.x{position:absolute;top:8px;right:10px;border:0;background:transparent;font-size:18px;line-height:1;color:#5d6675;cursor:pointer}' +
      '</style>' +
      '<div class="sheet"><button class="x" aria-label="閉じる">×</button><div class="t">VS.モバイル for KGY に送る準備をしています…</div><div class="bar"><i></i></div><div class="s"></div><div class="d"></div></div>';
    document.body.appendChild(host);
    var root = shadow.querySelector(".sheet");
    var title = root.querySelector(".t"), bar = root.querySelector(".bar"), fill = bar.querySelector("i"), sub = root.querySelector(".s"), detail = root.querySelector(".d");
    root.querySelector(".x").addEventListener("click", function () { host.style.display = "none"; });
    return {
      show: function () { host.style.display = ""; },
      info: function (text) { title.textContent = text; },
      progress: function (text, ratio) { title.textContent = text; fill.style.width = Math.round(ratio * 100) + "%"; },
      done: function (text, url, hasProblem) {
        title.textContent = text;
        title.className = "t " + (hasProblem ? "ng" : "ok");
        bar.className = "bar full";
        if (url) {
          sub.innerHTML = "";
          var a = document.createElement("a");
          a.href = url; a.target = "_blank"; a.rel = "noopener"; a.textContent = "アプリで対戦履歴を見る";
          sub.appendChild(a);
        } else {
          sub.textContent = "";
        }
      },
      detail: function (text) { detail.textContent = text; },
      fail: function (text) {
        title.textContent = text; title.className = "t ng"; bar.style.display = "none"; sub.textContent = "";
      }
    };
  }
})();
