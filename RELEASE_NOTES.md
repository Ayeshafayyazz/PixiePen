# PixiePen Release Notes

## Version 1.0.0

PixiePen is a child-friendly storytelling application built with Flutter and Firebase. It helps children write, publish, read, and interact with stories in a safe and creative environment.

### Highlights

- Secure user signup and login using Firebase Authentication.
- Child account support with parent email registration.
- Profile management with built-in avatars and uploaded profile photos.
- Rich text story editor with draft saving and publishing.
- My Stories section for published stories, drafts, and saved stories.
- Community feed with likes, comments, replies, ratings, and follow support.
- In-app notifications for story activity and approval updates.
- Parent approval flow for child story publishing.
- E-book reader with swipeable pages and PDF export.
- Speech-to-text support for voice-based writing.
- Text-to-speech support for reading stories aloud.
- AI-assisted content moderation and creative story tools.
- AI image generation for story and e-book covers.
- Pixie Dash mini-game with score, gems, power-ups, and unlockable skins.
- Badge and reward features to encourage engagement.

### Technical Stack

- Flutter and Dart for mobile app development.
- Firebase Authentication for user identity.
- Cloud Firestore for users, stories, comments, notifications, follows, and e-book data.
- Firebase Storage for profile photos, story images, and generated images.
- Firebase Cloud Functions for AI image generation.
- OpenAI APIs for moderation, creative text features, and image generation.
- Flutter Quill for rich text editing.
- PDF and Printing packages for e-book export.
- Speech-to-text and text-to-speech packages for voice features.

### Improvements

- Added child-friendly moderation using local rule-based checks and AI-assisted semantic review.
- Improved profile email handling for child accounts registered with parent email.
- Improved story save feedback and snackbar dismissal behavior.
- Improved notification routing so story-related notifications open the relevant section.
- Added responsive layouts for profile, e-book, game, and writing screens.
- Added clearer error messages for Firebase, API, permission, and image upload failures.

### Known Limitations

- AI features require internet access and external API availability.
- Some AI text/moderation calls are configured from app environment settings during development.
- Generated PDFs are created on demand and are not stored as separate files in Firebase.
- Some dependencies are included for planned or optional features but are not active in the current user flow.
