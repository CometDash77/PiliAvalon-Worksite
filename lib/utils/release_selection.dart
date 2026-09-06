/// Selects the newest published stable release in GitHub response order.
Map<String, dynamic>? latestStableRelease(List<dynamic> releases) {
  for (final release in releases) {
    if (release is Map<String, dynamic> &&
        release['draft'] == false &&
        release['prerelease'] == false) {
      return release;
    }
  }
  return null;
}
