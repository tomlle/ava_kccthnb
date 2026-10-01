const fs = require("node:fs");
const path = require("node:path");

const required = [1, 2, 3, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 23, 24, 27, 28, 29, 30, 31, 32, 33, 34];
const requiredSet = new Set(required.map(String));
const projectRoot = path.join(__dirname, "..");
let failed = false;
for (const id of required) {
  const filename = path.join(__dirname, "..", "pages", `${id}.html`);
  if (!fs.existsSync(filename)) {
    console.error(`missing: pages/${id}.html`);
    failed = true;
    continue;
  }
  const html = fs.readFileSync(filename, "utf8");
  if (!html.includes('<base href="../">') || !html.includes('href="mirror.css"') || !html.includes('id="wikibody"')) {
    console.error(`invalid mirror page: pages/${id}.html`);
    failed = true;
  }
  if (/譛|繧|縺|�/.test(html)) {
    console.error(`mojibake detected: pages/${id}.html`);
    failed = true;
  }
  if (/#(?:ref|image)\s*\(/i.test(html)) {
    console.error(`unrendered image directive in pages/${id}.html`);
    failed = true;
  }
  for (const match of html.matchAll(/\b(?:src|srcset|poster|data)=["'](https?:)?\/\//gi)) {
    console.error(`external resource dependency in pages/${id}.html: ${match[0]}`);
    failed = true;
  }
  for (const match of html.matchAll(/\bsrc=["'](?<url>(?!https?:|\/\/|data:)[^"']+)["']/gi)) {
    const localPath = path.join(projectRoot, decodeURIComponent(match.groups.url));
    if (!fs.existsSync(localPath)) {
      console.error(`missing local resource in pages/${id}.html: ${match.groups.url}`);
      failed = true;
    }
  }
  for (const match of html.matchAll(/href="pages\/(\d+)\.html"/g)) {
    if (!requiredSet.has(match[1])) {
      console.error(`broken page link in pages/${id}.html: ${match[0]}`);
      failed = true;
    }
  }
}
const indexHtml = fs.readFileSync(path.join(projectRoot, "index.html"), "utf8");
if (!indexHtml.includes('<base href="./">')) {
  console.error('GitHub Pages base path is missing from index.html');
  failed = true;
}
const runningCourse = fs.readFileSync(path.join(projectRoot, "pages", "13.html"), "utf8");
if (!runningCourse.includes('class="wiki-size"') || !runningCourse.includes('background-color:green') || !runningCourse.includes('color:yellow')) {
  console.error("PM running course inline size/color styling is missing");
  failed = true;
}
const glossary = fs.readFileSync(path.join(projectRoot, "pages", "16.html"), "utf8");
if (!glossary.includes('class="wiki-toc"') || !glossary.includes('class="wiki-toc-level-4"') || !glossary.includes('id="wiki-heading-1"')) {
  console.error("KCCT glossary table of contents/heading hierarchy is missing");
  failed = true;
}
for (const asset of ["mirror.css", "assets/uploads/manifest.json", "index.html"]) {
  if (!fs.existsSync(path.join(__dirname, "..", asset))) {
    console.error(`missing: ${asset}`);
    failed = true;
  }
}
const css = fs.readFileSync(path.join(projectRoot, "mirror.css"), "utf8");
if (!/background:\s*#000\b/i.test(css) || !/color:\s*#fff\b/i.test(css)) {
  console.error("original black-background/white-text theme is missing from mirror.css");
  failed = true;
}
if (!/#contents\s*\{[\s\S]*?width:\s*860px/i.test(css) || !/#menubar\s*\{[\s\S]*?width:\s*200px/i.test(css)) {
  console.error("original 860px/200px two-column layout is missing from mirror.css");
  failed = true;
}
if (/@import\s+|url\(\s*["']?(?:https?:)?\/\//i.test(css)) {
  console.error("external stylesheet resource dependency in mirror.css");
  failed = true;
}
if (failed) process.exit(1);
console.log(`OK: ${required.length} menu pages are present.`);
