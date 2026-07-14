# Bookstore on AWS — deployment steps

VPC assumed: 2 public subnets (ALB), 2 private subnets (EC2), 3 isolated subnets (RDS).
Default security group allowing all traffic is fine for this demo.

---

## 0. Internet access for the private subnets

EC2 in a private subnet cannot run `apt-get install` without a route out.
Pick **one**:

- **NAT Gateway** — create it in a public subnet, then in the *private* route table add
  `0.0.0.0/0 → nat-xxxx`. Costs ~$0.045/hr, so delete it after the demo.
- **Skip it** — launch the ASG into the *public* subnets with "Auto-assign public IP" on.
  Free, works immediately. Still shows off the ALB and ASG.

Also confirm the public route table has `0.0.0.0/0 → Internet Gateway`.

---

## 1. RDS MySQL

1. RDS → Subnet groups → create one from your **3 isolated subnets**.
2. RDS → Create database → MySQL → **Free tier / db.t3.micro**, Single-AZ.
   - DB instance identifier: `bookstore-db`
   - Master username: `admin`, set a password you'll remember
   - VPC: yours. Subnet group: the one above. Security group: default.
   - Public access: **No**
3. Copy the **endpoint** once it's available.

Load the data (from any EC2 in the VPC, or temporarily set public access to Yes):

```bash
mysql -h <RDS-ENDPOINT> -u admin -p < schema.sql
```

---

## 2. Upload the backend to S3

```bash
cd backend
zip -r backend.zip server.js package.json
aws s3 mb s3://bookstore-code-yourname
aws s3 cp backend.zip s3://bookstore-code-yourname/
```

Create an IAM role named `bookstore-ec2-role`:
- Trusted entity: EC2
- Policy: `AmazonS3ReadOnlyAccess`

---

## 3. Launch template

EC2 → Launch templates → Create:

| Field | Value |
|---|---|
| Name | `bookstore-lt` |
| AMI | Ubuntu Server 24.04 LTS (64-bit x86) |
| Instance type | `t2.micro` or `t3.micro` |
| Key pair | your key (so you can SSH in to debug) |
| Subnet | *Don't include in template* — the ASG sets this |
| Security group | default |
| IAM instance profile | `bookstore-ec2-role` (Advanced details) |
| User data | paste `user-data.sh`, with the four variables at the top edited |

**Test it once before building the ASG.** Launch a single instance from the template, wait 3 minutes, SSH in and run:

```bash
sudo tail -50 /var/log/user-data.log
curl localhost:3000/health          # should return {"status":"ok",...}
curl localhost:3000/api/books       # should return the 12 books
```

If that works, terminate it and move on. Debugging a broken ASG is much worse than debugging one instance.

---

## 4. Target group + ALB

**Target group:**
- Type: Instances
- Protocol/port: **HTTP : 3000**
- VPC: yours
- Health check path: **`/health`**
- Advanced: healthy threshold 2, interval 15s (makes the demo faster)
- Register no targets — the ASG does that.

**Load balancer:**
- Application Load Balancer, internet-facing, IPv4
- Subnets: your **2 public subnets**
- Security group: default
- Listener: HTTP : 80 → forward to your target group

Copy the ALB **DNS name**.

---

## 5. Auto Scaling group

EC2 → Auto Scaling groups → Create:

| Field | Value |
|---|---|
| Launch template | `bookstore-lt` |
| Subnets | your 2 private subnets (or public, if you skipped the NAT) |
| Load balancing | Attach to existing → your target group |
| Health check type | **ELB** (not EC2) + 300s grace period |
| Desired / Min / Max | **2 / 1 / 4** |
| Scaling policy | Target tracking → Average CPU utilization → **50** |

Wait until both targets show **healthy** in the target group. Then:

```
http://<ALB-DNS-NAME>/api/books
```

You should see JSON. Backend is done.

---

## 6. Frontend on S3 + CloudFront

1. Edit `frontend/index.html` — set `const API = 'http://<ALB-DNS-NAME>';`
2. Create bucket `bookstore-site-yourname`, **uncheck Block all public access**.
3. Properties → Static website hosting → Enable → index document `index.html`.
4. Permissions → Bucket policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::bookstore-site-yourname/*"
  }]
}
```

5. Upload `index.html`.
6. CloudFront → Create distribution → Origin = the S3 **website endpoint** (the
   `...s3-website-...` URL, not the bucket dropdown), default root object `index.html`.
7. Open the CloudFront domain. Books should load.

> Note: the page loads over HTTPS (CloudFront) but calls the ALB over HTTP, so
> browsers may block it as mixed content. For a demo the easy fix is to open the
> **S3 website endpoint** (plain HTTP) instead. If you want it fully clean, add the
> ALB as a second origin on the same CloudFront distribution with path pattern
> `/api/*` and caching disabled — then set `const API = '';` in index.html.

---

## 7. Demo script

**Load balancing** — the footer shows which EC2 instance answered. Refresh a few
times, or `curl http://<ALB-DNS>/api/whoami` repeatedly; the hostname changes.

**Auto scaling** — hit the CPU burner endpoint in a loop:

```bash
for i in {1..40}; do curl -s http://<ALB-DNS>/api/load & done
```

Watch ASG → Activity: within ~3-5 minutes it launches new instances. Then stop and
watch it scale back in.

**Self-healing** — terminate an instance manually. The ASG replaces it, and the ALB
stops sending traffic to it in the meantime.

---

## 8. Tear down (don't skip this)

Delete in this order: ASG → ALB → target group → RDS (skip final snapshot) →
NAT Gateway → CloudFront → S3 buckets → launch template.
The NAT Gateway and RDS are the ones that quietly cost money.
