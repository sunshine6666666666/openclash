# Current Server Baseline

This reference captures the deployment shape to reproduce on a fresh VPS, without copying secrets.

- OS: Debian GNU/Linux 12 on KVM
- Kernel family: Linux 6.1 cloud amd64
- Size class: 1 vCPU, about 1 GiB RAM, no swap
- Root disk: about 10 GiB, low utilization
- Public network: one public IPv4 on `eth0`
- Runtime: Docker + containerd
- 3x-ui image: `ghcr.io/mhsanaei/3x-ui:latest`
- Container name: `3x-ui`
- Docker mode: host network
- Data bind: `/opt/3x-ui/db` to `/etc/x-ui`
- Active node process: xray from the 3x-ui container
- Public node port: `443`
- Public subscription/helper port: `2096`
- Panel listen: localhost only
- Protocol target: one `vless` inbound using `tcp` + `reality`
- Flow: `xtls-rprx-vision`
- REALITY fingerprint: `chrome`
- Example REALITY target/SNI: `www.microsoft.com:443` / `www.microsoft.com`

Do not clone private values from the reference server. Always generate fresh UUIDs, REALITY keys, short IDs, panel paths, and client subscription IDs for a new VPS.
