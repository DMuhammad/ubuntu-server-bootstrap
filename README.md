# 🚀 Ubuntu Server Bootstrap

One-command interactive server setup for Ubuntu. No more repetitive manual configuration.

![Bash](https://img.shields.io/badge/bash-5.0%2B-green?logo=gnu-bash)
![Ubuntu](https://img.shields.io/badge/ubuntu-22.04%20|%2024.04-orange?logo=ubuntu)
![License](https://img.shields.io/badge/license-MIT-blue)

## Quick Start

The fastest way to run this on a fresh server is via the one-liner. It will automatically download the project to `/tmp` and execute the interactive CLI:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/DMuhammad/ubuntu-server-bootstrap/main/install.sh)
```

Or, if you prefer cloning it manually:

```bash
git clone https://github.com/DMuhammad/ubuntu-server-bootstrap.git
cd ubuntu-server-bootstrap
sudo bash install.sh
```

## ✨ Features

- **Interactive CLI** — Arrow-key navigation, space toggle, multi-select (no more typing numbers)
- **Modular** — Pick only the modules you need, or install everything at once
- **Idempotent** — Safe to run multiple times
- **Logged** — All actions logged to `~/.server-setup.log`

## 📦 Modules

| # | Module | Description |
|---|--------|-------------|
| 1 | **Initial Setup** | Update packages, timezone, firewall (UFW), swap, sudo user |
| 2 | **Nginx** | Install Nginx, configure virtual host with domain |
| 3 | **SSL** | Certbot + Let's Encrypt, auto-renewal |
| 4 | **PHP** | PHP 8.1 / 8.2 / 8.3 / 8.4 with selectable extensions, Composer |
| 5 | **Node.js** | NVM + Node.js (LTS/18/20/22), optional yarn & pnpm |
| 6 | **MySQL** | MySQL Server, automated secure install, optional DB & user |
| 7 | **PostgreSQL** | PostgreSQL 14-17, optional DB & user |
| 8 | **Redis** | Redis server, optional password, configurable maxmemory |
| 9 | **phpMyAdmin** | phpMyAdmin with Nginx, custom access path for security |
| 10 | **Git + SSH** | Git config, SSH key generation (ed25519/rsa), known_hosts |
| 11 | **Supervisor** | Supervisor daemon, optional Laravel queue worker config |
| 12 | **Scheduler** | Laravel scheduler or custom cron entry |

## 🎮 Controls

| Key | Action |
|-----|--------|
| `↑` `↓` | Navigate options |
| `Space` | Toggle selection (multi-select) |
| `a` | Select all |
| `n` | Select none |
| `Enter` | Confirm |

## 📁 Project Structure

```
server-setup/
├── install.sh              # Main entry point
├── utils/
│   ├── helper.sh           # Color output, logging, system checks
│   └── ui.sh               # Interactive UI engine
├── modules/
│   ├── initial.sh          # Initial server setup
│   ├── nginx.sh            # Nginx web server
│   ├── ssl.sh              # SSL / Let's Encrypt
│   ├── php.sh              # PHP-FPM
│   ├── node.sh             # Node.js via NVM
│   ├── mysql.sh            # MySQL
│   ├── postgres.sh         # PostgreSQL
│   ├── redis.sh            # Redis
│   ├── phpmyadmin.sh       # phpMyAdmin
│   ├── github.sh           # Git + SSH
│   ├── supervisor.sh       # Supervisor
│   └── scheduler.sh        # Cron scheduler
└── templates/
    ├── nginx.conf.stub      # Nginx virtual host template
    ├── nginx-ssl.conf.stub  # Nginx SSL template
    └── laravel-worker.conf.stub  # Supervisor worker template
```

## 🔧 Requirements

- Ubuntu 22.04 or 24.04
- Root or sudo access
- Bash 5.0+
- Internet connection

## 📝 License

MIT
