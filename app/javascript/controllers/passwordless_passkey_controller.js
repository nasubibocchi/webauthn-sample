import { Controller } from "@hotwired/stimulus";
// https://github.com/github/webauthn-json/tree/main/browser-ponyfill
import {
  create,
  parseCreationOptionsFromJSON
} from "@github/webauthn-json/browser-ponyfill";

export default class extends Controller {
  static targets = ["form", "credentialField"];
  static values = {
    creationOptionsUrl: String
  };

  connect() {
    // コントローラーが接続されたら自動的にパスキー作成を開始
    this.submit();
  }

  submit(event) {
    if (event) {
      event.preventDefault();
    }

    fetch(this.creationOptionsUrlValue, {
      method: "GET",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        "Accept": "application/json",
      }
    })
      .then(response => response.json())
      .then(async creationOption => {
        console.log(creationOption);
        // ここに成功時の処理を書く
        const credentialCreationOptions = parseCreationOptionsFromJSON({ publicKey: creationOption });
        const credentialCreationResponse = await create(credentialCreationOptions);
        this.credentialFieldTarget.value = JSON.stringify(credentialCreationResponse);
        this.formTarget.submit();
      })
      .catch(error => {
        console.error(error);
      });
  }
}
