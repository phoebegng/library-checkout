// Supabase Edge Function: verify-admin-pin
//
// Set the expected PIN as a Supabase secret:
//   npx supabase secrets set ADMIN_PIN "your-pin"
//
// The admin/settings pages send the entered PIN here instead of checking it
// in client-side config.js, so the PIN is never committed to GitHub.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const expectedPin = Deno.env.get("ADMIN_PIN");

    if (!expectedPin) {
      return new Response(
        JSON.stringify({ success: false, error: "ADMIN_PIN secret not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { pin } = await req.json().catch(() => ({}));

    if (pin !== expectedPin) {
      return new Response(
        JSON.stringify({ success: false, error: "Invalid PIN" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("verify-pin error:", message);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
