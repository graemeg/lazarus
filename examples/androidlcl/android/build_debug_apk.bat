REM Adjust these paths to yours
SET PATH=C:\Programas\android-sdk\tools;C:\Programas\android-sdk\platform-tools\;C:\Progra~1\Java\jdk1.6.0_37\bin
SET APP_NAME=androidlcltest
SET ANDROID_HOME=C:\Programas\android-sdk
SET APK_SDK_PLATFORM=C:\Programas\android-sdk\platforms\android-8
SET APK_PROJECT_PATH=C:\Programas\lazarussvn\examples\androidlcl\android

REM Create necessary directory Structure
mkdir bin
mkdir bin\classes
mkdir gen
mkdir gen\com
mkdir gen\com\pascal
mkdir gen\com\pascal\lcltest
mkdir raw
mkdir raw\lib
mkdir raw\lib\armeabi

REM Cleanup
del bin\%APP_NAME%.ap_
del bin\%APP_NAME%.apk
del raw\lib\armeabi\*.so

REM More directory preparation
copy libs\armeabi\*.so raw\lib\armeabi\

REM Resource compilation
call aapt p -v -f -M AndroidManifest.xml -F bin\%APP_NAME%.ap_ -I %APK_SDK_PLATFORM%\android.jar -S res -m -J gen raw

REM Java compiler
call javac -verbose -encoding UTF8 -classpath %APK_SDK_PLATFORM%\android.jar -d bin\classes src\com\pascal\lcltest\LCLActivity.java

REM Convert the java bytecode to dalvik bytecode
call java -Djava.ext.dirs=%ANDROID_HOME%\platform-tools\lib\ -jar %ANDROID_HOME%\platform-tools\lib\dx.jar --dex --verbose --output=%APK_PROJECT_PATH%\bin\classes.dex %APK_PROJECT_PATH%\bin\classes

REM It seams that dx calls echo off
@echo on
REM Now build the unsigned APK
del %APK_PROJECT_PATH%\bin\%APP_NAME%-unsigned.apk
call java -classpath %ANDROID_HOME%\tools\lib\sdklib.jar com.android.sdklib.build.ApkBuilderMain %APK_PROJECT_PATH%\bin\%APP_NAME%-unsigned.apk -v -u -z %APK_PROJECT_PATH%\bin\%APP_NAME%.ap_ -f %APK_PROJECT_PATH%\bin\classes.dex

REM Generating on the fly a debug key
rem keytool -genkey -v -keystore bin\LCLDebugKey.keystore -alias LCLDebugKey -keyalg RSA -validity 10000 -dname NAME -storepass senhas -keypass senhas

REM Signing the APK with a debug key
del bin\%APP_NAME%-unaligned.apk
REM JDK1.6,Please use this command
jarsigner -verbose -keystore bin\LCLDebugKey.keystore -keypass 123456 -storepass 123456 -signedjar bin\%APP_NAME%-unaligned.apk bin\%APP_NAME%-unsigned.apk LCLDebugKey
REM JDK1.7 OR JDK1.8,Please use this command
REM jarsigner -verbose -sigalg MD5withRSA -digestalg SHA1 -keystore bin\LCLDebugKey.keystore -keypass 123456 -storepass 123456 -signedjar bin\%APP_NAME%-unaligned.apk bin\%APP_NAME%-unsigned.apk LCLDebugKey

REM Align the final APK package
zipalign -v 4 bin\%APP_NAME%-unaligned.apk bin\%APP_NAME%.apk

REM call and pause together allow us to see the results in the end
pause
