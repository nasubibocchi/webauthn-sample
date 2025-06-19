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
  
  isWebAuthnSupported() {
    return window.PublicKeyCredential !== undefined;
  }

  signInWithPasskey(event) {
    event.preventDefault();
    this.getChallengeAndSubmitCredential(false);
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

    if (this.isWebAuthnSupported()) {
      if (PublicKeyCredential.isConditionalMediationAvailable) {
        // Check if the browser supports conditional mediation.
        // https://developer.mozilla.org/en-US/docs/Web/API/PublicKeyCredential/isConditionalMediationAvailable
        const isCMA = await PublicKeyCredential.isConditionalMediationAvailable();
        if (isCMA) {
          console.log("Conditional Mediation is available - initiating auto sign-in");
          // ページロード時に自動的にパスキー認証を開始
          this.getChallengeAndSubmitCredential(true);
        } else {
          console.log("Conditional Mediation is not available");
        }
      } else {
        console.log("Conditional Mediation is not supported");
      }
    } else {
      console.log("WebAuthn is not supported");
    }
  }

  getChallengeAndSubmitCredential(isCMA) {
    const data = new FormData(this.formTarget);
    data.delete('_method');

    console.log("Getting challenge and submitting credential");
    
    // POSTデータの準備
    // メールアドレス入力フィールドが空の場合は、discoverable credentialsフローを使用
    const isDiscoverableFlow = !data.get('user[email]') || data.get('user[email]').trim() === '';
    if (isDiscoverableFlow) {
      console.log("Using discoverable credentials flow");
      // メールアドレスが空の場合はPOSTボディから削除
      data.delete('user[email]');
    } else {
      console.log("Using traditional flow with email:", data.get('user[email]'));
    }

    fetch(this.requestOptionsUrlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        "Accept": "application/json",
      },
      body: isDiscoverableFlow ? null : data
    })
      .then(response => response.json())
      .then(async requestOption => {
        console.log("Challenge received:", requestOption);
        const credentialRequestOptions = parseRequestOptionsFromJSON({ publicKey: requestOption });
        if (isCMA) {        // https://w3c.github.io/webappsec-credential-management/#mediation-requirements
        credentialRequestOptions['mediation'] = 'conditional';
          
          // ユーザーの認証情報に関するヒントを追加（オプション）
          credentialRequestOptions.hints = {
            // ページがロードされたときにパスキーUIを自動的に表示する
            autoPrompt: true,
          };
        }
        
        try {
          console.log("Requesting credential with options:", credentialRequestOptions);
          const credentialRequestResponse = await get(credentialRequestOptions);
          console.log("Credential response received:", credentialRequestResponse);
          
          if (credentialRequestResponse) {
            this.credentialFieldTarget.value = JSON.stringify(credentialRequestResponse);
            console.log("Submitting form with credential");
            this.formTarget.submit();
          }
        } catch (error) {
          console.error("Error getting credential:", error);
          // エラーが発生した場合でも処理を続行できるようにする
          // ユーザーがキャンセルした場合などはエラーが発生するが、
          // それは正常なユーザーフローの一部である
        }
      })
      .catch(error => {
        console.error("Error during authentication:", error);
      });
  }
}
