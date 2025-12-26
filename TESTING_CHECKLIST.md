# All1Fit - Manual Testing Checklist

## Pre-Release Testing

### Authentication

- [ ] **Login email/password**: Enter valid credentials → logs in
- [ ] **Login invalid**: Wrong password → shows error message
- [ ] **Login Google**: Completes OAuth flow → logs in
- [ ] **Login Apple**: Completes Sign in with Apple → logs in
- [ ] **Logout**: Tap logout → returns to login screen
- [ ] **Register**: Create new account → success
- [ ] **Password Reset**: Request reset → email sent

### Onboarding

- [ ] **First launch**: Shows onboarding screens
- [ ] **Complete onboarding**: Saves to Firebase and local
- [ ] **Skip**: (if available) Skips to login

### RMs (Ejercicios)

- [ ] **Empty state**: No exercises → shows "Sin ejercicios"
- [ ] **Create exercise**: Add new with RM → appears in list
- [ ] **Add RM**: Add new RM to existing → updates value
- [ ] **View percentages**: Expand → shows correct table
- [ ] **View chart**: Navigate → shows history graph
- [ ] **Delete exercise**: Swipe delete → removes
- [ ] **Pull to refresh**: Refreshes data

### Workouts

- [ ] **View categories**: Switch between running/crossfit/competition
- [ ] **View workout**: Tap → shows detail with exercises
- [ ] **Add result (For Time)**: Enter time → saves
- [ ] **Add result (AMRAP)**: Enter rounds → saves
- [ ] **View PR**: Shows personal record badge
- [ ] **Record indicator**: Shows count on cards

### Settings

- [ ] **View profile**: Shows user name/email
- [ ] **Edit profile**: Change name → saves to Firebase
- [ ] **Change theme**: Switch light/dark/system → applies
- [ ] **Change weight unit**: kg/lb → updates all views
- [ ] **About links**: Privacy, contact work

### Edge Cases

- [ ] **No internet**: App doesn't crash, shows cached data
- [ ] **Long text**: Exercise name 50+ chars → truncates properly
- [ ] **Empty fields**: Submit empty form → shows validation

### Performance

- [ ] **Launch time**: < 3 seconds to usable
- [ ] **Scroll**: Smooth 60fps
- [ ] **Memory**: No leaks after extended use

---

## TestFlight Setup

1. **Xcode → Archive**: Product → Archive
2. **Organizer**: Distribute App → App Store Connect
3. **App Store Connect**: TestFlight → add testers
4. **Beta Review**: Usually < 24h for first build
