"""Post-send verification for the scheduled Ombudsman follow-up.

Runs ~30min after SynigorosFollowupMon fires. Checks state.json for
sent_at AND queries Gmail SENT for the recipient, then Telegram-notifies
the outcome. Reuses gmail-schedule-reply.py's token/api/tg helpers.
"""
import importlib.util, json, os, sys, time, urllib.parse

HERE = os.path.dirname(os.path.abspath(__file__))
STATE = os.path.join(HERE, "ombudsman-followup-state.json")
GSR = r"C:\Users\tbaltzakis\AppData\Roaming\devin\skills\gmail-send-ops\scripts\gmail-schedule-reply.py"

spec = importlib.util.spec_from_file_location("gsr", GSR)
gsr = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gsr)

st = gsr.load_state(STATE)
to = st.get("to", "?")
subject = st.get("subject", "?")

sent_ok = False
evidence = ""
try:
    q = gsr.api("GET", "messages?q=" + urllib.parse.quote(
        "in:sent to:%s newer_than:3d" % to) + "&maxResults=5")
    msgs = q.get("messages", [])
    # confirm subject match on the newest hit
    for m in msgs:
        full = gsr.api("GET", "messages/" + m["id"] + "?format=metadata"
                       "&metadataHeaders=Subject")
        headers = {h["name"].lower(): h["value"]
                   for h in full.get("payload", {}).get("headers", [])}
        if headers.get("subject", "").startswith("ΣΥΜΠΛΗΡΩΜΑΤΙΚΗ"):
            sent_ok = True
            evidence = "Gmail SENT msg " + m["id"]
            break
except Exception as e:
    evidence = "gmail check failed: " + str(e)[:200]

if not sent_ok and st.get("sent_at"):
    sent_ok = True
    evidence = "state.json sent_at=%s msg=%s" % (
        time.strftime("%H:%M", time.localtime(st["sent_at"])),
        st.get("sent_message_id", "?"))

if sent_ok:
    gsr.tg("✅ Synigoros follow-up VERIFIED sent: %s -> %s\n%s" % (
        subject, to, evidence))
    print("VERIFIED:", evidence)
    sys.exit(0)

log = os.path.join(HERE, "ombudsman-followup-state.log")
tail = ""
try:
    tail = open(log, encoding="utf-8", errors="replace").read()[-400:]
except Exception:
    pass
gsr.tg("⚠️ Synigoros follow-up NOT confirmed sent to %s.\n"
       "state=%s\n%s%s" % (to, json.dumps(st, ensure_ascii=False)[:300],
                           evidence, ("\nlog tail:\n" + tail) if tail else ""))
print("NOT SENT — alerted")
sys.exit(1)
