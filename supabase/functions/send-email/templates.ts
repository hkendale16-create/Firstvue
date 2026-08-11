export type EmailTemplatePayload = Record<string, unknown>;

export interface RenderedEmail {
  subject: string;
  html: string;
  text: string;
}

const brand = "FirstVue";
const gold = "#D8B56A";
const background = "#0B0D10";

function layout(subject: string, bodyHtml: string): string {
  return `<!DOCTYPE html>
<html>
  <body style="margin:0;padding:0;background:${background};font-family:Arial,sans-serif;color:#ffffff;">
    <table width="100%" cellpadding="0" cellspacing="0" style="background:${background};padding:32px 16px;">
      <tr>
        <td align="center">
          <table width="100%" style="max-width:560px;background:#151B22;border-radius:16px;padding:28px;border:1px solid rgba(216,181,106,0.25);">
            <tr>
              <td style="padding-bottom:18px;">
                <div style="font-size:24px;font-weight:bold;color:${gold};letter-spacing:2px;">${brand}</div>
                <div style="font-size:11px;color:#888;margin-top:4px;letter-spacing:1px;">SEE FIRST. BOOK FIRST.</div>
              </td>
            </tr>
            <tr>
              <td style="color:#ffffff;line-height:1.6;font-size:15px;">${bodyHtml}</td>
            </tr>
          </table>
          <div style="color:#666;font-size:12px;margin-top:16px;">${subject}</div>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

function render(
  subject: string,
  bodyHtml: string,
  bodyText: string,
): RenderedEmail {
  return {
    subject: `${brand} — ${subject}`,
    html: layout(subject, bodyHtml),
    text: `${brand}\n\n${bodyText}\n`,
  };
}

export function renderEmailTemplate(
  template: string,
  payload: EmailTemplatePayload,
): RenderedEmail {
  switch (template) {
    case "business_approved":
      return render(
        "Business approved",
        `<p>Great news — <strong>${payload.business_name ?? "your business"}</strong> is now approved on FirstVue.</p>
         <p>Sign in to update your profile, add photos, and start reaching customers.</p>`,
        `Your business "${payload.business_name ?? "your business"}" was approved on FirstVue.`,
      );

    case "business_rejected":
      return render(
        "Business submission update",
        `<p>Your submission for <strong>${payload.business_name ?? "your business"}</strong> was not approved at this time.</p>
         <p>Sign in to review your listing and contact support if you have questions.</p>`,
        `Your business "${payload.business_name ?? "your business"}" was not approved.`,
      );

    case "rental_approved":
      return render(
        "Rental listing approved",
        `<p>Your rental listing <strong>${payload.title ?? "listing"}</strong> is now live on FirstVue.</p>`,
        `Your rental "${payload.title ?? "listing"}" was approved.`,
      );

    case "rental_rejected":
      return render(
        "Rental listing update",
        `<p>Your rental listing <strong>${payload.title ?? "listing"}</strong> was not approved.</p>
         <p>Sign in to edit and resubmit if needed.</p>`,
        `Your rental "${payload.title ?? "listing"}" was not approved.`,
      );

    case "review_approved":
      return render(
        "Review published",
        `<p>Your review for <strong>${payload.business_name ?? "a business"}</strong> is now visible on FirstVue.</p>`,
        `Your review for "${payload.business_name ?? "a business"}" was approved.`,
      );

    case "review_rejected":
      return render(
        "Review update",
        `<p>Your review for <strong>${payload.business_name ?? "a business"}</strong> was not published.</p>`,
        `Your review for "${payload.business_name ?? "a business"}" was not approved.`,
      );

    case "professional_approved":
      return render(
        "Professional profile approved",
        `<p>Your professional profile <strong>${payload.display_name ?? "profile"}</strong> is now live on FirstVue.</p>`,
        `Your professional profile "${payload.display_name ?? "profile"}" was approved.`,
      );

    case "professional_rejected":
      return render(
        "Professional profile update",
        `<p>Your professional profile <strong>${payload.display_name ?? "profile"}</strong> was not approved.</p>`,
        `Your professional profile "${payload.display_name ?? "profile"}" was not approved.`,
      );

    case "rental_inquiry_received":
      return render(
        "New rental inquiry",
        `<p>Someone sent an inquiry about <strong>${payload.rental_title ?? "your rental"}</strong>.</p>
         <p style="color:#aaa;">"${payload.message_preview ?? ""}"</p>
         <p>Sign in to FirstVue to respond.</p>`,
        `New inquiry on "${payload.rental_title ?? "your rental"}": ${payload.message_preview ?? ""}`,
      );

    case "subscription_activated":
      return render(
        "Subscription active",
        `<p>Your <strong>${String(payload.plan ?? "premium").toUpperCase()}</strong> plan is active for <strong>${payload.business_name ?? "your business"}</strong>.</p>
         <p>Thank you for growing with FirstVue.</p>`,
        `Your ${payload.plan ?? "premium"} subscription is active for ${payload.business_name ?? "your business"}.`,
      );

    case "admin_new_business_submission":
      return render(
        "New business submission",
        `<p>A new business is waiting for review: <strong>${payload.business_name ?? "Unknown"}</strong>.</p>
         <p>Business ID: ${payload.business_id ?? ""}</p>
         <p>Sign in to the admin queue to approve or reject.</p>`,
        `New business submission: ${payload.business_name ?? "Unknown"} (${payload.business_id ?? ""}).`,
      );

    default:
      return render(
        "Notification",
        `<p>You have a new update on FirstVue.</p>`,
        "You have a new update on FirstVue.",
      );
  }
}
