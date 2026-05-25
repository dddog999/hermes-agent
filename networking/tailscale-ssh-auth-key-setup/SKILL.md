---
name: tailscale-ssh-auth-key-setup
description: "Setup Tailscale SSH auth key to bypass interactive login (no-click method)"
category: networking
---

# Tailscale SSH Auth Key Setup (No‑Click Method)

**Purpose**  
Create a reusable auth key for Tailscale SSH that bypasses the browser‑based “login” step, allowing headless or automated connections to a device (e.g., `kangle`) from another Tailscale node.

**When to use**  
- You need a stable, script‑able SSH endpoint (e.g., for CI/CD, remote services, or when you’re on the machine itself).  
- You want to avoid the interactive “open this URL and authorize” flow for each new device.  
- You are comfortable managing ACL tags and expiration.

**Prerequisites**  
- Access to the Tailscale admin console (tailscale.com/admin).  
- Permission to create auth keys in the admin panel.  
- The target device must be running a Tailscale SSH server (enabled by default).  

**Steps**

1. **Generate the key**  
   - Open `https://login.tailscale.com/admin/settings/keys`.  
   - Click **Generate auth key**.  
   - **Important:** Check **Pre‑authorized** (this makes the key usable without further UI confirmation).  
   - Optionally set a short expiration (7–30 days) or leave default.  
   - Click **Generate key** and copy the displayed string.

2. **Configure the receiving device** (`kangle` in this case)  
   - Paste the key into the device’s `~/.ssh/authorized_keys` via the Tailscale admin panel “SSH authorized keys” section, or let Tailscale inject it automatically when you start SSH with the key.  
   - Ensure the device’s SSH daemon is listening (default port 22). No extra firewall changes are needed if you stay within the Tailscale network.

3. **Connect headlessly**  
   ```bash
   ssh -i <private-key> -p 22 kangle@<tailscale-ip>
   ```
   - The private key is derived from the auth key; you can use `ssh -Auth_key=<generated-key>` if your client supports it.  
   - Because the key is pre‑authorized, the connection succeeds without any UI prompt.

4. **Optional – expose via Windows port‑proxy (for non‑Tailscale clients)**  
   ```powershell
   netsh interface portproxy add v4tov4 listenport=2222 listenaddress=0.0.0.0 connectport=22 connectaddress=<tailscale-ip>
   ```
   - Then connect from any host as `ssh user@localhost -p 2222`.  

5. **Monitoring & revocation**  
   - Revoke the key anytime from the admin console → **Keys** → **Revoke**.  
   - The revocation is immediate; no daemon restart required.

**Common pitfalls & fixes**

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `Permission denied (publickey)` | Key not pasted into `authorized_keys` or not pre‑authorized. | Double‑check the key format and that **Pre‑authorized** was checked. |
| Connection times out | SSH daemon not running or blocked by local firewall. | `sudo service ssh status` → `sudo service ssh start`. Open port 22 locally if a firewall blocks it. |
| ACL denies access | Device tag not whitelisted in ACL. | Add the device’s tag (e.g., `kangle`) to the ACL rules in the admin console. |
| Keyboard‑interactive prompts appear | Using an older Tailscale version. | Upgrade Tailscale to the latest release. |

**Tips for production use**

- Store the generated key in a secret manager (e.g., HashiCorp Vault, 1Password) rather than hard‑coding it in scripts.  
- Rotate keys periodically (e.g., every 30 days) to limit exposure.  
- Tag devices with meaningful labels (`kangle`, `wooking`, etc.) to simplify ACL management.  

**References**  
- Tailscale Docs: [Auth Keys](https://tailscale.com/docs/features/access-control/auth-keys)  
- Tailscale Docs: [SSH Authorized Keys](https://tailscale.com/docs/netflow/ssh)  

---  

*Saved as a reusable skill for future headless Tailscale SSH setups.*