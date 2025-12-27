# Stripe SDK - Keep all classes for payment processing
-keep class com.stripe.** { *; }
-keep class com.reactnativestripesdk.** { *; }
-dontwarn com.stripe.android.**

# Google MLKit
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }

# Google Pay - Required for Stripe Google Pay integration
-keep class com.google.android.gms.wallet.** { *; }
-dontwarn com.google.android.gms.wallet.**

# AppCompat theme classes (CRITICAL for Stripe payment sheet)
# Without these rules, ProGuard minification in release builds may strip AppCompat classes,
# causing Stripe to fail with "Your theme isn't set to use Theme.AppCompat" error.
# These rules ensure all AppCompat components remain intact in release builds.
-keep class androidx.appcompat.app.AppCompatActivity { *; }
-keep class androidx.appcompat.** { *; }
-keep class android.support.** { *; }

# Keep resources that Stripe needs for payment UI
-keepresources color,drawable,layout,menu,anim,attr,transition,interpolator,id,style

# Keep theme attributes for Stripe compatibility
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses

# Don't warn about missing classes
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.stripe.android.pushProvisioning.**
-dontwarn com.reactnativestripesdk.pushprovisioning.**
