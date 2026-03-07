# AzureLab-Autopilot

> Automated Windows Server & Azure hybrid infrastructure deployment toolkit.  
> Deploy a complete client infrastructure from a single config file — no clicking, no forgetting.

---

## What it does

Instead of spending 3-4 hours clicking through GUIs for every new client, you run a script and get a fully configured infrastructure in minutes.

Every module is driven by a `config.json` file — change the client name, rerun, done.

---

## Modules

### ✅ Module 1 — AD Factory
Deploy a complete Active Directory environment from a single JSON config.

- Forest & Domain installation
- Sites & Services (multi-site replication)
- Organizational Unit structure
- Security Groups & User accounts
- Fine-Grained Password Policies
- DNS (forwarders, records, scavenging)
- DHCP (scopes, options, failover)

```powershell
# Simulate first
.\Deploy-ADStructure.ps1 -WhatIf

# Deploy
.\Deploy-ADStructure.ps1
```

→ [Go to Module 1](./01-ad-factory/)

---

### 🔜 Module 2 — HyperV Autoprovision
Automated VM provisioning from templates on Hyper-V.

- VM creation & configuration from template
- Virtual switch setup (internal / external / private)
- Hyper-V replication
- Windows Admin Center pre-configured dashboard

→ *Coming soon*

---

### 🔜 Module 3 — Arc Connect
Onboard and manage servers at scale via Azure Arc.

- Automated onboarding of N servers into Azure Arc
- Azure Policy application (compliance, guest config)
- Update Manager & Azure Monitor configuration
- HTML compliance report generation

→ *Coming soon*

---

### 🔜 Module 4 — Server Health Dashboard
Automated server health reporting across your entire fleet.

- CPU, RAM, disk, critical services monitoring
- Expiring certificates detection
- HTML report + email delivery
- Scheduled execution via Task Scheduler

→ *Coming soon*

---

## Real-world impact

| Without this toolkit | With this toolkit |
|---|---|
| 3-4 hours per client onboarding | Under 10 minutes |
| Manual steps, human errors | Repeatable, tested, version-controlled |
| Hard to audit or hand off | Everything is in Git |
| Tied to one admin's knowledge | Any engineer can pick it up |

---

## Stack

![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue?logo=powershell)
![Windows Server](https://img.shields.io/badge/Windows%20Server-2019%2F2022-0078D4?logo=windows)
![Azure](https://img.shields.io/badge/Microsoft%20Azure-Arc%20%7C%20Monitor-0089D6?logo=microsoft-azure)
![License](https://img.shields.io/badge/License-MIT-green)

- **PowerShell 5.1+** — automation & orchestration
- **Active Directory / Entra ID** — identity management
- **Azure Arc** — hybrid server management
- **Azure Monitor** — observability
- **Windows Admin Center** — centralized management
- **GitHub Actions** — CI/CD pipeline *(coming Module 3)*

---

## Requirements

- Windows Server 2019 or 2022
- PowerShell 5.1+
- Roles: AD DS, DNS, DHCP (Module 1)
- Azure subscription (Module 3+)
- Run as Administrator

---

## Getting started

```powershell
# Clone the repo
git clone https://github.com/MeriemAyari/azurelab-autopilot.git
cd azurelab-autopilot

# Go to Module 1
cd 01-ad-factory

# Edit config for your client
notepad config.json

# Simulate
.\Deploy-ADStructure.ps1 -WhatIf

# Deploy
.\Deploy-ADStructure.ps1
```

---

## Project structure

```
azurelab-autopilot/
├── 01-ad-factory/
│   ├── config.json               # Client configuration
│   ├── Deploy-ADStructure.ps1    # Main deployment script
│   └── README.md
├── 02-hyperv-autoprovision/      # Coming soon
├── 03-arc-connect/               # Coming soon
├── 04-server-health-dashboard/   # Coming soon
└── README.md                     # You are here
```

---

## Author

Built by **Meriem Ayari** — Cloud & Hybrid Infrastructure Engineer  
Specializing in Windows Server, Active Directory, Azure & PowerShell automation.

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-0A66C2?logo=linkedin)](https://linkedin.com/in/your-profile)
[![GitHub](https://img.shields.io/badge/GitHub-Follow-181717?logo=github)](https://github.com/MeriemAyari)

---

## License

MIT — free to use, adapt, and share.