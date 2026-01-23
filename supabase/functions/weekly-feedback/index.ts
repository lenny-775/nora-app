import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // 1. Initialiser Supabase
  const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!)

  try {
    // 2. Récupérer les feedbacks non traités
    const { data: feedbacks, error } = await supabase
      .from('app_feedback')
      .select('id, type, content, created_at, user_id') // On récupère l'ID pour update après
      .eq('is_processed', false)

    if (error) throw error
    
    // Si rien à envoyer, on s'arrête là
    if (!feedbacks || feedbacks.length === 0) {
      return new Response(JSON.stringify({ message: "Rien à signaler." }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // 3. Trier les retours
    const bugs = feedbacks.filter(f => f.type === 'bug')
    const ideas = feedbacks.filter(f => f.type === 'idea')
    const others = feedbacks.filter(f => f.type === 'other')

    // 4. Construire le HTML du mail
    let htmlContent = `<h1>📊 Récap NORA</h1><p>Voici les retours de la semaine :</p>`

    const addSection = (title, items) => {
      if (items.length === 0) return ''
      let html = `<h3>${title} (${items.length})</h3><ul>`
      items.forEach(i => html += `<li>${i.content}</li>`)
      html += `</ul>`
      return html
    }

    htmlContent += addSection('🪲 BUGS', bugs)
    htmlContent += addSection('💡 IDÉES', ideas)
    htmlContent += addSection('💬 AUTRES', others)

    // 5. Envoyer le mail via Resend
    // REMPLACE 'ton-email@gmail.com' PAR LE TIEN 👇
    const myEmail = 'lennylanglois8@gmail.com' 
    
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: 'NORA App <onboarding@resend.dev>',
        to: [myEmail], 
        subject: `Rapport Feedback NORA`,
        html: htmlContent,
      }),
    })

    if (!res.ok) {
      const errorData = await res.text()
      throw new Error(`Erreur Resend: ${errorData}`)
    }

    // 6. Marquer comme "vu" dans la base de données
    const ids = feedbacks.map(f => f.id)
    if (ids.length > 0) {
        await supabase
        .from('app_feedback')
        .update({ is_processed: true })
        .in('id', ids)
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})