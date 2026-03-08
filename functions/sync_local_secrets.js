const fs = require("fs");
const path = require("path");

const envPath = path.join(__dirname, ".env.local");
const secretPath = path.join(__dirname, ".secret.local");

if (!fs.existsSync(envPath)) {
  console.log("[sync-local-secrets] .env.local bulunamadi, atlandi.");
  process.exit(0);
}

const envContent = fs.readFileSync(envPath, "utf8");
const secretContent = fs.existsSync(secretPath) ?
  fs.readFileSync(secretPath, "utf8") :
  "";

if (envContent === secretContent) {
  console.log("[sync-local-secrets] .secret.local guncel.");
  process.exit(0);
}

fs.writeFileSync(secretPath, envContent, "utf8");
console.log("[sync-local-secrets] .env.local -> .secret.local senkronlandi.");
