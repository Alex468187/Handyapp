package de.alex468187.handyapp

import android.app.ActivityOptions
import android.app.Notification
import android.app.PendingIntent
import android.app.Person
import android.app.RemoteInput
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONObject
import java.io.File

/**
 * Liest Benachrichtigungen von WhatsApp und Gmail mit und schreibt sie in
 * eine Datei, die Summer anzeigt. Antworten laufen über die
 * „Antworten“-Funktion der jeweiligen Benachrichtigung.
 */
class SummerListener : NotificationListenerService() {

    companion object {
        private val APPS = mapOf(
            "com.whatsapp" to "whatsapp",
            "com.whatsapp.w4b" to "whatsapp",
            "com.google.android.gm" to "gmail",
        )
        private const val FILE = "summer_messages.jsonl"
        private val COUNT_SUFFIX = Regex("""\s*\(\d+ [^)]*\)$""")

        // Nur gültig, solange die jeweilige Benachrichtigung existiert.
        private val replyActions = HashMap<String, Notification.Action>()
        private val openIntents = HashMap<String, PendingIntent>()
        private val seen = LinkedHashSet<String>()
        private val lock = Any()

        fun file(ctx: Context) = File(ctx.filesDir, FILE)

        fun canReply(chat: String) = synchronized(lock) { replyActions.containsKey(chat) }

        fun reply(ctx: Context, chat: String, text: String): Boolean {
            val action = synchronized(lock) { replyActions[chat] } ?: return false
            val inputs = action.remoteInputs ?: return false
            val intent = Intent()
            val results = Bundle()
            for (ri in inputs) results.putCharSequence(ri.resultKey, text)
            RemoteInput.addResultsToIntent(inputs, intent, results)
            return try {
                action.actionIntent.send(ctx, 0, intent)
                val parts = chat.split("|", limit = 2)
                append(ctx, listOf(entry(parts[0], parts.getOrElse(1) { "" }, "Du", text,
                    System.currentTimeMillis(), null, "out|$chat|${System.currentTimeMillis()}", true)))
                true
            } catch (e: Exception) {
                synchronized(lock) { replyActions.remove(chat) }
                false
            }
        }

        fun open(ctx: Context, chat: String, pkg: String): Boolean {
            val pi = synchronized(lock) { openIntents[chat] }
            if (pi != null) {
                try {
                    if (Build.VERSION.SDK_INT >= 34) {
                        val opts = ActivityOptions.makeBasic()
                            .setPendingIntentBackgroundActivityStartMode(
                                ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED)
                        pi.send(ctx, 0, null, null, null, null, opts.toBundle())
                    } else {
                        pi.send()
                    }
                    return true
                } catch (e: Exception) {
                    synchronized(lock) { openIntents.remove(chat) }
                }
            }
            val launch = ctx.packageManager.getLaunchIntentForPackage(pkg) ?: return false
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            ctx.startActivity(launch)
            return true
        }

        private fun entry(
            source: String, chat: String, sender: String, text: String,
            time: Long, account: String?, id: String, outgoing: Boolean = false,
        ) = JSONObject().apply {
            put("id", id)
            put("source", source)
            put("chat", chat)
            put("sender", sender)
            put("text", text)
            put("time", time)
            if (account != null) put("account", account)
            if (outgoing) put("out", true)
        }

        private fun append(ctx: Context, entries: List<JSONObject>) {
            if (entries.isEmpty()) return
            synchronized(lock) {
                val f = file(ctx)
                f.appendText(entries.joinToString("") { it.toString() + "\n" })
                // Datei klein halten: nur die letzten 1500 Einträge.
                if (f.length() > 1_500_000) {
                    val lines = f.readLines()
                    f.writeText(lines.takeLast(1500).joinToString("") { it + "\n" })
                }
            }
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val source = APPS[sbn.packageName] ?: return
        val n = sbn.notification ?: return
        if (n.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        val ex = n.extras ?: return
        val title = ex.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: return
        if (title == "WhatsApp" || title == "Gmail") return

        val conversation = ex.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)?.toString()
        val chat = (conversation ?: title).replace(COUNT_SUFFIX, "").trim()
        val account = ex.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()
        val chatKey = "$source|$chat"

        synchronized(lock) {
            n.contentIntent?.let { openIntents[chatKey] = it }
            n.actions?.firstOrNull { !it.remoteInputs.isNullOrEmpty() }
                ?.let { replyActions[chatKey] = it }
        }

        val out = ArrayList<JSONObject>()
        val msgs = ex.getParcelableArray(Notification.EXTRA_MESSAGES)
        if (source == "whatsapp" && msgs != null && msgs.isNotEmpty()) {
            for (p in msgs) {
                val b = p as? Bundle ?: continue
                val text = b.getCharSequence("text")?.toString() ?: continue
                val time = b.getLong("time", sbn.postTime)
                var sender = b.getCharSequence("sender")?.toString()
                if (sender == null && Build.VERSION.SDK_INT >= 28) {
                    @Suppress("DEPRECATION")
                    sender = b.getParcelable<Person>("sender_person")?.name?.toString()
                }
                val id = "wa|$chat|$time|${text.hashCode()}"
                if (remember(id)) out.add(entry(source, chat, sender ?: chat, text, time, null, id))
            }
        } else {
            val text = (ex.getCharSequence(Notification.EXTRA_BIG_TEXT)
                ?: ex.getCharSequence(Notification.EXTRA_TEXT))?.toString() ?: return
            val id = "$source|${sbn.key}|${text.hashCode()}"
            if (remember(id)) out.add(entry(source, chat, title, text, sbn.postTime, account, id))
        }
        append(this, out)
    }

    /** `true`, wenn die Nachricht neu ist. */
    private fun remember(id: String): Boolean = synchronized(lock) {
        if (!seen.add(id)) return false
        if (seen.size > 3000) seen.remove(seen.first())
        true
    }
}
