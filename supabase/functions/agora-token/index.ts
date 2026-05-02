import { RtcTokenBuilder, RtcRole } from 'npm:agora-access-token@^2.0.4';

const AGORA_APP_ID = Deno.env.get('AGORA_APP_ID')!;
const AGORA_CERTIFICATE = Deno.env.get('AGORA_CERTIFICATE')!;

Deno.serve(async (req: Request) => {
    try {
        const { channelName, uid } = await req.json();
        const token = RtcTokenBuilder.buildTokenWithUid(
            AGORA_APP_ID,
            AGORA_CERTIFICATE,
            channelName,
            uid || 0,
            RtcRole.PUBLISHER,
            Math.floor(Date.now() / 1000) + 3600
        );
        return new Response(JSON.stringify({ token }), {
            headers: { 'Content-Type': 'application/json' },
        });
    } catch (error: any) {
        return new Response(JSON.stringify({ error: error.message }), { status: 500 });
    }
});