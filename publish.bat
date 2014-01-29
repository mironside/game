call c:\Users\colsen\Desktop\dart\dart-sdk\bin\pub.bat build
rmdir /S /q C:\projects\mironside.github.io\game
mkdir C:\projects\mironside.github.io\game
xcopy C:\Users\colsen\dart\game\build\* C:\projects\mironside.github.io\game /E
