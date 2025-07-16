#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# 1️⃣  Destination filename (final, post‑injection)
###############################################################################
FORM_FILE="form-contact-with-script.html"

###############################################################################
# 2️⃣  Download the latest raw Jotform source
###############################################################################
curl -Ls 'https://hipaa.jotform.com/251305644776158?source=full' -o "$FORM_FILE"

###############################################################################
# 3️⃣  Inject testSubmitFunction() just before </body>
###############################################################################
TMP_FILE="$(mktemp)"
perl -0777 -pe '
  s{</body>}{
<script>

      // This was autoupdated
    
      function testSubmitFunction() {
      // Gather field values from the form


      // matches 👂🏻   👃🏻   🗣️   (ear+light-tone, nose+light-tone, speaking-head)
      const emojiRE = /(👂🏻|👃🏻|🗣️)/gu;
      var serviceLine = document.getElementById("input_6") ? document.getElementById("input_6").value : "";
      const serviceLineCleaned  = serviceLine.replace(emojiRE, '').trim();   // text without the emojis
      const extractedEmojis   = serviceLine.match(emojiRE) || [];          // ["👂🏻"] etc. if you need them

  
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

      // Build the data object
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

      // Send the data to the parent window
      window.parent.postMessage({
        type: "jotformSubmission",
        data: submissionData
      }, "*");

      // Return true to allow normal form submission (or false if you want to block it)
      return true;
    }
  </script>
</body>}i' "$FORM_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$FORM_FILE"

###############################################################################
# 4️⃣  Commit & push (rebasing to avoid non‑fast‑forward errors)
###############################################################################
git add "$FORM_FILE"
if ! git diff --cached --quiet; then
  git commit -m "chore: auto‑update $FORM_FILE $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  git pull --rebase origin main
  git push origin main
else
  echo "✅ $FORM_FILE is already up to date."
fi
