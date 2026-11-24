import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from generate_raw_data import generate  # noqa: E402

DATA = generate(seed=7)


def test_sizes():
    assert len(DATA["members"]) == 600
    assert len(DATA["providers"]) == 60
    assert len({c["claim_id"] for c in DATA["claims"]}) == 2500


def test_same_seed_is_repeatable():
    assert generate(seed=7)["claims"] == DATA["claims"]


def test_redelivered_claims_go_from_pending_to_final():
    by_id = {}
    for c in DATA["claims"]:
        by_id.setdefault(c["claim_id"], []).append(c)
    dups = [sorted(v, key=lambda c: c["_loaded_at"]) for v in by_id.values() if len(v) > 1]
    assert len(dups) == 50
    for first, last in dups:
        assert first["claim_status"].strip().upper() == "PENDING"
        assert last["claim_status"] == "DENIED"
        assert last["_loaded_at"] > first["_loaded_at"]


def test_planted_problems_are_there():
    provider_ids = {p["provider_id"] for p in DATA["providers"]}
    assert sum(c["provider_id"] not in provider_ids for c in DATA["claims"]) == 5
    assert sum(c["paid_amount"] > c["billed_amount"] for c in DATA["claims"]) == 3
    statuses = [c["claim_status"] for c in DATA["claims"]]
    messy = [s for s in statuses if s != s.strip().upper()]
    assert messy, "expected some messy status values"


def test_lines_match_headers_for_clean_claims():
    lines = Counter()
    for ln in DATA["claim_lines"]:
        lines[ln["claim_id"]] += round(ln["line_billed_amount"] * 100)
    for c in DATA["claims"]:
        assert round(c["billed_amount"] * 100) == lines[c["claim_id"]]


def test_zip_codes_keep_leading_zeros():
    assert all(len(m["zip_code"]) == 5 for m in DATA["members"])
