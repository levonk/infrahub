Based on available information, **Gravity Sync**, **Orbital Sync**, and **Nebula Sync** are community-developed tools primarily designed to synchronize configuration settings across multiple **Pi-hole** instances. This is typically done to maintain consistency for ad/blocklist management and achieve network redundancy/high availability for DNS filtering.

It's important to note that the landscape for these tools has evolved, particularly with the release of Pi-hole v6, which is reflected in their current status and intended use.

## Overview and Purpose

| Tool             | Primary Purpose                                                                                                                                                          | Pi-hole Version Compatibility                                                                                                     | Current Status/Successor Note                                                                                                                                                    |
| :--------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Gravity Sync** | To replicate core Pi-hole configuration settings (adlists, whitelists, local DNS, DHCP settings) between two Pi-hole instances, originally in a primary/secondary setup. | Primarily Pi-hole 5.x                                                                                                             | The project has seen a major rewrite to version 4.0, which moved to a peer-to-peer model, but the overall project is considered _archived_ by some users looking for v6 support. |
| **Orbital Sync** | To synchronize multiple Pi-hole instances by using Pi-hole's built-in **Teleporter** backup/restore function via the web interface, making it Docker-friendly.           | Pi-hole 5.x and below is generally supported; v6 support was planned but older reports indicated it was not yet fully compatible. | One user comment suggests it was abandoned, while others use it successfully for v5.                                                                                             |
| **Nebula Sync**  | A successor/rewrite of Gravity Sync, specifically designed to sync Pi-hole settings and blocklists between multiple **Pi-hole v6** instances using the new **API**.      | Pi-hole v6 and higher.                                                                                                            | Actively developed and recommended for Pi-hole v6+.                                                                                                                              |

## Feature Comparison Matrix

| Feature                               | Gravity Sync (v4+)                                                                                | Orbital Sync                                                     | Nebula Sync                                                                |
| :------------------------------------ | :------------------------------------------------------------------------------------------------ | :--------------------------------------------------------------- | :------------------------------------------------------------------------- |
| **⭐ FOSS**                           | ☑️ OSS (Community effort)                                                                         | ☑️ OSS                                                           | ⭐ FOSS                                                                    |
| **UX/UI (or CLI)**                    | Primarily CLI-driven with installation/config utilities.                                          | Relies on Admin Interface (via HTTP calls).                      | Configuration primarily via environment variables (Docker/Compose) or CLI. |
| **Setup Difficulty**                  | Rearchitected for simpler installation, but requires reinstallation for v4+.                      | Described as much easier to set up in Docker than Gravity Sync.  | Docker-Friendly; setup uses environment variables (e.g., Docker Compose).  |
| **Community**                         | Active development on v4, but less focus post-v6 release.                                         | Mixed reports on continued active development for v6.            | Actively developed as the successor to Gravity Sync for v6.                |
| **Last Commit Day Ago**               | Check specific repo for latest update date.                                                       | Check specific repo for latest update date.                      | Check specific repo for latest update date.                                |
| **Stars/Forks**                       | Check specific repo for latest stats.                                                             | Check specific repo for latest stats.                            | Check specific repo for latest stats.                                      |
| **Year Introduced**                   | Original version circa 2020.                                                                      | Introduced around 2022.                                          | Introduced as a successor to Gravity Sync for v6.                          |
| **Public Repository Link**            | Search for `vmstan/gravity-sync` on GitHub.                                                       | Search for `mattwebbio/orbital-sync` on GitHub.                  | Search for `lovelaze/nebula-sync` on GitHub.                               |
| **Run Modes**                         | CLI, Automation Jobs (Systemd).                                                                   | Primarily Docker container.                                      | Primarily Docker/Containerized.                                            |
| **Implementation Tech Stack**         | Not specified in detail, but involves SSH keys for connection.                                    | Node.js based, uses Teleporter backup/restore via Web Interface. | Uses the Pi-hole v6 **API**.                                               |
| **Platform Support**                  | Runs on the Pi-hole hosts themselves.                                                             | Any host running Docker.                                         | Any host running Docker/Container runtime.                                 |
| **Sync Mechanism**                    | Direct file/setting replication (Peer-to-Peer in v4+).                                            | Teleporter Backup/Restore via Web Interface login.               | Pi-hole API calls.                                                         |
| **Pi-hole v6 API Use**                | No (Successor needed for API).                                                                    | No (Relies on Teleporter, an older mechanism).                   | Yes.                                                                       |
| **Full/Selective Sync**               | Replicates core settings; limitations on what it _doesn't_ sync (e.g., upstream resolvers, logs). | Full sync via Teleporter backup/restore.                         | Full or Partial Sync Options available.                                    |
| **Automation**                        | Automation jobs (cron/randomized times).                                                          | Runs indefinitely or on specified interval (default 60 min).     | Cron-Based scheduling.                                                     |
| **Webhooks**                          | Not explicitly mentioned.                                                                         | Option to send notifications on success/failure.                 | Can invoke success/failure webhooks.                                       |
| **Configuration Changes on Replicas** | Changes on secondary nodes are overwritten.                                                       | Changes made on non-primary nodes will be overwritten.           | Not explicitly detailed, but implied primary-to-replicas push.             |
| **Requires SSH/Root Access**          | Yes, uses SSH for remote connection.                                                              | No, only requires Admin Web Interface access (URL/Password).     | No direct mention, relies on API over HTTP/S.                              |

## Summary of Use and Difficulty

- **Gravity Sync**: Was the original standard, best for Pi-hole v5 users comfortable with a CLI/SSH-based setup directly on the host machine. Its transition to v4 introduced a peer-to-peer model, simplifying the primary/secondary concept, but its focus has been superseded by v6-specific tools.
- **Orbital Sync**: Offers a distinct, user-friendly approach for Docker users by interacting with the web GUI (Teleporter). If you prefer not to grant SSH/root access, this is an option, _provided_ you are on Pi-hole v5 or the developer has finalized v6 support.
- **Nebula Sync**: This is the modern choice if you are running **Pi-hole v6**. It uses the official API, is Docker-friendly, and is actively maintained as the spiritual successor to the original Gravity Sync's functionality for the latest Pi-hole versions.

## Suggested Follow-up Questions

1.  What is the current last commit date and official repository link for **Nebula Sync** to confirm active maintenance?
2.  Are there any known issues or migration guides for moving from **Gravity Sync** (v5) to **Nebula Sync** (v6)?
3.  Does **Nebula Sync** support synchronization of custom DHCP settings, or is it limited to blocklists/whitelists like Pi-hole's Teleporter backup?

---

_Footnotes:_

1.  Common knowledge in the context of Pi-hole community maintenance that Gravity Sync was not immediately compatible with Pi-hole v6 and successors emerged.
2.  Gravity Sync v4+ introduced a peer-to-peer architecture instead of a strict primary/secondary relationship.
