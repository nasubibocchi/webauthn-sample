import { Controller } from "@hotwired/stimulus";
import {
  get,
  parseRequestOptionsFromJSON
} from "@github/webauthn-json/browser-ponyfill";

export default class extends Controller {
  static targets = ["form", "credentialField"];
  static values = {
    requestOptionsUrl: String
  };

  signInWithPasskey(event) {
    event.preventDefault();
    this.getChallengeAndSubmitCredential();
  }

  async formTargetConnected(element) {
    // Check if the browser supports WebAuthn.
    if (window.PublicKeyCredential === undefined) {
      console.log("WebAuthn is not supported in this browser.");
      return;
    }

    if (window.PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable) {
      // Check if the browser supports User Verifying Platform Authenticator.
      // https://developer.mozilla.org/en-US/docs/Web/API/PublicKeyCredential/isUserVerifyingPlatformAuthenticatorAvailable
      const isUVPA = await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable();
      if (isUVPA) {
        console.log("User Verifying Platform Authenticator is available.");
      } else {
        console.log("User Verifying Platform Authenticator is not available.");
      }
    }

    // if (window.PublicKeyCredential.getClientCapabilities) {
    //   const capabilities = await PublicKeyCredential.getClientCapabilities();
    //   if (capabilities.userVerifyingPlatformAuthenticator) {
    //     console.log("User Verifying Platform Authenticator is supported.");
    //   }
    //   if (capabilities.passkeyPlatformAuthenticator) {
    //     console.log("Passkey Platform Authenticator is supported.");
    //   }
    //   if (capabilities.conditionalGet) {
    //     console.log("Conditional Get is supported.");
    //   }
    //   if (capabilities.conditionalCreate) {
    //     console.log("Conditional Create is supported.");
    //   }
    //   if (capabilities.hybridTransport) {
    //     console.log("Hybrid Transport is supported.");
    //   }
    // }

    if (supported()) {
      if (PublicKeyCredential.isConditionalMediationAvailable) {
        // Check if the browser supports conditional mediation.
        // https://developer.mozilla.org/en-US/docs/Web/API/PublicKeyCredential/isConditionalMediationAvailable
        const isCMA = await PublicKeyCredential.isConditionalMediationAvailable();
        if (isCMA) {
          console.log("CMA is available");
          this.getChallengeAndSubmitCredential(isCMA);
        } else {
          console.log("CMA is not available");
        }
      } else {
        console.log("CMA is not supported");
      }
    } else {
      console.log("WebAuthn is not supported");
    }
  }

  getChallengeAndSubmitCredential(isCMA) {
    const data = new FormData(this.formTarget);
    data.delete('_method');

    console.log("Getting challenge and submitting credential");

    fetch(this.requestOptionsUrlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        "Accept": "application/json",
      },
      body: data
    })
      .then(response => response.json())
      .then(async requestOption => {
        console.log("Challenge received:", requestOption);
        const credentialRequestOptions = parseRequestOptionsFromJSON({ publicKey: requestOption });
        if (isCMA) {
          // https://w3c.github.io/webappsec-credential-management/#mediation-requirements
          credentialRequestOptions['mediation'] = 'conditional';
        }
        const credentialRequestResponse = await get(credentialRequestOptions);
        console.log("Credential response:", credentialRequestResponse);
        this.credentialFieldTarget.value = JSON.stringify(credentialRequestResponse);
        this.formTarget.submit();
      })
      .catch(error => {
        console.error("Error during authentication:", error);
      });
  }
}
