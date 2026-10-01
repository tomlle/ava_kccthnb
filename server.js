const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");

const root = __dirname;
const port = Number(process.env.PORT || 3000);
const types = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".svg": "image/svg+xml",
};

http.createServer((request, response) => {
  const url = new URL(request.url, "http://localhost");
  let pathname = decodeURIComponent(url.pathname);
  if (pathname === "/" || pathname === "/ava_kccthnb/") pathname = "/pages/1.html";
  if (/^\/pages\/\d+$/.test(pathname)) pathname += ".html";
  const filename = path.resolve(root, `.${pathname}`);
  if (!filename.startsWith(root) || !fs.existsSync(filename) || fs.statSync(filename).isDirectory()) {
    response.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
    response.end("ページが見つかりません。");
    return;
  }
  response.writeHead(200, {
    "Content-Type": types[path.extname(filename).toLowerCase()] || "application/octet-stream",
    "Cache-Control": "no-cache",
  });
  fs.createReadStream(filename).pipe(response);
}).listen(port, () => {
  console.log(`AVA_KCCT本部 mirror: http://localhost:${port}`);
});
