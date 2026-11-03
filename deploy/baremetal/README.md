# baremetal/ — the sovereign target (on-prem host)

Deploy the moon-pod onto a host **you already own, in your facility**. This is the target
that matters operationally: by principle, **mission data at rest does not live in the cloud**
— it lives on sovereign hardware. The cloud path (`..`) is only a convenience for a
**demo**; this is the real shape.

The pod is identical to the cloud demo — same `pod-up.sh`, same signed bundle. The only
difference is that the host already exists (nothing is provisioned in anyone's cloud) and the
data plane runs on your iron. That is the whole point: swapping the *target* doesn't change
the *pod*.

## Use

```
cp target.env.example target.env     # point at YOUR host (HOST / SSH_USER / SSH_KEY)
# stage the (gitignored) secrets in the shared parent dir, same as the cloud path:
#   ../bundle/{cert.pem,key.pem,ca.pem}   ../pod.env
./bootstrap.sh
```

`bootstrap.sh` SSHes in, installs prerequisites (`prereqs.sh` — the bare-metal equivalent of
the cloud path's cloud-init), delivers the bundle out-of-band, and runs `pod-up.sh`: enroll on
the mesh → start the pod router → **peer router-to-router with the fabric** → publish through
it. Check the fabric panoscope; your identity should be live.

## Why this is the sovereignty story

| | Cloud (`..`) | Bare metal (here) |
|---|---|---|
| Purpose | demo / throwaway | real operations |
| Host | provisioned EC2 (ephemeral) | **yours, on-prem** |
| Mission data at rest | not allowed (demo only, destroy after) | **stays on your hardware** |
| The pod | identical | identical |
| Provisioning | Terraform | none — the host exists |

Nothing about the fabric, the identity, or the pod changes between the two. Sovereignty is a
property of **where you run it**, and the pod is built so that's a free choice.
