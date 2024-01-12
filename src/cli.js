import process from 'node:process';
import { Hono } from "hono";
import { serve } from "@hono/node-server";
import sqlite3 from "sqlite3";
let server = null;
let timer = null;
const app = new Hono();
const db_path = "state.db";
let db = null;
let master, toMaster = false;
let readyToStop = false;
console.log(`master = false`);
console.log(`readyToStop = true`);

// cold start and wait
function init() {
    master = false;
    readyToStop = true;
    console.log(`master = false`);
    console.log(`readyToStop = true`);
    server = serve({
        fetch: app.fetch,
        port: process.env?.PORT ?? 3000,
    }, (info) => {
        console.log(`Listening on http://localhost:${info.port}`);
    });
}
// received hook to switch to master
async function start() {
    // TODO: replace to state machine
    if(master || toMaster) return Promise.reject("Already master!");
    toMaster = true;
    readyToStop = false;
    console.log(`readyToStop = false`);
    db = new sqlite3.Database(db_path, sqlite3.OPEN_READWRITE | sqlite3.OPEN_CREATE);
    console.log("DB Open");
    db.serialize(() => {
        db.run("CREATE TABLE IF NOT EXISTS increment (idx TEXT)");

        const stmt = db.prepare("INSERT INTO increment VALUES (?)");
        for (let i = 0; i < 1; i++) {
            stmt.run(`${toBase64(Date.now())}${toBase64(i)}`);
        }
        stmt.finalize();

        db.each("SELECT rowid AS id FROM increment ORDER BY id DESC LIMIT 1", (err, row) => {
            console.log(row.id);
        });

        // watchdog hook ready to stop
        timer = setInterval(() => {
            // check time since last printed code
            readyToStop = true;
            console.log(`readyToStop = true`);
        }, 60e3);
        toMaster = false;

        console.log("Master ready");
        master = true;
        console.log(`master = true`);
    });
}

async function stop() {
    if(!readyToStop) console.error(new Error("Stopping without ready!"));
    clearInterval(timer);
    await Promise.all([
        db ? new Promise(resolve => db.close(() => resolve())) : Promise.resolve(),
        server ? new Promise(resolve => server.close(() => resolve())) : Promise.resolve()
    ]);
    console.log("Cleanup done");
}

// cleanup refs before exit
function handle(signal) {
    console.log(`Received ${signal}`);
}
process.on("SIGINT", async signal => {
    handle(signal);
    await stop();
});
process.on("SIGTERM", handle);

function toBase64(input) {
    return Buffer.from(`${input}`, "utf-8").toString("base64url");
}

app.get("/ready", (c) => c.json({
    status: "ok",
    master,
    readyToStop,
}));

app.put("/master", async(c) => {
    // TODO: replace to event emitter
    try {
        await start();
        return c.json({
            status: "ok",
        });
    } catch (e) {
        return c.json({ status: "already master" }, 403);
    }
});

await init();