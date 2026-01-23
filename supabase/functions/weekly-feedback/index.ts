import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { Resend } from "npm:resend@2.0.0"

const resend = new Resend('re_gZo1Jup3_BUwaL4BkauxFF5w1iSVYMqgD') // Ta clé API Resend
const myEmail = 'lennylanglois8@gmail.com'

serve(async (req) => {
  try {
    const payload = await req.json()
    const feedback = payload.record // La nouvelle ligne insérée

    if (!feedback) {
      return new Response(JSON.stringify({ message: "Pas de données" }), { status: 200 })
    }

    // --- LOGIQUE D'AFFICHAGE DYNAMIQUE ---
    let subjectEmoji = "📢"
    let titleText = "Nouveau Message"
    let color = "#333"

    if (feedback.type === 'bug') {
      subjectEmoji = "🚨"
      titleText = "Nouveau BUG Signalé !"
      color = "#e74c3c" // Rouge
    } else if (feedback.type === 'idea') {
      subjectEmoji = "💡"
      titleText = "Nouvelle IDÉE Reçue !"
      color = "#f1c40f" // Jaune
    }

    console.log(`Envoi du mail pour : ${feedback.type}`)

    // --- CONTENU DU MAIL ---
    const emailHtml = `
      <div style="font-family: sans-serif; padding: 20px;">
        <h1 style="color: ${color};">${subjectEmoji} ${titleText}</h1>
        <p>Un utilisateur vient de poster un retour :</p>
        
        <div style="background-color: #f4f4f4; padding: 15px; border-left: 5px solid ${color}; margin: 20px 0;">
          <p style="font-size: 16px; font-style: italic;">"${feedback.content}"</p>
        </div>

        <p style="color: #888; font-size: 12px;">
          Type : <strong>${feedback.type}</strong><br/>
          Utilisateur ID : ${feedback.user_id}<br/>
          Reçu à l'instant via NORA App.
        </p>
      </div>
    `

    const data = await resend.emails.send({
      from: 'Nora App <onboarding@resend.dev>',
      to: [myEmail],
      subject: `${subjectEmoji} ${titleText}`, // Le sujet change aussi !
      html: emailHtml,
    })

    return new Response(JSON.stringify(data), {
      headers: { "Content-Type": "application/json" },
    })

  } catch (error) {
    console.error(error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    })
  }
})