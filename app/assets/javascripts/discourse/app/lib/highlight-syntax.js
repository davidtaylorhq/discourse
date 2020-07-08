import { Promise } from "rsvp";
import { getURLWithCDN } from "discourse-common/lib/get-url";
import { next } from "@ember/runloop";
import loadScript from "discourse/lib/load-script";
import { isTesting } from "discourse-common/config/environment";

const _moreLanguages = [];
let _worker = null;
let _workerPromise = null;
const _pendingResolution = {};
let _counter = 0;
let _cachedResultsMap = new Map();

const CACHE_SIZE = 100;

export function registerHighlightJSLanguage(name, fn) {
  _moreLanguages.push({ name: name, fn: fn });
}

export default function highlightSyntax(elem) {
  const selector = Discourse.SiteSettings.autohighlight_all_code
    ? "pre code"
    : "pre code[class]";

  elem.querySelectorAll(selector).forEach(function(e) {
    // Large code blocks can cause crashes or slowdowns
    if (e.innerHTML.length > 30000) {
      return;
    }

    e.classList.remove("lang-auto");
    let lang = null;
    e.classList.forEach(c => {
      if (c.startsWith("lang-")) {
        lang = c.slice("lang-".length);
      }
    });

    asyncHighlight(e.textContent, lang).then(res =>
      // Batch DOM changes using the Ember runloop
      next(() => {
        e.innerHTML = res;
        e.classList.add("hljs");
      })
    );
  });
}

function getWorker() {
  if (_worker) return Promise.resolve(_worker);
  if (_workerPromise) return _workerPromise;

  const w = new Worker(Discourse.HighlightJSWorkerURL);
  w.onmessage = onWorkerMessage;
  w.postMessage({
    type: "loadHighlightJs",
    path: highlightJSUrl()
  });

  _workerPromise = setupCustomLanguages(w).then(() => (_worker = w));
  return _workerPromise;
}

function setupCustomLanguages(worker) {
  if (_moreLanguages.length === 0) return Promise.resolve();
  // To build custom language definitions we need to have hljs loaded
  // Plugins/themes can't run code in a worker, so we have to load hljs in the main thread
  // But the actual highlighting will still be done in the worker

  return loadScript(Discourse.HighlightJSPath).then(() => {
    _moreLanguages.forEach(({ name, fn }) => {
      const definition = fn(window.hljs);
      worker.postMessage({
        type: "registerLanguage",
        definition,
        name
      });
    });
  });
}

function asyncHighlight(text, language) {
  return getWorker().then(w => {
    let result;
    if ((result = _cachedResultsMap.get(cacheKey(text, language)))) {
      return result;
    }

    let resolve;
    const promise = new Promise(f => (resolve = f));

    w.postMessage({
      type: "highlight",
      id: _counter,
      text,
      language
    });

    _pendingResolution[_counter] = {
      promise,
      resolve,
      text,
      language
    };

    _counter++;

    return promise;
  });
}

function onWorkerMessage(message) {
  const id = message.data.id;
  const request = _pendingResolution[id];
  delete _pendingResolution[id];
  request.resolve(message.data.result);

  cacheResult({
    text: request.text,
    language: request.language,
    result: message.data.result
  });
}

function cacheResult({ text, language, result }) {
  _cachedResultsMap.set(cacheKey(text, language), result);
  while (_cachedResultsMap.size > CACHE_SIZE) {
    _cachedResultsMap.delete(_cachedResultsMap.entries().next().value[0]);
  }
}

function cacheKey(text, lang) {
  return `${lang}:${text}`;
}

function highlightJSUrl() {
  let hljsUrl = getURLWithCDN(Discourse.HighlightJSPath);

  // Need to use full URL including protocol/domain
  // for use in a worker
  if (hljsUrl.startsWith("/")) {
    hljsUrl = window.location.protocol + "//" + window.location.host + hljsUrl;
  }

  return hljsUrl;
}

// To be used in qunit tests. Running highlight in a worker means that the
// normal system which waits for ember rendering in tests doesn't work.
// This promise will resolve once all pending highlights are done
export function waitForHighlighting() {
  if (!isTesting()) {
    throw "This function should only be called in a test environment";
  }
  const promises = Object.values(_pendingResolution).map(r => r.promise);
  return new Promise(resolve => {
    Promise.all(promises).then(() => next(resolve));
  });
}
