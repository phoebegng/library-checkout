// Supabase Edge Function: send-overdue-emails
// Uses Brevo (brevo.com) — free tier, no IT setup, no domain required.
//
// One-time setup:
//   1. Sign up free at https://brevo.com
//   2. Account → Senders & IPs → Senders → Add a sender (verify your email)
//   3. Account → SMTP & API → API Keys → Create API key
//
// Required Supabase Secrets (Dashboard → Edge Functions → Secrets):
//   BREVO_API_KEY = your Brevo API key
//   FROM_EMAIL    = your verified sender email address

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const brevoApiKey = Deno.env.get("BREVO_API_KEY")!;
    const fromEmail = Deno.env.get("FROM_EMAIL")!;

    if (!brevoApiKey || !fromEmail) {
      return new Response(
        JSON.stringify({ error: "Email not configured. Add BREVO_API_KEY and FROM_EMAIL as Supabase secrets." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supa = createClient(supabaseUrl, supabaseServiceKey);

    // Fetch all overdue checkouts not yet returned
    const { data: overdue, error } = await supa
      .from("checkouts")
      .select("*, books(title, author)")
      .is("returned_at", null)
      .lt("due_date", new Date().toISOString());

    if (error) throw error;

    if (!overdue || overdue.length === 0) {
      return new Response(
        JSON.stringify({ sent: 0, message: "No overdue books." }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let sent = 0;
    for (const checkout of overdue) {
      const dueDate = new Date(checkout.due_date).toLocaleDateString("en-US", {
        weekday: "long", year: "numeric", month: "long", day: "numeric",
      });
      const daysOverdue = Math.floor(
        (Date.now() - new Date(checkout.due_date).getTime()) / (1000 * 60 * 60 * 24)
      );
      const bookTitle = checkout.books?.title || "Unknown Book";
      const bookAuthor = checkout.books?.author || "";

      const htmlBody = `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background: #1e40af; padding: 24px; border-radius: 8px 8px 0 0;">
            <h1 style="color: white; margin: 0; font-size: 20px;">Library Book Overdue Reminder</h1>
          </div>
          <div style="background: #fff; padding: 24px; border: 1px solid #e5e7eb; border-top: none; border-radius: 0 0 8px 8px;">
            <p style="color: #374151;">Hi <strong>${checkout.borrower_name}</strong>,</p>
            <p style="color: #374151;">This is a friendly reminder that a book you borrowed from the <strong>Arthrex Learning Library</strong> is now overdue.</p>
            <div style="background: #fef2f2; border: 1px solid #fecaca; border-radius: 8px; padding: 16px; margin: 20px 0;">
              <p style="margin: 0 0 8px; color: #991b1b; font-weight: bold;">${bookTitle}</p>
              ${bookAuthor ? `<p style="margin: 0 0 8px; color: #6b7280; font-size: 14px;">by ${bookAuthor}</p>` : ""}
              <p style="margin: 0 0 4px; color: #dc2626; font-size: 14px;"><strong>Due date:</strong> ${dueDate}</p>
              <p style="margin: 0; color: #dc2626; font-size: 14px;"><strong>Days overdue:</strong> ${daysOverdue} day${daysOverdue !== 1 ? "s" : ""}</p>
            </div>
            <p style="color: #374151;">Please return the book at your earliest convenience so others can enjoy it too.</p>
            <p style="color: #6b7280; font-size: 13px; margin-top: 24px; border-top: 1px solid #e5e7eb; padding-top: 16px;">
              This is an automated message from the Arthrex Learning Library.<br/>
              If you have already returned this book, please disregard this email.
            </p>
          </div>
        </div>
      `;

      try {
        const res = await fetch("https://api.brevo.com/v3/smtp/email", {
          method: "POST",
          headers: {
            "api-key": brevoApiKey,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            sender: { name: "Arthrex Learning Library", email: fromEmail },
            to: [{ email: checkout.borrower_email, name: checkout.borrower_name }],
            subject: `[Library Reminder] "${bookTitle}" is ${daysOverdue} day${daysOverdue !== 1 ? "s" : ""} overdue`,
            htmlContent: htmlBody,
          }),
        });
        if (!res.ok) {
          const errText = await res.text();
          throw new Error(errText);
        }
        sent++;
      } catch (mailErr) {
        console.error(`Failed to send to ${checkout.borrower_email}:`, mailErr);
      }
    }

    return new Response(
      JSON.stringify({ sent, total: overdue.length }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("Edge function error:", message);
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
