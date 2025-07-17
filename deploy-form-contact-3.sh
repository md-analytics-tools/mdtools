#!/usr/bin/env bash
set -euo pipefail

# ◼︎ CONFIGURATION
JOTFORM_URL='https://hipaa.jotform.com/251305644776158'
FORM_SOURCE_FILE="form-contact.html"
FORM_OUTPUT_FILE="form-contact-with-script.html"

# ─── JotForm download artifact ───────────────────────────
# We fetch form-contact.html on each deploy run; don’t commit it.
form-contact.html
# ──────────────────────────────────────────────────────────


# 1️⃣ Download the raw JotForm HTML
curl -Ls "$JOTFORM_URL" > "$FORM_SOURCE_FILE"

# 2️⃣ Build the insertion block (edit *only* between EOFs)
INSERT_FILE="$(mktemp)"
cat << 'EOF' > "$INSERT_FILE"
<!-- 🧩 auto‑inserted mdtools block -->
<script>
/* make a shared namespace on window */
window.selectedAppointment = '';   // default empty string

/* ───── slot listener ────────────────────────────────────────────── */
(function () {
  const FIELD_ID = 'input_101';

  window.addEventListener('message', (evt) => {
    let slotText = null;

    if (evt?.data?.type === 'appointmentSelected' && evt.data.data) {
      slotText = evt.data.data.label ?? evt.data.data.start;
    } else if (evt?.data?.type === 'debugFill') {
      slotText = evt.data.slot;
    }
    if (!slotText) return;

    /* 1️⃣  Put it in the form field so Jotform sees it */
    const el = document.getElementById(FIELD_ID);
    if (el) {
      el.value = slotText;
      ['input','change','blur'].forEach(ev =>
        el.dispatchEvent(new Event(ev, { bubbles:true })));
    }

    /* 2️⃣  Keep an extra copy for testSubmitFunction() */
    window.selectedAppointment = slotText;
  }, false);
})();

/* jotform → parent bridge */
function testSubmitFunction() {
  const emojiRE = /(👂🏻|👃🏻|🗣️)/gu;
  const serviceLine = document.getElementById("input_6")?.value || "";
  const serviceLineCleaned = serviceLine.replace(emojiRE,'').trim();
  var appointmentDateTime = String(
    document.getElementById('input_101')?.value ||
    window.selectedAppointment ||   '');
  console.log('🗓️ appointment_date_time:', appointmentDateTime);

  const data = {
    location:                document.getElementById("input_89")?.value || "",
    provider:                document.getElementById("input_90")?.value || "",
    appointment_date_time:   appointmentDateTime,
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
EOF

# 3️⃣ Insert it before </body> via awk
awk -v ins="$INSERT_FILE" '
  BEGIN {
    while ( ( getline line < ins ) > 0 ) block = block line "\n"
    close(ins)
  }
  /<\/body>/ {
    printf "%s", block
  }
  { print }
' "$FORM_SOURCE_FILE" > "$FORM_OUTPUT_FILE"

# 4️⃣ Cleanup only the temp here-doc file
rm "$INSERT_FILE"

# 5️⃣ Git commit + pull (with autostash fallback) + push
git add "$FORM_OUTPUT_FILE"
git commit -m "auto-update form-contact-with-script.html $(date -u +%Y-%m-%dT%H:%M:%SZ)"

if git pull --rebase --autostash; then
  echo "Pulled with --autostash"
else
  git stash push -u -m "autostash before pull" >/dev/null
  git pull --rebase
  git stash pop --quiet
fi

git push
