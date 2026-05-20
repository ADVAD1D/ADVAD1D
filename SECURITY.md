### ADVAD Security and Architecture 

### Report: Encryption of Compiled Godot Games and Executables

## Introduction

This document outlines the security architecture implemented for protecting game assets, scripts, and resources in exported Godot executables in ADVAD. The primary mechanism relies on PCK file encryption using AES-256, combined with custom-compiled export templates. This approach provides a practical layer of protection against casual asset extraction while acknowledging the inherent limitations of client-side security.

## Encryption Architecture

Core Mechanism
Godot packs all project resources (scenes, scripts, textures, audio, etc.) into a .pck file (or embeds it directly into the executable). When encryption is enabled:

The PCK file is encrypted using AES-256 in CBC mode.
The encryption key (256-bit) is compiled directly into the custom export template binary.
At runtime, the Godot engine decrypts the resources on-the-fly using the embedded key.

## Key Components

Custom Export Templates: Official precompiled templates do not support encryption. Custom templates must be built from source with the encryption key defined at compile time.
Export Preset Configuration: In the Godot editor, the "Encrypt Exported PCK" option is enabled and the matching key is provided.
Binary Integration: The key resides in the final executable, protected by compilation optimizations (stripping symbols, release builds).

## Security Benefits

Prevents easy extraction of assets using common tools (e.g., simple PCK viewers or unpackers).,
Protects GDScript source code, scene structures, and resource files from casual inspection or "script kiddie" ripping.,
Maintains full game functionality with minimal performance overhead during loading.

## Implementation Details

Key Generation: Use a strong, randomly generated 256-bit key (e.g., via secure tools supporting AES-256-CBC).
Template Compilation: Build export templates from Godot source code, passing the encryption key during the build process.

## Limitations and Threat Model

Important Note: This encryption is not unbreakable. Since the decryption key must be available at runtime within the executable:

Determined reverse engineers can locate the key in the binary (especially with debugging tools or memory analysis).
It serves primarily as a deterrent rather than absolute protection.
Assets remain vulnerable to sophisticated attacks (binary patching, memory dumping, etc.).

## Conclusion

The PCK encryption system in Godot provides an effective balance between usability and security for most indie and small-studio projects. While it does not offer military-grade protection (impossible in fully offline client executables), it successfully deters casual and moderate threats, protecting advad intellectual property during distribution. Although I provide access to the source code, it's best to avoid reverse engineering to prevent exposing sensitive access tokens.

For questions regarding the implementation or further enhancements, refer to the project’s development documentation.

### Data Collection Notice

ADVAD uses anonymous device identifiers (UIDs) temporarily to maintain the security of transmissions and the integrity of global scores. No personally identifiable information is collected.

This data is stored on the backend infrastructure hosted on Render and is not sold to any third party.

### Vulnerability reporting
We take security breaches or flaws in the scoring system or AI API consumption very seriously.

If you find a severe vulnerability (such as the ability to bypass token authentication, encryption vulnerabilities, or injections affecting server integrity), please do not open a public issue.

Instead, report it directly by sending an email to: angelleonardohern3@gmail.com

Please provide clear details on how to reproduce the vulnerability. We will evaluate and fix the issue as soon as possible.

### Backend Security
# 🪐 Advad‑AI‑Server

A modular FastAPI-based API that proxies requests to Google’s Gemini LLM and manages a real-time game leaderboard.  
Designed to be embedded in a Godot game so your project can **consume a language‑model API securely and with rate‑limiting**, while also tracking player scores securely.

> ⚠️ **Security note**  
> The server expects requests to carry `X‑App‑Token` / `X-Admin-Key` headers; keep these tokens secret.  
> The real LLM API key and other secrets are securely encrypted at rest and decrypted in memory during runtime.

---

## 📁 Repository structure

```text
.
├── app/                      # Main application package
│   ├── config/               # Centralized configuration & runtime decryption
│   ├── database/             # Supabase / PostgreSQL connection
│   ├── routers/              # API endpoints (AI, Leaderboard, etc.)
│   ├── security/             # Cryptography scripts (gen_key.py, encrypt.py)
│   ├── services/             # Business logic & AI context
│   └── main.py               # FastAPI application factory
├── main.py                   # Main Uvicorn entry point
├── render.yaml               # Render Infrastructure-as-Code config
├── requirements.txt          # Python dependencies
└── README.md                 # This documentation
```

---

## 🧰 Features

- Single endpoint (`/askai`) to send prompts and receive generated text.
- Advanced AI Service layer using static methods and external markdown context.
- Leaderboard API for managing a PostgreSQL database (Supabase).
- Built‑in rate limiting (10 requests/minute per client IP for the AI).
- CORS enabled for cross‑origin calls from your Godot project or Astro Frontend.
- Simple token‑based authentication to prevent unauthorized use.

---

## 🛡️ Security Architecture & Encryption

Multiple security layers have been implemented to protect the server, the Gemini API quota, and mitigate vulnerabilities:

- **Environment Variable Encryption (Zero-Disk):** Secrets are NOT stored in plain text. The project uses the `cryptography` library (Fernet AES-128-CBC) to encrypt the `.env` file into a `.env.enc` payload. `app/config/settings.py` decrypts this payload directly into RAM via `io.StringIO` during startup.
- **Anti-DDoS Rate Limiting:** Integration of `slowapi`, limiting requests to **10 per minute per IP**. It uses `X-Forwarded-For` (`forwarded_allow_ips="*"`) to accurately resolve real IPs behind cloud reverse proxies like Render.
- **Strict Origin Validation (CORS):** HTTP requests are restricted exclusively to trusted domains.
- **Token Authentication (`X-App-Token` / `X-Admin-Key`):** Mandatory validation before processing requests, returning `403 Forbidden` if invalid.
- **Prompt Injection Mitigation:** User inputs are safely encapsulated and system instructions are strictly enforced.

---

## 🔐 The Encryption Workflow (How to manage secrets)

To ensure maximum operational security (OPSEC), we encrypt secrets locally before deploying.

### 1. Generating the Key
Run the key generator to create your local `secret.key` (This file is ignored in `.gitignore`):
```bash
python app/security/gen_key.py
```

### 2. Encrypting the Environment
Create your standard `.env` file with your real secrets:
```ini
GEMINI_API_KEY=your_key
DATABASE_URL=your_db_url
APP_TOKEN=your_token
```
Run the encryptor script:
```bash
python app/security/encrypt.py
```
This will generate `.env.enc`. 

### 3. Loading (Automatic)
The `settings.py` file automatically handles loading. Locally, it looks for `app/security/secret.key` and decrypts `.env.enc`. In production (Render), it looks for the `SECRET_KEY` environment variable.

---

## 🚀 Setup

1. **Clone the repo**:
   ```bash
   git clone https://github.com/<your‑username>/advad-backend.git
   cd advad-backend
   ```

2. **Create a virtual environment**:
   ```bash
   python -m venv venv
   source venv/bin/activate     # macOS / Linux
   .\venv\Scripts\activate      # Windows
   ```

3. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

4. **Run locally**:
   Simply run the main entry point. The server will decrypt variables and boot up Uvicorn.
   ```bash
   python main.py
   ```
   The unified server listens on the port specified by the environment (default `10000`).

---

## 🛠 Deployment to Render

This project is fully configured for Render utilizing **Secret Files** to maintain a clean GitHub repository.

1. Connect your repository to Render using the `render.yaml` blueprint (Docker environment).
2. Go to the **Environment** tab in your Render Web Service dashboard.
3. Add a normal **Environment Variable**:
   - `SECRET_KEY` = `<paste the contents of your local secret.key>`
4. Scroll down to **Secret Files** and create a file:
   - Filename: `.env.enc`
   - Contents: `<paste the contents of your .env.enc (gAAAAAB...)>`
5. Render will automatically place the Secret File at `/etc/secrets/.env.enc`. The `settings.py` module will detect it, decrypt it in memory, and boot the server seamlessly.

---

## 📡 API Endpoints

### AI Endpoints
- **`GET /`** → Health check.
- **`POST /askai`** → Send a prompt to the LLM. Requires `X-App-Token`.

### Leaderboard Endpoints
- **`POST /api/record-phase`** → Submit a player's reached phase.
- **`GET /api/check-name/{pilot_name}`** → Check pilot name availability.
- **`GET /api/top-pilots`** → Returns the top 10 grouped high scores.
- **`DELETE /api/admin/delete-pilot/{pilot_name}`** → Purge a pilot (Requires `X-Admin-Key`).

---

## 📝 Customization

- **Change AI Context:** Modify `app/services/chatai_context.md` to alter the core instructions.
- **Adjust rate limiting:** Modify the `@limiter.limit` decorator rules in the routers.

---

## 🧾 License & Contribution

Feel free to fork, modify, or integrate this microserver into your own projects.  
Contributions and issues are welcome.