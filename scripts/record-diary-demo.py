#!/usr/bin/env python3
"""Capture only the synthetic diary test, after its explicit authenticated-ready marker."""
import argparse
import pathlib
import signal
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument("log", type=pathlib.Path)
parser.add_argument("output", type=pathlib.Path)
args = parser.parse_args()
start = time.monotonic()
while time.monotonic() - start < 600:
    content = args.log.read_text(errors="replace") if args.log.exists() else ""
    if "DIARY_RECORD_READY" in content:
        break
    if "** TEST EXECUTE FAILED **" in content or "** TEST FAILED **" in content:
        raise SystemExit("The writing test did not reach its capture marker")
    time.sleep(1)
else:
    raise SystemExit("Timed out waiting for the writing test")

if args.output.exists():
    raise SystemExit("Choose a new output path; previous evidence is preserved")
args.output.parent.mkdir(parents=True, exist_ok=True)
with args.output.with_suffix(".recorder.log").open("w") as log:
    recorder = subprocess.Popen([
        "xcrun", "simctl", "io", "ABA536C2-EFB6-4AC2-A37A-31BDFA8C409D",
        "recordVideo", "--codec=h264", str(args.output.resolve())
    ], stdout=log, stderr=log)
    complete = False
    start = time.monotonic()
    while time.monotonic() - start < 150:
        content = args.log.read_text(errors="replace")
        if "DIARY_RECORD_DONE" in content:
            complete = True
            time.sleep(2)
            break
        if "testWritingFlowRecording]' failed" in content or recorder.poll() is not None:
            break
        time.sleep(1)
    if recorder.poll() is None:
        recorder.send_signal(signal.SIGINT)
    try:
        code = recorder.wait(timeout=30)
    except subprocess.TimeoutExpired:
        recorder.terminate()
        code = recorder.wait(timeout=10)
print("Completed workflow capture" if complete and code == 0 else "Diagnostic capture only")
raise SystemExit(0 if complete and code == 0 else 2)
