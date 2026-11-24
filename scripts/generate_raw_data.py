"""
Generates synthetic payer data as CSVs - the "raw" layer the ELT loads.

    python scripts/generate_raw_data.py                 # -> seeds/raw/*.csv
    python scripts/generate_raw_data.py --out data/raw  # somewhere else (e.g. to PUT to a Snowflake stage)

Random values only - no real members, providers or claims.

Like real source extracts, the files are a little messy on purpose so the
staging layer has real work to do:
  - some pending claims are delivered again once adjudicated (same claim_id,
    later _loaded_at, final status)
  - status / gender values have inconsistent case and stray spaces
  - a few claims point at a provider that isn't in the provider file
  - a few claims have paid_amount > billed_amount
"""
import argparse
import csv
import random
from datetime import date, datetime, timedelta
from pathlib import Path

FIRST = ["James", "Mary", "Robert", "Patricia", "John", "Jennifer", "Ravi", "Anita",
         "Carlos", "Maria", "Wei", "Mei", "Ahmed", "Fatima", "David", "Sarah"]
LAST = ["Smith", "Johnson", "Williams", "Brown", "Patel", "Garcia", "Lee", "Khan",
        "Nguyen", "Lopez", "Wilson", "Reddy", "Kim", "Martin"]
PLANS = ["PPO", "HMO", "EPO", "HDHP"]
SPECIALTIES = ["Family Medicine", "Internal Medicine", "Pediatrics", "Cardiology",
               "Orthopedics", "Dermatology", "Radiology", "Emergency Medicine"]
STATES = ["IL", "TN", "TX", "OH", "IN", "WI", "MO"]
CLAIM_TYPES = ["PROFESSIONAL", "INSTITUTIONAL", "OUTPATIENT"]
STATUSES = ["PAID"] * 7 + ["DENIED"] * 2 + ["PENDING"]
# CPT-style codes with a rough allowed amount
PROCEDURES = {"99213": 110, "99214": 165, "99203": 140, "93000": 45, "71046": 60,
              "80053": 25, "85025": 18, "20610": 120, "97110": 55, "36415": 10}

LOAD_START = datetime(2026, 1, 5, 6, 0)


def rand_date(rng, start, end):
    return start + timedelta(days=rng.randint(0, (end - start).days))


def messy(rng, value):
    """Return the value with random case / whitespace noise ~15% of the time."""
    if rng.random() < 0.15:
        return rng.choice([value.lower(), f" {value}", f"{value} ", value.title()])
    return value


def members(rng, n):
    rows = []
    for i in range(1, n + 1):
        rows.append({
            "member_id": f"M{i:06d}",
            "first_name": rng.choice(FIRST),
            "last_name": rng.choice(LAST),
            "date_of_birth": rand_date(rng, date(1940, 1, 1), date(2022, 12, 31)).isoformat(),
            "gender": messy(rng, rng.choice(["M", "F"])),
            "plan_code": rng.choice(PLANS),
            "zip_code": f"{rng.randint(1, 99999):05d}",
            "effective_date": rand_date(rng, date(2022, 1, 1), date(2025, 12, 1)).isoformat(),
            "updated_at": (LOAD_START - timedelta(days=rng.randint(0, 300))).isoformat(sep=" "),
        })
    return rows


def providers(rng, n):
    rows = []
    for i in range(1, n + 1):
        rows.append({
            "provider_id": f"P{i:05d}",
            "npi": str(rng.randint(1_000_000_000, 1_999_999_999)),
            "provider_name": f"Dr. {rng.choice(FIRST)} {rng.choice(LAST)}",
            "specialty": rng.choice(SPECIALTIES),
            "state": rng.choice(STATES),
        })
    return rows


def claims_and_lines(rng, n, member_ids, provider_ids):
    claims, lines = [], []
    for i in range(1, n + 1):
        claim_id = f"CLM{i:08d}"
        service = rand_date(rng, date(2025, 7, 1), date(2025, 12, 31))
        received = service + timedelta(days=rng.randint(1, 45))
        status = rng.choice(STATUSES)

        n_lines = rng.choices([1, 2, 3, 4], weights=[50, 30, 15, 5])[0]
        billed_total = paid_total = 0.0
        for ln in range(1, n_lines + 1):
            code, allowed = rng.choice(list(PROCEDURES.items()))
            units = rng.choices([1, 2, 3], weights=[80, 15, 5])[0]
            billed = round(allowed * units * rng.uniform(1.2, 2.5), 2)
            paid = round(allowed * units * rng.uniform(0.7, 1.0), 2) if status == "PAID" else 0.0
            billed_total += billed
            paid_total += paid
            lines.append({"claim_id": claim_id, "line_number": ln, "procedure_code": code,
                          "units": units, "line_billed_amount": billed, "line_paid_amount": paid})

        loaded = LOAD_START + timedelta(days=(received - date(2025, 7, 1)).days // 7,
                                        minutes=rng.randint(0, 600))
        claims.append({
            "claim_id": claim_id,
            "member_id": rng.choice(member_ids),
            "provider_id": rng.choice(provider_ids),
            "claim_type": rng.choice(CLAIM_TYPES),
            "service_date": service.isoformat(),
            "received_date": received.isoformat(),
            "claim_status": messy(rng, status),
            "billed_amount": round(billed_total, 2),
            "paid_amount": round(paid_total, 2),
            "_loaded_at": loaded.isoformat(sep=" "),
        })

    # --- source problems the staging layer has to deal with ---
    # 1) pending claims re-delivered a few days later once they were adjudicated
    pending = [c for c in claims if c["claim_status"].strip().upper() == "PENDING"]
    for c in rng.sample(pending, k=min(len(pending), max(1, n // 50))):
        again = dict(c)
        again["claim_status"] = "DENIED"
        again["_loaded_at"] = (datetime.fromisoformat(c["_loaded_at"]) + timedelta(days=3)).isoformat(sep=" ")
        claims.append(again)
    # 2) a handful of claims for providers missing from the provider file
    for c in rng.sample(claims, k=5):
        c["provider_id"] = f"P9{rng.randint(1000, 9999)}"
    # 3) a few paid > billed (adjustments gone wrong upstream)
    for c in rng.sample([c for c in claims if c["paid_amount"] > 0], k=3):
        c["paid_amount"] = round(c["billed_amount"] * 1.15, 2)

    claims.sort(key=lambda c: (c["_loaded_at"], c["claim_id"]))
    return claims, lines


def write(path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    print(f"{len(rows):>6} rows -> {path}")


def generate(seed=7, n_members=600, n_providers=60, n_claims=2500):
    rng = random.Random(seed)
    m = members(rng, n_members)
    p = providers(rng, n_providers)
    c, cl = claims_and_lines(rng, n_claims, [r["member_id"] for r in m], [r["provider_id"] for r in p])
    return {"members": m, "providers": p, "claims": c, "claim_lines": cl}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="seeds/raw")
    ap.add_argument("--seed", type=int, default=7)
    args = ap.parse_args()
    for name, rows in generate(seed=args.seed).items():
        write(Path(args.out) / f"{name}.csv", rows)


if __name__ == "__main__":
    main()
