import re

p = 'android/app/src/main/AndroidManifest.xml'
s = open(p, encoding='utf-8').read()

s = re.sub(r'android:label="[^"]*"', 'android:label="StudyBuddy"', s)

perms = (
    '    <uses-permission android:name="android.permission.READ_SMS"/>\n'
    '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n'
    '    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>\n'
)
s = s.replace('<application', perms + '    <application', 1)

recv = open('android_overrides/receivers.xml', encoding='utf-8').read()
s = s.replace('</application>', recv + '    </application>', 1)

open(p, 'w', encoding='utf-8').write(s)
print('manifest patched')
