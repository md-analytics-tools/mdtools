#!/usr/bin/env bash
###############################################################################
# deploy-form-contact.sh
#
# • Works from the root of the mdtools clone
# • Leaves form-contact.html untouched
# • Produces   form-contact-with-script.html
# • --dry-run  → prints the transformed HTML to stdout (no file, no git)
###############################################################################
set -euo pipefail

# ─── CLI flags ────────────────────────────────────────────────────────────────
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) echo "❌ Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

# ─── Filenames ────────────────────────────────────────────────────────────────
SRC_HTML="form-contact.html"
DST_HTML="form-contact-with-script.html"
TMP_HTML="$(mktemp)"

# ─── Combined slot‑listener + testSubmitFunction block (quotes preserved) ────
read -r -d '' MDTOOLS_BLOCK <<'JS'
<!-- 🧩 auto‑inserted mdtools block -->
<script>
/* ───── slot listener ────────────────────────────────────────────────────── */
(function () {
  const FIELD_ID = 'input_101';                              // Jotform field id
  window.addEventListener('message', (evt) => {
    if (!evt?.data) return;

    let slotText = null;
    if (evt.data.type === 'appointmentSelected' && evt.data.data) {
      slotText = evt.data.data.label ?? evt.data.data.start;
    } else if (evt.data.type === 'debugFill') {
      slotText = evt.data.slot;
    }
    if (!slotText) return;

    const el = document.getElementById(FIELD_ID);
    if (!el) { console.warn(`[slot‑listener] ${FIELD_ID} not found`); return; }

    el.value = slotText;
    ['input','change','blur'].forEach(ev =>
      el.dispatchEvent(new Event(ev, { bubbles:true })));

    console.log(`[slot‑listener] Filled ${FIELD_ID} with “${slotText}”`);
  }, false);
})();

/* ───── jotform → parent bridge ──────────────────────────────────────────── */
function testSubmitFunction() {
  // Gather field values from the form
  const emojiRE = /(👂🏻|👃🏻|🗣️)/gu;
  var serviceLine = document.getElementById("input_6") ? document.getElementById("input_6").value : "";
  const serviceLineCleaned = serviceLine.replace(emojiRE, '').trim();
  const extractedEmojis = serviceLine.match(emojiRE) || [];

  var location = document.getElementById("input_89") ? document.getElementById("input_89").value : "";
  var provider = document.getElementById("input_90") ? document.getElementById("input_90").value : "";
  var appointment_date_time = document.getElementById("input_101") ? document.getElementById("input_101").value : "";

  var condition = document.getElementById("input_48") ? document.getElementById("input_48").value : "";
  var urgent = document.getElementById("input_58") ? document.getElementById("input_58").value : "";
  var extra_services = document.getElementById("input_57") ? document.getElementById("input_57").value : "";

  var insurance = document.getElementById("input_16") ? document.getElementById("input_16").value : "";
  var otherInsurances = document.getElementById("input_26") ? document.getElementById("input_26").value : "";
  var email = document.getElementById("input_1") ? document.getElementById("input_1").value : "";
  var phone_number = document.getElementById("input_11")
                    ? document.getElementById("input_11").value.replace(/\D/g, "")
                    : "";
  var unsecure_text_ok = document.getElementById("input_84") ? document.getElementById("input_84").value : "";
  var newsletter = document.getElementById("input_5_0") ? document.getElementById("input_5_0").checked : false;

  var submissionData = {
    location: location,
    provider: provider,
    appointment_date_time: appointment_date_time,
    serviceLine: serviceLineCleaned,
    condition: condition,
    urgent: urgent,
    extra_services: extra_services,
    unsecure_text_ok: unsecure_text_ok,
    insurance: insurance,
    otherInsurances: otherInsurances,
    email: email,
    phone_number: phone_number,
    newsletter: newsletter
  };

  window.parent.postMessage({
    type: "jotformSubmission",
    data: submissionData
  }, "*");

  return true; // allow normal form submission
}
</script>
<!-- /🧩 mdtools block -->
JS

# ─── Transform HTML ───────────────────────────────────────────────────────────
perl -0777 -pe "
  # 1. Remove any previous mdtools block
  s{<!-- 🧩 auto‑inserted mdtools block -->(.|\\n)*?<!-- /🧩 mdtools block -->}{}g;

  # 2. Inject fresh block immediately before </body>
  s{</body>}{$MDTOOLS_BLOCK\n</body>}i;
" "$SRC_HTML" > "$TMP_HTML"

# ─── Dry‑run? ────────────────────────────────────────────────────────────────
if $DRY_RUN; then
  cat "$TMP_HTML"
  rm  "$TMP_HTML"
  echo "✅ Dry‑run complete — no file written, no git commands run."
  exit 0
fi

# ─── Move into place & commit ────────────────────────────────────────────────
mv "$TMP_HTML" "$DST_HTML"
echo "✅ Injection complete: $DST_HTML generated."

git add "$DST_HTML"
git commit -m "chore: auto‑update ${DST_HTML} $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "✅ Committed changes, pulling latest from remote..."
git pull --rebase origin main
git push origin main
echo "🚀 Deployed!"
