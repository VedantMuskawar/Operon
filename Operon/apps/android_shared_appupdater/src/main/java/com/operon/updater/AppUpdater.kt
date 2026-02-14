package com.operon.updater

import android.app.Activity
import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.util.Log
import android.widget.Toast
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.core.content.pm.PackageInfoCompat
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File
import java.lang.ref.WeakReference
import java.net.HttpURLConnection
import java.net.URL

class AppUpdater private constructor(activity: Activity) {
    private var activityRef: WeakReference<Activity> = WeakReference(activity)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var downloadId: Long? = null
    private var downloadReceiver: BroadcastReceiver? = null

    companion object {
        private const val TAG = "AppUpdater"
        private const val APK_FILE_NAME = "operon_update.apk"

        @Volatile
        private var instance: AppUpdater? = null

        fun with(activity: Activity): AppUpdater {
            return instance?.also { it.updateActivity(activity) }
                ?: synchronized(this) {
                    instance?.also { it.updateActivity(activity) }
                        ?: AppUpdater(activity).also { instance = it }
                }
        }
    }

    fun check(updateUrl: String) {
        val activity = activityRef.get() ?: return
        scope.launch {
            val resolvedUrl = resolveUpdateUrl(updateUrl, activity)
            val updateInfo = withContext(Dispatchers.IO) { fetchUpdateInfo(resolvedUrl) }

            if (updateInfo == null) {
                Log.w(TAG, "No update info returned from $resolvedUrl")
                return@launch
            }

            if (updateInfo.versionCode > getCurrentVersionCode(activity)) {
                showUpdateDialog(activity, updateInfo)
            }
        }
    }

    fun hasInstallPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    fun requestInstallPermission(activity: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                data = Uri.parse("package:${activity.packageName}")
            }
            activity.startActivity(intent)
        }
    }

    private fun updateActivity(activity: Activity) {
        activityRef = WeakReference(activity)
    }

    private fun resolveUpdateUrl(templateUrl: String, context: Context): String {
        val appName = readAppName(context)
        return templateUrl
            .replace("{app_name}", appName)
            .replace("{appName}", appName)
    }

    private fun readAppName(context: Context): String {
        val buildConfigName = "${context.packageName}.BuildConfig"
        return try {
            val buildConfigClass = Class.forName(buildConfigName)
            val field = buildConfigClass.getDeclaredField("APP_NAME")
            val value = field.get(null) as? String
            if (value.isNullOrBlank()) context.packageName else value
        } catch (error: Exception) {
            context.packageName
        }
    }

    private fun showUpdateDialog(activity: Activity, updateInfo: UpdateInfo) {
        if (activity.isFinishing || activity.isDestroyed) return

        val dialogBuilder = MaterialAlertDialogBuilder(activity)
            .setTitle(R.string.app_update_title)
            .setMessage(updateInfo.releaseNotes)
            .setPositiveButton(R.string.app_update_update) { _, _ ->
                startUpdateFlow(activity, updateInfo)
            }

        if (!updateInfo.isForceUpdate) {
            dialogBuilder.setNegativeButton(R.string.app_update_later) { dialog, _ ->
                dialog.dismiss()
            }
        } else {
            dialogBuilder.setCancelable(false)
        }

        dialogBuilder.show()
    }

    private fun startUpdateFlow(activity: Activity, updateInfo: UpdateInfo) {
        if (!hasInstallPermission(activity)) {
            Toast.makeText(
                activity,
                activity.getString(R.string.app_update_permission_required),
                Toast.LENGTH_LONG
            ).show()
            requestInstallPermission(activity)
            return
        }

        val downloadManager = activity.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val request = DownloadManager.Request(Uri.parse(updateInfo.apkUrl))
            .setTitle(activity.getString(R.string.app_update_title))
            .setDescription(activity.getString(R.string.app_update_downloading))
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(true)
            .setDestinationInExternalFilesDir(
                activity,
                Environment.DIRECTORY_DOWNLOADS,
                APK_FILE_NAME
            )

        downloadId = downloadManager.enqueue(request)
        registerDownloadReceiver(activity.applicationContext, downloadManager)
    }

    private fun registerDownloadReceiver(context: Context, downloadManager: DownloadManager) {
        unregisterDownloadReceiver(context)

        downloadReceiver = object : BroadcastReceiver() {
            override fun onReceive(receivedContext: Context, intent: Intent) {
                val id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1)
                if (id != downloadId) return

                handleDownloadComplete(receivedContext, downloadManager, id)
                unregisterDownloadReceiver(receivedContext)
            }
        }

        val filter = IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE)
        ContextCompat.registerReceiver(
            context,
            downloadReceiver,
            filter,
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
    }

    private fun unregisterDownloadReceiver(context: Context) {
        downloadReceiver?.let {
            try {
                context.unregisterReceiver(it)
            } catch (error: IllegalArgumentException) {
                // Receiver already unregistered.
            }
        }
        downloadReceiver = null
    }

    private fun handleDownloadComplete(
        context: Context,
        downloadManager: DownloadManager,
        id: Long
    ) {
        val query = DownloadManager.Query().setFilterById(id)
        downloadManager.query(query).use { cursor ->
            if (!cursor.moveToFirst()) {
                showDownloadFailure(context)
                return
            }

            val statusIndex = cursor.getColumnIndex(DownloadManager.COLUMN_STATUS)
            if (statusIndex == -1) {
                showDownloadFailure(context)
                return
            }

            val status = cursor.getInt(statusIndex)
            if (status != DownloadManager.STATUS_SUCCESSFUL) {
                showDownloadFailure(context)
                return
            }

            val localUriIndex = cursor.getColumnIndex(DownloadManager.COLUMN_LOCAL_URI)
            val localUri = if (localUriIndex != -1) cursor.getString(localUriIndex) else null
            val localPath = localUri?.let { Uri.parse(it).path }
            if (localPath.isNullOrBlank()) {
                showDownloadFailure(context)
                return
            }

            installApk(context, File(localPath))
        }
    }

    private fun installApk(context: Context, apkFile: File) {
        val apkUri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            apkFile
        )

        val installIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(apkUri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        context.startActivity(installIntent)
    }

    private fun showDownloadFailure(context: Context) {
        Toast.makeText(
            context,
            context.getString(R.string.app_update_download_failed),
            Toast.LENGTH_LONG
        ).show()
    }

    private fun getCurrentVersionCode(context: Context): Long {
        val packageInfo = context.packageManager.getPackageInfo(context.packageName, 0)
        return PackageInfoCompat.getLongVersionCode(packageInfo)
    }

    private fun fetchUpdateInfo(url: String): UpdateInfo? {
        return try {
            val connection = (URL(url).openConnection() as HttpURLConnection).apply {
                connectTimeout = 10_000
                readTimeout = 10_000
                requestMethod = "GET"
            }

            connection.inputStream.bufferedReader().use { reader ->
                val response = reader.readText()
                parseUpdateInfo(response)
            }
        } catch (error: Exception) {
            Log.e(TAG, "Failed to fetch update info", error)
            null
        }
    }

    private fun parseUpdateInfo(response: String): UpdateInfo? {
        return try {
            val json = JSONObject(response)
            UpdateInfo(
                versionCode = json.getInt("versionCode"),
                apkUrl = json.getString("apkUrl"),
                releaseNotes = json.optString("releaseNotes", ""),
                isForceUpdate = json.optBoolean("isForceUpdate", false)
            )
        } catch (error: Exception) {
            Log.e(TAG, "Invalid update JSON", error)
            null
        }
    }

    data class UpdateInfo(
        val versionCode: Int,
        val apkUrl: String,
        val releaseNotes: String,
        val isForceUpdate: Boolean
    )
}
