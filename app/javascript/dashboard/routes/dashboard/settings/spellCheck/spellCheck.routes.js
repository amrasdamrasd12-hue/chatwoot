import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

// Eltafouk: settings route for the per-account spell-check guard config.
// Admin-only since toggling DM/comments scope affects every agent.
export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/spell-check'),
      meta: { permissions: ['administrator'] },
      component: SettingsWrapper,
      props: {
        headerTitle: 'SPELL_CHECK_SETTINGS.TITLE',
        icon: 'i-lucide-spell-check',
        showNewButton: false,
      },
      children: [
        {
          path: '',
          name: 'spell_check_settings_index',
          component: Index,
          meta: { permissions: ['administrator'] },
        },
      ],
    },
  ],
};
