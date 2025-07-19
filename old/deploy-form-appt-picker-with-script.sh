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
###############################################################################

# 1️⃣  Source and destination filenames
SRC_HTML="form-appt-picker-no-script.html"
DST_HTML="form-appt-picker-with-script.html"        # final output lives here

# 2️⃣  Copy the raw file to the destination
cp "$SRC_HTML" "$DST_HTML"

# 3️⃣  Inject a tiny helper that piggy‑backs on confirmAppointment()
#     • Grabs the slot via AppointmentPicker.getSelectedAppointment()
#     • postMessage’s it to whatever page is embedding the picker
TMP_FILE="$(mktemp)"
perl -0777 -pe '
  s{</body>}{
<script>
/* ----- auto‑inserted $(date -u +%Y-%m-%dT%H:%M:%SZ) ----- */
(function () {
  /* Preserve any existing confirmAppointment() */
  const originalConfirm = window.confirmAppointment || function() {};

  window.confirmAppointment = function () {
    try {
      // Grab the chosen slot from AppointmentPicker
      const slot = window.AppointmentPicker?.getSelectedAppointment?.();
      if (slot) {
        /* 👉 NEW: log it so you see exactly what we’re posting */
        console.log("appointmentSelected →", slot);

        // Ship it to the embedding window
        window.parent.postMessage(
          { type: "appointmentSelected", data: slot },
          "*"
        );
      }
    } catch (err) {
      console.error("postMessage for appointment failed:", err);
    }

    /* fall through to whatever confirmAppointment already did */
    return originalConfirm.apply(this, arguments);
  };
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
