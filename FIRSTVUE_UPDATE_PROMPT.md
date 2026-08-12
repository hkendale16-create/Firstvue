# FirstVue Update Prompt

Canonical product update requirements for FirstVue. Preserve all current working functionality and extend the existing Flutter + Supabase architecture instead of creating duplicate systems.

---

Add the following updates to the existing FirstVue implementation. Preserve all current working functionality and extend the existing Flutter + Supabase architecture instead of creating duplicate systems.

1. Fix Go Live Status Notification on Profiles

There is currently an issue where the Go Live / status check notification remains stuck on the profile screen.

Fix this behavior.

When checking whether a user or profile is live:

* Show the status notification temporarily.
* Automatically dismiss it after the status is shown.
* Do not leave the notification permanently stuck on screen.
* Do not block profile interaction.
* Do not leave an indefinite loading indicator.
* Make sure repeated checks do not stack multiple notifications.

Use a lightweight toast/snackbar/banner style notification and automatically remove it.

2. Facebook-Style Photo Albums / Portfolio

For:

* Business profiles
* Professional profiles
* Creator/service profiles
* Other owner-managed profile types

add a Facebook-style photo album/portfolio system.

The owner should be able to create and manage photo collections.

Examples:

* Portfolio
* Work
* Projects
* Products
* Before & After
* Events
* Services
* General Photos

Users viewing the profile should see this primarily as a Portfolio / Photos section.

Allow owners to:

* Upload photos.
* Upload multiple photos.
* Create albums where applicable.
* Rename albums.
* Add descriptions/captions.
* Change/replace photos.
* Remove photos.
* Change album cover.
* Reorder photos where practical.
* Open photos full-screen.

Do not force all photos to be posts in the Newsfeed.

Photos can exist as portfolio/profile media independently.

3. Profile Photo Management

Owners of Business, Professional and supported profile types must be able to:

* Change profile photo.
* Remove profile photo.
* Change cover/header photo where available.
* Remove cover photo.
* Replace portfolio photos.
* Delete portfolio photos.

Make sure replacing a photo does not trigger the existing duplicate-avatar database issue.

Inspect the existing Supabase constraints before modifying this.

There should only be one active avatar for a profile where the database expects one.

When replacing an avatar:

1. Update or deactivate the old avatar record.
2. Then save the new avatar.
3. Avoid inserting another active avatar that violates the unique constraint.

4. Business Feed Must Only Contain Business Content

The Business profile feed should show posts created as that Business.

Do not automatically display the owner’s personal user posts inside the Business feed.

Keep the identities separate.

Example:

Kendale’s personal user profile
→ personal posts

FirstVue Barber Studio business profile
→ Business-created posts only

The owner can control the Business, but the Business feed should not simply mirror the owner’s personal feed.

If a user has the ability to choose their posting identity, they should explicitly choose:

* Post as myself
* Post as Business
* Post as Professional profile
* Post as another managed profile

Store the correct author/profile identity with the post.

5. Redesign Profile Feed Similar to Facebook

On Business, Professional, User and other supported profiles, redesign the posts/feed section to feel similar to a modern Facebook-style profile feed while maintaining FirstVue’s own visual identity.

Keep the interface borderless.

Do not add large card borders around every post.

Use:

* Clean spacing
* Profile image
* Name
* Timestamp
* Group/Community context
* Post text
* Media
* Spark/reaction controls
* Comments
* Share
* Video controls where applicable

The feed should feel native and clean rather than a collection of boxed cards.

6. Add Go Live Next to Video

In the profile post creation/actions section, add:

Photo | Video | Go Live

or an equivalent FirstVue layout.

Place Go Live directly next to the Video option.

Keep the existing post composer functionality.

Do not replace video upload with Go Live.

They are separate actions.

7. Fix Approval Center

The Approval Center currently fails to approve certain requests, including Community creation requests.

Fix the Approval Center so authorized administrators/moderators can correctly:

* Approve Community creation requests.
* Deny Community creation requests.
* Approve Group-related requests.
* Deny Group-related requests.
* Approve profile/business verification requests where applicable.
* Approve Community Group requests.
* Deny Community Group requests.
* Handle all other supported request types.

Investigate why certain approval actions fail.

Check:

* Supabase RLS
* RPC permissions
* Foreign keys
* Request status values
* Enum/status mismatches
* Missing reviewed_by
* Missing reviewed_at
* User permissions
* Community creation triggers
* Flutter error handling
* Transactions

Do not just hide the error.

Fix the underlying database/API issue.

8. Approval/Deny Actions Must Be Atomic

Approval operations should either completely succeed or completely fail.

For example, approving a Community request should correctly:

1. Validate authorization.
2. Mark request approved.
3. Create/activate the Community if needed.
4. Assign its Leader.
5. Save approval metadata.
6. Return the new Community record.
7. Update the Flutter UI.

Do not leave requests partially approved.

Use Supabase RPC/database transactions where appropriate.

9. Move Profile Search Bar to the Top

Move the profile search bar to the very top of the profile experience.

Make it borderless.

It should visually integrate with the header instead of looking like a separate boxed field.

Keep:

* Search icon
* Placeholder text
* Existing search behavior
* Keyboard handling
* Filtering/results

The search field should remain easy to identify while using minimal visual chrome.

10. Spark Reaction Effect

When a user presses Spark to like/react to a post, give it a distinctive FirstVue effect.

The interaction should include:

* A small spark animation.
* A subtle visual burst.
* A subtle sound effect.
* Immediate reaction feedback.
* No excessive animation.

The animation should feel premium and quick rather than distracting.

Example:

User taps Spark.

→ small spark particles briefly appear around the button
→ Spark icon animates
→ subtle sound plays
→ reaction count updates

Do not play the sound if device/system settings indicate sound should not play.

Respect mute/silent/accessibility settings where possible.

11. Refresh Sound

When the Newsfeed/profile feed refresh completes, play a unique but very subtle FirstVue refresh sound.

The sound should:

* Be short.
* Be quiet.
* Not repeat excessively.
* Only play when the user intentionally refreshes where appropriate.
* Respect device sound settings.

Do not play a loud notification sound every time background content reloads.

12. Every Profile Shows Groups and Communities

Every supported user/profile should show the Groups and Communities they are connected to.

Add sections equivalent to:

Groups

and

Communities

Display:

* Group/Community image
* Name
* Relationship/role where appropriate

For example:

* Member
* Group Leader
* Community Leader
* Community Editor

These must be clickable.

Clicking a Group opens its dedicated Group page.

Clicking a Community opens its dedicated Community page.

Do not show private membership information to users who are not allowed to see it.

Respect Group/Community privacy settings.

13. Full-Screen Post Viewer

When a user taps a post, do not open the content in a floating modal/pop-up.

Open it as a full-screen page.

Create a dedicated Post Detail screen.

The page should contain:

* Author
* Profile photo
* Timestamp
* Text
* Media
* Group/Community context
* Spark/reactions
* Comments
* Replies
* Share
* Report
* Existing owner/moderator controls

The user should use normal navigation/back behavior to return.

14. Full-Screen Video Viewer

When a user taps a video:

Do not use a small modal/pop-up.

Open a dedicated full-screen video player similar to modern Instagram/TikTok media viewing.

The video should:

* Fill the appropriate screen space.
* Preserve aspect ratio.
* Have play/pause controls.
* Loop where required by the existing FirstVue feed behavior.
* Support mute/unmute.
* Display post information appropriately.
* Display reactions/comments controls.
* Allow navigation back.
* Avoid accidentally playing several videos simultaneously.

If future vertical video navigation exists, structure the player so swipe-to-next video can be added cleanly.

15. Full-Screen Image Viewer

Images should similarly open in a full-screen viewer/page.

Support:

* Pinch zoom where practical.
* Swipe for multiple images.
* Author information.
* Post information.
* Reactions/comments.
* Normal back navigation.

Do not show video play icons on image posts.

16. Small Group Indicator on Posts

If a post belongs to a Group, display a very small circular Group image near the post attribution.

Example layout:

[User Avatar] User Name
small [Group Circle] Group Name

or another compact layout.

The Group indicator should not overpower the user’s profile photo.

It should be:

* Small
* Circular
* Clearly associated with the post
* Clickable

Clicking it opens the Group page.

If the post belongs to a Community through a Group, show Community context where appropriate without overcrowding the post.

17. Managed Profile Shortcut on User Profiles

On a user’s personal profile, in the section that currently contains:

* Edit Profile
* Share Profile

restore/add direct shortcuts for managed profiles.

For example:

Edit Profile | Share Profile | My Business

If the user owns/manages a Professional profile:

My Professional Profile

If they have multiple managed profile types, provide an appropriate management shortcut/menu.

These links should open the actual associated profile directly.

Do not make users search for their own Business or Professional profile.

18. Restore Existing Approved Profile Links

Previously available approved profile links should remain available.

Examples include:

* Business profile
* Professional profile
* Creator/service profile
* Rental/property profile
* Other approved profile types

If the user has an approved profile, expose it directly from their user profile.

Do not create a new profile when the user clicks the shortcut.

Open the existing approved profile.

19. Rental Inquiry Links

For relevant rental/property profiles, keep or restore direct inquiry functionality.

Examples:

* Rental Inquiry
* Contact Owner
* Request Information
* Schedule Viewing

These should remain accessible from the appropriate profile.

Do not mix rental inquiry actions into unrelated Business profiles.

Use profile type to determine which actions appear.

20. Profile Action Bar Must Be Dynamic

The profile action section should adapt based on who is viewing the profile and what type of profile it is.

Owner viewing personal profile

Possible actions:

Edit Profile | Share Profile | My Business

Other user viewing personal profile

Possible actions:

Follow | Message | Share

Business owner viewing Business profile

Possible actions:

Edit Business | Create Post | Manage Photos

Customer viewing Business profile

Possible actions:

Follow | Message | Call/Book/Visit depending on available Business functionality.

Rental profile

Possible actions:

Rental Inquiry | Message | Save

Do not display owner-only actions to normal users.

21. Portfolio Should Be Separate From Feed

Do not make the new photo Portfolio identical to the feed.

Profile structure should conceptually support:

Posts | Portfolio/Photos | Groups | Communities | About

depending on profile type.

For Business/Professional profiles, Portfolio should be especially visible.

For normal user profiles, Photos may be used instead of Portfolio.

22. Profile Navigation

Create consistent profile tabs/sections where appropriate.

For example:

User

Posts | Photos | Groups | Communities | About

Business

Posts | Portfolio | Reviews | About

and possibly:

Groups | Communities

when connected.

Professional

Posts | Portfolio | Reviews | Groups | Communities | About

Do not force exactly the same sections onto every profile type.

Use each profile’s purpose.

23. Post Identity Must Be Explicit

Because one user may own multiple profiles, update post attribution so the database knows which identity actually created the post.

Conceptually support:

* author_user_id
* author_profile_id
* author_profile_type

or adapt the existing FirstVue structure.

Examples:

Kendale posts personally:

author_user_id = Kendale
author_profile_type = user

Kendale posts as his Business:

author_user_id = Kendale
author_profile_id = business_id
author_profile_type = business

This keeps authentication tied to the real user while displaying the correct public identity.

24. Supabase Security for Managed Profiles

RLS must ensure:

* Only Business owners/authorized staff can post as a Business.
* Users cannot impersonate another Business.
* Users cannot post as another Professional profile.
* Only owners/managers can modify portfolio photos.
* Only authorized users can change profile images.
* Approval Center actions require administrator/moderator authorization.
* Users cannot approve their own approval requests unless a specific workflow allows it.
* Private Group/Community membership is not exposed to unauthorized users.

25. Media Storage

Reuse existing Supabase Storage where possible.

Organize media so the app can distinguish:

* Avatar
* Cover photo
* Post media
* Portfolio photo
* Album media
* Business media
* Professional profile media

Do not create duplicate storage objects unnecessarily.

When replacing a profile image, clean up/deactivate the previous database association safely.

26. Performance

Portfolio and profile feeds may contain many photos/videos.

Use:

* Pagination
* Lazy loading
* Thumbnail previews
* Image caching
* Proper video controller disposal
* Visibility-based video playback

Do not load every portfolio image and every post when the profile first opens.

27. Borderless Visual Language

Apply the FirstVue borderless visual style consistently to:

* Profile search
* Profile feed
* Post cards
* Portfolio
* Groups/Communities
* Composer
* Media viewers

Use spacing, typography, background differences and subtle separators instead of thick borders around every section.

28. Required Bug Fixes

Specifically investigate and fix:

1. Go Live/status notification remains stuck.
2. Approval Center cannot approve some requests.
3. Community creation requests cannot be approved.
4. Profile avatar replacement can produce duplicate-key failures.
5. Business feed incorrectly includes owner’s personal posts.
6. Images displaying incorrect video/play indicators.
7. Media opening as pop-ups instead of dedicated screens.

Do not work around these bugs by hiding functionality.

Fix their root causes.

29. Final Profile Experience

A normal personal profile should approximately support:

Top Borderless Search

Profile Header

Profile Photo
Name / Bio / Stats

Actions

Edit Profile | Share Profile | My Business / Managed Profile

Create

Photo | Video | Go Live

Tabs

Posts | Photos | Groups | Communities | About

Feed

Borderless Facebook-style posts

Posts with Group context display a small clickable circular Group image.

Selecting a post opens a full-screen Post page.

Selecting a video opens a full-screen video player.

30. Final Business/Professional Profile Experience

Business and Professional profiles should approximately support:

Top Borderless Search

Profile Header

Business/Professional image
Name
Description
Ratings/details

Owner Actions

Edit | Create Post | Manage Portfolio

Visitor Actions

Follow | Message | Business-specific actions

Post Composer

Photo | Video | Go Live

Tabs

Posts | Portfolio | Reviews | Groups | Communities | About

The Business feed must contain Business-created content only.

The Portfolio displays owner-managed media independent of the feed.

31. Required Testing

Do not consider this complete until testing verifies:

* Go Live status message disappears correctly.
* Multiple status checks do not stack.
* Owner can change/remove profile photo.
* Avatar replacement does not trigger duplicate-key errors.
* Business owner can create a Portfolio.
* Portfolio photos can be added.
* Portfolio photos can be replaced.
* Portfolio photos can be deleted.
* Business feed excludes owner’s personal posts.
* Owner can explicitly post as Business.
* Personal posts remain on personal profile.
* Go Live appears next to Video.
* Community request can be approved.
* Community request can be denied.
* All Approval Center request types respond correctly.
* Failed approvals return meaningful error information.
* Profile search is at the top and borderless.
* Spark animation works.
* Spark sound works subtly.
* Refresh sound only plays appropriately.
* Groups display on profiles.
* Communities display on profiles.
* Group links open correct Group pages.
* Community links open correct Community pages.
* Clicking a post opens full-screen.
* Clicking a video opens a full-screen player.
* Clicking an image opens a full-screen viewer.
* Images never receive video play icons.
* Group icon appears correctly on Group-associated posts.
* Group icon opens the correct Group.
* My Business/Professional shortcut opens existing approved profile.
* Rental inquiries remain available on appropriate profile types.
* Unauthorized users cannot manage another person’s profile/Portfolio.
* RLS prevents users from posting as profiles they do not own.


32. General App Theme Setting

Add a global app setting that allows users to switch the entire FirstVue app between:

Light Mode and Dark Mode

This should apply across the full app, including:

* Main Newsfeed
* VUE
* User profiles
* Business profiles
* Professional profiles
* Community pages
* Group pages
* Approval Center
* Search
* Messages where applicable
* Settings
* Post detail pages
* Full-screen media viewers
* Portfolio/photo albums
* Forms
* Menus
* Dialogs
* Navigation bars
* Buttons
* Input fields
* Loading states
* Empty states

Add the theme option inside the general app settings.

The setting should provide:

* Light
* Dark
* System Default

If System Default is selected, FirstVue should automatically follow the user’s iPhone/Android operating-system appearance setting.

Persist the user’s selection so the app does not reset its theme every time it closes.

Use Flutter’s centralized theme architecture rather than manually changing colors on individual screens.

Implement and maintain:

* ThemeData for light mode
* ThemeData for dark mode
* Shared semantic colors
* Text themes
* Icon colors
* Navigation colors
* Surface/background colors
* Input styles
* Button styles
* Divider/separator styles
* Error/success/status colors

Avoid hardcoded colors throughout individual widgets whenever possible.

The existing FirstVue borderless design should remain consistent in both modes.

Light Mode

Light Mode should use:

* Clean light backgrounds
* Strong readable dark text
* Subtle surface contrast
* Minimal borders
* Proper contrast for buttons, icons, posts, profiles, and media controls

Do not simply invert the existing dark theme.

Design a proper native-looking light FirstVue theme.

Dark Mode

Preserve the current FirstVue dark visual identity while moving its colors into the centralized theme system.

Dark Mode should maintain:

* Dark surfaces
* Clear readable text
* Existing premium/futuristic FirstVue feel
* Borderless profile/feed design
* Proper media control visibility

Theme Switching

Changing the theme from Settings should update the app immediately without requiring the user to restart FirstVue.

For example:

Settings → Appearance → Theme

Options:

System Default
Light
Dark

Show a checkmark or other subtle indicator beside the active selection.

Persist Preference

Store the selected theme preference locally using the project’s existing preferences/settings system.

If no preference exists, default to:

System Default

Do not require Supabase to load before the app can determine its initial theme.

If FirstVue later syncs user preferences across devices, the local setting can be synchronized with the user’s account, but local theme loading should remain fast.

Media and Content

Photos and videos themselves should not be visually altered when switching themes.

Only surrounding interface elements should change.

Make sure:

* Video controls remain visible in both modes.
* Image backgrounds look correct.
* Spark effects remain visible.
* Group/Community indicators remain readable.
* Rating stars remain visible.
* Business/profile information maintains proper contrast.

Theme Testing

Verify:

* User switches Dark → Light and the entire app updates immediately.
* User switches Light → Dark and the entire app updates immediately.
* System Default follows the device appearance.
* Theme selection persists after closing/reopening the app.
* Theme persists through login/logout where appropriate.
* No major screen remains hardcoded to the wrong theme.
* Text remains readable in both themes.
* Profile feeds remain borderless.
* Communities and Groups render properly.
* Portfolio pages render properly.
* Approval Center works in both modes.
* Full-screen video/image/post pages render correctly.
* Spark animation/effects remain visible.
* Loading and error states support both themes.
* Status bar/navigation-bar icon brightness changes correctly for Light and Dark Mode.

