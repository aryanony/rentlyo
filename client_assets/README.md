# 📁 Centralized Client Assets Folder (`client_assets/`)

Drop your new client's branding assets here before running the setup script!

### 📋 What Goes in This Folder:

1. **`logo.png`**:
   - The square app icon & logo for the client (Recommended: 512x512 PNG with transparent background).
   - Automatically copied to both Tenant and Admin apps.
   - Automatically used to generate Android/iOS app launcher icons & splash screens.

2. **`banner.png`**:
   - The horizontal brand banner or wide logo (e.g. 1024x500 or wide transparent PNG).
   - Automatically copied to both Tenant and Admin splash/login screens.

3. **`google-services.json`**:
   - The Firebase configuration file downloaded from the client's Firebase Console project.
   - Automatically copied to both `Arya Spaces/android/app/` and `AryaSpaces Admin/android/app/`.
   - *(Optional: If you created separate Firebase apps with different files, you can name them `google-services-admin.json` and `google-services-tenant.json`)*.

4. **`templates/`**:
   - Contains original vector source files (`.ai`, `.svg`, `.pdf`) and design references for creating banners and icons for clients.

---

When you run `dart scripts/setup_client.dart` or double-click `setup_new_client.bat`, these files are automatically distributed to all required places across both apps!
