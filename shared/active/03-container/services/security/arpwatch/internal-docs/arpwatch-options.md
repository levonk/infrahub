# Network Monitoring Research Summary

You asked for structured JSON logging, custom tagging/alerting logic, and bandwidth monitoring. Here is a comparison of options:

## 1. Pi.Alert (Recommended for "Something Better")

**Pi.Alert** (or the [Pialert](https://github.com/pucherot/Pi.Alert) fork) is a robust, open-source tool designed specifically for this use case.

- **Pros:**
  - **Web UI:** Excellent interface for managing devices, tags, and alerts.
  - **Device Discovery:** Automatically identifies manufacturers and stores history.
  - **Alerts:** Supports webhooks, email, MQTT, etc.
  - **Docker:** Easy to deploy via Docker.
- **Cons:**
  - **Bandwidth:** Does _not_ monitor bandwidth per device (requires router-level data or intrusive monitoring).
  - **JSON Logs:** Uses a database (SQLite) rather than a stream of JSON logs, though it can trigger webhooks (JSON) on events.

## 2. Bettercap

**Bettercap** is a "Swiss Army knife" for network reconnaissance.

- **Pros:**
  - **Events:** Can stream events in JSON format.
  - **Passive Mode:** Can run passively to listen for ARP/MDNS.
- **Cons:**
  - **Complexity:** Steep learning curve; designed for security professionals/pentesters.
  - **Overkill:** Includes offensive tools that might be unnecessary or risky on a home network.

## 3. Custom Python Container (Scapy)

We can build a custom container using Python and Scapy to replace `arpwatch`.

- **Pros:**
  - **Exact Fit:** We can implement the exact JSON structure and tagging logic you described.
  - **Lightweight:** Only does what you ask.
- **Cons:**
  - **Maintenance:** You own the code.
  - **Bandwidth:** Still cannot passively monitor bandwidth via ARP.

## The Bandwidth Limitation

**Important:** Passive ARP monitoring (like `arpwatch` or `Pi.Alert`) _cannot_ measure bandwidth usage. ARP packets only establish connections; they do not carry the data payload.
To monitor bandwidth, you must:

1.  **Mirror Port:** Send all switch traffic to the monitoring port.
2.  **Gateway/Router:** Monitor at the router level (e.g., SNMP, NetFlow, or a custom router firmware).
3.  **ARP Spoofing:** (Not recommended) Trick devices into routing traffic through your container (intrusive, slows down network).

## Recommendation

- If you want a **"better" existing tool** with a UI and alerts: **Use Pi.Alert**.
- If you strictly need **custom JSON logs** and specific tagging logic: **Build the Custom Python Container**.

## Follow-up Answers

### Is Bettercap better than arp-scan?

**Yes, for continuous monitoring.**

- **`arp-scan`** is an _active_ scanner. It runs once, shouts "Who is here?", lists the replies, and exits. It is not designed to sit and watch for new devices in real-time.
- **`bettercap`** is a _framework_. It can run indefinitely, passively listening to network traffic (ARP, mDNS, etc.) to detect new devices the moment they speak. It generates a stream of events (JSON) that you can log or act upon.

### Is Pi.Alert compatible with AdGuard/CoreDNS?

**Yes.**

- **No Dependency:** Pi.Alert does _not_ require Pi-hole. It primarily uses `arp-scan` (under the hood) to discover devices on the network layer.
- **DNS Integration:** While it _can_ import data from Pi-hole, it works perfectly fine without it. It will still detect devices, MAC addresses, and vendors regardless of what DNS server you use (AdGuard, dnsdist, CoreDNS, etc.).
