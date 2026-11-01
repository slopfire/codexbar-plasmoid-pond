#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import {validate} from "./CodexBarSettings.mjs";

let temporary = "";
try {
  const file = process.argv[2];
  if (!file || !path.isAbsolute(file)) throw new Error("Settings path is invalid");
  const request = JSON.parse(fs.readFileSync(0, "utf8"));
  const patch = validate(request.patch);
  let current = {};
  try {
    current = JSON.parse(fs.readFileSync(file, "utf8"));
  } catch (error) {
    if (error.code !== "ENOENT") throw new Error("Cannot read settings. The existing file was kept.");
  }
  if (!current || typeof current !== "object" || Array.isArray(current)) throw new Error("Settings must be a JSON object");
  if (request.base && JSON.stringify(current) !== JSON.stringify(request.base))
    throw new Error("Settings changed outside this page. Close and reopen Settings before applying.");
  fs.mkdirSync(path.dirname(file), {recursive: true, mode: 0o700});
  temporary = file + "." + crypto.randomBytes(8).toString("hex") + ".tmp";
  fs.writeFileSync(temporary, JSON.stringify(Object.assign({}, current, patch), null, 2) + "\n", {mode: 0o600, flag: "wx"});
  fs.renameSync(temporary, file);
  temporary = "";
  process.stdout.write(JSON.stringify({ok: true}) + "\n");
} catch (error) {
  // Input and credentials must never appear in error output.
  process.stdout.write(JSON.stringify({ok: false, error: error instanceof SyntaxError ? "Settings contain invalid JSON" : error.message}) + "\n");
  process.exitCode = 1;
} finally {
  if (temporary) { try { fs.unlinkSync(temporary); } catch {} }
}
