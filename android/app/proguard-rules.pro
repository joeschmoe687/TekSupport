# Stripe
-keep class com.stripe.** { *; }
-keep class com.reactnativestripesdk.** { *; }

# Google MLKit
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }

# Flutter Stripe
-keep class com.google.android.gms.wallet.** { *; }

# AppCompat theme classes (required for Stripe)
-keep class androidx.appcompat.app.AppCompatActivity { *; }
-keep class androidx.appcompat.** { *; }
-keep class android.support.** { *; }
-keepresources color,drawable,layout,menu,anim,attr,transition,interpolator,id

# Don't warn about missing classes
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.stripe.android.pushProvisioning.**
-dontwarn com.reactnativestripesdk.pushprovisioning.**
