package com.cardscan.cardscan_ai

import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.ContactsContract
import android.provider.ContactsContract.CommonDataKinds
import android.provider.ContactsContract.Intents.Insert
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "cardscan/contacts"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "openContactEditor") {
                    val args = call.arguments as? Map<*, *>
                    if (args == null) {
                        result.error("bad_args", "Missing contact data", null)
                    } else {
                        openContactEditor(args, result)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun openContactEditor(contact: Map<*, *>, result: MethodChannel.Result) {
        try {
            val primary = buildInsertIntent(contact, ContactsContract.RawContacts.CONTENT_TYPE)
            val intent = if (primary.resolveActivity(packageManager) != null) {
                primary
            } else {
                buildInsertIntent(contact, ContactsContract.Contacts.CONTENT_TYPE)
            }
            startActivity(Intent.createChooser(intent, "Save contact"))
            result.success(true)
        } catch (_: ActivityNotFoundException) {
            result.error("no_app", "No Contacts app was found on this phone.", null)
        } catch (e: Exception) {
            result.error("open_failed", e.message ?: "Could not open Contacts.", null)
        }
    }

    private fun buildInsertIntent(contact: Map<*, *>, mimeType: String): Intent {
        val phones = stringList(contact["phones"])
        val emails = stringList(contact["emails"])
        val websites = stringList(contact["websites"])
        val name = (contact["name"] as? String)?.trim().orEmpty().ifEmpty { "Unknown" }
        val org = (contact["org"] as? String)?.trim().orEmpty()
        val title = (contact["title"] as? String)?.trim().orEmpty()

        return Intent(Insert.ACTION).apply {
            type = mimeType
            putExtra(Insert.NAME, name)
            if (org.isNotEmpty()) putExtra(Insert.COMPANY, org)
            if (title.isNotEmpty()) putExtra(Insert.JOB_TITLE, title)
            if (phones.isNotEmpty()) {
                putExtra(Insert.PHONE, phones[0])
                putExtra(Insert.PHONE_TYPE, CommonDataKinds.Phone.TYPE_MOBILE)
            }
            if (phones.size > 1) putExtra(Insert.SECONDARY_PHONE, phones[1])
            if (phones.size > 2) putExtra(Insert.TERTIARY_PHONE, phones[2])
            if (emails.isNotEmpty()) {
                putExtra(Insert.EMAIL, emails[0])
                putExtra(Insert.EMAIL_TYPE, CommonDataKinds.Email.TYPE_WORK)
            }
            if (emails.size > 1) putExtra(Insert.SECONDARY_EMAIL, emails[1])
            if (emails.size > 2) putExtra(Insert.TERTIARY_EMAIL, emails[2])
            if (websites.isNotEmpty()) {
                putExtra(Insert.NOTES, websites.joinToString("\n"))
            }
            putExtra("finishActivityOnSaveCompleted", true)
        }
    }

    private fun stringList(raw: Any?): List<String> {
        val items = raw as? List<*> ?: return emptyList()
        return items.mapNotNull { it?.toString()?.trim() }.filter { it.isNotEmpty() }
    }
}
