# Tạo Xcode project

Nếu máy Mac đã cài XcodeGen:
```bash
cd GiaHaiPatch
xcodegen generate
open GiaHaiPatch.xcodeproj
```

Nếu chưa có XcodeGen, có thể tạo project iOS SwiftUI mới trong Xcode rồi kéo 4 file Swift,
Info.plist và thêm package ZIPFoundation:
https://github.com/weichsel/ZIPFoundation
