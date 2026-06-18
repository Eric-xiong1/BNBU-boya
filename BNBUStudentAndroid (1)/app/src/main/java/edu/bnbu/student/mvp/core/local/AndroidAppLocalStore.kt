package edu.bnbu.student.mvp.core.local

import android.content.Context
import com.google.gson.Gson
import com.google.gson.GsonBuilder
import edu.bnbu.student.mvp.core.model.CheckInDraft
import edu.bnbu.student.mvp.core.model.StudentTaskList
import edu.bnbu.student.mvp.core.model.StudentWorkspace

class AndroidAppLocalStore(
    context: Context,
    private val gson: Gson = GsonBuilder().disableHtmlEscaping().create()
) {
    private val preferences = context.applicationContext.getSharedPreferences(
        StoreName,
        Context.MODE_PRIVATE
    )

    fun loadWorkspace(): StudentWorkspace? = readWorkspace().value

    fun readWorkspace(): LocalStoreReadResult<StudentWorkspace> {
        val raw = read(WorkspaceStorageKey, StudentWorkspace::class.java)
        if (raw.value == null) return raw
        val sanitized = ensureWorkspaceDefaults(raw.value)
        return raw.copy(value = sanitized)
    }

    fun saveWorkspace(workspace: StudentWorkspace): Boolean {
        return save(WorkspaceStorageKey, workspace)
    }

    fun loadDraft(): CheckInDraft? = readDraft().value

    fun readDraft(): LocalStoreReadResult<CheckInDraft> {
        return read(DraftStorageKey, CheckInDraft::class.java)
    }

    fun saveDraft(draft: CheckInDraft): Boolean {
        return save(DraftStorageKey, draft)
    }

    fun clearDraft() {
        preferences.edit().remove(DraftStorageKey).apply()
    }

    fun clearAll() {
        preferences.edit()
            .remove(WorkspaceStorageKey)
            .remove(DraftStorageKey)
            .apply()
    }

    // ── Schema-evolution guard ──────────────────────────────────────
    // Gson bypasses Kotlin data-class constructors via UnsafeAllocator,
    // so `= emptyList()` defaults are never applied for fields added
    // AFTER the app was last launched. Old cached JSON leaves them null.
    private fun ensureWorkspaceDefaults(ws: StudentWorkspace): StudentWorkspace {
        val teachersNull = try {
            val f = StudentWorkspace::class.java.getDeclaredField("teachers")
            f.isAccessible = true
            f.get(ws) == null
        } catch (_: NoSuchFieldException) { false }

        val syncOpsNull = try {
            val f = StudentWorkspace::class.java.getDeclaredField("syncOperations")
            f.isAccessible = true
            f.get(ws) == null
        } catch (_: NoSuchFieldException) { false }

        val exemptionsNull = try {
            val f = StudentWorkspace::class.java.getDeclaredField("exemptions")
            f.isAccessible = true
            f.get(ws) == null
        } catch (_: NoSuchFieldException) { false }

        val studentTasksNull = try {
            val f = StudentWorkspace::class.java.getDeclaredField("studentTasks")
            f.isAccessible = true
            f.get(ws) == null
        } catch (_: NoSuchFieldException) { false }

        if (!teachersNull && !syncOpsNull && !exemptionsNull && !studentTasksNull) return ws

        return ws.copy(
            teachers = if (teachersNull) emptyList() else ws.teachers,
            syncOperations = if (syncOpsNull) emptyList() else ws.syncOperations,
            exemptions = if (exemptionsNull) emptyList() else ws.exemptions,
            studentTasks = if (studentTasksNull) StudentTaskList(emptyList(), emptyList()) else ws.studentTasks
        )
    }

    private fun <T> read(key: String, clazz: Class<T>): LocalStoreReadResult<T> {
        val json = preferences.getString(key, null)
            ?: return LocalStoreReadResult(value = null, status = LocalStoreReadStatus.Missing)

        return try {
            val value = gson.fromJson(json, clazz)
            if (value == null) {
                LocalStoreReadResult(value = null, status = LocalStoreReadStatus.DecodeFailed)
            } else {
                LocalStoreReadResult(value = value, status = LocalStoreReadStatus.Loaded)
            }
        } catch (_: RuntimeException) {
            LocalStoreReadResult(value = null, status = LocalStoreReadStatus.DecodeFailed)
        }
    }

    private fun save(key: String, value: Any): Boolean {
        return try {
            preferences.edit().putString(key, gson.toJson(value)).commit()
        } catch (_: RuntimeException) {
            false
        }
    }

    companion object {
        const val StoreName = "bnbu.student.local.v1"
        const val WorkspaceStorageKey = "bnbu.student.workspace.v1"
        const val DraftStorageKey = "bnbu.student.checkin.draft.v1"
    }
}
