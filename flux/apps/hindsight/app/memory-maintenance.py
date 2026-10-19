#!/usr/bin/env python3
"""Shared Hindsight maintenance. Run only through one Forbid CronJob."""

import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime
from zoneinfo import ZoneInfo

TZ = ZoneInfo("Europe/Athens")
# Python weekdays: Monday=0, Wednesday=2, Thursday=3, Saturday=5.
DAYS = {0: "oh-my-pi", 2: "hermes-heron", 3: "oh-my-pi", 5: "hermes-heron"}
BANKS = ("hermes-heron", "oh-my-pi")
POLL_SECONDS = 30
SUBMISSION_HEADROOM = 600

class Maintenance:
    def __init__(self, bank, seconds):
        self.bank = bank
        self.base = os.environ["HINDSIGHT_API_URL"].rstrip("/")
        self.token = os.environ["HINDSIGHT_API_KEY"]
        self.deadline = time.monotonic() + seconds
        self.active = None

    def log(self, event, **fields):
        print(json.dumps({"event": event, "bank": self.bank, **fields}), flush=True)

    def remaining(self):
        seconds = self.deadline - time.monotonic()
        if seconds <= 0:
            raise TimeoutError("07:00 cutoff reached; server work may still be running")
        return seconds

    def request(self, bank, path, payload=None):
        url = f"{self.base}/v1/default/banks/{urllib.parse.quote(bank, safe='')}/{path}"
        req = urllib.request.Request(
            url,
            data=None if payload is None else json.dumps(payload).encode(),
            headers={"Authorization": f"Bearer {self.token}",
                     "Content-Type": "application/json"},
            method="GET" if payload is None else "POST",
        )
        with urllib.request.urlopen(req, timeout=min(30, self.remaining())) as response:
            return json.load(response)

    def listing(self, bank, path, key="items", **filters):
        result = []
        while True:
            query = urllib.parse.urlencode({**filters, "limit": 100, "offset": len(result)})
            page = self.request(bank, f"{path}?{query}")[key]
            result.extend(page)
            if len(page) < 100:
                return result

    def wait(self, bank, operation_id):
        self.active = {"bank": bank, "operation_id": operation_id}
        while True:
            operation = self.request(bank, f"operations/{operation_id}")
            status = operation["status"]
            self.log("operation", **self.active, status=status,
                     progress=operation.get("progress"))
            if status == "completed":
                self.active = None
                return
            if status in {"failed", "cancelled"}:
                raise RuntimeError(f"Operation {operation_id} ended {status}; inspect it in Hindsight")
            time.sleep(min(POLL_SECONDS, self.remaining()))

    def drain(self, banks, kinds):
        # Re-list after waiting: a consolidation can enqueue its next round.
        while True:
            active = []
            for bank in banks:
                for kind in kinds:
                    for status in ("processing", "pending"):
                        active.extend((bank, op["operation_id"]) for op in self.listing(
                            bank, "operations", key="operations", type=kind, status=status))
            if not active:
                return
            for bank, identifier in dict.fromkeys(active):
                self.wait(bank, identifier)

    def submit(self, path, payload):
        if self.remaining() < SUBMISSION_HEADROOM:
            raise TimeoutError("Not starting more work with less than ten minutes remaining")
        # Never retry an ambiguous POST failure: it may already have queued work.
        self.log("submitting", path=path)
        result = self.request(self.bank, path, payload)
        self.log("accepted", operation_id=result["operation_id"])
        self.wait(self.bank, result["operation_id"])

    def check_policies(self):
        for bank in BANKS:
            config = self.request(bank, "config")["config"]
            if not config["enable_observations"] or config["enable_auto_consolidation"]:
                raise RuntimeError(f"{bank}: require observations on and auto-consolidation off")
            for model in self.listing(bank, "mental-models", detail="content"):
                trigger = model.get("trigger") or {}
                if trigger.get("refresh_after_consolidation") or trigger.get("refresh_cron"):
                    raise RuntimeError(f"{bank}/{model['id']}: independent refresh trigger is enabled")

    def run(self):
        self.check_policies()
        self.drain(BANKS, ("consolidation", "refresh_mental_model"))
        self.submit("consolidate", {})
        self.drain((self.bank,), ("consolidation",))

        models = self.listing(self.bank, "mental-models", detail="metadata")
        models.sort(key=lambda model: (model.get("last_refreshed_at") or "", model["id"]))
        failed = []
        for model in models:
            identifier = model["id"]
            if model.get("last_refresh_failed_at"):
                failed.append(identifier)
                self.log("needs_attention", model=identifier)
                continue
            if not model["is_stale"]:
                self.log("unchanged", model=identifier)
                continue
            self.submit(f"mental-models/{urllib.parse.quote(identifier, safe='')}/refresh", {})
        if failed:
            raise RuntimeError(f"Models require investigation before retry: {failed}")
        self.log("maintenance_completed")


def main():
    now = datetime.now(TZ)
    bank = DAYS.get(now.weekday())
    cutoff = now.replace(hour=7, minute=0, second=0, microsecond=0)
    if bank is None or not 2 <= now.hour < 7:
        print(json.dumps({"event": "outside_maintenance_window"}))
        return 0
    runner = Maintenance(bank, cutoff.timestamp() - now.timestamp())
    try:
        runner.run()
        return 0
    except urllib.error.HTTPError as error:
        runner.log("failed", http_status=error.code, active=runner.active)
    except Exception as error:
        runner.log("failed", error=str(error), active=runner.active)
    return 1


if __name__ == "__main__":
    sys.exit(main())
