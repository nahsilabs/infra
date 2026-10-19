import json
import os
import sys
import time
import urllib.error
import urllib.request

BANK = "hermes-heron"
BASE_URL = os.environ["HINDSIGHT_API_URL"].rstrip("/")
TOKEN = os.environ["HINDSIGHT_API_KEY"]
STARTED = time.monotonic()
DEADLINE = STARTED + 10800
stage = "starting"
operation_id = None


def log(event, **fields):
    print(json.dumps({
        "event": event,
        "stage": stage,
        "bank": BANK,
        "operation_id": operation_id,
        "elapsed_seconds": round(time.monotonic() - STARTED),
        **fields,
    }), flush=True)


def request(path, method="GET"):
    req = urllib.request.Request(
        f"{BASE_URL}/v1/default/banks/{BANK}/{path}",
        data=b"{}" if method == "POST" else None,
        method=method,
        headers={
            "Authorization": f"Bearer {TOKEN}",
            "Content-Type": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.load(response)


def check_deadline():
    if time.monotonic() >= DEADLINE:
        raise TimeoutError(
            "Maintenance deadline exceeded; server operations may still be running"
        )


def wait_for_operation(identifier):
    global operation_id
    operation_id = identifier
    while True:
        check_deadline()
        operation = request(f"operations/{operation_id}")
        status = operation["status"]
        progress = operation.get("progress") or {}
        log("progress", status=status, phase=progress.get("stage"),
            processed=progress.get("processed"), total=progress.get("total"))
        if status == "completed":
            log("completed")
            return
        if status in {"failed", "cancelled"}:
            raise RuntimeError(operation.get("error_message") or f"Operation {status}")
        time.sleep(30)


def submit_and_wait(name, path):
    global stage, operation_id
    stage, operation_id = name, None
    check_deadline()
    log("submitting")
    result = request(path, method="POST")
    operation_id = result["operation_id"]
    log("accepted", deduplicated=result.get("deduplicated", False))
    wait_for_operation(operation_id)


def finish_consolidation_rounds():
    while True:
        check_deadline()
        active = []
        for status in ("processing", "pending"):
            result = request(f"operations?type=consolidation&status={status}&limit=100")
            active.extend(result["operations"])
        if not active:
            return
        for operation in active:
            wait_for_operation(operation["operation_id"])


def main():
    submit_and_wait("consolidation", "consolidate")
    finish_consolidation_rounds()
    for model in ("user-profile", "current-context", "goals-and-interests"):
        submit_and_wait(model, f"mental-models/{model}/refresh")
    log("maintenance_completed")


if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as error:
        log("http_error", status=error.code)
        sys.exit(1)
    except Exception as error:
        log("failed", error_type=type(error).__name__, error=str(error))
        sys.exit(1)
