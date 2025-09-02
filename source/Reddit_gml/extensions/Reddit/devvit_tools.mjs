#!/usr/bin/env node
import { spawn } from "node:child_process";
import { promises as fs } from "node:fs";
import path from "node:path";

/* ---------- utils ---------- */

async function ensureDir(p) {
    await fs.mkdir(p, { recursive: true });
}

async function pathExists(p) {
    try { await fs.access(p); return true; } catch { return false; }
}

/** Copy directory recursively (Node 16+: fs.cp exists; fallback if not) */
async function copyDir(src, dest) {
    if (fs.cp) {
        await fs.cp(src, dest, { recursive: true });
        return;
    }
    await ensureDir(dest);
    const entries = await fs.readdir(src, { withFileTypes: true });
    await Promise.all(entries.map(async (e) => {
        const s = path.join(src, e.name);
        const d = path.join(dest, e.name);
        if (e.isDirectory()) await copyDir(s, d);
        else if (e.isFile()) await fs.copyFile(s, d);
    }));
}

/**
 * Run a command.
 * @param {string} cmd           Program/exe (e.g., "npm", "git", "devvit")
 * @param {string[]} args        Arguments array
 * @param {string} cwd           Working directory
 * @param {object} [opts]
 * @param {boolean} [opts.newWindow=false]  Open in a new console window (Windows).
 * @param {boolean} [opts.wait=true]        Wait for the command to finish (when newWindow=true).
 * @param {string}  [opts.title=""]         Title for the new window (Windows).
 */
function run(cmd, args, cwd, opts = {}) {
    const { newWindow = false, wait = true, title = "" } = opts;

    return new Promise((resolve, reject) => {
        let child;

        if (newWindow && process.platform === "win32") {
            // Use cmd.exe built-in `start` to create a new window.
            // No shell:true; we invoke cmd.exe directly, so no DEP0190.
            const startArgs = ["/c", "start", title];
            if (wait) startArgs.push("/wait");
            // Ensure the new window starts in the desired working directory:
            if (cwd) startArgs.push("/D", cwd);
            // Run the actual command and close when done (`cmd /c`):
            startArgs.push("cmd", "/c", cmd, ...args);

            child = spawn("cmd.exe", startArgs, {
                cwd,
                stdio: "inherit",
                shell: false,
                windowsHide: false,
            });
        } else {
            // Same window (and the only mode on non-Windows)
            child = spawn(cmd, args, {
                cwd,
                stdio: "inherit",
                shell: false,      // safe; no DEP0190
                windowsHide: false
            });
        }

        child.on("close", (code) => {
            if (code === 0) resolve();
            else reject(new Error(`${cmd} ${args.join(" ")} -> exit ${code}`));
        });
        child.on("error", reject);
    });
}

/** Read UTF-8 string, strip BOM if present */
async function readUtf8(p) {
    let s = await fs.readFile(p, "utf8");
    if (s.charCodeAt(0) === 0xFEFF) s = s.slice(1); // strip BOM
    return s;
}

/** Write UTF-8 without BOM */
async function writeUtf8(p, s) {
    // Node writes UTF-8 without BOM by default:
    await fs.writeFile(p, s, "utf8");
}

/* ---------- env helpers for GameMaker-style names ---------- */

/** Replace non-alphanumerics with '_' and UPPERCASE (typical env style) */
function normalizeExtName(name) {
    return String(name ?? "").replace(/[^A-Za-z0-9]/g, "_").toUpperCase();
}

/** Case-insensitive env lookup (POSIX is case-sensitive, Windows is not) */
function getEnvInsensitive(key) {
    if (key in process.env) return process.env[key];
    const lower = key.toLowerCase();
    for (const k of Object.keys(process.env)) {
        if (k.toLowerCase() === lower) return process.env[k];
    }
    return undefined;
}

/** Loose boolean parse: "1|true|yes|on" (case-insensitive) -> true */
function envToBool(v, dflt = false) {
    return v == null ? dflt : /^(1|true|yes|on)$/i.test(String(v).trim());
}

/** Integer parse with default */
function envToInt(v, dflt = 0) {
    const n = Number(v);
    return Number.isFinite(n) ? n : dflt;
}

/**
 * Read a specific extension option:
 * YYEXTOPT_<EXT>_<option>
 */
function getExtensionOption(extName, option, dflt = undefined) {
    const EXT = normalizeExtName(extName);
    const key = `YYEXTOPT_${EXT}_${option}`;
    const v = getEnvInsensitive(key);
    return v !== undefined ? v : dflt;
}

/** Typed variants */
function getExtensionOptionBool(extName, option, dflt = false) {
    return envToBool(getExtensionOption(extName, option), dflt);
}

function getExtensionOptionInt(extName, option, dflt = 0) {
    return envToInt(getExtensionOption(extName, option), dflt);
}

/**
 * Get the extension version:
 * GMEXT_<EXT>_version
 */
function getExtensionVersion(extName, dflt = undefined) {
    const EXT = normalizeExtName(extName);
    const key = `GMEXT_${EXT}_version`;
    const v = getEnvInsensitive(key);
    return v !== undefined ? v : dflt;
}

/**
 * List all options for an extension as an object map.
 * Scans process.env for keys starting with YYEXTOPT_<EXT>_ (case-insensitive).
 */
function listExtensionOptions(extName) {
    const EXT = normalizeExtName(extName);
    const prefixLower = `yyextopt_${EXT.toLowerCase()}_`;
    const out = {};
    for (const [k, v] of Object.entries(process.env)) {
        if (k.toLowerCase().startsWith(prefixLower)) {
            const opt = k.slice(prefixLower.length); // keep original case after the prefix
            out[opt] = v;
        }
    }
    return out;
}

/* ---------- tasks ---------- */

// Must match: ^[a-zA-Z][a-zA-Z0-9_]*$
function isValidSubredditName(name) {
    return /^[A-Za-z][A-Za-z0-9_]*$/.test(name);
}

function isValidProjectName(name) {
  return /^[a-z0-9-]{3,16}$/.test(String(name ?? ""));
}

/**
 * Build a subreddit-safe name from a project name.
 * - strips diacritics (café -> cafe)
 * - replaces unsupported chars with "_"
 * - collapses multiple "_" and trims edges
 * - ensures it starts with a letter (prefixes with "r" if not)
 * - optional min/max length clamp (Reddit is typically 3–21 chars)
 */
function toDevSubreddit(projectName, { minLen = 3, maxLen = 21, fallbackPrefix = "r" } = {}) {
    let s = String(projectName ?? "").trim();

    // strip diacritics (Node 12+ supports Unicode property escapes)
    s = s.normalize("NFKD").replace(/\p{M}/gu, "");

    // replace unsupported with "_" and normalize underscores
    s = s.replace(/[^A-Za-z0-9_]+/g, "_")
        .replace(/_+/g, "_")
        .replace(/^_+|_+$/g, "");

    // ensure starts with a letter
    if (!/^[A-Za-z]/.test(s)) s = (fallbackPrefix + "_" + s).replace(/_+$/, "");

    // clamp length (optional, but usually desired)
    if (s.length > maxLen) s = s.slice(0, maxLen).replace(/_+$/, "");
    while (s.length < minLen) s += "_"; // pad if you care about minimum

    // final safety: if it somehow became empty, fall back to a constant
    if (!s) s = "dev_subreddit";

    return s;
}

async function ensureDevvitProject({ outputDir, project, templateUrl, subredditDev }) {
    const projDir = path.join(outputDir, project);
    const devvitJson = path.join(projDir, "devvit.json");

    if (await pathExists(devvitJson)) return projDir;

    console.log(`[INFO] No devvit project found. Cloning template to ${projDir} ...`);
    await ensureDir(outputDir);
    await run("git", ["clone", templateUrl, project], outputDir);

    // Optionally personalize template JSONs:
    await updateJson(path.join(projDir, "package.json"), (j) => {
        if (!j) return j;
        j.name = project;
        return j;
    });
    await updateJson(path.join(projDir, "devvit.json"), (j) => {
        if (!j) return j;
        j.name = project;

        if (j.menu && j.menu.items) {
            j.menu.items[0].description = project;
        }

        if (!j.dev) j.dev = {};
        subredditDev ??= project;
        j.dev.subreddit = isValidSubredditName(subredditDev) ? subredditDev : `${toDevSubreddit(subredditDev)}_dev`;

        return j;
    });

    return projDir;
}

async function updateJson(p, mutator) {
    if (!(await pathExists(p))) return;
    const raw = await readUtf8(p);
    let j;
    try { j = JSON.parse(raw); }
    catch { console.warn(`[WARN] ${p} is not valid JSON; skipping structured update.`); return; }
    const newJ = mutator(j);
    const pretty = JSON.stringify(newJ, null, 2) + "\n";
    await writeUtf8(p, pretty);
}

async function copyBuildIntoClient({ sourceDir, clientDir }) {
    const srcHtml5 = path.join(sourceDir, "html5game");
    const destPublic = path.join(clientDir, "public");
    await ensureDir(destPublic);

    // html5game folder
    if (await pathExists(srcHtml5)) {
        await copyDir(srcHtml5, path.join(destPublic, "html5game"));
    } else {
        console.warn(`[WARN] Source html5game folder not found at ${srcHtml5}`);
    }

    // favicon
    const favSrc = path.join(sourceDir, "favicon.ico");
    if (await pathExists(favSrc)) {
        await fs.copyFile(favSrc, path.join(destPublic, "favicon.ico"));
    }

    // index.html
    const idxSrc = path.join(sourceDir, "index.html");
    if (!(await pathExists(idxSrc))) throw new Error(`Missing source index.html at ${idxSrc}`);
    await fs.copyFile(idxSrc, path.join(clientDir, "index.html"));
}

async function patchIndexHtml(indexPath) {
    let html = await readUtf8(indexPath);

    // Skip if already patched
    if (/<script[^>]*type\s*=\s*['"]module['"]/i.test(html)) {
        console.log(`[INFO] Already patched: ${indexPath}`);
        return;
    }

    // Match classic GM runtime tag + optional cachebust
    const pattern1 = /<script[^>]*\bsrc\s*=\s*['"]\s*\/?html5game\/([^'"\?]+)\.js(?:\?[^'"]*)?['"][^>]*>\s*<\/script>/is;
    // Remove inline onload init
    const pattern2 = /\s*<script[^>]*>\s*window\.onload\s*=\s*GameMaker_Init\s*;?\s*<\/script>/is;

    const m = html.match(pattern1);
    if (!m) {
        // Show a loose hint if the strict match fails
        const loose = html.match(/<script[^>]*\bsrc[^>]*html5game[^>]*>/is);
        if (loose) console.warn(`[WARN] Found html5game script but strict pattern didn't match:\n${loose[0]}`);
        throw new Error(`Could not find html5game/*.js <script> tag in ${indexPath}`);
    }
    const game = m[1];

    const replacement = `<script type="module">
  const s = document.createElement('script');
  s.src = '/html5game/$1.js';
  s.onload = () => window.GameMaker_Init?.();
  document.head.appendChild(s);
</script>`;

    // Backup and write
    await fs.copyFile(indexPath, `${indexPath}.bak`);
    html = html.replace(pattern1, replacement).replace(pattern2, "");
    await writeUtf8(indexPath, html);

    console.log(`[INFO] Patched ${indexPath} (game file: ${game}.js). Backup: ${indexPath}.bak`);
}

async function expandPlaceholderInTree(rootDir, placeholder, replacement, { renamePaths = false } = {}) {
    // Simple recursive walk; skip vendor/binary dirs; treat JSON safely
    const skipDirs = new Set([".git", "node_modules", "dist", "build"]);
    const skipExts = new Set([".png", ".jpg", ".jpeg", ".gif", ".ico", ".pdf", ".zip", ".wasm", ".mp3", ".ogg"]);
    let changed = 0, renamed = 0;

    async function walk(dir) {
        const entries = await fs.readdir(dir, { withFileTypes: true });
        for (const e of entries) {
            const full = path.join(dir, e.name);
            if (e.isDirectory()) {
                if (skipDirs.has(e.name)) continue;
                await walk(full);
                if (renamePaths && e.name.includes(placeholder)) {
                    const newName = e.name.split(placeholder).join(replacement);
                    const dest = path.join(dir, newName);
                    if (dest !== full) { await fs.rename(full, dest); renamed++; }
                }
            } else if (e.isFile()) {
                if (skipExts.has(path.extname(e.name).toLowerCase())) continue;
                let text = await readUtf8(full);
                if (!text.includes(placeholder)) {
                    // maybe the file has BOM only: already handled in readUtf8
                } else {
                    if (full.toLowerCase().endsWith(".json")) {
                        // Escape replacement for JSON strings
                        const safe = replacement
                            .replace(/\\/g, "\\\\")
                            .replace(/"/g, '\\"')
                            .replace(/\t/g, "\\t")
                            .replace(/\r/g, "\\r")
                            .replace(/\n/g, "\\n");
                        text = text.split(placeholder).join(safe);
                    } else {
                        text = text.split(placeholder).join(replacement);
                    }
                    await writeUtf8(full, text);
                    changed++;
                }
                if (renamePaths && e.name.includes(placeholder)) {
                    const newName = e.name.split(placeholder).join(replacement);
                    const dest = path.join(dir, newName);
                    if (dest !== full) { await fs.rename(full, dest); renamed++; }
                }
            }
        }
    }

    await walk(rootDir);
    console.log(`[INFO] Placeholder "${placeholder}" -> "${replacement}": ${changed} file(s) changed${renamePaths ? `, ${renamed} path(s) renamed` : ""}.`);
}

/* ---------- main flow ---------- */

(async () => {

    const outputDir = getExtensionOption("Reddit", "outputPath", undefined);
    const projectName = getExtensionOption("Reddit", "projectName", undefined);
    const buildAction = getExtensionOption("Reddit", "buildAction", undefined);

    const subredditDev = getExtensionOption("Reddit", "subredditDev", "");
    const subredditProd = getExtensionOption("Reddit", "subredditProd", "");
    const templateUrl = "https://github.com/reddit/devvit-template-hello-world.git";
    const sourceDir = getEnvInsensitive("YYoutputFolder");

    console.log(`[INFO] Reddit extension version: ${getExtensionVersion("Reddit")}`);

    if (!outputDir.trim() || !projectName.trim()) {
        console.error("[ERROR] Missing required extension options: 'outputDirectory' and 'projectName'.");
        process.exit(1);
    }

    if (!isValidProjectName(projectName)) {
        console.error("[ERROR] Invalid project name provided: project names must be between 3 and 16 characters long, and can contain lowercase letters, numbers, and hyphens.");
        process.exit(1);
    }

    // Ensure devvit project
    let projectDir = path.join(outputDir, projectName);
    if (!(await pathExists(path.join(projectDir, "devvit.json")))) {
        projectDir = await ensureDevvitProject({ outputDir, project: projectName, templateUrl, subredditDev });
        console.log("[INFO] Template cloned and personalized.");
    }

    const clientDir = path.join(projectDir, "src", "client");
    await ensureDir(clientDir);

    // Clean previous client build (only files we overwrite)
    await fs.rm(path.join(clientDir, "index.html"), { force: true });
    await fs.rm(path.join(clientDir, "public"), { recursive: true, force: true });

    // Copy new build
    await copyBuildIntoClient({ sourceDir, clientDir });

    // Patch index.html
    await patchIndexHtml(path.join(clientDir, "index.html"));

    // Expand template placeholder if your template still has it
    await expandPlaceholderInTree(projectDir, "<% name %>", projectName, { renamePaths: false });

    // npm install in project root (prefer ci if lockfile present)
    const hasLock = await pathExists(path.join(projectDir, "package-lock.json"));
    console.log("[INFO] Installing dependencies...");
    await run("npm", [hasLock ? "ci" : "i"], projectDir, { newWindow: true, title: "Installing npm dependencies" });
    console.log("[INFO] Dependencies ready.");

    // Switch on build action
    switch (buildAction) {
        case "Playtest":
            console.log("[INFO] Uploading and starting playtest...");
            await run("npm", ["run", "dev"], projectDir, { newWindow: true, title: "Starting playtest..." });
            console.log("[INFO] Playtest started. Refresh your subreddit page.");
            process.exit(255);
        case "Build":
            console.log("[INFO] Building client and server projects...");
            await run("npm", ["run", "build"], projectDir, { newWindow: true, title: "Building projects..." });
            process.exit(255);
        case "Upload":
            console.log("[INFO] Uploading new version of the application...");
            await run("npm", ["run", "deploy"], projectDir, { newWindow: true, title: "Uploading application..." });
            process.exit(255);
        case "Publish": 
            console.log("[INFO] Publishing application for review...");
            await run("npm", ["run", "launch"], projectDir, { newWindow: true, title: "Publishing application..." });
            process.exit(255);
        default:
            console.log("[INFO] Project ready:");
            console.log(`  Folder: ${projectDir}`);
            console.log(`  Next steps:`);
            console.log(`    npm run dev -> starts a development server where you can develop your application live on Reddit.`);
            console.log(`    npm run build -> builds your client and server projects.`);
            console.log(`    npm run deploy -> uploads a new version of your app.`);
            console.log(`    npm run launch -> publishes your app for review.`);
            process.exit(255);
            break;
    }
})().catch(err => {
    console.error("[ERROR]", err.message || err);
    process.exit(1);
});
