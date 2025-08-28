import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["form", "credentialField"];
  static values = {
    creationOptionsUrl: String
  };

  parseCreationOptionsFromJSON(options) {
    const publicKey = {
      ...options.publicKey,
      challenge: this.base64urlToArrayBuffer(options.publicKey.challenge),
      user: {
        ...options.publicKey.user,
        id: this.base64urlToArrayBuffer(options.publicKey.user.id)
      }
    };

    if (options.publicKey.excludeCredentials) {
      publicKey.excludeCredentials = options.publicKey.excludeCredentials.map(cred => ({
        ...cred,
        id: this.base64urlToArrayBuffer(cred.id)
      }));
    }

    return { publicKey };
  }

  credentialToJSON(credential) {
    return {
      id: credential.id,
      rawId: this.arrayBufferToBase64url(credential.rawId),
      response: {
        attestationObject: this.arrayBufferToBase64url(credential.response.attestationObject),
        clientDataJSON: this.arrayBufferToBase64url(credential.response.clientDataJSON)
      },
      type: credential.type
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

  submit(event) {
    event.preventDefault();

    const data = new FormData(this.formTarget);
    data.delete('_method');

    fetch(this.creationOptionsUrlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        "Accept": "application/json",
      },
      body: data
    })
      .then(response => response.json())
      .then(async creationOption => {
        console.log(creationOption);
        // ここに成功時の処理を書く
        const credentialCreationOptions = this.parseCreationOptionsFromJSON({ publicKey: creationOption });
        const credentialCreationResponse = await navigator.credentials.create(credentialCreationOptions);
        this.credentialFieldTarget.value = JSON.stringify(this.credentialToJSON(credentialCreationResponse));
        this.formTarget.submit();
      })
      .catch(error => {
        console.error(error);
        // ここにエラー時の処理を書く
      });
  }
}
