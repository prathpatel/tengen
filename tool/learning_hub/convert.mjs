// Converts the Learning Hub of the online-go.com web client to assets/learning_hub/learning_hub.json.
//
// The Learning Hub content is part of online-go.com (https://github.com/online-go/online-go.com),
// licensed under the GNU AGPL v3. Rather than parsing its TypeScript, this runs the page classes
// with small stand-ins for React, the translation functions and the page base class, so that every
// page's config() and text() produce exactly what the website shows. Moves are decoded with the
// decodeMoves function of the OGS goban library.
//
// Usage: node convert.mjs <online-go.com checkout> <goban checkout> <output json>

import * as esbuild from "esbuild";
import { writeFileSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const { decodeMoves } = await import(
  "data:text/javascript;base64," +
    Buffer.from(
      (
        await esbuild.build({
          entryPoints: [resolve(process.argv[3], "src/engine/util/move_encoding.ts")],
          bundle: true,
          write: false,
          format: "esm",
          platform: "node",
          logLevel: "warning",
        })
      ).outputFiles[0].text,
    ).toString("base64")
);

const [ogsDir, gobanDir, outFile] = process.argv.slice(2).map((p) => resolve(p));
if (!outFile) {
  console.error("Usage: node convert.mjs <online-go.com> <goban> <output.json>");
  process.exit(2);
}

const stubs = {
  react: `
    export function createElement(type, props, ...children) {
      return { type, props: { ...(props || {}), children: children.flat() } };
    }
    export function useState(initial) { return [initial, () => {}]; }
    export const Fragment = "fragment";
    export class Component { constructor(props) { this.props = props; } }
    export default { createElement, useState, Fragment, Component };
  `,
  translate: `
    export const _ = (s) => s;
    export const pgettext = (_ctx, s) => s;
    export const npgettext = (_ctx, s, p, n) => (n === 1 ? s : p);
    export const ngettext = (s, p, n) => (n === 1 ? s : p);
    export const interpolate = (s, args) =>
      String(s).replace(/{{(\\w+)}}|%s/g, (m, k) => (k ? args[k] : args.shift()));
  `,
  goban: `export { decodeMoves } from ${JSON.stringify(gobanDir + "/src/engine/util/move_encoding.ts")};`,
  learningPage: `
    import { decodeMoves } from "goban";
    export class LearningPage {
      constructor(props) {
        this.props = props;
        this.onCorrectAnswer = () => { this.__correct = true; };
        this.onWrongAnswer = () => { this.__wrong = true; };
        this.onUpdate = () => {};
      }
      button() { return null; }
      complete() { return false; }
      failed() { return false; }
      onStoneRemoval() {}
      // Same as LearningPage.makePuzzleMoveTree of the OGS web client.
      makePuzzleMoveTree(_correct, _wrong, width = 9, height = 9) {
        const ret = { x: -1, y: -1, branches: [] };
        function walk(cur, path, cb) {
          if (!path.length) { cb(cur); return; }
          for (const branch of cur.branches) {
            if (branch.x === path[0].x && branch.y === path[0].y) {
              path.shift(); walk(branch, path, cb); return;
            }
          }
          const nb = { x: path[0].x, y: path[0].y, branches: [] };
          cur.branches.push(nb); path.shift(); walk(nb, path, cb);
        }
        for (const s of _correct) walk(ret, decodeMoves(s, width, height), (n) => (n.correct_answer = true));
        for (const s of _wrong) walk(ret, decodeMoves(s, width, height), (n) => (n.wrong_answer = true));
        return ret;
      }
    }
  `,
  section: `export class LearningHubSection {}`,
  instructionalGoban: `export class InstructionalGoban {}`,
};

const stubPlugin = {
  name: "stubs",
  setup(build) {
    const map = [
      [/^react$/, "react"],
      [/^@\/lib\/translate$/, "translate"],
      [/^goban$/, "goban"],
      [/LearningPage$/, "learningPage"],
      [/LearningHubSection$/, "section"],
      [/InstructionalGoban$/, "instructionalGoban"],
    ];
    for (const [filter, name] of map) {
      build.onResolve({ filter }, () => ({ path: name, namespace: "stub" }));
    }
    build.onLoad({ filter: /.*/, namespace: "stub" }, (args) => ({
      contents: stubs[args.path],
      loader: "js",
      resolveDir: gobanDir,
    }));
  },
};

const entry = `
  import { sections } from ${JSON.stringify(ogsDir + "/src/views/LearningHub/sections.ts")};
  export { sections };
`;
const bundle = await esbuild.build({
  stdin: { contents: entry, loader: "ts", resolveDir: ogsDir },
  bundle: true,
  write: false,
  format: "esm",
  platform: "node",
  jsx: "transform",
  jsxFactory: "React.createElement",
  jsxFragment: "React.Fragment",
  plugins: [stubPlugin],
  logLevel: "warning",
});
const tmp = resolve(dirname(outFile), ".learning_hub_bundle.mjs");
mkdirSync(dirname(outFile), { recursive: true });
writeFileSync(tmp, bundle.outputFiles[0].text);
const { sections } = await import(pathToFileURL(tmp).href);

/** Collects the strings of a React element tree. */
function texts(node, out = []) {
  if (node == null || node === false) return out;
  if (typeof node === "string" || typeof node === "number") {
    out.push(String(node));
  } else if (Array.isArray(node)) {
    node.forEach((n) => texts(n, out));
  } else if (node.props) {
    texts(node.props.children, out);
  }
  return out;
}

function findAll(node, pred, out = []) {
  if (node == null) return out;
  if (Array.isArray(node)) {
    node.forEach((n) => findAll(n, pred, out));
  } else if (typeof node === "object" && node.props) {
    if (pred(node)) out.push(node);
    findAll(node.props.children, pred, out);
  }
  return out;
}

/** Renders a multiple choice function component and finds its options and correct answer. */
function multipleChoice(element) {
  const render = (props) => element.type(props);
  const tree = render({ onCorrectAnswer() {}, onWrongAnswer() {} });
  const question = findAll(tree, (n) => n.type === "p")
    .map((p) => texts(p).join("").trim())
    .filter(Boolean)
    .join("\n\n");
  const options = findAll(tree, (n) => n.type === "label").map((label) => {
    const input = findAll(label, (n) => n.type === "input")[0];
    return { value: String(input.props.value), label: texts(label).join("").trim() };
  });
  let correct = null;
  for (const option of options) {
    let hit = false;
    const t = render({ onCorrectAnswer: () => (hit = true), onWrongAnswer() {} });
    const input = findAll(t, (n) => n.type === "input" && String(n.props.value) === option.value)[0];
    input.props.onChange({ target: { value: option.value } });
    if (hit) correct = option.value;
  }
  if (!question || options.length < 2 || correct == null) {
    throw new Error("Unrecognized multiple choice page");
  }
  return { question, options, correct };
}

/** The chains of stones of a position given in the OGS letter encoding. */
function chains(config) {
  const w = config.width ?? 9, h = config.height ?? 9;
  const color = new Map();
  for (const [c, str] of [["b", config.initial_state?.black ?? ""], ["w", config.initial_state?.white ?? ""]]) {
    for (let i = 0; i + 1 < str.length; i += 2) color.set(str[i] + str[i + 1], c);
  }
  const key = (x, y) => String.fromCharCode(97 + x) + String.fromCharCode(97 + y);
  const seen = new Set(), out = [];
  for (const [k, c] of color) {
    if (seen.has(k)) continue;
    const chain = [], stack = [k];
    seen.add(k);
    while (stack.length) {
      const cur = stack.pop();
      chain.push(cur);
      const x = cur.charCodeAt(0) - 97, y = cur.charCodeAt(1) - 97;
      for (const [nx, ny] of [[x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]]) {
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        const nk = key(nx, ny);
        if (color.get(nk) === c && !seen.has(nk)) { seen.add(nk); stack.push(nk); }
      }
    }
    out.push(chain);
  }
  return out;
}

/** Finds the removal string a stone removal page accepts, trying sets of up to 3 chains. */
function findRemoval(page, config) {
  // Removal strings list the points row by row, as the goban engine does.
  const encode = (points) =>
    [...points].sort((a, b) => a[1].localeCompare(b[1]) || a[0].localeCompare(b[0])).join("");
  const all = chains(config);
  const sets = [];
  for (let a = 0; a < all.length; a++) {
    sets.push([a]);
    for (let b = a + 1; b < all.length; b++) {
      sets.push([a, b]);
      for (let c = b + 1; c < all.length; c++) sets.push([a, b, c]);
    }
  }
  for (const set of sets) {
    const s = encode(set.flatMap((i) => all[i]));
    page.onStoneRemoval(s);
    if (page.complete()) return s;
  }
  throw new Error("Could not find the stones to remove");
}

/**
 * Positions and marks are written either in the letter encoding (`aa` is the top left corner) or
 * in board coordinates (`c3`); the goban decoder accepts both. Normalize to the letter encoding,
 * dropping points outside the board as the goban decoder does.
 */
function normalizePoints(value, width, height) {
  if (typeof value !== "string" || value === "") return value;
  return decodeMoves(value, width, height)
    .filter((m) => m.x >= 0 && m.y >= 0)
    .map((m) => String.fromCharCode(97 + m.x) + String.fromCharCode(97 + m.y))
    .join("");
}

function cleanConfig(config) {
  const w = config.width ?? 9, h = config.height ?? 9;
  config = { ...config };
  if (config.initial_state) {
    config.initial_state = {
      black: normalizePoints(config.initial_state.black ?? "", w, h),
      white: normalizePoints(config.initial_state.white ?? "", w, h),
    };
  }
  if (config.marks) {
    config.marks = Object.fromEntries(
      Object.entries(config.marks).map(([k, v]) => [k, normalizePoints(v, w, h)]),
    );
  }
  const out = {};
  for (const k of ["width", "height", "initial_state", "initial_player", "bounds", "marks", "phase", "mode", "move_tree"]) {
    if (config[k] !== undefined) out[k] = config[k];
  }
  out.width ??= 9;
  out.height ??= 9;
  return out;
}

const result = { source: "https://github.com/online-go/online-go.com/tree/main/src/views/LearningHub", license: "AGPL-3.0", sections: [] };
let pageCount = 0;
const custom = [];
for (const [title, topics] of sections) {
  const section = { title, topics: [] };
  for (const Topic of topics) {
    const topic = { id: Topic.section(), title: Topic.title(), subtext: Topic.subtext(), pages: [] };
    for (const [i, Page] of Topic.pages().entries()) {
      const page = new Page({ title: topic.title, nPages: 0, curPage: i, section: topic.id });
      const config = cleanConfig(page.config());
      const text = page.text();
      const out = { config };
      const overrides = ["complete", "button", "onStoneRemoval"].filter(
        (m) => Object.prototype.hasOwnProperty.call(Page.prototype, m),
      );
      if (typeof text === "string") {
        out.text = text;
      } else if (text && typeof text.type === "function") {
        Object.assign(out, { choice: multipleChoice(text) });
      } else {
        out.text = texts(text).join("").trim();
      }
      if (overrides.includes("button")) {
        // A page completed by pressing its button (e.g. "Pass").
        const label = texts(page.button()).join("").trim();
        page.onUpdate = () => {};
        out.special = { type: "button", label };
      } else if (overrides.includes("onStoneRemoval")) {
        // A page completed by marking the right dead stones: find them by asking the page itself.
        out.special = { type: "remove", stones: findRemoval(page, config) };
      } else if (overrides.length) {
        throw new Error(`Unsupported page ${topic.id}/${i + 1}: ${overrides}`);
      }
      if (out.special) custom.push(`${topic.id}/${i + 1}: ${JSON.stringify(out.special)}`);
      topic.pages.push(out);
      pageCount++;
    }
    section.topics.push(topic);
  }
  result.sections.push(section);
}
writeFileSync(outFile, JSON.stringify(result));
console.log(`${result.sections.length} sections, ${result.sections.reduce((n, s) => n + s.topics.length, 0)} topics, ${pageCount} pages`);
console.log("special pages:\n  " + custom.join("\n  "));
