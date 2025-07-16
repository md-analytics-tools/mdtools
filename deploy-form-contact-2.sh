#!/usr/bin/env bash
###############################################################################
# deploy-form-contact-2.sh  ‑‑ FINAL VERSION
###############################################################################
set -euo pipefail

# ─── optional flag -----------------------------------------------------------
DRY_RUN=false
[[ ${1:-} == "--dry-run" ]] && DRY_RUN=true

SRC_HTML="form-contact.html"
DST_HTML="form-contact-with-script.html"
TMP_HTML="$(mktemp)"

# ─── combined mdtools block --------------------------------------------------
MDTOOLS_BLOCK=$(cat <<'JSEND'
<!-- 🧩 auto‑inserted mdtools block -->
<script>
/* slot listener */
(function () {
  const FIELD_ID = 'input_101';
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
    if (!el) return console.warn(`[slot‑listener] ${FIELD_ID} not found`);
    el.value = slotText;
    ['input','change','blur'].forEach(ev =>
      el.dispatchEvent(new Event(ev,{bubbles:true})));
    console.log(`[slot‑listener] Filled ${FIELD_ID} with “${slotText}”`);
  }, false);
})();

/* jotform → parent bridge */
function testSubmitFunction() {
  const emojiRE = /(👂🏻|👃🏻|🗣️)/gu;
  const serviceLine = document.getElementById("input_6")?.value || "";
  const serviceLineCleaned = serviceLine.replace(emojiRE,'').trim();

  const data = {
    location:                document.getElementById("input_89")?.value || "",
    provider:                document.getElementById("input_90")?.value || "",
    appointment_date_time:   document.getElementById("input_101")?.value || "",
    serviceLine:             serviceLineCleaned,
    condition:               document.getElementById("input_48")?.value || "",
    urgent:                  document.getElementById("input_58")?.value || "",
    extra_services:          document.getElementById("input_57")?.value || "",
    unsecure_text_ok:        document.getElementById("input_84")?.value || "",
    insurance:               document.getElementById("input_16")?.value || "",
    otherInsurances:         document.getElementById("input_26")?.value || "",
    email:                   document.getElementById("input_1") ?.value || "",
    phone_number:            (document.getElementById("input_11")?.value || "").replace(/\D/g,""),
    newsletter:              document.getElementById("input_5_0")?.checked || false
  };

  window.parent.postMessage({ type: "jotformSubmission", data }, "*");
  return true;
}
</script>
<!-- /🧩 mdtools block -->
JSEND
)

# ─── transform HTML ----------------------------------------------------------
perl -0777 -pe "
  s{<!-- 🧩 auto‑inserted mdtools block -->(.|\\n)*?<!-- /🧩 mdtools block -->}{}g;
  s{</body>}{$MDTOOLS_BLOCK\n</body>}i;
" "$SRC_HTML" > "$TMP_HTML"

# ─── dry‑run? ----------------------------------------------------------------
if \$DRY_RUN; then
  cat "$TMP_HTML"
  rm "$TMP_HTML"
  echo '✅ Dry‑run complete.'
  exit 0
fi

# ─── write, commit, push -----------------------------------------------------
mv "$TMP_HTML" "$DST_HTML"
echo "✅ $DST_HTML generated."

git add "$DST_HTML"
git commit -m "chore: auto‑update ${DST_HTML} \$(date -u +%Y-%m-%dT%H:%M:%SZ)"
git pull --rebase origin main
git push origin main
echo "🚀 Deployed!"
