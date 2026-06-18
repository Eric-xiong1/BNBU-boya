# Keep local JSON persistence stable if R8/minification is enabled for release.
# Gson reflects over model field names for the current SharedPreferences store.
-keep class edu.bnbu.student.mvp.core.model.** { *; }
-keep class edu.bnbu.student.mvp.core.local.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
