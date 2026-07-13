# Phase 6 - APP CLIENTE - Multi-Tenant Login Flow Implementation

## Summary

Phase 6 completes the multi-tenant login flow for the client app with the following enhancements:

1. **TenantLoadingWidget** - Reusable component for handling tenant loading states
2. **Enhanced LoginScreen** - Shows loading state while tenant config loads from Firestore
3. **Updated AppShell** - Displays tenant name and user role with logout button
4. **Router Guards** - Enforces tenant_id verification and suspended tenant blocking
5. **Branding Application** - Button color customization from tenant config
6. **Debug Info** - Tenant ID visible during development mode

---

## Components Implemented

### 1. TenantLoadingWidget (`lib/shared/widgets/tenant_loading_widget.dart`)

**Purpose**: Reusable widget that handles all tenant loading states in a consistent way.

**Features**:
- Shows loading spinner with "Cargando configuración de tu salón..." message
- Displays error state with optional retry button
- Checks if tenant is suspended and shows "Tu salón está suspendido" message
- Used by LoginScreen and can be reused in other tenant-aware screens

**Usage Example**:
```dart
TenantLoadingWidget(
  onSuccess: (context, ref, tenantId, tenantName) {
    return MyContentWidget(tenantId: tenantId);
  },
  showSuspendedMessage: true,
  onRetry: () => ref.refresh(currentTenantProvider),
)
```

---

### 2. Enhanced LoginScreen (`lib/features/auth/presentation/login_screen.dart`)

**Changes Made**:
- ✅ Imports `tenantIdProvider` and `tenantRepositoryProvider` from auth/tenant providers
- ✅ After successful login, shows loading state: "Cargando configuración de tu salón..."
- ✅ Waits for `currentTenantProvider` to load before showing UI
- ✅ Displays tenant_id in development mode (gray text below subtitle)
- ✅ Applies custom primary color to login button from branding (if available)
- ✅ Shows logo from `tenant.branding.logoUrl` with fallback to scissors icon
- ✅ Handles all error scenarios gracefully with Spanish error messages

**Key Methods**:
- `_entrar()` - Calls `AuthRepository.signIn()` (Phase 5 already validates tenant)
- `build()` - Shows loading state when tenant is being fetched

---

### 3. Updated AppShell (`lib/features/shell/presentation/app_shell.dart`)

**Changes Made**:
- ✅ Displays tenant name in AppBar title
- ✅ Shows user role below tenant name:
  - "Dueño" if user is owner
  - "Recepcionista" if user is receptionist  
  - "Estilista" if user is stylist
- ✅ Added logout button with confirmation dialog
- ✅ Logout clears session and redirects to login
- ✅ Imports `usuarioActualProvider` to fetch current user info

**AppBar Format**:
```
Salón Ana
Recepcionista
```

---

### 4. Router Guards (`lib/app/router.dart`)

**New Guards Added**:

**Guard 2 (Tenant ID Verification)**:
- Verifies that user has `tenant_id` in Custom Claims
- Redirects to `/login` if tenant_id is null
- Handles edge case of super-admin without specific tenant

**Guard 3 (Tenant Loading & Status)**:
- Checks if `currentTenantProvider` has loaded successfully
- If tenant has error, redirects to `/login`
- If tenant is suspended (`estado != 'activo'`), calls `signOut()` and redirects to `/login`
- Prevents access to protected routes until tenant is verified

**Guard 4 & 5** (Pre-existing):
- Role-based guards for admin-only and super-admin routes

---

## Authentication Flow

### Login Flow Sequence:

1. User enters email/password on LoginScreen
2. Form validation passes
3. **Phase 5**: AuthRepository.signIn() called
   - Signs in with Firebase Auth
   - Extracts `tenant_id` from Custom Claims
   - Verifies tenant exists and `estado == 'activo'`
   - Throws exception if any check fails
   - Signs out if verification fails
4. LoginScreen shows loading state: "Cargando configuración de tu salón..."
5. **Phase 6**: currentTenantProvider starts fetching tenant doc from Firestore
   - Loads branding config
   - Verifies tenant still active
6. Router redirects to `/agenda` when authentication + tenant loading complete
7. AppShell displays tenant name and user role

### Session Recovery on App Restart:

1. App starts and checks `FirebaseAuth.currentUser` in main.dart
2. If user exists:
   - Validates refresh token (handles stale sessions)
   - Router checks if `tenantIdProvider` has value
   - If valid, navigates directly to `/agenda`
   - If invalid, redirects to `/login`
3. AppShell loads tenant branding and displays header
4. App continues with full multi-tenant awareness

---

## Error Scenarios & Recovery

### Scenario 1: Invalid Credentials
- **Expected**: Error message "Correo o contraseña incorrectos."
- **Recovery**: User re-enters credentials and tries again

### Scenario 2: User Without Tenant
- **Expected**: AuthRepository throws "Usuario sin asignar a salón"
- **Recovery**: Contact admin to assign tenant

### Scenario 3: Tenant Suspended
- **Expected**: AuthRepository throws "Tu salón ha sido suspendido"
- **Recovery**: Router guard catches state change and forces logout

### Scenario 4: Tenant Deleted
- **Expected**: Firestore query returns null, custom exception thrown
- **Message**: "Salón no encontrado"
- **Recovery**: Contact admin

### Scenario 5: Network Error During Login
- **Expected**: Firebase throws network-request-failed
- **Message**: "Sin conexión. Verifica tu red e intenta de nuevo."
- **Recovery**: Retry when network returns

### Scenario 6: Tenant Suspended Between App Restart
- **Expected**: AppShell's AppBar loads, tenant is suspended
- **Recovery**: Router Guard 3 detects suspension, signs out, redirects to login

---

## Verification Checklist

- [ ] **Compilation**: `flutter analyze` passes with no errors in Phase 6 code
- [ ] **Login Success**: Valid user logs in and sees "Cargando configuración..."
- [ ] **Tenant Loading**: After login, AppBar shows tenant name + role
- [ ] **Branding Applied**: Login button color matches tenant.branding.colorPrimary
- [ ] **Debug Info**: Tenant ID visible during development (gray text on login)
- [ ] **Suspended Tenant Blocked**: User with suspended tenant gets error message
- [ ] **Missing Tenant ID**: User without tenant_id redirected to login
- [ ] **Logout Works**: Menu button → "Cerrar sesión" → confirmation → redirects to login
- [ ] **Session Persists**: Close and reopen app → directly to `/agenda` (no login)
- [ ] **Invalid Credentials**: Shows error "Correo o contraseña incorrectos."
- [ ] **Network Error**: Shows error "Sin conexión. Verifica tu red..."
- [ ] **Spanish Messages**: All error messages in Spanish

---

## Files Modified

### New Files:
- `lib/shared/widgets/tenant_loading_widget.dart` - Reusable tenant loading widget

### Modified Files:
- `lib/features/auth/presentation/login_screen.dart` - Enhanced with tenant loading states
- `lib/features/shell/presentation/app_shell.dart` - Added user role display + logout
- `lib/app/router.dart` - Added tenant guards (Guard 2 & 3)

### Unchanged (Already Implemented in Phase 5):
- `lib/features/auth/data/auth_repository.dart` - Tenant verification in signIn()
- `lib/features/tenant/application/tenant_providers.dart` - currentTenantProvider
- `lib/features/auth/application/auth_providers.dart` - tenantIdProvider

---

## Phase 5 Dependencies (Already Complete)

This Phase 6 implementation depends on Phase 5 components already in place:

1. **AuthRepository.signIn()** - Validates tenant after Firebase Auth login
2. **AuthRepository._verifyTenantAfterLogin()** - Checks tenant status
3. **tenantIdProvider** - Extracts tenant_id from Custom Claims
4. **currentTenantProvider** - Watches tenant/{tenant_id} from Firestore
5. **Tenant & Branding Models** - Domain objects from Phase 1
6. **ThemeService** - Parses hex colors and builds tenant-specific themes

---

## Testing Strategy

### Unit Tests:
- Test `TenantLoadingWidget` with various tenant states (loading, error, suspended, active)
- Test router guards with different authentication scenarios

### Integration Tests:
- Login → load tenant → navigate to agenda
- Logout from AppShell menu
- Session persistence across app restart
- Error handling for suspended tenants

### Manual Testing:
1. **Valid Login**: Use test user from admin app
2. **Suspended Tenant**: Suspend tenant in admin app, try login
3. **Brand Colors**: Create tenant with custom primary color, verify button color
4. **Logout**: Click menu → "Cerrar sesión" → confirm
5. **Session Recovery**: Login, close app, reopen → directly to agenda

---

## Known Limitations & Future Work

### Current Scope:
- ✅ Multi-tenant login with custom claims verification
- ✅ Branding application (color + logo)
- ✅ Suspended tenant detection
- ✅ Session recovery on app restart
- ✅ User role display

### Future Enhancements (Phase 7+):
- [ ] Deep link handling with tenant context
- [ ] Tenant switching for users with multiple salon assignments
- [ ] More advanced branding (fonts, theme customization)
- [ ] Two-factor authentication per tenant
- [ ] Session timeout per tenant policy
- [ ] Role-based UI customization beyond role label

---

## Deployment Notes

### Before Deploying to Production:

1. **Firestore Rules**: Ensure rules check `request.auth.token.tenant_id` matches document path
2. **Custom Claims**: Verify Cloud Functions set tenant_id + role correctly
3. **Testing**: Test with real Firebase project (not emulator only)
4. **Error Messages**: Translate any remaining English messages to Spanish
5. **Performance**: Monitor Firestore reads for tenant/{tenantId} queries

### Environment Variables:
- No new environment variables required
- Custom colors from Firestore branding config
- Debug mode: Tenant ID shown if not `dart.vm.product`

---

## Related Documentation

- **Phase 5**: `lib/features/auth/data/auth_repository.dart` (tenant verification)
- **Phase 1**: `lib/features/tenant/domain/tenant.dart` (models)
- **Theme**: `lib/app/theme_service.dart` (color parsing)
- **Routing**: `lib/app/router.dart` (full guard implementation)
