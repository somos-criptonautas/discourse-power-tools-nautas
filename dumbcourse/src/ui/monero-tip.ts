// The tip sheet for discourse-monero-tips. The address rides along with the
// post stream, so the button is decided without a request; the QR is drawn by
// the plugin and only fetched when the sheet opens.

import { get } from "../api.ts";
import { copyText, setHtml } from "../dom.ts";
import { html, type SafeHtml } from "../html.ts";
import { icon } from "./icons.ts";
import { openLayer, toast } from "./layers.ts";

const FIELD = "monero_address";

interface TipPayload {
  address: string;
  uri: string;
  qr: string;
  attributed?: boolean;
}

export function moneroAddress(
  fields: Record<string, string> | null | undefined
): string {
  return (fields && fields[FIELD]) || "";
}

export function tipButton(username: string, hasAddress: boolean): SafeHtml {
  if (!hasAddress) return html``;

  return html`<button
    type="button"
    class="pa"
    data-act="monero-tip"
    data-user="${username}"
    tabindex="-1"
    aria-label="Monero Tips for ${username}"
  >
    ${icon("xmr")}
  </button>`;
}

export function openTipSheet(username: string): void {
  if (!username) return;

  const layer = openLayer({
    kind: "sheet",
    label: `Monero Tips — ${username}`,
    className: "monero-tip",
    body: html`<div class="sheet monero-tip-sheet">
      <div class="sheet-head">
        <div class="sheet-title">Monero Tips — ${username}</div>
      </div>
      <div class="monero-tip-body" data-tip-body>
        <p class="muted">Loading…</p>
      </div>
    </div>`,
    softkeys: { left: "", center: "", right: "Close" },
  });

  void get<TipPayload>(`/monero-tips/${encodeURIComponent(username)}.json`)
    .then((data) => {
      const body = layer.el.querySelector("[data-tip-body]");
      if (!body) return;

      // The tip goes wallet to wallet; nothing here can confirm it arrived.
      const note = data.attributed
        ? "This address was made for you alone, so the tip is credited to you."
        : "Paid straight to their wallet. Nothing is recorded here.";

      setHtml(
        body,
        html`<img
            class="monero-tip-qr"
            src="${data.qr}"
            alt="Scan with your wallet"
            width="240"
            height="240"
          />
          <p class="monero-tip-address">${data.address}</p>
          <p class="muted">${note}</p>
          <div class="btn-row" data-row>
            <button type="button" class="btn primary" data-tip-copy>
              Copy address
            </button>
            <a class="btn" href="${data.uri}">Open in wallet</a>
          </div>`
      );

      const copy = body.querySelector("[data-tip-copy]");
      if (copy) {
        copy.addEventListener("click", () => {
          const done = copyText(data.address);
          toast(
            done ? "Address copied." : "Could not copy.",
            done ? "success" : "error"
          );
        });
      }
    })
    .catch(() => {
      const body = layer.el.querySelector("[data-tip-body]");
      if (body) {
        setHtml(
          body,
          html`<p class="notice error small">
            This member has no Monero address.
          </p>`
        );
      }
    });
}
