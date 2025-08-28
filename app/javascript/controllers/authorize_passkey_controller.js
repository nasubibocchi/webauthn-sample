import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["form", "credentialField"];
  static values = {
    requestOptionsUrl: String
  };

  parseRequestOptionsFromJSON(options) {
    const publicKey = {
      ...options.publicKey,
      challenge: this.base64urlToArrayBuffer(options.publicKey.challenge)
    };

    if (options.publicKey.allowCredentials) {
      publicKey.allowCredentials = options.publicKey.allowCredentials.map(cred => ({
        ...cred,
        id: this.base64urlToArrayBuffer(cred.id)
      }));
    }

    return { publicKey };
  }

  assertionToJSON(assertion) {
    return {
      id: assertion.id,
      rawId: this.arrayBufferToBase64url(assertion.rawId),
      response: {
        authenticatorData: this.arrayBufferToBase64url(assertion.response.authenticatorData),
        clientDataJSON: this.arrayBufferToBase64url(assertion.response.clientDataJSON),
        signature: this.arrayBufferToBase64url(assertion.response.signature),
        userHandle: assertion.response.userHandle ? this.arrayBufferToBase64url(assertion.response.userHandle) : null
      },
      type: assertion.type
    };
  }

  base64urlToArrayBuffer(base64url) {
    const base64 = base64url.replace(/-/g, '+').replace(/_/g, '/');
    const padded = base64.padEnd(base64.length + (4 - base64.length % 4) % 4, '=');
    const binary = atob(padded);
    const buffer = new ArrayBuffer(binary.length);
    const view = new Uint8Array(buffer);
    for (let i = 0; i < binary.length; i++) {
      view[i] = binary.charCodeAt(i);
    }
    return buffer;
  }

  arrayBufferToBase64url(buffer) {
    const binary = String.fromCharCode(...new Uint8Array(buffer));
    const base64 = btoa(binary);
    return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
  }
  
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
      return;
    }

    if (window.PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable) {
      // Check if the browser supports User Verifying Platform Authenticator.
      // https://developer.mozilla.org/en-US/docs/Web/API/PublicKeyCredential/isUserVerifyingPlatformAuthenticatorAvailable
      const isUVPA = await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable();
    }

    if (this.isWebAuthnSupported()) {
      if (PublicKeyCredential.isConditionalMediationAvailable) {
        // Check if the browser supports conditional mediation.
        // https://developer.mozilla.org/en-US/docs/Web/API/PublicKeyCredential/isConditionalMediationAvailable
        const isCMA = await PublicKeyCredential.isConditionalMediationAvailable();
        if (isCMA) {
          // ページロード時に自動的にパスキー認証を開始
          this.getChallengeAndSubmitCredential(true);
        }
      }
    }
  }

  getChallengeAndSubmitCredential(isCMA) {
    const data = new FormData(this.formTarget);
    data.delete('_method');
    
    // POSTデータの準備
    // メールアドレス入力フィールドが空の場合は、discoverable credentialsフローを使用
    const isDiscoverableFlow = !data.get('user[email]') || data.get('user[email]').trim() === '';
    if (isDiscoverableFlow) {
      // メールアドレスが空の場合はPOSTボディから削除
      data.delete('user[email]');
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
        if (requestOption.error) {
          return;
        }
        const credentialRequestOptions = this.parseRequestOptionsFromJSON({ publicKey: requestOption });
        if (isCMA) {        // https://w3c.github.io/webappsec-credential-management/#mediation-requirements
          credentialRequestOptions['mediation'] = 'conditional';
          
          // ユーザーの認証情報に関するヒントを追加（オプション）
          credentialRequestOptions.hints = {
            // ページがロードされたときにパスキーUIを自動的に表示する
            autoPrompt: true,
          };
        }
        
        try {
          const credentialRequestResponse = await navigator.credentials.get(credentialRequestOptions);
          
          if (credentialRequestResponse) {
            this.credentialFieldTarget.value = JSON.stringify(this.assertionToJSON(credentialRequestResponse));
            this.formTarget.submit();
          }
        } catch (error) {
          // ユーザーがキャンセルした場合などはエラーが発生するが、
          // それは正常なユーザーフローの一部である
        }
      })
      .catch(error => {
        console.error("認証処理中にエラーが発生しました");
      });
  }
}
