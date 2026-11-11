import { otpEmail } from "./otp_email.ts";

Deno.test("OTP alternatives preserve leading zeroes and remain usable without images or scripts", () => {
  const code = "012345";
  const email = otpEmail(code);
  if (email.subject.includes(code)) throw new Error("Code must stay out of the subject");
  for (const body of [email.text, email.html]) {
    if (body.split(code).length !== 2) throw new Error("Each alternative needs one contiguous code");
    if (!body.includes("10 minutes")) throw new Error("Expiry guidance missing");
    if (!body.includes("paste it into Filo")) throw new Error("Copy fallback missing");
  }
  if (/<script|<button|onclick=|https?:|mailto:/i.test(email.html)) {
    throw new Error("Email must not rely on scripts, remote requests or a fake copy button");
  }
});

Deno.test("OTP template rejects malformed values instead of interpolating HTML", () => {
  for (const code of ["12345", "1234567", "12 345", "<img>", "12345\n", "123456\n", ""]) {
    let rejected = false;
    try { otpEmail(code); } catch { rejected = true; }
    if (!rejected) throw new Error("Malformed verification code accepted");
  }
});

Deno.test("OTP branding is inline, decorative leaves are optional and the code remains text", () => {
  const email = otpEmail("012345");
  if (email.attachments.length !== 2) throw new Error("Expected backed brand and transparent leaves");
  for (const asset of email.attachments) {
    if (!email.html.includes(`cid:${asset.cid}`)) throw new Error("Inline asset not referenced");
    if (asset.contentType !== "image/png" || asset.encoding !== "base64" ||
        !asset.content.startsWith("iVBORw0KGgo") || asset.contentDisposition !== "inline") {
      throw new Error("Invalid inline PNG");
    }
  }
  if (!email.html.includes('src="cid:leaves.otp@filo" width="480" alt=""') ||
      !email.html.includes('alt="filo"') || !email.html.includes('>012345</p>')) {
    throw new Error("Brand fallback, decorative semantics or selectable text code missing");
  }
});

Deno.test("OTP email retains dark text styling without depending on artwork switching", () => {
  const email = otpEmail("012345");
  for (const fragment of [
    'name="color-scheme" content="light dark"', '@media (prefers-color-scheme: dark)',
    'background-color:#0F1A17 !important', 'color:#E8F1EB !important',
    'background-color:#F9FAF5',
    'cid:brand.otp@filo', 'cid:leaves.otp@filo',
  ]) {
    if (!email.html.includes(fragment)) throw new Error("Theme or matching artwork missing");
  }
  if (email.html.includes("dark-art") || email.html.includes("light-art")) {
    throw new Error("Branding must not depend on media-query image swapping");
  }
  const leaves = email.attachments.find((asset) => asset.cid === "leaves.otp@filo")!;
  if (atob(leaves.content).charCodeAt(25) !== 6) throw new Error("Footer must use RGBA PNG");
  if (email.text.includes("cid:")) throw new Error("Plaintext must stay independent of artwork");
});
