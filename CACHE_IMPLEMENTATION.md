# Chat List Caching Implementation

## Overview
This implementation adds caching to the chat list feature to prevent unnecessary API requests when navigating to the messages view.

## How it works

### 1. Cache Service (`lib/core/service/cache_service.dart`)
- Uses `shared_preferences` to store chat list data locally
- Caches both the chat list and unread count
- Implements cache expiry (5 minutes by default)
- Provides methods to store, retrieve, and clear cached data

### 2. Message Cubit Updates (`lib/feature/messages/data/message_cubit.dart`)
- Modified `loadChatList()` method to check cache first
- Added `forceRefresh` parameter to bypass cache when needed
- Cache is cleared when new messages are received
- Cache is cleared when messages are marked as read

### 3. Messages View Updates (`lib/feature/messages/presentation/views/messages_view.dart`)
- Refresh button now uses `forceRefresh: true` to get fresh data
- Pull-to-refresh also uses `forceRefresh: true`

## Cache Behavior

### When cache is used:
- First time loading (no cache exists)
- Cache is valid (less than 5 minutes old)
- User navigates to messages view

### When cache is bypassed:
- User manually refreshes (refresh button or pull-to-refresh)
- Cache has expired (more than 5 minutes old)
- `forceRefresh: true` is passed

### When cache is cleared:
- New message is received via SignalR
- Messages are marked as read
- Manual cache clearing

## Benefits
1. **Faster navigation**: No API call needed when cache is valid
2. **Reduced server load**: Fewer unnecessary requests
3. **Better user experience**: Instant loading from cache
4. **Offline capability**: Can show cached data when offline

## Configuration
- Cache expiry: 5 minutes (configurable in `CacheService._cacheExpiry`)
- Cache keys: `chat_list_cache`, `chat_list_timestamp`, `unread_count_cache`

## Testing
You can test the caching by:
1. Loading the messages view (should make API call)
2. Navigating away and back (should load from cache)
3. Waiting 5+ minutes and navigating back (should make API call)
4. Using the refresh button (should make API call) 