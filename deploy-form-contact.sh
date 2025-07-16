#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# 1️⃣  Destination filename (final, post-injection)
###############################################################################
FORM_FILE="form-contact-with-script.html"

###############################################################################
# 2️⃣  Always rebase on latest remote before doing anything
###############################################################################
git fetch origin
git rebase origin/main

###############################################################################
# 3️⃣  Download latest Jotform source
###############################################################################
curl -Ls 'https://hipaa.jotform.com/251305644776158?source=full' -o "$FORM_FILE"

###############################################################################
# 4️⃣  Inject testSubmitFunction() just before </body>
###############################################################################
TMP_FILE="$(mktemp)"
perl -0777 -pe '
  s{</body>}{
<script>
// ----- auto‑inserted $(date -u +"%Y-%m-%dT%H:%M:%SZ") -----
function testSubmitFunction() {
  const emojiRE = /(👂🏻|👃🏻|🗣️)/gu;
  const serviceLine = document.getElementById("input_6")?.value || "";
  const serviceLineCleaned = serviceLine.replace(emojiRE, "").trim();
  const data = {
    location: document.getElementById("input_89")?.value || "",
    provider: document.getElementById("input_90")?.value || "",
    appointment_date_time: document.getElementById("input_101")?.value || "",
    serviceLine: serviceLineCleaned,
    condition: document.getElementById("input_48")?.value || "",
    urgent: document.getElementById("input_58")?.value || "",
    extra_services: document.getElementById("input_57")?.value || "",
    unsecure_text_ok: document.getElementById("input_84")?.value || "",
    insurance: document.getElementById("input_16")?.value || "",
    otherInsurances: document.getElementById("input_26")?.value || "",
    email: document.getElementById("input_1")?.value || "",
    phone_number: (document.getElementById("input_11")?.value || "").replace(/\\D/g, ""),
    newsletter: document.getElementById("input_5_0")?.checked || false
  };
  window.parent.postMessage({ type: "jotformSubmission", data }, "*");
  return true;
}
</script>
</body>}i' "$FORM_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$FORM_FILE"

###############################################################################
# 5️⃣  Commit & push if there are changes
###############################################################################
git add "$FORM_FILE"
if ! git diff --cached --quiet; then
  git commit -m "chore: auto‑update $FORM_FILE $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  git push origin main
else
  echo "✅ $FORM_FILE is already up to date."
fi
