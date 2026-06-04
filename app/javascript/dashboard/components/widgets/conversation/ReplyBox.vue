<script>
import { defineAsyncComponent, useTemplateRef } from 'vue';
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useTrack } from 'dashboard/composables';
import keyboardEventListenerMixins from 'shared/mixins/keyboardEventListenerMixins';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

import ReplyToMessage from './ReplyToMessage.vue';
import AttachmentPreview from 'dashboard/components/widgets/AttachmentsPreview.vue';
import ReplyTopPanel from 'dashboard/components/widgets/WootWriter/ReplyTopPanel.vue';
import ReplyEmailHead from './ReplyEmailHead.vue';
import ReplyBottomPanel from 'dashboard/components/widgets/WootWriter/ReplyBottomPanel.vue';
import CopilotReplyBottomPanel from 'dashboard/components/widgets/WootWriter/CopilotReplyBottomPanel.vue';
import ArticleSearchPopover from 'dashboard/routes/dashboard/helpcenter/components/ArticleSearch/SearchPopover.vue';
import CopilotEditorSection from './CopilotEditorSection.vue';
import MessageSignatureMissingAlert from './MessageSignatureMissingAlert.vue';
import ReplyBoxBanner from './ReplyBoxBanner.vue';
import QuotedEmailPreview from './QuotedEmailPreview.vue';
import { REPLY_EDITOR_MODES } from 'dashboard/components/widgets/WootWriter/constants';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import AudioRecorder from 'dashboard/components/widgets/WootWriter/AudioRecorder.vue';
import { AUDIO_FORMATS } from 'shared/constants/messages';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { CMD_AI_ASSIST } from 'dashboard/helper/commandbar/events';
import {
  getMessageVariables,
  getUndefinedVariablesInMessage,
  replaceVariablesInMessage,
} from '@chatwoot/utils';
import WhatsappTemplates from './WhatsappTemplates/Modal.vue';
import ContentTemplates from './ContentTemplates/ContentTemplatesModal.vue';
import { MESSAGE_MAX_LENGTH } from 'shared/helpers/MessageTypeHelper';
import inboxMixin, { INBOX_FEATURES } from 'shared/mixins/inboxMixin';
import { trimContent, debounce, getRecipients } from '@chatwoot/utils';
import wootConstants from 'dashboard/constants/globals';
import {
  extractQuotedEmailText,
  buildQuotedEmailHeader,
  truncatePreviewText,
  appendQuotedTextToMessage,
} from 'dashboard/helper/quotedEmailHelper';
import {
  CONVERSATION_EVENTS,
  CAPTAIN_EVENTS,
} from '../../../helper/AnalyticsHelper/events';
import fileUploadMixin from 'dashboard/mixins/fileUploadMixin';
import {
  appendSignature,
  removeSignature,
  getEffectiveChannelType,
} from 'dashboard/helper/editorHelper';
import { useCopilotReply } from 'dashboard/composables/useCopilotReply';
import { useKbd } from 'dashboard/composables/utils/useKbd';
import { isFileTypeAllowedForChannel } from 'shared/helpers/FileHelper';
import TasksAPI from 'dashboard/api/captain/tasks';
import SpellCheckModal from './SpellCheckModal.vue';
import { useSpellCheckSettingsStore } from 'dashboard/store/spellCheckSettings';

import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import { LocalStorage } from 'shared/helpers/localStorage';
import { emitter } from 'shared/helpers/mitt';
const EmojiInput = defineAsyncComponent(
  () => import('shared/components/emoji/EmojiInput.vue')
);

export default {
  components: {
    ArticleSearchPopover,
    AttachmentPreview,
    AudioRecorder,
    ReplyBoxBanner,
    EmojiInput,
    MessageSignatureMissingAlert,
    ReplyBottomPanel,
    ReplyEmailHead,
    ReplyToMessage,
    ReplyTopPanel,
    ContentTemplates,
    WhatsappTemplates,
    WootMessageEditor,
    QuotedEmailPreview,
    CopilotEditorSection,
    CopilotReplyBottomPanel,
    SpellCheckModal,
  },
  mixins: [inboxMixin, fileUploadMixin, keyboardEventListenerMixins],
  props: {
    popOutReplyBox: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['update:popOutReplyBox'],
  setup() {
    const {
      uiSettings,
      isEditorHotKeyEnabled,
      fetchSignatureFlagFromUISettings,
      setQuotedReplyFlagForInbox,
      fetchQuotedReplyFlagFromUISettings,
    } = useUISettings();

    const replyEditor = useTemplateRef('replyEditor');
    const copilot = useCopilotReply();
    const shortcutKey = useKbd(['$mod', '+', 'enter']);
    // Eltafouk: per-account spell-check toggle lookup. Exposed as a
    // store reference so the template / methods can read .isDmEnabled
    // synchronously without any prop drilling.
    const spellCheckSettingsStore = useSpellCheckSettingsStore();

    return {
      uiSettings,
      isEditorHotKeyEnabled,
      fetchSignatureFlagFromUISettings,
      setQuotedReplyFlagForInbox,
      fetchQuotedReplyFlagFromUISettings,
      replyEditor,
      copilot,
      shortcutKey,
      spellCheckSettingsStore,
    };
  },
  data() {
    return {
      message: '',
      inReplyTo: {},
      isFlashing: false,
      isFocused: false,
      showEmojiPicker: false,
      attachedFiles: [],
      isRecordingAudio: false,
      recordingAudioState: '',
      recordingAudioDurationText: '',
      replyType: REPLY_EDITOR_MODES.REPLY,
      bccEmails: '',
      ccEmails: '',
      toEmails: '',
      doAutoSaveDraft: () => {},
      showWhatsAppTemplatesModal: false,
      showContentTemplatesModal: false,
      updateEditorSelectionWith: '',
      undefinedVariableMessage: '',
      showMentions: false,
      showUserMentions: false,
      showCannedMenu: false,
      showVariablesMenu: false,
      newConversationModalActive: false,
      showArticleSearchPopover: false,
      hasRecordedAudio: false,
      copilotAcceptedMessages: {},
      // Eltafouk: pre-send spell-check state. We pre-fetch in the
      // background while the agent types (debounced) so the modal opens
      // instantly when they click send — the cache is keyed by the trimmed
      // body. `spellCheckInFlight` lets a click that lands mid-pre-fetch
      // reuse the in-flight promise instead of starting a new request.
      //
      // `spellCheckBypassOnce` is a single-use bypass flag: when the modal
      // resolves (any option), it flips on so the recursive
      // `confirmOnSendReply()` call doesn't re-open the modal in an
      // infinite loop. Critically, it does NOT persist beyond that one
      // send — the next time the agent hits send (even for identical
      // text), the spell-check runs again. The user asked for "every send
      // re-checks", so we deliberately don't keep a session-wide approval.
      isSpellChecking: false,
      showSpellCheckModal: false,
      spellCheckOriginal: '',
      spellCheckCorrected: '',
      spellCheckFixes: [],
      // Model that actually ran the check (returned by /spell_check). Stashed
      // so the decision-time create can persist model_used on the audit row.
      spellCheckModelUsed: null,
      spellCheckBypassOnce: false,
      // Stores the trimmed text at the moment the agent clicked "تعديل النص".
      // If they press send again with the same unchanged text, we auto-bypass
      // the spell-check and send their original rather than re-opening the
      // modal (which would then auto-send the correction on Enter).
      spellCheckEditedText: null,
      // True between clicking "تعديل النص" and the next send: defers the
      // 'edited' audit row to the send so we record the agent's FINAL text
      // (edited_text). Cleared when a fresh re-check supersedes the edit.
      spellCheckPendingEdited: false,
      spellCheckCache: new Map(),
      spellCheckInFlight: null,
      // Monotonic token: each prefetch bumps it; a resolving prefetch only
      // commits to the cache / clears in-flight if it's still the latest,
      // so superseded burst-typing requests are ignored.
      spellCheckPrefetchSeq: 0,
      debouncedSpellCheckPrefetch: () => {},
      // Eltafouk: race guard against double-Enter. Without this, two
      // confirmOnSendReply invocations can sit on the same spell_check
      // await; the first one wins, clears this.message, then the
      // laggards try to send an empty payload that WhatsApp rejects
      // with "text.body is required".
      isSendInProgress: false,
    };
  },
  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      messageSignature: 'getMessageSignature',
      currentUser: 'getCurrentUser',
      lastEmail: 'getLastEmailInSelectedChat',
      globalConfig: 'globalConfig/get',
      accountId: 'getCurrentAccountId',
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
    }),
    currentContact() {
      const senderId = this.currentChat?.meta?.sender?.id;
      if (!senderId) return {};
      return this.$store.getters['contacts/getContact'](senderId);
    },
    shouldShowReplyToMessage() {
      return (
        this.inReplyTo?.id &&
        !this.isPrivate &&
        this.inboxHasFeature(INBOX_FEATURES.REPLY_TO) &&
        !this.is360DialogWhatsAppChannel
      );
    },
    showWhatsappTemplates() {
      // We support templates for API channels if someone updates templates manually via API
      // That's why we don't explicitly check for channel type here
      const templates = this.$store.getters['inboxes/getWhatsAppTemplates'](
        this.inboxId
      );
      return !!(templates && templates.length) && !this.isPrivate;
    },
    showContentTemplates() {
      return this.isATwilioWhatsAppChannel && !this.isPrivate;
    },
    isPrivate() {
      if (
        this.currentChat.can_reply ||
        this.isAWhatsAppChannel ||
        this.isAPIInbox
      ) {
        return this.isOnPrivateNote;
      }
      return true;
    },
    isReplyRestricted() {
      return (
        !this.currentChat?.can_reply &&
        !(this.isAWhatsAppChannel || this.isAPIInbox)
      );
    },
    inboxId() {
      return this.currentChat.inbox_id;
    },
    inbox() {
      return this.$store.getters['inboxes/getInbox'](this.inboxId);
    },
    messagePlaceHolder() {
      if (this.isEditorDisabled) {
        return this.isAWhatsAppChannel
          ? this.$t('CONVERSATION.FOOTER.MESSAGING_RESTRICTED_WHATSAPP')
          : this.$t('CONVERSATION.FOOTER.MESSAGING_RESTRICTED');
      }
      return this.isPrivate
        ? this.$t('CONVERSATION.FOOTER.PRIVATE_MSG_INPUT')
        : this.$t('CONVERSATION.FOOTER.MSG_INPUT');
    },
    isMessageLengthReachingThreshold() {
      return this.message.length > this.maxLength - 50;
    },
    charactersRemaining() {
      return this.maxLength - this.message.length;
    },
    isReplyButtonDisabled() {
      // Eltafouk: disable the send button visually while a previous send
      // is still in flight, so the agent sees feedback that their click
      // landed and stops mashing Enter.
      if (this.isSendInProgress) return true;
      if (this.isEditorDisabled) return true;
      if (this.isATwitterInbox) return true;
      if (this.hasAttachments || this.hasRecordedAudio) return false;

      return (
        this.isMessageEmpty ||
        this.message.length === 0 ||
        this.message.length > this.maxLength
      );
    },
    sender() {
      return {
        name: this.currentUser.name,
        thumbnail: this.currentUser.avatar_url,
      };
    },
    conversationType() {
      const { additional_attributes: additionalAttributes } = this.currentChat;
      const type = additionalAttributes ? additionalAttributes.type : '';
      return type || '';
    },
    maxLength() {
      if (this.isPrivate) {
        return MESSAGE_MAX_LENGTH.GENERAL;
      }
      if (this.isAFacebookInbox) {
        return MESSAGE_MAX_LENGTH.FACEBOOK;
      }
      if (this.isAnInstagramChannel) {
        return MESSAGE_MAX_LENGTH.INSTAGRAM;
      }
      if (this.isATiktokChannel) {
        return MESSAGE_MAX_LENGTH.TIKTOK;
      }
      if (this.isATwilioWhatsAppChannel) {
        return MESSAGE_MAX_LENGTH.TWILIO_WHATSAPP;
      }
      if (this.isAWhatsAppCloudChannel) {
        return MESSAGE_MAX_LENGTH.WHATSAPP_CLOUD;
      }
      if (this.isASmsInbox) {
        return MESSAGE_MAX_LENGTH.TWILIO_SMS;
      }
      if (this.isAnEmailChannel) {
        return MESSAGE_MAX_LENGTH.EMAIL;
      }
      if (this.isATwilioSMSChannel) {
        return MESSAGE_MAX_LENGTH.TWILIO_SMS;
      }
      if (this.isAWhatsAppChannel) {
        return MESSAGE_MAX_LENGTH.WHATSAPP_CLOUD;
      }
      return MESSAGE_MAX_LENGTH.GENERAL;
    },
    showFileUpload() {
      return (
        this.isAWebWidgetInbox ||
        this.isAFacebookInbox ||
        this.isAWhatsAppChannel ||
        this.isAPIInbox ||
        this.isAnEmailChannel ||
        this.isASmsInbox ||
        this.isATelegramChannel ||
        this.isALineChannel ||
        this.isAnInstagramChannel
      );
    },
    replyButtonLabel() {
      let sendMessageText = this.$t('CONVERSATION.REPLYBOX.SEND');
      if (this.isPrivate) {
        sendMessageText = this.$t('CONVERSATION.REPLYBOX.CREATE');
      }
      const keyLabel = this.isEditorHotKeyEnabled('cmd_enter')
        ? `(${this.shortcutKey})`
        : '(↵)';
      return `${sendMessageText} ${keyLabel}`;
    },
    replyBoxClass() {
      return {
        'is-private': this.isPrivate,
        'is-focused': this.isFocused || this.hasAttachments,
        'transition-all duration-300': true,
        'ring-2 ring-woot-500/50 ring-offset-2 scale-[0.99]': this.isFlashing,
      };
    },
    hasAttachments() {
      return this.attachedFiles.length;
    },
    showAudioRecorder() {
      return !this.isOnPrivateNote && this.showFileUpload;
    },
    showAudioRecorderEditor() {
      return this.showAudioRecorder && this.isRecordingAudio;
    },
    isOnPrivateNote() {
      return this.replyType === REPLY_EDITOR_MODES.NOTE;
    },
    isOnExpandedLayout() {
      const {
        LAYOUT_TYPES: { CONDENSED },
      } = wootConstants;
      const { conversation_display_type: conversationDisplayType = CONDENSED } =
        this.uiSettings;
      return conversationDisplayType !== CONDENSED;
    },
    isMessageEmpty() {
      if (!this.message) {
        return true;
      }
      return !this.message.trim().replace(/\n/g, '').length;
    },
    showReplyHead() {
      return !this.isOnPrivateNote && this.isAnEmailChannel;
    },
    enableMultipleFileUpload() {
      return (
        this.isAnEmailChannel ||
        this.isAWebWidgetInbox ||
        this.isAPIInbox ||
        this.isAWhatsAppChannel ||
        this.isATelegramChannel
      );
    },
    isSignatureEnabledForInbox() {
      return !this.isPrivate && this.sendWithSignature;
    },
    isSignatureAvailable() {
      return !!this.messageSignature;
    },
    sendWithSignature() {
      return this.fetchSignatureFlagFromUISettings(this.channelType);
    },
    conversationId() {
      return this.currentChat.id;
    },
    conversationIdByRoute() {
      return this.conversationId;
    },
    editorStateId() {
      return `draft-${this.conversationIdByRoute}-${this.replyType}`;
    },
    audioRecordFormat() {
      if (this.isAWhatsAppChannel || this.isATelegramChannel) {
        return AUDIO_FORMATS.MP3;
      }
      if (this.isAPIInbox) {
        return AUDIO_FORMATS.MP3;
      }
      return AUDIO_FORMATS.WAV;
    },
    messageVariables() {
      const variables = getMessageVariables({
        conversation: this.currentChat,
        contact: this.currentContact,
        inbox: this.inbox,
      });
      return variables;
    },
    connectedPortalSlug() {
      const { help_center: portal = {} } = this.inbox;
      const { slug = '' } = portal;
      return slug;
    },
    isQuotedEmailReplyEnabled() {
      return this.isFeatureEnabledonAccount(
        this.accountId,
        FEATURE_FLAGS.QUOTED_EMAIL_REPLY
      );
    },
    quotedReplyPreference() {
      if (!this.isAnEmailChannel || !this.isQuotedEmailReplyEnabled) {
        return false;
      }

      return !!this.fetchQuotedReplyFlagFromUISettings(this.channelType);
    },
    lastEmailWithQuotedContent() {
      if (!this.isAnEmailChannel) {
        return null;
      }

      const lastEmail = this.lastEmail;
      if (!lastEmail || lastEmail.private) {
        return null;
      }

      return lastEmail;
    },
    quotedEmailText() {
      return extractQuotedEmailText(this.lastEmailWithQuotedContent);
    },
    quotedEmailPreviewText() {
      return truncatePreviewText(this.quotedEmailText, 80);
    },
    shouldShowQuotedReplyToggle() {
      return (
        this.isAnEmailChannel &&
        !this.isOnPrivateNote &&
        this.isQuotedEmailReplyEnabled
      );
    },
    shouldShowQuotedPreview() {
      return (
        this.shouldShowQuotedReplyToggle &&
        this.quotedReplyPreference &&
        !!this.quotedEmailText
      );
    },
    isDefaultEditorMode() {
      return !this.showAudioRecorderEditor && !this.copilot.isActive.value;
    },
    isEditorDisabled() {
      return (
        this.isAWhatsAppChannel &&
        !this.isOnPrivateNote &&
        !this.currentChat.can_reply
      );
    },
  },
  watch: {
    inboxId: {
      immediate: true,
      handler(id) {
        // Populate the inbox's assignable agents so the @-mention autocomplete
        // (private notes) can restrict suggestions to mentionable users only.
        if (id) {
          this.$store.dispatch('inboxAssignableAgents/fetch', [id]);
        }
      },
    },
    currentChat(conversation, oldConversation) {
      const { can_reply: canReply } = conversation;
      if (oldConversation && oldConversation.id !== conversation.id) {
        // Only update email fields when switching to a completely different conversation (by ID)
        // This prevents overwriting user input (e.g., CC/BCC fields) when performing actions
        // like self-assign or other updates that do not actually change the conversation context
        this.setCCAndToEmailsFromLastChat();
        // Reset Copilot editor state (includes cancelling ongoing generation)
        this.copilot.reset();
      }

      if (this.isOnPrivateNote) {
        return;
      }

      if (canReply || this.isAWhatsAppChannel || this.isAPIInbox) {
        this.replyType = REPLY_EDITOR_MODES.REPLY;
      } else {
        this.replyType = REPLY_EDITOR_MODES.NOTE;
      }

      this.fetchAndSetReplyTo();
    },
    // When moving from one conversation to another, the store may not have the
    // list of all the messages. A fetch is subsequently made to get the messages.
    // This watcher handles two main cases:
    // 1. When switching conversations and messages are fetched/updated, ensures CC/BCC fields are set from the latest OUTGOING/INCOMING email (not activity/private messages).
    // 2. Fixes and issue where CC/BCC fields could be reset/lost after assignment/activity actions or message mutations that did not represent a true email context change.
    lastEmail: {
      handler(lastEmail) {
        if (!lastEmail) return;
        this.setCCAndToEmailsFromLastChat();
      },
      deep: true,
    },
    conversationIdByRoute(conversationId, oldConversationId) {
      if (conversationId !== oldConversationId) {
        this.setToDraft(oldConversationId, this.replyType);
        this.getFromDraft();
        this.resetRecorderAndClearAttachments();
        // Reset spell-check state to prevent cross-conversation leakage
        this.showSpellCheckModal = false;
        this.spellCheckModelUsed = null;
        this.spellCheckBypassOnce = false;
        this.spellCheckOriginal = '';
        this.spellCheckCorrected = '';
        this.spellCheckFixes = [];
        this.spellCheckCache.clear();
        this.spellCheckInFlight = null;
        // Bump the prefetch token so any in-flight request from the previous
        // conversation is treated as stale and dropped on resolve.
        this.spellCheckPrefetchSeq += 1;
        this.spellCheckEditedText = null;
        this.spellCheckPendingEdited = false;
      }
    },
    message() {
      // Autosave the current message draft.
      this.doAutoSaveDraft();
      // Eltafouk: also kick off a background spell-check so the modal
      // can open instantly on send instead of waiting on a fresh API call.
      this.debouncedSpellCheckPrefetch();
    },
    replyType(updatedReplyType, oldReplyType) {
      this.setToDraft(this.conversationIdByRoute, oldReplyType);
      this.getFromDraft();
    },
  },

  mounted() {
    this.getFromDraft();
    // Don't use the keyboard listener mixin here as the events here are supposed to be
    // working even if the editor is focussed.
    document.addEventListener('paste', this.onPaste);
    document.addEventListener('keydown', this.handleKeyEvents);
    this.setCCAndToEmailsFromLastChat();
    this.doAutoSaveDraft = debounce(
      () => {
        this.saveDraft(this.conversationIdByRoute, this.replyType);
      },
      500,
      true
    );

    // Eltafouk: pre-fetch the spell check 500 ms after the agent stops
    // typing. Result lands in `spellCheckCache` keyed by trimmed body so
    // `confirmOnSendReply` can read it instantly. Reduced from 1000 ms to
    // 500 ms (gain ~30% latency): typical pause between "natural" typing
    // bursts is 400-600 ms, so 500 ms catches real pauses without throttling
    // genuine multi-burst messages. Skip private notes, very short drafts,
    // and anything with no Arabic letters (emoji / numbers / links).
    this.debouncedSpellCheckPrefetch = debounce(() => {
      if (this.isPrivate) return;
      if (this.spellCheckSettingsStore?.isDmEnabled === false) return;
      // Key on the signature-stripped body so the send-path lookup (which
      // also strips the signature) actually hits this prefetched result.
      const trimmed = this.spellCheckBody(this.message);
      if (trimmed.length < 3) return;
      if (!/\p{Script=Arabic}/u.test(trimmed)) return;
      if (this.spellCheckCache.has(trimmed)) return;
      if (this.spellCheckInFlight?.trimmed === trimmed) return;
      this.runBackgroundSpellCheck(trimmed);
    }, 500);

    // Lazy-load the settings store once per session so toggle decisions
    // can resolve synchronously from cache afterwards.
    if (!this.spellCheckSettingsStore.uiFlags.loaded) {
      this.spellCheckSettingsStore.fetch();
    }

    this.fetchAndSetReplyTo();
    emitter.on(BUS_EVENTS.TOGGLE_REPLY_TO_MESSAGE, this.fetchAndSetReplyTo);

    // A hacky fix to solve the drag and drop
    // Is showing on top of new conversation modal drag and drop
    // TODO need to find a better solution
    emitter.on(
      BUS_EVENTS.NEW_CONVERSATION_MODAL,
      this.onNewConversationModalActive
    );
    emitter.on(BUS_EVENTS.INSERT_INTO_NORMAL_EDITOR, this.addIntoEditor);
    emitter.on(CMD_AI_ASSIST, this.executeCopilotAction);
  },
  unmounted() {
    document.removeEventListener('paste', this.onPaste);
    document.removeEventListener('keydown', this.handleKeyEvents);
    emitter.off(BUS_EVENTS.TOGGLE_REPLY_TO_MESSAGE, this.fetchAndSetReplyTo);
    emitter.off(BUS_EVENTS.INSERT_INTO_NORMAL_EDITOR, this.addIntoEditor);
    emitter.off(
      BUS_EVENTS.NEW_CONVERSATION_MODAL,
      this.onNewConversationModalActive
    );
    emitter.off(CMD_AI_ASSIST, this.executeCopilotAction);
  },
  methods: {
    getDraftKey(
      conversationId = this.conversationIdByRoute,
      replyType = this.replyType
    ) {
      return `draft-${conversationId}-${replyType}`;
    },
    getCopilotAcceptedMessage(replyType = this.replyType) {
      const key = this.getDraftKey(this.conversationIdByRoute, replyType);
      return this.copilotAcceptedMessages[key] || '';
    },
    setCopilotAcceptedMessage(message, replyType = this.replyType) {
      const key = this.getDraftKey(this.conversationIdByRoute, replyType);
      this.copilotAcceptedMessages[key] = trimContent(message || '');
    },
    clearCopilotAcceptedMessage(replyType = this.replyType) {
      const key = this.getDraftKey(this.conversationIdByRoute, replyType);
      delete this.copilotAcceptedMessages[key];
    },
    handleInsert(article) {
      const { url, title } = article;
      // Removing empty lines from the title
      const lines = title.split('\n');
      const nonEmptyLines = lines.filter(line => line.trim() !== '');
      const filteredMarkdown = nonEmptyLines.join(' ');
      emitter.emit(
        BUS_EVENTS.INSERT_INTO_RICH_EDITOR,
        `[${filteredMarkdown}](${url})`
      );

      useTrack(CONVERSATION_EVENTS.INSERT_ARTICLE_LINK);
    },
    toggleQuotedReply() {
      if (!this.isAnEmailChannel) {
        return;
      }

      const nextValue = !this.quotedReplyPreference;
      this.setQuotedReplyFlagForInbox(this.channelType, nextValue);
    },
    shouldIncludeQuotedEmail() {
      return (
        this.isQuotedEmailReplyEnabled &&
        this.quotedReplyPreference &&
        this.shouldShowQuotedReplyToggle &&
        !!this.quotedEmailText
      );
    },
    getMessageWithQuotedEmailText(message) {
      if (!this.shouldIncludeQuotedEmail()) {
        return message;
      }

      const quotedText = this.quotedEmailText || '';
      const header = buildQuotedEmailHeader(
        this.lastEmailWithQuotedContent,
        this.currentContact,
        this.inbox
      );

      return appendQuotedTextToMessage(message, quotedText, header);
    },
    resetRecorderAndClearAttachments() {
      // Reset audio recorder UI state
      this.resetAudioRecorderInput();
      // Reset attached files
      this.attachedFiles = [];
    },
    saveDraft(conversationId, replyType) {
      if (this.message || this.message === '') {
        const key = this.getDraftKey(conversationId, replyType);
        const draftToSave = trimContent(this.message || '');

        this.$store.dispatch('draftMessages/set', {
          key,
          message: draftToSave,
        });
      }
    },
    setToDraft(conversationId, replyType) {
      this.saveDraft(conversationId, replyType);
      this.message = '';
    },
    getFromDraft() {
      if (this.conversationIdByRoute) {
        const key = this.getDraftKey();
        const messageFromStore =
          this.$store.getters['draftMessages/get'](key) || '';

        // ensure that the message has signature set based on the ui setting
        this.message = this.toggleSignatureForDraft(messageFromStore);
      }
    },
    toggleSignatureForDraft(message) {
      if (this.isPrivate) {
        return message;
      }

      const effectiveChannelType = getEffectiveChannelType(
        this.channelType,
        this.inbox?.medium || ''
      );
      return this.sendWithSignature
        ? appendSignature(message, this.messageSignature, effectiveChannelType)
        : removeSignature(message, this.messageSignature, effectiveChannelType);
    },
    removeFromDraft() {
      if (this.conversationIdByRoute) {
        const key = this.getDraftKey();
        this.$store.dispatch('draftMessages/delete', { key });
      }
    },
    getElementToBind() {
      return this.replyEditor;
    },
    getKeyboardEvents() {
      return {
        Escape: {
          action: () => {
            this.hideEmojiPicker();
          },
          allowOnFocusedInput: true,
        },
        '$mod+KeyK': {
          action: e => {
            e.preventDefault();
            const ninja = document.querySelector('ninja-keys');
            ninja.open();
          },
          allowOnFocusedInput: true,
        },
        Enter: {
          action: e => {
            if (this.isAValidEvent('enter')) {
              this.onSendReply();
              e.preventDefault();
            }
          },
          allowOnFocusedInput: true,
        },
        '$mod+Enter': {
          action: () => {
            if (this.copilot.isActive.value && this.isFocused) {
              this.onSubmitCopilotReply();
            } else if (this.isAValidEvent('cmd_enter')) {
              this.onSendReply();
            }
          },
          allowOnFocusedInput: true,
        },
      };
    },
    isAValidEvent(selectedKey) {
      return (
        !this.showUserMentions &&
        !this.showMentions &&
        !this.showCannedMenu &&
        !this.showVariablesMenu &&
        this.isFocused &&
        this.isEditorHotKeyEnabled(selectedKey)
      );
    },
    onPaste(e) {
      // Don't handle paste if compose new conversation modal is open
      if (this.newConversationModalActive) return;

      // Don't handle paste if editor is disabled
      if (this.isEditorDisabled) return;

      // Filter valid files (non-zero size)
      Array.from(e.clipboardData.files)
        .filter(file => file.size > 0)
        .filter(file => {
          const isAllowed = isFileTypeAllowedForChannel(file, {
            channelType: this.channelType || this.inbox?.channel_type,
            medium: this.inbox?.medium,
            conversationType: this.conversationType,
            isInstagramChannel: this.isAnInstagramChannel,
            isOnPrivateNote: this.isOnPrivateNote,
          });

          if (!isAllowed) {
            useAlert(
              this.$t('CONVERSATION.FILE_TYPE_NOT_SUPPORTED', {
                fileName: file.name,
              })
            );
          }

          return isAllowed;
        })
        .forEach(file => {
          const { name, type, size } = file;
          this.onFileUpload({ name, type, size, file });
        });
    },
    toggleUserMention(currentMentionState) {
      this.showUserMentions = currentMentionState;
    },
    toggleCannedMenu(value) {
      this.showCannedMenu = value;
    },
    toggleVariablesMenu(value) {
      this.showVariablesMenu = value;
    },
    openWhatsappTemplateModal() {
      this.showWhatsAppTemplatesModal = true;
    },
    hideWhatsappTemplatesModal() {
      this.showWhatsAppTemplatesModal = false;
    },
    openContentTemplateModal() {
      this.showContentTemplatesModal = true;
    },
    hideContentTemplatesModal() {
      this.showContentTemplatesModal = false;
    },
    // Eltafouk: the canonical body the spell-check runs on. We always strip
    // the signature (it must never be "corrected", and it must not change the
    // cache key) and trim. Used identically by the prefetcher's cache key and
    // the send-path lookup so a prefetched result is actually reused.
    spellCheckBody(message) {
      let trimmed = (message || '').trim();
      if (this.sendWithSignature && this.messageSignature && !this.isPrivate) {
        const effectiveChannelType = getEffectiveChannelType(
          this.channelType,
          this.inbox?.medium || ''
        );
        trimmed = removeSignature(
          trimmed,
          this.messageSignature,
          effectiveChannelType
        );
      }
      return trimmed;
    },
    // Eltafouk: kick off a spell-check request in the background and
    // populate the cache. Returns the promise so a near-simultaneous send
    // click can await the same in-flight request rather than starting a
    // duplicate one. A monotonic sequence token tags each request; when a
    // later one supersedes it, the stale resolve is dropped (cache write
    // skipped, in-flight slot left untouched) so burst-typing doesn't leave
    // an outdated result cached under a key that's no longer being typed.
    runBackgroundSpellCheck(trimmed) {
      this.spellCheckPrefetchSeq += 1;
      const seq = this.spellCheckPrefetchSeq;
      const promise = TasksAPI.spellCheck(trimmed, 'dm', this.currentChat?.id)
        .then(({ data }) => {
          if (seq === this.spellCheckPrefetchSeq) {
            this.spellCheckCache.set(trimmed, data);
          }
          return data;
        })
        .catch(e => {
          // eslint-disable-next-line no-console
          console.warn('[spell_check] prefetch failed', e);
          return null;
        })
        .finally(() => {
          if (
            seq === this.spellCheckPrefetchSeq &&
            this.spellCheckInFlight?.trimmed === trimmed
          ) {
            this.spellCheckInFlight = null;
          }
        });
      this.spellCheckInFlight = { trimmed, promise, seq };
      return promise;
    },
    // Eltafouk: spell-check modal callbacks. Each "send" path flips
    // `spellCheckBypassOnce` so the recursive `confirmOnSendReply()`
    // skips the modal exactly once — the bypass is consumed on entry
    // to that call. The next send (even for identical text) will run
    // a fresh check; agents asked to be re-prompted every time so they
    // can't accidentally bypass a typo by sending twice.
    // Eltafouk: tiny helper — create the audit-log event at decision time
    // (Solution 3) and fire it in the background. Catch and discard errors;
    // an audit miss must never delay the actual reply. The row is built from
    // the snapshot the stateless check returned, so a typing prefetch that
    // never leads to a send leaves no orphaned row.
    finalizeSpellCheckDecision(decision) {
      TasksAPI.spellCheckDecisionCreate({
        decision,
        original: this.spellCheckOriginal,
        corrected: this.spellCheckCorrected,
        fixes: this.spellCheckFixes,
        surface: 'dm',
        conversationDisplayId: this.currentChat?.id,
        modelUsed: this.spellCheckModelUsed,
      }).catch(() => {});
    },
    // Eltafouk: re-attach the signature that was stripped before the check.
    // The modal works on a signature-stripped body, so the corrected /
    // original text it hands back has no signature; without this the customer
    // would receive a message missing the signature a normal send appends.
    // Mirrors the normal send path's appendSignature (no-op for accounts with
    // signatures disabled or empty signatures).
    withSignature(message) {
      if (this.sendWithSignature && this.messageSignature && !this.isPrivate) {
        const effectiveChannelType = getEffectiveChannelType(
          this.channelType,
          this.inbox?.medium || ''
        );
        return appendSignature(
          message,
          this.messageSignature,
          effectiveChannelType
        );
      }
      return message;
    },
    onSpellCheckSendCorrected(corrected) {
      this.finalizeSpellCheckDecision('corrected');
      this.message = this.withSignature(corrected);
      this.spellCheckBypassOnce = true;
      this.showSpellCheckModal = false;
      this.confirmOnSendReply();
    },
    onSpellCheckSendOriginal(original) {
      this.finalizeSpellCheckDecision('sent_original');
      this.message = this.withSignature(original);
      this.spellCheckBypassOnce = true;
      this.showSpellCheckModal = false;
      this.confirmOnSendReply();
    },
    onSpellCheckEdit() {
      // Defer the 'edited' audit row to the next send so we capture the
      // agent's FINAL text (edited_text) rather than the pre-edit suggestion.
      // confirmOnSendReply creates it then — or clears this flag if a fresh
      // re-check supersedes the edit. Record the snapshot so an unchanged
      // re-send is detected; guard against a spurious empty modal-close.
      this.spellCheckPendingEdited = true;
      const snapshot = this.spellCheckBody(this.message);
      if (snapshot) {
        this.spellCheckEditedText = snapshot;
      }
      this.showSpellCheckModal = false;
    },
    async confirmOnSendReply() {
      // Eltafouk: race guard. A double-Enter (or any rapid re-entry while
      // the spell-check await is in flight) would otherwise stack two
      // concurrent confirmOnSendReply invocations on the same draft. The
      // first one finishes and calls clearMessage(); the second one
      // resumes after its await with this.message already wiped and
      // sends an empty body, which WhatsApp rejects ("text.body is
      // required"). The lock dedupes the click — the second tap is
      // silently dropped instead of producing a phantom failed message.
      if (this.isSendInProgress) {
        return;
      }
      if (this.isReplyButtonDisabled) {
        return;
      }
      if (this.showMentions) {
        return;
      }

      this.isSendInProgress = true;
      try {
        // Eltafouk: pre-send spell/grammar guard. Skipped for private
        // notes (only visible to agents internally), empty messages, and
        // the single send immediately after the modal resolves
        // (`bypassOnce`).
        //
        // We deliberately re-check on every send — including identical
        // text — so the agent can't accidentally bypass corrections by
        // sending the same draft twice. The single-use bypass is only
        // there to prevent the recursive `confirmOnSendReply()` call
        // from re-opening the modal in an infinite loop right after the
        // agent picks an option.
        //
        // Cache strategy: the debounced typing-time prefetcher usually
        // has a result already cached by the time the agent clicks send,
        // so the modal opens instantly. If the cache misses, we await
        // the in-flight prefetch when it's for the same content;
        // otherwise fall back to a fresh blocking call. Failure is
        // fail-open.
        // Capture the conversation we're composing/checking for BEFORE any
        // await. If the agent switches conversation while the spell-check is
        // in flight, this lets us abort rather than leak conversation A's
        // reply into conversation B. (Fail-safe: never send a body into a
        // conversation other than the one it was composed for.)
        const targetConversationId = this.currentChat?.id;
        // Remove signature before spell-check to prevent it from being
        // corrected, and to match the prefetch cache key exactly.
        const trimmed = this.spellCheckBody(this.message);
        // If the agent clicked "تعديل النص" but sent the same unchanged text,
        // treat this send as a bypass — they reviewed and chose to keep the
        // original. Clear the record so subsequent sends re-check normally.
        if (
          this.spellCheckEditedText !== null &&
          trimmed === this.spellCheckEditedText
        ) {
          this.spellCheckEditedText = null;
          this.spellCheckBypassOnce = true;
        }

        // Honor the account-level DM toggle — when an admin disables the
        // guard for DM messages the modal stays out of the agent's way
        // and we never hit the LLM endpoint at all.
        const dmEnabled = this.spellCheckSettingsStore?.isDmEnabled !== false;
        const needsSpellCheck =
          dmEnabled &&
          !this.isPrivate &&
          trimmed.length > 0 &&
          !this.spellCheckBypassOnce;
        // Consume the bypass flag whether or not we ran a check — it's a
        // single-use token, never persists past this confirm.
        this.spellCheckBypassOnce = false;
        if (needsSpellCheck) {
          let data = this.spellCheckCache.get(trimmed);
          if (
            !data &&
            this.spellCheckInFlight?.trimmed === trimmed &&
            this.spellCheckInFlight?.promise
          ) {
            try {
              this.isSpellChecking = true;
              data = await this.spellCheckInFlight.promise;
            } finally {
              this.isSpellChecking = false;
            }
          }
          if (!data) {
            try {
              this.isSpellChecking = true;
              data = await this.runBackgroundSpellCheck(trimmed);
            } finally {
              this.isSpellChecking = false;
            }
          }
          // The agent may have switched conversations while we awaited the
          // spell-check above. Sending now would deliver this draft into the
          // wrong conversation (and opening the modal would attach it to the
          // wrong chat). Abort: the draft stays put for the original chat.
          if (this.currentChat?.id !== targetConversationId) {
            return;
          }
          // The agent may have edited the draft while we awaited the check above, so
          // the snapshot we validated ('trimmed') is now stale and the result can't be
          // trusted for the current body. Abort; the next send re-checks the live text.
          if (this.spellCheckBody(this.message) !== trimmed) {
            return;
          }
          if (data?.has_errors) {
            // A fresh check that found errors supersedes any prior "edit"
            // intent — the agent decides again on this modal.
            this.spellCheckPendingEdited = false;
            this.spellCheckOriginal = data.original || trimmed;
            this.spellCheckCorrected = data.corrected || trimmed;
            this.spellCheckFixes = Array.isArray(data.fixes) ? data.fixes : [];
            // Stash the model that ran so the decision-time create can persist
            // model_used. No event exists yet — the check is stateless; the row
            // is created when the agent picks a modal option (Solution 3).
            this.spellCheckModelUsed = data.model_used || null;
            this.showSpellCheckModal = true;
            return;
          }
          // Clean send: the check ran and found no errors. Persist a
          // 'no_errors_send' audit row (Solution 3) so reports' total_checks
          // stays continuous. Placed AFTER both abort guards above so a
          // stale/aborted check never records, and fired fire-and-forget so it
          // never delays the actual reply below.
          if (data && !data.has_errors && !this.spellCheckPendingEdited) {
            TasksAPI.spellCheckDecisionCreate({
              decision: 'no_errors_send',
              original: data.original || trimmed,
              corrected: data.corrected || trimmed,
              fixes: [],
              surface: 'dm',
              conversationDisplayId: targetConversationId,
              modelUsed: data.model_used,
            }).catch(() => {});
          }
        }

        if (!this.showMentions) {
          // Edit-capture (Solution 3): the agent took over via "تعديل النص",
          // so record 'edited' NOW with the final text being sent (edited_text)
          // plus the suggestion context stashed when the modal opened.
          // Fire-and-forget — never blocks the reply.
          if (this.spellCheckPendingEdited) {
            TasksAPI.spellCheckDecisionCreate({
              decision: 'edited',
              original: this.spellCheckOriginal,
              corrected: this.spellCheckCorrected,
              fixes: this.spellCheckFixes,
              surface: 'dm',
              conversationDisplayId: targetConversationId,
              modelUsed: this.spellCheckModelUsed,
              editedText: trimmed,
            }).catch(() => {});
            this.spellCheckPendingEdited = false;
          }
          const copilotAcceptedMessage = this.getCopilotAcceptedMessage();
          const isOnWhatsApp =
            this.isATwilioWhatsAppChannel ||
            this.isAWhatsAppCloudChannel ||
            this.is360DialogWhatsAppChannel;
          // When users send messages containing both text and attachments on Instagram, Instagram treats them as separate messages.
          // Although Chatwoot combines these into a single message, Instagram sends separate echo events for each component.
          // This can create duplicate messages in Chatwoot. To prevent this issue, we'll handle text and attachments as separate messages.
          const isOnInstagram = this.isAnInstagramChannel;
          if ((isOnWhatsApp || isOnInstagram) && !this.isPrivate) {
            this.sendMessageAsMultipleMessages(
              this.message,
              copilotAcceptedMessage
            );
          } else {
            const messagePayload = this.getMessagePayload(this.message);
            this.sendMessage(
              messagePayload,
              this.message,
              copilotAcceptedMessage
            );
          }

          if (!this.isPrivate) {
            this.clearEmailField();
          }

          this.clearMessage();
          this.hideEmojiPicker();
          this.$emit('update:popOutReplyBox', false);
        }
      } finally {
        // Release the lock even if anything above threw. Always done in
        // the same tick the send-or-modal completes; the modal callbacks
        // call confirmOnSendReply() recursively and will see the flag
        // already cleared by this finally.
        this.isSendInProgress = false;
      }
    },
    sendMessageAsMultipleMessages(message, copilotAcceptedMessage = '') {
      const messages = this.getMultipleMessagesPayload(message);
      messages.forEach(messagePayload => {
        this.sendMessage(
          messagePayload,
          messagePayload.message || '',
          copilotAcceptedMessage
        );
      });
    },
    sendMessageAnalyticsData(
      isPrivate,
      { editorMessage = '', copilotAcceptedMessage = '' } = {}
    ) {
      const normalizeForComparison = message => {
        let normalizedMessage = message || '';

        if (this.sendWithSignature && this.messageSignature && !isPrivate) {
          const effectiveChannelType = getEffectiveChannelType(
            this.channelType,
            this.inbox?.medium || ''
          );
          normalizedMessage = removeSignature(
            normalizedMessage,
            this.messageSignature,
            effectiveChannelType
          );
        }

        return trimContent(normalizedMessage);
      };

      const normalizedAcceptedMessage = normalizeForComparison(
        copilotAcceptedMessage
      );
      const normalizedEditorMessage = normalizeForComparison(editorMessage);

      if (normalizedAcceptedMessage && normalizedEditorMessage) {
        useTrack(CAPTAIN_EVENTS.AI_ASSISTED_MESSAGE_SENT, {
          conversationId: this.conversationIdByRoute,
          channelType: this.channelType,
          editedBeforeSend:
            normalizedAcceptedMessage !== normalizedEditorMessage,
          isPrivate,
        });
      }

      // Analytics data for message signature is enabled or not in channels
      return isPrivate
        ? useTrack(CONVERSATION_EVENTS.SENT_PRIVATE_NOTE)
        : useTrack(CONVERSATION_EVENTS.SENT_MESSAGE, {
            channelType: this.channelType,
            signatureEnabled: this.sendWithSignature,
            hasReplyTo: !!this.inReplyTo?.id,
          });
    },
    async onSendReply() {
      const undefinedVariables = getUndefinedVariablesInMessage({
        message: this.message,
        variables: this.messageVariables,
      });
      if (undefinedVariables.length > 0) {
        const undefinedVariablesCount =
          undefinedVariables.length > 1 ? undefinedVariables.length : 1;
        this.undefinedVariableMessage = this.$t(
          'CONVERSATION.REPLYBOX.UNDEFINED_VARIABLES.MESSAGE',
          {
            undefinedVariablesCount,
            undefinedVariables: undefinedVariables.join(', '),
          }
        );

        const ok = await this.$refs.confirmDialog.showConfirmation();
        if (ok) {
          this.confirmOnSendReply();
        }
      } else {
        this.confirmOnSendReply();
      }
    },
    async sendMessage(
      messagePayload,
      editorMessage = '',
      copilotAcceptedMessage = ''
    ) {
      try {
        await this.$store.dispatch(
          'createPendingMessageAndSend',
          messagePayload
        );
        emitter.emit(BUS_EVENTS.SCROLL_TO_MESSAGE);
        emitter.emit(BUS_EVENTS.MESSAGE_SENT);
        this.removeFromDraft();
        this.sendMessageAnalyticsData(messagePayload.private, {
          editorMessage,
          copilotAcceptedMessage,
        });
      } catch (error) {
        const errorMessage =
          error?.response?.data?.error || this.$t('CONVERSATION.MESSAGE_ERROR');
        useAlert(errorMessage);
      }
    },
    async onSendWhatsAppReply(messagePayload) {
      this.sendMessage({
        conversationId: this.currentChat.id,
        ...messagePayload,
      });
      this.hideWhatsappTemplatesModal();
    },
    async onSendContentTemplateReply(messagePayload) {
      this.sendMessage({
        conversationId: this.currentChat.id,
        ...messagePayload,
      });
      this.hideContentTemplatesModal();
    },
    replaceText(message) {
      if (this.sendWithSignature && !this.private) {
        // if signature is enabled, append it to the message
        // appendSignature ensures that the signature is not duplicated
        // so we don't need to check if the signature is already present
        const effectiveChannelType = getEffectiveChannelType(
          this.channelType,
          this.inbox?.medium || ''
        );
        message = appendSignature(
          message,
          this.messageSignature,
          effectiveChannelType
        );
      }

      const updatedMessage = replaceVariablesInMessage({
        message,
        variables: this.messageVariables,
      });

      setTimeout(() => {
        useTrack(CONVERSATION_EVENTS.INSERTED_A_CANNED_RESPONSE);
        this.message = updatedMessage;
      }, 100);
    },
    setReplyMode(mode = REPLY_EDITOR_MODES.REPLY) {
      // Clear attachments when switching between private note and reply modes
      // This is to prevent from breaking the upload rules
      if (this.attachedFiles.length > 0) this.attachedFiles = [];

      const { can_reply: canReply } = this.currentChat;
      this.$store.dispatch('draftMessages/setReplyEditorMode', {
        mode,
      });
      if (canReply || this.isAWhatsAppChannel || this.isAPIInbox)
        this.replyType = mode;
      if (this.isRecordingAudio) {
        this.toggleAudioRecorder();
      }
    },
    clearEditorSelection() {
      this.updateEditorSelectionWith = '';
    },
    addIntoEditor(content) {
      this.updateEditorSelectionWith = content;
      this.onFocus();
    },
    executeCopilotAction(action, data) {
      this.copilot.execute(action, data);
    },
    clearMessage() {
      this.message = '';
      this.clearCopilotAcceptedMessage();
      if (this.sendWithSignature && !this.isPrivate) {
        // if signature is enabled, append it to the message
        const effectiveChannelType = getEffectiveChannelType(
          this.channelType,
          this.inbox?.medium || ''
        );
        this.message = appendSignature(
          this.message,
          this.messageSignature,
          effectiveChannelType
        );
      }
      this.attachedFiles = [];
      this.isRecordingAudio = false;
      this.resetReplyToMessage();
      this.resetAudioRecorderInput();
    },
    clearEmailField() {
      this.ccEmails = '';
      this.bccEmails = '';
      this.toEmails = '';
    },

    toggleEmojiPicker() {
      this.showEmojiPicker = !this.showEmojiPicker;
    },
    toggleAudioRecorder() {
      this.isRecordingAudio = !this.isRecordingAudio;
      if (!this.isRecordingAudio) {
        this.resetAudioRecorderInput();
      }
    },
    toggleAudioRecorderPlayPause() {
      if (!this.$refs.audioRecorderInput) return;
      if (!this.recordingAudioState) {
        this.$refs.audioRecorderInput.stopRecording();
      } else {
        this.$refs.audioRecorderInput.playPause();
      }
    },
    hideEmojiPicker() {
      if (this.showEmojiPicker) {
        this.toggleEmojiPicker();
      }
    },
    onTypingOn() {
      this.toggleTyping('on');
    },
    onTypingOff() {
      this.toggleTyping('off');
    },
    onBlur() {
      this.isFocused = false;
      this.saveDraft(this.conversationIdByRoute, this.replyType);
    },
    onFocus() {
      this.isFocused = true;
    },
    onRecordProgressChanged(duration) {
      this.recordingAudioDurationText = duration;
    },
    onFinishRecorder(file) {
      this.recordingAudioState = 'stopped';
      this.hasRecordedAudio = true;
      // Added a new key isRecordedAudio to the file to find it's and recorded audio
      // Because to filter and show only non recorded audio and other attachments
      const autoRecordedFile = {
        ...file,
        isRecordedAudio: true,
      };
      return file && this.onFileUpload(autoRecordedFile);
    },
    toggleTyping(status) {
      const conversationId = this.currentChat.id;
      const isPrivate = this.isPrivate;

      if (!conversationId) {
        return;
      }

      this.$store.dispatch('conversationTypingStatus/toggleTyping', {
        status,
        conversationId,
        isPrivate,
      });
    },
    attachFile({ blob, file }) {
      const reader = new FileReader();
      reader.readAsDataURL(file.file);
      reader.onloadend = () => {
        this.attachedFiles.push({
          currentChatId: this.currentChat.id,
          resource: blob || file,
          isPrivate: this.isPrivate,
          thumb: reader.result,
          blobSignedId: blob ? blob.signed_id : undefined,
          isRecordedAudio: file?.isRecordedAudio || false,
        });
      };
    },
    removeAttachment(attachments) {
      this.attachedFiles = attachments;
    },
    setReplyToInPayload(payload) {
      if (this.inReplyTo?.id) {
        return {
          ...payload,
          contentAttributes: {
            ...payload.contentAttributes,
            in_reply_to: this.inReplyTo.id,
          },
        };
      }

      return payload;
    },
    getMultipleMessagesPayload(message) {
      const multipleMessagePayload = [];

      if (this.attachedFiles && this.attachedFiles.length) {
        let caption = this.isAnInstagramChannel ? '' : message;
        this.attachedFiles.forEach(attachment => {
          const attachedFile = this.globalConfig.directUploadsEnabled
            ? attachment.blobSignedId
            : attachment.resource.file;
          let attachmentPayload = {
            conversationId: this.currentChat.id,
            files: [attachedFile],
            private: false,
            message: caption,
            sender: this.sender,
          };

          attachmentPayload = this.setReplyToInPayload(attachmentPayload);
          multipleMessagePayload.push(attachmentPayload);
          // For WhatsApp, only the first attachment gets a caption
          if (!this.isAnInstagramChannel) caption = '';
        });
      }

      const hasNoAttachments =
        !this.attachedFiles || !this.attachedFiles.length;
      // For Instagram, we need a separate text message
      // For WhatsApp, we only need a text message if there are no attachments
      if (
        (this.isAnInstagramChannel && this.message) ||
        (!this.isAnInstagramChannel && hasNoAttachments)
      ) {
        let messagePayload = {
          conversationId: this.currentChat.id,
          message,
          private: false,
          sender: this.sender,
        };

        messagePayload = this.setReplyToInPayload(messagePayload);

        multipleMessagePayload.push(messagePayload);
      }

      return multipleMessagePayload;
    },
    getMessagePayload(message) {
      const messageWithQuote = this.getMessageWithQuotedEmailText(message);

      let messagePayload = {
        conversationId: this.currentChat.id,
        message: messageWithQuote,
        private: this.isPrivate,
        sender: this.sender,
      };
      messagePayload = this.setReplyToInPayload(messagePayload);

      if (this.attachedFiles && this.attachedFiles.length) {
        messagePayload.files = [];
        this.attachedFiles.forEach(attachment => {
          if (this.globalConfig.directUploadsEnabled) {
            messagePayload.files.push(attachment.blobSignedId);
          } else {
            messagePayload.files.push(attachment.resource.file);
          }
        });
      }

      if (this.ccEmails && !this.isOnPrivateNote) {
        messagePayload.ccEmails = this.ccEmails;
      }

      if (this.bccEmails && !this.isOnPrivateNote) {
        messagePayload.bccEmails = this.bccEmails;
      }

      if (this.toEmails && !this.isOnPrivateNote) {
        messagePayload.toEmails = this.toEmails;
      }
      return messagePayload;
    },
    setCcEmails(value) {
      this.bccEmails = value.bccEmails;
      this.ccEmails = value.ccEmails;
    },
    setCCAndToEmailsFromLastChat() {
      const conversationContact = this.currentChat?.meta?.sender?.email || '';
      const { email: inboxEmail, forward_to_email: forwardToEmail } =
        this.inbox;

      const { cc, bcc, to } = getRecipients(
        this.lastEmail,
        conversationContact,
        inboxEmail,
        forwardToEmail
      );

      this.toEmails = to.join(', ');
      this.ccEmails = cc.join(', ');
      this.bccEmails = bcc.join(', ');
    },
    fetchAndSetReplyTo() {
      const replyStorageKey = LOCAL_STORAGE_KEYS.MESSAGE_REPLY_TO;
      const replyToMessageId = LocalStorage.getFromJsonStore(
        replyStorageKey,
        this.conversationId
      );

      this.inReplyTo = this.currentChat?.messages?.find(message => {
        if (message.id === replyToMessageId) {
          return true;
        }
        return false;
      });

      if (this.inReplyTo) {
        this.isFlashing = true;
        setTimeout(() => {
          this.isFlashing = false;
        }, 400);
        // Return the cursor to the editor so the agent can type the reply
        // immediately without having to click into the input again.
        this.$nextTick(() => {
          emitter.emit(BUS_EVENTS.FOCUS_MESSAGE_EDITOR);
        });
      }
    },
    resetReplyToMessage() {
      const replyStorageKey = LOCAL_STORAGE_KEYS.MESSAGE_REPLY_TO;
      LocalStorage.deleteFromJsonStore(replyStorageKey, this.conversationId);
      emitter.emit(BUS_EVENTS.TOGGLE_REPLY_TO_MESSAGE);
    },
    onNewConversationModalActive(isActive) {
      // Issue is if the new conversation modal is open and we drag and drop the file
      // then the file is not getting attached to the new conversation modal
      // and it is getting attached to the current conversation reply box
      // so to fix this we are removing the drag and drop event listener from the current conversation reply box
      // When new conversation modal is open
      this.newConversationModalActive = isActive;
    },
    onSearchPopoverClose() {
      this.showArticleSearchPopover = false;
    },
    toggleInsertArticle() {
      this.showArticleSearchPopover = !this.showArticleSearchPopover;
    },
    resetAudioRecorderInput() {
      this.recordingAudioDurationText = '00:00';
      this.isRecordingAudio = false;
      this.recordingAudioState = '';
      this.hasRecordedAudio = false;
      // Only clear the recorded audio when we click toggle button.
      this.attachedFiles = this.attachedFiles.filter(
        file => !file?.isRecordedAudio
      );
    },
    togglePopout() {
      this.$emit('update:popOutReplyBox', !this.popOutReplyBox);
    },
    onSubmitCopilotReply() {
      const acceptedMessage = this.copilot.accept();
      this.message = acceptedMessage;
      this.setCopilotAcceptedMessage(acceptedMessage);
    },
  },
};
</script>

<template>
  <ReplyBoxBanner :message="message" :is-on-private-note="isOnPrivateNote" />
  <div ref="replyEditor" class="reply-box" :class="replyBoxClass">
    <ReplyTopPanel
      :mode="replyType"
      :conversation-id="conversationId"
      :is-reply-restricted="isReplyRestricted"
      :disabled="
        (copilot.isActive.value && copilot.isButtonDisabled.value) ||
        showAudioRecorderEditor
      "
      :is-editor-disabled="isEditorDisabled"
      :is-message-length-reaching-threshold="isMessageLengthReachingThreshold"
      :characters-remaining="charactersRemaining"
      :popout-reply-box="popOutReplyBox"
      @set-reply-mode="setReplyMode"
      @toggle-popout="togglePopout"
      @toggle-copilot="copilot.toggleEditor"
      @execute-copilot-action="executeCopilotAction"
    />
    <ArticleSearchPopover
      v-if="showArticleSearchPopover && connectedPortalSlug"
      :selected-portal-slug="connectedPortalSlug"
      @insert="handleInsert"
      @close="onSearchPopoverClose"
    />
    <Transition
      mode="out-in"
      enter-active-class="transition-all duration-300 ease-out"
      enter-from-class="opacity-0 translate-y-2 scale-[0.98]"
      enter-to-class="opacity-100 translate-y-0 scale-100"
      leave-active-class="transition-all duration-200 ease-in"
      leave-from-class="opacity-100 translate-y-0 scale-100"
      leave-to-class="opacity-0 translate-y-2 scale-[0.98]"
    >
      <div :key="copilot.editorTransitionKey.value" class="reply-box__top">
        <ReplyToMessage
          v-if="shouldShowReplyToMessage"
          :message="inReplyTo"
          @dismiss="resetReplyToMessage"
        />
        <EmojiInput
          v-if="showEmojiPicker"
          v-on-clickaway="hideEmojiPicker"
          :class="{
            'emoji-dialog--expanded': isOnExpandedLayout || popOutReplyBox,
          }"
          :on-click="addIntoEditor"
        />
        <ReplyEmailHead
          v-if="showReplyHead && isDefaultEditorMode"
          v-model:cc-emails="ccEmails"
          v-model:bcc-emails="bccEmails"
          v-model:to-emails="toEmails"
        />
        <AudioRecorder
          v-if="showAudioRecorderEditor"
          ref="audioRecorderInput"
          :audio-record-format="audioRecordFormat"
          @recorder-progress-changed="onRecordProgressChanged"
          @finish-record="onFinishRecorder"
          @play="recordingAudioState = 'playing'"
          @pause="recordingAudioState = 'paused'"
        />
        <CopilotEditorSection
          v-if="copilot.isActive.value && !showAudioRecorderEditor"
          :show-copilot-editor="copilot.showEditor.value"
          :is-generating-content="copilot.isGenerating.value"
          :generated-content="copilot.generatedContent.value"
          :is-popout="popOutReplyBox"
          :placeholder="$t('CONVERSATION.FOOTER.COPILOT_MSG_INPUT')"
          @focus="onFocus"
          @blur="onBlur"
          @clear-selection="clearEditorSelection"
          @close="copilot.showEditor.value = false"
          @content-ready="copilot.setContentReady"
          @send="copilot.sendFollowUp"
        />
        <WootMessageEditor
          v-else-if="!showAudioRecorderEditor"
          v-model="message"
          :conversation-id="conversationId"
          :inbox-id="inboxId"
          :editor-id="editorStateId"
          class="input popover-prosemirror-menu"
          :is-private="isOnPrivateNote"
          :placeholder="messagePlaceHolder"
          :update-selection-with="updateEditorSelectionWith"
          :min-height="4"
          :disabled="isEditorDisabled"
          enable-variables
          :variables="messageVariables"
          :signature="messageSignature"
          allow-signature
          :channel-type="channelType"
          :medium="inbox.medium"
          @typing-off="onTypingOff"
          @typing-on="onTypingOn"
          @focus="onFocus"
          @blur="onBlur"
          @toggle-user-mention="toggleUserMention"
          @toggle-canned-menu="toggleCannedMenu"
          @toggle-variables-menu="toggleVariablesMenu"
          @clear-selection="clearEditorSelection"
          @execute-copilot-action="executeCopilotAction"
        />

        <QuotedEmailPreview
          v-if="shouldShowQuotedPreview && isDefaultEditorMode"
          :quoted-email-text="quotedEmailText"
          :preview-text="quotedEmailPreviewText"
          class="mb-2"
          @toggle="toggleQuotedReply"
        />

        <div
          v-if="hasAttachments && isDefaultEditorMode"
          class="bg-transparent py-0 mb-2"
          @paste="onPaste"
        >
          <AttachmentPreview
            class="mt-2"
            :attachments="attachedFiles"
            @remove-attachment="removeAttachment"
          />
        </div>
        <MessageSignatureMissingAlert
          v-if="
            isSignatureEnabledForInbox &&
            !isSignatureAvailable &&
            isDefaultEditorMode
          "
          class="mb-2"
        />
      </div>
    </Transition>

    <Transition
      mode="out-in"
      enter-active-class="transition-all duration-300 ease-out"
      enter-from-class="opacity-0 translate-y-2 scale-[0.98]"
      enter-to-class="opacity-100 translate-y-0 scale-100"
      leave-active-class="transition-all duration-200 ease-in"
      leave-from-class="opacity-100 translate-y-0 scale-100"
      leave-to-class="opacity-0 translate-y-2 scale-[0.98]"
    >
      <CopilotReplyBottomPanel
        v-if="copilot.isActive.value"
        key="copilot-bottom-panel"
        :is-generating-content="copilot.isButtonDisabled.value"
        @submit="onSubmitCopilotReply"
        @cancel="copilot.reset"
      />
      <ReplyBottomPanel
        v-else
        key="reply-bottom-panel"
        :conversation-id="conversationId"
        :enable-multiple-file-upload="enableMultipleFileUpload"
        :enable-whats-app-templates="showWhatsappTemplates"
        :enable-content-templates="showContentTemplates"
        :inbox="inbox"
        :is-on-private-note="isOnPrivateNote"
        :is-recording-audio="isRecordingAudio"
        :is-send-disabled="isReplyButtonDisabled"
        :is-note="isPrivate"
        :is-editor-disabled="isEditorDisabled"
        :on-file-upload="onFileUpload"
        :on-send="onSendReply"
        :conversation-type="conversationType"
        :recording-audio-duration-text="recordingAudioDurationText"
        :recording-audio-state="recordingAudioState"
        :send-button-text="replyButtonLabel"
        :show-audio-recorder="showAudioRecorder"
        :show-emoji-picker="showEmojiPicker"
        :show-file-upload="showFileUpload"
        :show-quoted-reply-toggle="shouldShowQuotedReplyToggle"
        :quoted-reply-enabled="quotedReplyPreference"
        :toggle-audio-recorder-play-pause="toggleAudioRecorderPlayPause"
        :toggle-audio-recorder="toggleAudioRecorder"
        :toggle-emoji-picker="toggleEmojiPicker"
        :message="message"
        :portal-slug="connectedPortalSlug"
        :new-conversation-modal-active="newConversationModalActive"
        @select-whatsapp-template="openWhatsappTemplateModal"
        @select-content-template="openContentTemplateModal"
        @replace-text="replaceText"
        @toggle-insert-article="toggleInsertArticle"
        @toggle-quoted-reply="toggleQuotedReply"
      />
    </Transition>

    <WhatsappTemplates
      :inbox-id="inbox.id"
      :show="showWhatsAppTemplatesModal"
      @close="hideWhatsappTemplatesModal"
      @on-send="onSendWhatsAppReply"
      @cancel="hideWhatsappTemplatesModal"
    />

    <ContentTemplates
      :inbox-id="inbox.id"
      :show="showContentTemplatesModal"
      @close="hideContentTemplatesModal"
      @on-send="onSendContentTemplateReply"
      @cancel="hideContentTemplatesModal"
    />

    <woot-confirm-modal
      ref="confirmDialog"
      :title="$t('CONVERSATION.REPLYBOX.UNDEFINED_VARIABLES.TITLE')"
      :description="undefinedVariableMessage"
    />

    <!-- Eltafouk: pre-send spell-check confirmation modal -->
    <SpellCheckModal
      :show="showSpellCheckModal"
      :original="spellCheckOriginal"
      :corrected="spellCheckCorrected"
      :fixes="spellCheckFixes"
      @update:show="showSpellCheckModal = $event"
      @send-corrected="onSpellCheckSendCorrected"
      @send-original="onSpellCheckSendOriginal"
      @edit="onSpellCheckEdit"
    />
  </div>
</template>

<style lang="scss" scoped>
.send-button {
  @apply mb-0;
}

.reply-box {
  @apply relative mb-2 mx-2 border border-n-weak rounded-xl bg-n-solid-1;

  &.is-private {
    @apply bg-n-solid-amber dark:border-n-amber-3/10 border-n-amber-12/5;
  }
}

.send-button {
  @apply mb-0;
}

.reply-box__top {
  @apply relative py-0 px-4 -mt-px;
}

.emoji-dialog {
  @apply top-[unset] -bottom-10 ltr:-left-80 ltr:right-[unset] rtl:left-[unset] rtl:-right-80;

  &::before {
    filter: drop-shadow(0px 4px 4px rgba(0, 0, 0, 0.08));
    @apply ltr:-right-4 bottom-2 rtl:-left-4 ltr:rotate-[270deg] rtl:rotate-[90deg];
  }
}

.emoji-dialog--expanded {
  @apply left-[unset] bottom-0 absolute z-[100];

  &::before {
    transform: rotate(0deg);
    @apply ltr:left-1 rtl:right-1 -bottom-2;
  }
}
</style>
