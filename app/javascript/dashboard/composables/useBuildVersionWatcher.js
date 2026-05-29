import { ref, onMounted, onBeforeUnmount } from 'vue';

// Eltafouk: long-running Chatwoot tabs hang on to the JS bundle that
// loaded with them, so a deploy doesn't reach agents who never close
// their browser. This composable polls a tiny version endpoint and
// flips `newVersionAvailable` to true the first time it disagrees
// with the version captured on mount.
//
// The companion <NewVersionBanner /> component reads that flag and
// runs an idle-aware auto-reload (silent during typing, force after a
// hard timeout) so we never lose an in-flight draft AND we never let a
// stale bundle linger longer than 10 minutes after a deploy.

const POLL_INTERVAL_MS = 60_000;
const VERSION_URL = '/api/v1/build_version';

export function useBuildVersionWatcher() {
  const newVersionAvailable = ref(false);
  const initialVersion = ref(null);
  const lastActivityAt = ref(Date.now());
  let pollHandle = null;

  const markActive = () => {
    lastActivityAt.value = Date.now();
  };

  const fetchVersion = async () => {
    try {
      const res = await fetch(VERSION_URL, { cache: 'no-store' });
      if (!res.ok) return;
      const data = await res.json();
      const v = data?.version;
      if (v == null) return;
      if (initialVersion.value == null) {
        initialVersion.value = v;
        return;
      }
      if (v !== initialVersion.value) {
        newVersionAvailable.value = true;
      }
    } catch {
      // Network blip — ignore, next poll will retry.
    }
  };

  onMounted(() => {
    fetchVersion();
    pollHandle = setInterval(fetchVersion, POLL_INTERVAL_MS);
    // Activity heuristic: keystrokes & pointer presses mean the agent
    // is actively working. We use this to gate the auto-reload so an
    // in-progress reply isn't blown away mid-typing.
    window.addEventListener('keydown', markActive, { passive: true });
    window.addEventListener('mousedown', markActive, { passive: true });
    window.addEventListener('focus', fetchVersion);
  });

  onBeforeUnmount(() => {
    if (pollHandle) clearInterval(pollHandle);
    window.removeEventListener('keydown', markActive);
    window.removeEventListener('mousedown', markActive);
    window.removeEventListener('focus', fetchVersion);
  });

  return { newVersionAvailable, lastActivityAt };
}
