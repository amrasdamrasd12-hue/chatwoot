import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/backups'),
      // Full DB dumps are instance-global → super-admin only. The route-guard
      // permission system only understands account roles, so `administrator`
      // is the narrowest gate it can express here; the actual super-admin
      // boundary is enforced by the API (`Current.user.is_a?(SuperAdmin)`),
      // the sidebar entry (hidden unless SuperAdmin), and Index.vue's own guard.
      meta: { permissions: ['administrator'] },
      component: SettingsWrapper,
      props: {
        headerTitle: 'النسخ الاحتياطي لقاعدة البيانات',
        icon: 'i-lucide-database',
        showNewButton: false,
      },
      children: [
        {
          path: '',
          name: 'backup_settings_index',
          component: Index,
          meta: { permissions: ['administrator'] },
        },
      ],
    },
  ],
};
