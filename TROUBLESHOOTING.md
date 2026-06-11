# Troubleshooting — DevOps Infrastructure

## Issue 1: ingress-nginx stuck Pending (port conflict)

**Gejala:**
```
0/1 nodes available: node(s) didn't have free ports for the requested pod ports
```

**Root cause:**
k3s built-in Traefik bind hostPort 80/443. ingress-nginx juga minta hostPort 80/443. Cuma 1 node.

**Fix:**
1. Delete Traefik:
   ```bash
   kubectl delete helmchart -n kube-system traefik traefik-crd
   kubectl delete addon -n kube-system traefik
   ```
2. Hapus manifest Traefik (permanen):
   ```bash
   sudo rm /var/lib/rancher/k3s/server/manifests/traefik.yaml
   ```
3. Tambah `disable: traefik` di `/etc/rancher/k3s/config.yaml` (format YAML):
   ```yaml
   disable:
     - traefik
   ```
4. Restart k3s:
   ```bash
   sudo systemctl restart k3s
   ```

**Pencegahan:**
- Ansible k3s role sudah pakai `--disable=traefik` di `ansible/roles/k3s_server/tasks/main.yml`
- Setup.sh juga sudah handle via ansible
- Kalau install k3s manual, pastikan tambah `--disable=traefik`

---

## Issue 2: CoreDNS UDP 53 timeout — DNS resolution gagal

**Gejala:**
- cloudflared: `lookup region1.v2.argotunnel.com on 10.43.0.10:53: server misbehaving`
- cert-manager: `Error initializing issuer: dial tcp: lookup acme-v02.api.letsencrypt.org: server misbehaving`
- CoreDNS logs: `read udp 10.42.0.X:XXXXX->8.8.8.8:53: i/o timeout`

**Root cause:**
UDP port 53 dari pod network (10.42.0.0/24) ke upstream DNS (8.8.8.8/8.8.4.4) diblok oleh firewall/network. Host bisa resolve via systemd-resolved, tapi pod tidak bisa.

Dikonfirmasi: ICMP ke 8.8.8.8 OK, TCP 53 OK, UDP 53 timeout.

**Fix:**
1. Patch CoreDNS ConfigMap — ganti `forward . /etc/resolv.conf` jadi `forward . 8.8.8.8 8.8.4.4 { force_tcp }`:
   ```bash
   kubectl patch configmap -n kube-system coredns --type merge -p '{
       "data": {
           "Corefile": ".:53 {\n    errors\n    health\n    ready\n    kubernetes cluster.local in-addr.arpa ip6.arpa {\n      pods insecure\n      fallthrough in-addr.arpa ip6.arpa\n    }\n    hosts /etc/coredns/NodeHosts {\n      ttl 60\n      reload 15s\n      fallthrough\n    }\n    prometheus :9153\n    cache 30\n    loop\n    reload\n    loadbalance\n    import /etc/coredns/custom/*.override\n    forward . 8.8.8.8 8.8.4.4 {\n        force_tcp\n    }\n}\nimport /etc/coredns/custom/*.server\n"
       }
   }'
   ```
2. Restart CoreDNS:
   ```bash
   kubectl rollout restart deploy -n kube-system coredns
   ```

**Pencegahan:**
- `fix_coredns_force_tcp()` sudah ditambah di `setup.sh`, dipanggil dari `deploy_all()` sebelum HelmCharts
- Idempotent — cek `force_tcp` existing sebelum patch

---

## Diagnosis commands

```bash
# Cek pod yg pakai hostPort 80/443
kubectl get ds,deploy -A -o json | python3 -c "
import json,sys
data=json.load(sys.stdin)
for item in data.get('items',[]):
    spec=item.get('spec',{}).get('template',{}).get('spec',{})
    for c in spec.get('containers',[]):
        for p in c.get('ports',[]):
            hp=p.get('hostPort',0)
            if hp in [80,443]:
                print(f\"{item['metadata']['namespace']}/{item['metadata']['name']}: {c['name']} hostPort={hp}\")
"

# Test DNS dari pod
kubectl run test-dns --rm -it --restart=Never --image=busybox:1.36 -- nslookup google.com

# Cek CoreDNS config
kubectl get configmap -n kube-system coredns -o jsonpath='{.data.Corefile}'

# Cek CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50 | grep -E 'ERROR|timeout|misbehaving'

# Cek outbound connectivity dari pod
kubectl run test-net --rm -it --restart=Never --image=busybox:1.36 -- sh -c 'ping -c 2 8.8.8.8; nslookup google.com 8.8.8.8'
```
