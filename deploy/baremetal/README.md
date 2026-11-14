# baremetal/ — the same pod on a host you own (on-prem host)

Deploy the moon-pod onto a host **you already own**, instead of one provisioned in a cloud.
It is the same pod, for the same purpose: what a moon-pod is for today, and what it is not,
is in [Run it on a real host](../../README.md#run-it-on-a-real-host).

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

## Cloud and bare metal compared

| | Cloud (`..`) | Bare metal (here) |
|---|---|---|
| Purpose | demo / throwaway | the same pod, on a host you keep |
| Host | provisioned EC2 (ephemeral) | **yours, on-prem** |
| The pod | identical | identical |
| Provisioning | Terraform | none — the host exists |

Nothing about the fabric, the identity, or the pod changes between the two, and neither does
who decides what the pod may do. Running the pod on your own hardware does not make it
sovereign: see [Run it on a real host](../../README.md#run-it-on-a-real-host).
