

#!/usr/bin/env bash
set -euo pipefail

FORM_SOURCE_FILE="form-contact.html"
FORM_OUTPUT_FILE="form-contact-with-script.html"

curl -Ls 'https://hipaa.jotform.com/251305644776158?source=full' -o "$FORM_SOURCE_FILE"

TMP_FILE="$(mktemp)"
perl -0777 -pe '
  s{</body>}{
<script>

      // This was auto-updated on '"$(date -u +"%Y-%m-%dT%H:%M:%SZ")"'
    
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
</body>}i' "$FORM_SOURCE_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$FORM_OUTPUT_FILE"

echo "✅ Injection complete: $FORM_OUTPUT_FILE generated."

# Discard changes to raw file to avoid blocking pull
git checkout -- "$FORM_SOURCE_FILE"

git add "$FORM_OUTPUT_FILE"
if ! git diff --cached --quiet; then
  git commit -m "chore: auto-update $FORM_OUTPUT_FILE $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  echo "✅ Committed changes, pulling latest from remote..."
  git pull --rebase origin main
  echo "✅ Pushing to remote..."
  git push origin main
else
  echo "✅ $FORM_OUTPUT_FILE is already up to date. No commit needed."
fi
