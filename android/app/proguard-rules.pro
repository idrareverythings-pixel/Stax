# Keep PDF/OCR libraries intact under R8 minification.
-keep class com.syncfusion.** { *; }
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-dontwarn com.syncfusion.**
-dontwarn com.google.mlkit.**

# pdfrx / PDFium native bindings
-keep class io.github.espresso3389.pdfrx.** { *; }
-dontwarn io.github.espresso3389.pdfrx.**
