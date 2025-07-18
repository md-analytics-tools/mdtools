#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# 0️⃣  Repo / branch / remote
#
# • Works from the root of the mdtools clone.
# • Assumes your normal `origin` remote and that you want to push to **main**.
#   If you authenticate over HTTPS with a PAT, keep the remote exactly as you
#   set it earlier:
#     git remote set-url origin "https://<PAT>@github.com/md-analytics-tools/mdtools.git"
#
# NOTE:
#   All JS strings now use double quotes ("pickerHeight", "load", "*") so the
#   outer shell‑level single quotes don’t clash—Perl no longer sees any embedded
#   ' to eat, and the quotes survive intact in the HTML output.
###############################################################################

# 1️⃣  Source and destination filenames
SRC_HTML="form-appt-picker-no-script.html"
DST_HTML="form-appt-picker-with-script.html"        # final output lives here

# 2️⃣  Copy the raw file to the destination
cp "$SRC_HTML" "$DST_HTML"

# 3️⃣  Inject helper + auto‑height + postMessage
TMP_FILE="$(mktemp)"
perl -0777 -pe '
  s{</body>}{
<script>
/* ----- auto‑inserted '"$(date -u +%Y-%m-%dT%H:%M:%SZ)"' ----- */
(function () {
  /* Preserve any existing confirmAppointment() */
  const originalConfirm = window.confirmAppointment || function () {};

  window.confirmAppointment = function () {
    try {
      const slot = window.AppointmentPicker?.getSelectedAppointment?.();
      if (slot) {
        console.log("appointmentSelected →", slot);
        window.parent.postMessage(
          { type: "appointmentSelected", data: slot },
          "*"
        );
      }
    } catch (err) {
      console.error("postMessage for appointment failed:", err);
    }
    return originalConfirm.apply(this, arguments);
  };

  function sendHeight () {
    const h = Math.max(
      document.documentElement.scrollHeight,
      document.body.scrollHeight
    );
    window.parent.postMessage({ type: "pickerHeight", value: h }, "*");
  }

  /* Fire once after first paint … */
  window.addEventListener("load", sendHeight, { once: true });

  /* …and again whenever the layout changes */
  new ResizeObserver(sendHeight).observe(document.body);
})();
</script>
</body>}gis;
' "$DST_HTML" > "$TMP_FILE" && mv "$TMP_FILE" "$DST_HTML"

# 4️⃣  Commit & push if anything changed
git add "$DST_HTML"
if ! git diff --cached --quiet; then
  git commit -m "auto: inject appointment postMessage $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  git push -u origin main
else
  echo "✅ $DST_HTML is already up to date."
fi
