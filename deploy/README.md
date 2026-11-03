# deploy/ — stand the pod up on a real cloud box and peer it into the fabric

Minimal IaC that proves the **literal moon-pod path end-to-end**: a Linux instance runs
the partner's own Zenoh **router**, that router dials your goatnet's fabric router over the mesh
(**router-to-router peering**), and a local publisher writes *through* it — so anything that
reaches the fabric provably transited the pod's router.

This is the cloud version of `tests/smoke/loopback.sh`: same shape, no stand-ins.

## Safety / partner-shareable by design

- **No secrets in code or state.** The signed bundle (cert/key) and the mesh setup-key are
  delivered to the instance *out-of-band* after apply — never through Terraform.
- **No account particulars committed.** VPC, subnet, AMI, and region are data-sourced or
  variables; nothing account-specific is hardcoded.
- **Gitignored:** state (it holds the generated SSH key + resource ids), `terraform.tfvars`
  (your IP), the generated key, and the delivered `bundle/` + `pod.env`. See `.gitignore`.

## Prerequisites

- Terraform ≥ 1.5, AWS credentials for your account, SSH, `scp`.
- A signed join bundle for the pod's identity (its cert/key/CA + the mesh setup-key, router
  endpoint, and slot). On the goat side this comes from `goat admin onboard`.

## 1. Deploy the box

```
cp terraform.tfvars.example terraform.tfvars   # set allowed_ssh_cidr = YOUR_IP/32
terraform init
terraform apply
```

Outputs the public IP and a ready `ssh_command`. cloud-init installs docker, netbird, and a
Zenoh client (~1–2 min after boot).

## 2. Deliver the bundle out-of-band + bring the pod up

```
IP=$(terraform output -raw public_ip)
KEY=$(terraform output -raw ssh_command | awk '{print $3}')

# Stage the (gitignored) secrets locally, then copy them up:
#   bundle/{cert.pem,key.pem,ca.pem}  — from your signed bundle tarball
#   pod.env                           — SETUP_KEY / MGMT_URL / ROUTER_ENDPOINT / SLOT
scp -i "$KEY" -r bundle pod.env pod-up.sh ubuntu@"$IP":~/

ssh -i "$KEY" ubuntu@"$IP" 'bash ~/pod-up.sh'
```

`pod-up.sh` enrolls on the mesh, renders the pod router config (dialing the fabric router),
starts the router, waits for the **router-to-router peering** line, and publishes through it.
Then check the fabric panoscope — the pod's identity should be live.

### pod.env shape (gitignored)

```
SETUP_KEY=...                       # from the bundle
MGMT_URL=https://netbird.<...>      # from the bundle
ROUTER_ENDPOINT=tls/zenoh.<...>:7447 # from the bundle
SLOT=<your-cert-CN / write-namespace>
```

## 3. Tear down (do this — it's an ephemeral demo box)

```
terraform destroy
```
