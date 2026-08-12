# R8 / ProGuard rules for Flutter application with Resource Shrinking

# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.internal.** { *; }
-keep class io.flutter.provider.** { *; }

# Keep Flutter Engine
-keep class io.flutter.embedding.** { *; }

# Keep WebSockets & WebViews
-keepclassmembers class * extends android.webkit.WebView {
   public *;
}
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Preserve generated plugin registrant
-keep class io.flutter.plugins.** { *; }

# Suppress missing optional Play Core deferred component references
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Preserve annotations and type signatures
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

