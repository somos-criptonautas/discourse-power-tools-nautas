// The button has to decide from what the post stream already carries, so the
// address reader and the markup it drives are checked without a browser.
import assert from "node:assert/strict";
import { before, test } from "node:test";

type MoneroTip = typeof import("../src/ui/monero-tip.ts");

let tip: MoneroTip;

before(async () => {
  await import("./stub-dom.ts");
  tip = await import("../src/ui/monero-tip.ts");
});

test("reads the address out of the post's public user fields", () => {
  assert.equal(tip.moneroAddress({ monero_address: "4abc" }), "4abc");
});

test("treats a member with no address as having none", () => {
  assert.equal(tip.moneroAddress({}), "");
  assert.equal(tip.moneroAddress(null), "");
  assert.equal(tip.moneroAddress(undefined), "");
});

test("offers no button when there is no address", () => {
  assert.equal(tip.tipButton("eviltrout", false).value, "");
});

test("names the member on the button and carries them in the action", () => {
  const markup = tip.tipButton("eviltrout", true).value;

  assert.match(markup, /data-act="monero-tip"/);
  assert.match(markup, /data-user="eviltrout"/);
  assert.match(markup, /Monero Tips for eviltrout/);
});

test("escapes a username rather than trusting it in markup", () => {
  const markup = tip.tipButton('a"><script>x</script>', true).value;

  assert.ok(!markup.includes("<script>"));
});
