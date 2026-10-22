#!/usr/bin/env python3
import json
import os
import sys
import urllib.error
import urllib.request


def main():
    try:
        base = os.environ["HINDSIGHT_API_URL"].rstrip("/")
        request = urllib.request.Request(
            f"{base}/v1/default/banks/personal/consolidate",
            data=b"{}",
            headers={
                "Authorization": f"Bearer {os.environ['HINDSIGHT_API_KEY']}",
                "Content-Type": "application/json",
            },
            method="POST",
        )
        # Do not retry an ambiguous submission: it may already have queued work.
        with urllib.request.urlopen(request, timeout=30) as response:
            result = json.load(response)
        print(json.dumps({"event": "accepted", "bank": "personal",
                          "operation_id": result["operation_id"]}), flush=True)
        return 0
    except urllib.error.HTTPError as error:
        print(json.dumps({"event": "failed", "http_status": error.code}), flush=True)
    except Exception as error:
        print(json.dumps({"event": "failed", "error": str(error)}), flush=True)
    return 1


if __name__ == "__main__":
    sys.exit(main())
